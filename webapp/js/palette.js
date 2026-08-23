/* Kimi Proxy Web — js/palette.js  (ui-js)
 * ⌘K command palette (Raycast-style): boxed input + result list with kbd
 * hints; items = sessions + actions (new session, toggle theme, toggle
 * plan/yolo, settings, export, shortcuts, reconnect). Arrow keys + Enter +
 * Esc. Renders inside the contract id #palette. Exposes the contract API:
 * Kimi.palette = { open, close, setItems, isOpen }. */
(function () {
  'use strict';

  const Kimi = window.Kimi;
  const q = (sel) => document.querySelector(sel);

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
  function kbd(text) {
    return h('kbd', 'kbd', text);
  }

  const els = {};
  let customItems = null; // set via setItems; null = build defaults
  let query = '';
  let active = -1;
  let rendered = []; // [{item, el}]

  /* ---------- actions ---------- */
  function actionItems() {
    const items = [
      { id: 'new', label: 'New session', icon: 'plus', group: 'Actions', run: () => { if (Kimi.ui && Kimi.ui.createSession) Kimi.ui.createSession(); } },
      { id: 'theme', label: 'Toggle theme', icon: 'sun', group: 'Actions', run: cycleTheme },
      { id: 'plan', label: 'Toggle plan mode', icon: 'target', group: 'Actions', run: toggleMode.bind(null, 'plan') },
      { id: 'yolo', label: 'Toggle YOLO mode', icon: 'bolt', group: 'Actions', run: toggleMode.bind(null, 'yolo') },
      { id: 'settings', label: 'Settings', icon: 'settings', kbd: '⌘,', group: 'Actions', run: () => { if (Kimi.settingsUI && Kimi.settingsUI.open) Kimi.settingsUI.open(); } },
      { id: 'export', label: 'Export session', icon: 'download', group: 'Actions', run: exportSession },
      { id: 'reconnect', label: 'Reconnect bridge', icon: 'refresh', group: 'Actions', run: reconnect },
      { id: 'shortcuts', label: 'Keyboard shortcuts', icon: 'keyboard', group: 'Actions', run: showShortcuts },
    ];
    return items;
  }

  function cycleTheme() {
    const order = ['dark', 'light', 'system'];
    const cur = Kimi.settings.get('theme', 'dark');
    const next = order[(order.indexOf(cur) + 1) % order.length];
    if (Kimi.settingsUI && Kimi.settingsUI.applyTheme) Kimi.settingsUI.applyTheme(next);
    if (Kimi.toast) Kimi.toast.info('Theme: ' + next);
  }

  function toggleMode(mode) {
    const cur = Kimi.settings.get('defaultMode', 'auto');
    const next = cur === mode ? 'auto' : mode;
    Kimi.settings.set('defaultMode', next);
    if (Kimi.toast) Kimi.toast.info('Default mode: ' + next);
  }

  function exportSession() {
    const s = Kimi.sessions.current();
    if (!s) {
      if (Kimi.toast) Kimi.toast.info('No active session to export');
      return;
    }
    const fmt = Kimi.settings.get('exportFormat', 'md') || 'md';
    if (Kimi.sessions.export) {
      Kimi.sessions.export(s.id, fmt);
      if (Kimi.toast) Kimi.toast.success('Session exported');
    } else if (Kimi.toast) {
      Kimi.toast.error('Export not available');
    }
  }

  function reconnect() {
    const url = Kimi.settings.get('bridgeUrl') || defaultBridgeUrl();
    if (Kimi.bridge && Kimi.bridge.connect) Kimi.bridge.connect(url);
    if (Kimi.toast) Kimi.toast.info('Reconnecting…');
  }

  function defaultBridgeUrl() {
    const proto = location.protocol === 'https:' ? 'wss://' : 'ws://';
    return proto + (location.hostname || 'localhost') + ':8765';
  }

  function showShortcuts() {
    const list = Kimi.ui && Kimi.ui.listShortcuts ? Kimi.ui.listShortcuts() : [];
    const items = list.map((sc) => ({
      id: 'sc_' + sc.combo,
      label: sc.desc || sc.combo,
      kbd: sc.combo.replace('mod', navigator.platform && /Mac/.test(navigator.platform) ? '⌘' : 'Ctrl'),
      icon: 'keyboard',
      group: 'Shortcuts',
      run: () => {},
    }));
    setItems(items);
    render();
  }

  function sessionItems() {
    const sessions = Kimi.sessions.list ? Kimi.sessions.list() : (Kimi.state.sessions || []);
    return sessions
      .slice()
      .sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0))
      .map((s) => ({
        id: s.id,
        label: s.name || 'New session',
        desc: s.status === 'idle' ? 'Session' : s.status,
        icon: 'chatNew',
        group: 'Sessions',
        run: () => Kimi.sessions.select(s.id),
      }));
  }

  function allItems() {
    return sessionItems().concat(actionItems());
  }

  /* ---------- dom ---------- */
  function ensure() {
    if (els.root) return els;
    els.root = q('#palette');
    if (!els.root) return els;

    els.box = h('div', 'palette-box');
    els.box.setAttribute('role', 'dialog');
    els.box.setAttribute('aria-label', 'Command palette');

    const head = h('div', 'palette-head');
    head.appendChild(icon('search', 'palette-search-icon'));
    els.input = h('input', 'palette-input');
    els.input.type = 'text';
    els.input.placeholder = 'Search sessions and commands…';
    els.input.setAttribute('aria-label', 'Search sessions and commands');
    els.input.spellcheck = false;
    head.appendChild(els.input);
    head.appendChild(kbd('esc'));
    els.box.appendChild(head);

    els.list = h('div', 'palette-list');
    els.box.appendChild(els.list);

    const foot = h('div', 'palette-foot');
    foot.appendChild(h('span', 'pf-group', ''));
    foot.appendChild(h('span', 'pf-sep', '·'));
    foot.appendChild(h('span', 'pf-hint', '↑↓ navigate'));
    foot.appendChild(h('span', 'pf-sep', '·'));
    foot.appendChild(h('span', 'pf-hint', '↵ run'));
    foot.appendChild(h('span', 'pf-sep', '·'));
    foot.appendChild(h('span', 'pf-hint', 'esc close'));
    els.box.appendChild(foot);

    els.root.appendChild(els.box);

    els.input.addEventListener('input', () => {
      query = els.input.value.trim();
      active = -1;
      render();
    });
    els.input.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowDown') { e.preventDefault(); e.stopPropagation(); move(1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); e.stopPropagation(); move(-1); }
      else if (e.key === 'Enter') { e.preventDefault(); e.stopPropagation(); runActive(); }
      else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); close(); }
    });
    els.root.addEventListener('click', (e) => {
      if (e.target === els.root) close();
    });
    return els;
  }

  /* ---------- rendering ---------- */
  function render() {
    ensure();
    if (!els.list) return;
    els.list.replaceChildren();
    rendered = [];

    const source = customItems ? customItems : allItems();
    const ql = query.toLowerCase();
    const items = ql
      ? source.filter((it) =>
          (it.label || '').toLowerCase().indexOf(ql) !== -1 ||
          (it.desc || '').toLowerCase().indexOf(ql) !== -1 ||
          (it.id || '').toLowerCase().indexOf(ql) !== -1)
      : source;

    if (!items.length) {
      els.list.appendChild(h('p', 'palette-empty', 'No matching commands'));
      return;
    }

    let lastGroup = null;
    items.forEach((it, idx) => {
      if (it.group && it.group !== lastGroup) {
        els.list.appendChild(h('div', 'palette-group', it.group));
        lastGroup = it.group;
      }
      const row = h('div', 'palette-row');
      row.appendChild(icon(it.icon || 'dots', 'pr-icon'));
      const labelEl = h('span', 'pr-label', it.label);
      row.appendChild(labelEl);
      if (it.desc) row.appendChild(h('span', 'pr-desc', it.desc));
      if (it.kbd) row.appendChild(kbd(it.kbd));
      row.dataset.idx = String(idx);
      row.addEventListener('click', () => runItem(it));
      row.addEventListener('mousemove', () => setActive(idx));
      els.list.appendChild(row);
      rendered.push({ item: it, el: row });
    });

    setActive(active >= 0 && active < items.length ? active : 0);
  }

  function setActive(idx) {
    if (!rendered.length) return;
    if (idx < 0) idx = 0;
    if (idx >= rendered.length) idx = rendered.length - 1;
    active = idx;
    rendered.forEach((r, i) => {
      const on = i === active;
      r.el.classList.toggle('active', on);
      if (on) {
        r.el.scrollIntoView({ block: 'nearest' });
      }
    });
  }

  function move(d) {
    if (!rendered.length) return;
    setActive((active + d + rendered.length) % rendered.length);
  }

  function runActive() {
    if (rendered[active]) runItem(rendered[active].item);
  }

  function runItem(item) {
    if (!item) return;
    if (item.run) item.run();
    // shortcuts view stays open with its own item list
    if (customItems && item.group === 'Shortcuts') return;
    close();
  }

  /* ---------- open/close ---------- */
  function open() {
    ensure();
    if (!els.root) return;
    customItems = null;
    query = '';
    active = -1;
    if (els.input) els.input.value = '';
    render();
    els.root.hidden = false;
    document.body.classList.add('modal-open');
    if (els.input) setTimeout(() => els.input.focus(), 10);
    Kimi.state.ui = Kimi.state.ui || {};
    Kimi.state.ui.paletteOpen = true;
    Kimi.bus.emit('ui.palette', { open: true });
  }

  function close() {
    if (!els.root) return;
    if (els.root.hidden) return;
    els.root.hidden = true;
    document.body.classList.remove('modal-open');
    customItems = null;
    Kimi.state.ui = Kimi.state.ui || {};
    Kimi.state.ui.paletteOpen = false;
    Kimi.bus.emit('ui.palette', { open: false });
  }

  /* ---------- public api ---------- */
  const Palette = {
    init() { ensure(); },
    open() { open(); },
    close() { close(); },
    setItems(items) {
      customItems = Array.isArray(items) ? items : null;
      if (els.root && !els.root.hidden) {
        query = '';
        active = -1;
        render();
      }
    },
    isOpen() { return !!els.root && !els.root.hidden; },
  };

  Kimi.palette = Palette;
})();
