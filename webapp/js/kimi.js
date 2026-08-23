/* ============================================================================
 * Kimi Proxy Web — core module (Agent B / infra-js)
 * window.Kimi: state store + event bus + sessions + settings + shortcuts.
 * Load FIRST (before icons.js, bridge.js, toast.js, render-js, ui-js).
 * Contract: ARCHITECTURE.md §3 (Global API), §5 (wire protocol).
 * ========================================================================== */
(function () {
  'use strict';

  if (window.Kimi && window.Kimi.__core) return; // guard against double load

  /* ------------------------------------------------------------------ utils */

  function uid(prefix) {
    var bytes = new Uint8Array(8);
    if (window.crypto && window.crypto.getRandomValues) {
      window.crypto.getRandomValues(bytes);
    } else {
      for (var i = 0; i < 8; i++) bytes[i] = Math.floor(Math.random() * 256);
    }
    var hex = '';
    for (var j = 0; j < bytes.length; j++) hex += ('0' + bytes[j].toString(16)).slice(-2);
    return (prefix || 'id_') + hex;
  }

  function now() { return Date.now(); }

  /* --------------------------------------------------------------- the core */

  var DEFAULTS = {
    bridgeUrl: '',          // '' => ws://<location.hostname>:8765
    theme: 'dark',          // dark | light | system
    fontSize: 'medium',     // small | medium | large | xlarge
    defaultMode: 'auto',    // auto | yolo | plan
    defaultModel: 'kimi',   // kimi | gpt-4.1-nano | gpt-4.1-mini | gpt-4o | deepseek
    exportFormat: 'md',     // md | json
  };

  var STORE_SESSIONS_KEY = 'kimi.sessions';
  var STORE_SETTINGS_KEY = 'kimi.settings';

  /* Event bus — synchronous pub/sub. Emit signature: emit(evt, data). */
  var handlers = {};

  var bus = {
    on: function (evt, fn) {
      (handlers[evt] || (handlers[evt] = [])).push(fn);
      return fn;
    },
    off: function (evt, fn) {
      var l = handlers[evt];
      if (!l) return;
      var i = l.indexOf(fn);
      if (i > -1) l.splice(i, 1);
    },
    emit: function (evt, data) {
      var l = handlers[evt];
      if (!l || !l.length) return;
      // snapshot so listeners can on/off during dispatch
      var arr = l.slice();
      for (var i = 0; i < arr.length; i++) {
        try {
          arr[i](data === undefined ? {} : data, evt);
        } catch (err) {
          if (window.console && console.error) console.error('[kimi bus] handler for "' + evt + '" failed:', err);
        }
      }
    },
  };

  /* ------------------------------------------------------------- sessions */

  function defaultSession(name) {
    var mode = Kimi.settings.get('defaultMode', DEFAULTS.defaultMode);
    var s = {
      id: uid('s_'),
      name: name || 'New Chat',
      workDir: null,
      status: 'idle',            // idle | streaming | thinking | toolRunning | error
      model: Kimi.settings.get('defaultModel', DEFAULTS.defaultModel),
      yolo: mode === 'yolo',
      planMode: mode === 'plan',
      createdAt: now(),
      updatedAt: now(),
      messageCount: 0,
      messages: [],              // Msg[]
      tools: [],                 // ToolEntry[] for current/last turn
      kimiSessionId: null,       // opaque resume id (server-internal; kept for parity)
      serverId: null,            // wire id (server randomUUID) — bridge-side, see ARCHITECTURE.md §5
    };
    return s;
  }

  function sanitizeSession(s) {
    if (!s || typeof s !== 'object') return null;
    s.messages = Array.isArray(s.messages) ? s.messages : [];
    s.tools = Array.isArray(s.tools) ? s.tools : [];
    s.status = s.status || 'idle';
    s.createdAt = s.createdAt || now();
    s.updatedAt = s.updatedAt || now();
    s.messageCount = s.messages.length;
    if (typeof s.serverId === 'undefined') s.serverId = null;
    if (typeof s.kimiSessionId === 'undefined') s.kimiSessionId = null;
    return s;
  }

  function loadSessions() {
    try {
      var raw = window.localStorage.getItem(STORE_SESSIONS_KEY);
      if (!raw) return;
      var parsed = JSON.parse(raw);
      if (parsed && Array.isArray(parsed.sessions)) {
        Kimi.state.sessions = parsed.sessions.map(sanitizeSession).filter(Boolean);
        var active = parsed.activeId;
        if (active && Kimi.sessions.get(active)) Kimi.state.activeId = active;
      } else if (Array.isArray(parsed)) {
        Kimi.state.sessions = parsed.map(sanitizeSession).filter(Boolean);
      }
    } catch (err) {
      if (window.console) console.warn('[kimi] failed to load sessions:', err);
    }
  }

  function persistSessions() {
    try {
      window.localStorage.setItem(
        STORE_SESSIONS_KEY,
        JSON.stringify({ sessions: Kimi.state.sessions, activeId: Kimi.state.activeId })
      );
    } catch (err) {
      if (window.console) console.warn('[kimi] failed to persist sessions:', err);
    }
  }

  function touch(session) {
    if (session) {
      session.updatedAt = now();
      session.messageCount = session.messages.length;
    }
    return session;
  }

  function emitChanged() {
    bus.emit('sessions.changed');
  }

  var sessions = {
    /* Internal — used by bridge.js after wire mutations. */
    _persist: persistSessions,
    _touch: touch,

    /* Internal — build an app Session from a server session (wire §5). */
    _fromServer: function (ss) {
      if (!ss || !ss.id) return null;
      var s = sanitizeSession(defaultSession(ss.name));
      s.serverId = ss.id;
      if (typeof ss.model !== 'undefined' && ss.model !== null) s.model = ss.model;
      if (typeof ss.yolo === 'boolean') s.yolo = ss.yolo;
      if (typeof ss.planMode === 'boolean') s.planMode = ss.planMode;
      if (ss.workDir) s.workDir = ss.workDir;
      if (ss.status) s.status = ss.status;
      if (ss.messageCount) s.messageCount = ss.messageCount;
      if (ss.createdAt) s.createdAt = new Date(ss.createdAt).getTime();
      if (ss.updatedAt) s.updatedAt = new Date(ss.updatedAt).getTime();
      return s;
    },

    create: function (name) {
      var s = sanitizeSession(defaultSession(name));
      Kimi.state.sessions.push(s);
      persistSessions();
      bus.emit('session.created', { session: s });
      emitChanged();
      sessions.select(s.id);
      // Tell the bridge server about it (best-effort; server echoes session.created).
      if (Kimi.state.connection === 'online' && Kimi.bridge) {
        Kimi.bridge.send({
          type: 'session.create',
          name: s.name,
          workDir: s.workDir,
          model: s.model,
        });
      }
      return s;
    },

    select: function (id) {
      if (!sessions.get(id)) return;
      Kimi.state.activeId = id;
      persistSessions();
      bus.emit('session.selected', { id: id });
      emitChanged();
    },

    rename: function (id, name) {
      var s = sessions.get(id);
      if (!s || !name) return;
      s.name = name;
      touch(s);
      persistSessions();
      emitChanged();
      if (Kimi.state.connection === 'online' && Kimi.bridge) {
        Kimi.bridge.send({ type: 'session.rename', sessionId: id, name: name });
      }
    },

    remove: function (id) {
      var s = sessions.get(id);
      if (!s) return;
      var i = Kimi.state.sessions.indexOf(s);
      Kimi.state.sessions.splice(i, 1);
      if (Kimi.state.activeId === id) {
        var next = Kimi.state.sessions.length ? Kimi.state.sessions[0].id : null;
        Kimi.state.activeId = next;
        if (next) bus.emit('session.selected', { id: next });
      }
      persistSessions();
      bus.emit('session.deleted', { sessionId: id });
      emitChanged();
      if (Kimi.state.connection === 'online' && Kimi.bridge) {
        Kimi.bridge.send({ type: 'session.delete', sessionId: id });
      }
    },

    list: function () { return Kimi.state.sessions; },

    get: function (id) {
      for (var i = 0; i < Kimi.state.sessions.length; i++) {
        if (Kimi.state.sessions[i].id === id) return Kimi.state.sessions[i];
      }
      return null;
    },

    current: function () { return sessions.get(Kimi.state.activeId); },

    export: function (id, format) {
      var s = sessions.get(id);
      if (!s) return;
      var fmt = format || Kimi.settings.get('exportFormat', DEFAULTS.exportFormat) || 'md';
      var text = fmt === 'json' ? JSON.stringify(s, null, 2) : exportMarkdown(s);
      var blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
      var a = document.createElement('a');
      var safe = (s.name || 'chat').replace(/[^\w\- ]+/g, '').trim() || 'chat';
      a.href = URL.createObjectURL(blob);
      a.download = safe + '.' + (fmt === 'json' ? 'json' : 'md');
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(function () { URL.revokeObjectURL(a.href); }, 2000);
    },
  };

  function exportMarkdown(s) {
    var lines = ['# ' + s.name, '', '_' + new Date(s.createdAt).toISOString() + '_', ''];
    s.messages.forEach(function (m) {
      var head = m.role === 'user' ? '## User' : m.role === 'system' ? '## System' : '## Assistant';
      lines.push(head, '');
      if (m.thinking) lines.push('> Thinking:\n>\n> ' + m.thinking.replace(/\n/g, '\n> '), '');
      if (m.content) lines.push(m.content, '');
      if (m.toolCalls && m.toolCalls.length) {
        lines.push('*Tools:* ' + m.toolCalls.join(', '), '');
      }
    });
    return lines.join('\n');
  }

  /* -------------------------------------------------------------- settings */

  function loadSettings() {
    try {
      var raw = window.localStorage.getItem(STORE_SETTINGS_KEY);
      var parsed = raw ? JSON.parse(raw) : {};
      var merged = {};
      Object.keys(DEFAULTS).forEach(function (k) { merged[k] = DEFAULTS[k]; });
      if (parsed && typeof parsed === 'object') {
        Object.keys(parsed).forEach(function (k) { merged[k] = parsed[k]; });
      }
      Kimi.state.settings = merged;
    } catch (err) {
      Kimi.state.settings = {};
      if (window.console) console.warn('[kimi] failed to load settings:', err);
    }
  }

  function persistSettings() {
    try {
      window.localStorage.setItem(STORE_SETTINGS_KEY, JSON.stringify(Kimi.state.settings));
    } catch (err) {
      if (window.console) console.warn('[kimi] failed to persist settings:', err);
    }
  }

  function resolveTheme(theme) {
    if (theme === 'system') {
      return window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
    }
    return theme === 'light' ? 'light' : 'dark';
  }

  var FONT_SIZES = { small: '13px', medium: '14px', large: '16px', xlarge: '18px' };

  function applyTheme() {
    var resolved = resolveTheme(Kimi.state.settings.theme);
    document.documentElement.setAttribute('data-theme', resolved);
  }

  function applyFontSize() {
    var size = Kimi.state.settings.fontSize || DEFAULTS.fontSize;
    document.documentElement.setAttribute('data-font-size', size);
    document.documentElement.style.fontSize = FONT_SIZES[size] || '14px';
  }

  var settings = {
    get: function (k, dflt) {
      var v = Kimi.state.settings[k];
      return v === undefined || v === null ? (dflt !== undefined ? dflt : DEFAULTS[k]) : v;
    },
    set: function (k, v) {
      Kimi.state.settings[k] = v;
      persistSettings();
      if (k === 'theme') applyTheme();
      if (k === 'fontSize') applyFontSize();
      return v;
    },
    toggle: function (k) {
      var v = !settings.get(k, false);
      settings.set(k, v);
      return v;
    },
  };

  /* ------------------------------------------------------------ shortcuts */

  // combo grammar: 'mod+n', 'mod+shift+p', 'escape', 'ctrl+,', 'mod+up'…
  function normalizeKey(key) {
    key = String(key).toLowerCase().trim();
    var map = {
      esc: 'escape', up: 'arrowup', down: 'arrowdown', left: 'arrowleft', right: 'arrowright',
      space: ' ', return: 'enter', plus: '+', comma: ',', period: '.', slash: '/',
    };
    return map[key] || key;
  }

  function matchCombo(parts, e) {
    var needMod = false, needCtrl = false, needAlt = false, needShift = false, needMeta = false;
    var key = null;
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i];
      if (p === 'mod') needMod = true;
      else if (p === 'ctrl') needCtrl = true;
      else if (p === 'alt') needAlt = true;
      else if (p === 'shift') needShift = true;
      else if (p === 'meta') needMeta = true;
      else key = normalizeKey(p);
    }
    var modPressed = e.ctrlKey || e.metaKey;
    if (needMod && !modPressed) return false;
    if (needCtrl && !e.ctrlKey) return false;
    if (needMeta && !e.metaKey) return false;
    if (needAlt !== !!e.altKey) return false;
    if (needShift !== !!e.shiftKey) return false;
    if (key !== null) {
      var pressed = normalizeKey(e.key);
      if (pressed !== key) return false;
    } else {
      if (modPressed) return false; // modifier-only combos need a key
    }
    return true;
  }

  function isEditable(target) {
    if (!target) return false;
    var t = target.tagName;
    return t === 'INPUT' || t === 'TEXTAREA' || t === 'SELECT' || target.isContentEditable;
  }

  var shortcutItems = [];

  var shortcuts = {
    _items: shortcutItems,
    modKey: (navigator.platform && /Mac|iPhone|iPad/.test(navigator.platform)) ? 'meta' : 'ctrl',

    register: function (combo, desc, fn) {
      shortcutItems.push({ combo: String(combo).toLowerCase(), parts: String(combo).toLowerCase().split('+'), desc: desc, fn: fn });
      return fn;
    },

    /* Manual dispatch — returns true when a shortcut matched. */
    handleKey: function (e) {
      for (var i = 0; i < shortcutItems.length; i++) {
        var item = shortcutItems[i];
        var hasMod = item.parts.indexOf('mod') > -1 || item.parts.indexOf('ctrl') > -1 || item.parts.indexOf('meta') > -1;
        if (!hasMod && isEditable(e.target)) continue; // don't hijack typing
        if (matchCombo(item.parts, e)) {
          if (e.preventDefault) e.preventDefault();
          if (e.stopPropagation) e.stopPropagation();
          try { item.fn(e, item); } catch (err) { if (window.console) console.error('[kimi] shortcut failed:', err); }
          return true;
        }
      }
      return false;
    },
  };

  /* ----------------------------------------------------------- bridge stub */

  // Real implementation lives in bridge.js (load order §2). Stub keeps the API
  // shape per §3 present even before bridge.js runs.
  var bridgeStub = {
    connect: function () {}, disconnect: function () {}, send: function () {},
    autoReconnect: true,
    get status() { return Kimi.state.connection; },
  };

  /* ---------------------------------------------------------- placeholders */

  // Filled by their owning modules (render-js, ui-js); stubs avoid crashes if
  // something calls before those files load.
  var noop = function () {};
  var stubFns = {
    render: {
      markdownToHtml: function (s) { return s; }, message: noop, thinkingRow: noop, toolCallLine: noop,
      toolOutputBlock: noop, activityRun: noop, escapeHtml: function (s) { return String(s == null ? '' : s); },
      highlightCode: function (s) { return s; },
    },
    toast: { show: noop, success: noop, error: noop, info: noop },
    palette: { open: noop, close: noop, setItems: noop, isOpen: function () { return false; } },
  };

  /* ----------------------------------------------------------------- init */

  var initialized = false;

  function init() {
    if (initialized) return Kimi;
    initialized = true;
    loadSettings();
    applyTheme();
    applyFontSize();
    loadSessions();
    if (window.matchMedia) {
      window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', function () {
        if (Kimi.state.settings.theme === 'system') applyTheme();
      });
    }
    document.addEventListener('keydown', shortcuts.handleKey);
    bus.emit('sessions.changed');
    return Kimi;
  }

  /* --------------------------------------------------------------- export */

  var Kimi = {
    version: '0.1.0',
    __core: true,
    uid: uid,

    state: {
      sessions: [],
      activeId: null,
      connection: 'offline', // offline | connecting | online
      settings: {},
      ui: { sidebarOpen: false, paletteOpen: false, workPanelOpen: false },
    },

    bus: bus,
    bridge: bridgeStub,
    sessions: sessions,
    settings: settings,
    shortcuts: shortcuts,
    init: init,

    // slots filled by other modules
    icons: {},
    render: stubFns.render,
    toast: stubFns.toast,
    palette: stubFns.palette,
  };

  window.Kimi = Kimi;
})();
