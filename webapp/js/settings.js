/* Kimi Proxy Web — js/settings.js  (ui-js)
 * Settings modal per ARCHITECTURE.md §3/§9: bridge URL, theme (dark/light/
 * system), font size stepper (small/medium/large/xlarge), default mode,
 * default model, export format, clear-all-sessions (with confirm), version
 * footer. Persists through Kimi.settings (localStorage 'kimi.settings').
 * Renders inside the contract id #settings-modal. */
(function () {
  'use strict';

  const Kimi = window.Kimi;
  const q = (sel) => document.querySelector(sel);

  const FONT_STEPS = ['small', 'medium', 'large', 'xlarge'];

  function h(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  function icon(name, cls) {
    const s = h('span', 'icon' + (cls ? ' ' + cls : ''));
    s.innerHTML = Kimi.icons[name] || '';
    return s;
  }
  function label(text) {
    return h('label', 'field-label', text);
  }
  function field(cls) {
    return h('div', 'field' + (cls ? ' ' + cls : ''));
  }

  const els = {};
  let _mq = null;

  /* ---------- defaults ---------- */
  function defaultBridgeUrl() {
    const proto = location.protocol === 'https:' ? 'wss://' : 'ws://';
    return proto + (location.hostname || 'localhost') + ':8765';
  }

  /* ---------- theme ---------- */
  function applyTheme(value) {
    const t = value || Kimi.settings.get('theme', 'dark') || 'dark';
    Kimi.settings.set('theme', t);
    const resolved = t === 'system'
      ? (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark')
      : t;
    document.documentElement.setAttribute('data-theme', resolved);
    if (t === 'system') {
      if (!_mq) {
        _mq = window.matchMedia('(prefers-color-scheme: light)');
        _mq.addEventListener('change', () => applyTheme('system'));
      }
    }
    if (els.theme) els.theme.value = t;
  }

  /* ---------- font size ---------- */
  function applyFontSize(value) {
    const v = value || Kimi.settings.get('fontSize', 'medium') || 'medium';
    // Kimi.settings.set('fontSize') triggers kimi.js applyFontSize, which sets
    // the root inline font-size + [data-font-size]; we mirror [data-font-scale]
    // as a hook for css/app.css.
    Kimi.settings.set('fontSize', v);
    document.documentElement.setAttribute('data-font-scale', v);
    if (els.fontLabel) {
      els.fontLabel.textContent = v.charAt(0).toUpperCase() + v.slice(1);
    }
  }

  function stepFont(delta) {
    const cur = Kimi.settings.get('fontSize', 'medium') || 'medium';
    const i = FONT_STEPS.indexOf(cur);
    const next = FONT_STEPS[Math.max(0, Math.min(FONT_STEPS.length - 1, (i === -1 ? 1 : i) + delta))];
    applyFontSize(next);
  }

  /* ---------- modal shell ---------- */
  function ensure() {
    if (els.modal) return els;
    els.modal = q('#settings-modal');
    if (!els.modal) return els;
    if (els.modal.querySelector('.settings-box')) {
      els.box = els.modal.querySelector('.settings-box');
      els.closeBtn = els.modal.querySelector('.settings-close');
      return els;
    }

    els.box = h('div', 'settings-box');
    els.box.setAttribute('role', 'dialog');
    els.box.setAttribute('aria-label', 'Settings');

    const head = h('div', 'settings-head');
    head.appendChild(h('h2', 'settings-title', 'Settings'));
    els.closeBtn = h('button', 'icon-btn settings-close');
    els.closeBtn.type = 'button';
    els.closeBtn.setAttribute('aria-label', 'Close settings');
    els.closeBtn.appendChild(icon('close'));
    head.appendChild(els.closeBtn);
    els.box.appendChild(head);

    const body = h('div', 'settings-body');

    /* connection */
    const secConn = h('section', 'settings-section');
    secConn.appendChild(h('h3', 'settings-title', 'Connection'));
    const fUrl = field();
    fUrl.appendChild(label('Bridge URL'));
    els.url = h('input', 'text-input');
    els.url.type = 'text';
    els.url.spellcheck = false;
    els.url.placeholder = defaultBridgeUrl();
    els.url.value = Kimi.settings.get('bridgeUrl', '') || defaultBridgeUrl();
    const rowUrl = h('div', 'field-row');
    const reconnectBtn = h('button', 'btn ghost-btn', 'Connect');
    reconnectBtn.type = 'button';
    rowUrl.appendChild(els.url);
    rowUrl.appendChild(reconnectBtn);
    fUrl.appendChild(rowUrl);
    secConn.appendChild(fUrl);
    body.appendChild(secConn);

    /* appearance */
    const secApp = h('section', 'settings-section');
    secApp.appendChild(h('h3', 'settings-title', 'Appearance'));
    const fTheme = field();
    fTheme.appendChild(label('Theme'));
    els.theme = h('select', 'select-input');
    [['dark', 'Dark'], ['light', 'Light'], ['system', 'System']].forEach((pair) => {
      const o = h('option', null, pair[1]);
      o.value = pair[0];
      els.theme.appendChild(o);
    });
    fTheme.appendChild(els.theme);
    secApp.appendChild(fTheme);

    const fFont = field();
    fFont.appendChild(label('Font size'));
    const stepper = h('div', 'stepper');
    const minus = h('button', 'stepper-btn', '−');
    minus.type = 'button';
    minus.setAttribute('aria-label', 'Decrease font size');
    els.fontLabel = h('span', 'stepper-value', 'Medium');
    const plus = h('button', 'stepper-btn', '+');
    plus.type = 'button';
    plus.setAttribute('aria-label', 'Increase font size');
    stepper.appendChild(minus);
    stepper.appendChild(els.fontLabel);
    stepper.appendChild(plus);
    fFont.appendChild(stepper);
    secApp.appendChild(fFont);
    body.appendChild(secApp);

    /* defaults */
    const secDef = h('section', 'settings-section');
    secDef.appendChild(h('h3', 'settings-title', 'Defaults'));
    const fMode = field();
    fMode.appendChild(label('Default mode'));
    els.mode = h('select', 'select-input');
    [['auto', 'Auto'], ['plan', 'Plan'], ['yolo', 'YOLO']].forEach((pair) => {
      const o = h('option', null, pair[1]);
      o.value = pair[0];
      els.mode.appendChild(o);
    });
    fMode.appendChild(els.mode);
    secDef.appendChild(fMode);

    const fModel = field();
    fModel.appendChild(label('Default model'));
    els.modelSel = h('select', 'select-input');
    const models = Kimi.settings.get('models', null);
    const list = Array.isArray(models) && models.length ? models : ['kimi'];
    list.forEach((m) => {
      const o = h('option', null, m);
      o.value = m;
      els.modelSel.appendChild(o);
    });
    fModel.appendChild(els.modelSel);
    secDef.appendChild(fModel);

    const fExp = field();
    fExp.appendChild(label('Session export format'));
    els.format = h('select', 'select-input');
    [['md', 'Markdown (.md)'], ['json', 'JSON (.json)']].forEach((pair) => {
      const o = h('option', null, pair[1]);
      o.value = pair[0];
      els.format.appendChild(o);
    });
    fExp.appendChild(els.format);
    secDef.appendChild(fExp);
    body.appendChild(secDef);

    /* data */
    const secData = h('section', 'settings-section');
    secData.appendChild(h('h3', 'settings-title', 'Data'));
    const fClear = field();
    fClear.appendChild(label('Sessions'));
    const clearBtn = h('button', 'danger-btn', 'Clear all sessions');
    clearBtn.type = 'button';
    fClear.appendChild(clearBtn);
    secData.appendChild(fClear);
    body.appendChild(secData);

    els.box.appendChild(body);

    const foot = h('div', 'settings-foot');
    foot.appendChild(h('span', 'version', 'Kimi Proxy v' + (Kimi.version || '0.1.0')));
    foot.appendChild(h('span', 'version-hint', 'PWA · no build step · zero deps'));
    els.box.appendChild(foot);

    els.modal.appendChild(els.box);

    /* wire */
    els.theme.addEventListener('change', () => applyTheme(els.theme.value));
    minus.addEventListener('click', () => stepFont(-1));
    plus.addEventListener('click', () => stepFont(1));
    els.mode.addEventListener('change', () => Kimi.settings.set('defaultMode', els.mode.value));
    els.modelSel.addEventListener('change', () => Kimi.settings.set('defaultModel', els.modelSel.value));
    els.format.addEventListener('change', () => Kimi.settings.set('exportFormat', els.format.value));
    els.url.addEventListener('change', () => Kimi.settings.set('bridgeUrl', els.url.value.trim()));
    reconnectBtn.addEventListener('click', () => {
      const url = els.url.value.trim() || defaultBridgeUrl();
      Kimi.settings.set('bridgeUrl', url);
      if (Kimi.bridge && Kimi.bridge.connect) {
        Kimi.bridge.connect(url);
        if (Kimi.toast) Kimi.toast.info('Connecting to ' + url);
      }
    });
    clearBtn.addEventListener('click', clearAll);
    els.closeBtn.addEventListener('click', close);
    els.modal.addEventListener('click', (e) => {
      if (e.target === els.modal) close();
    });

    return els;
  }

  function clearAll() {
    if (Kimi.ui && Kimi.ui.confirm) {
      Kimi.ui.confirm({
        title: 'Clear all sessions?',
        message: 'Every session and transcript will be permanently removed. This cannot be undone.',
        okLabel: 'Clear all',
        danger: true,
      }).then((ok) => {
        if (ok) doClearAll();
      });
    } else {
      doClearAll();
    }
  }

  function doClearAll() {
    const sessions = Kimi.sessions.list ? Kimi.sessions.list() : (Kimi.state.sessions || []);
    sessions.slice().forEach((s) => Kimi.sessions.remove(s.id));
    Kimi.settings.set('pinned', []);
    if (Kimi.toast) Kimi.toast.success('All sessions cleared');
    close();
  }

  function open() {
    ensure();
    if (!els.modal) return;
    els.modal.hidden = false;
    els.modal.classList.add('open');
    document.body.classList.add('modal-open');
    if (els.url) els.url.value = Kimi.settings.get('bridgeUrl', '') || defaultBridgeUrl();
    applyTheme(Kimi.settings.get('theme', 'dark'));
    applyFontSize(Kimi.settings.get('fontSize', 'medium'));
    if (els.mode) els.mode.value = Kimi.settings.get('defaultMode', 'auto') || 'auto';
    if (els.format) els.format.value = Kimi.settings.get('exportFormat', 'md') || 'md';
    if (els.modelSel) {
      const cur = Kimi.settings.get('defaultModel', 'kimi');
      if ([].slice.call(els.modelSel.options).some((o) => o.value === cur)) {
        els.modelSel.value = cur;
      }
    }
  }

  function close() {
    if (!els.modal) return;
    els.modal.hidden = true;
    els.modal.classList.remove('open');
    document.body.classList.remove('modal-open');
  }

  /* ---------- public api ---------- */
  const SettingsUI = {
    init() {
      ensure();
      applyTheme(Kimi.settings.get('theme', 'dark'));
      applyFontSize(Kimi.settings.get('fontSize', 'medium'));
    },
    open() { open(); },
    close() { close(); },
    isOpen() { return !!els.modal && !els.modal.hidden; },
    applyTheme(v) { applyTheme(v); },
    applyFontSize(v) { applyFontSize(v); },
  };

  Kimi.settingsUI = SettingsUI;
})();
