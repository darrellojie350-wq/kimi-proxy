/* Kimi Proxy Web — js/sidebar.js  (ui-js)
 * Session rail: search filter, session rows (title/meta/pin/delete),
 * new-session button, connection-status footer, mobile drawer toggle.
 * Renders ONLY into the contract ids: #sidebar-head, #session-search,
 * #session-list, #sidebar-foot (ARCHITECTURE.md §4/§7).
 * Uses Kimi.sessions / Kimi.state / Kimi.settings / Kimi.bus / Kimi.icons. */
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
  function iconBtn(cls, iconName, title, onClick) {
    const b = h('button', 'icon-btn ' + cls);
    b.type = 'button';
    b.title = title || '';
    b.setAttribute('aria-label', title || '');
    b.appendChild(icon(iconName));
    b.addEventListener('click', (e) => { e.stopPropagation(); onClick && onClick(e); });
    return b;
  }
  function spinner() {
    const s = h('span', 'spinner');
    s.innerHTML =
      '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2">' +
      '<circle cx="12" cy="12" r="9" opacity=".22"></circle>' +
      '<path d="M21 12a9 9 0 0 0-9-9" stroke-linecap="round"></path></svg>';
    return s;
  }

  const els = {};
  let query = '';

  /* ---------- build-if-missing DOM hooks ---------- */
  function ensure() {
    if (els.list) return els;
    els.sidebar = q('#sidebar');
    els.list = q('#session-list');
    els.search = q('#session-search');
    els.head = q('#sidebar-head');
    els.foot = q('#sidebar-foot');
    els.chatHeader = q('#chat-header');

    // search input
    if (els.search) {
      els.searchInput = els.search.classList.contains('search-input')
        ? els.search
        : els.search.querySelector('.search-input');
      if (!els.searchInput) {
        els.searchInput = h('input', 'search-input');
        els.searchInput.type = 'search';
        els.searchInput.placeholder = 'Search sessions';
        els.searchInput.setAttribute('aria-label', 'Search sessions');
        els.search.appendChild(els.searchInput);
      }
      els.searchInput.addEventListener('input', () => {
        query = els.searchInput.value.trim();
        renderList();
      });
    }

    // new-session button in sidebar head
    if (els.head) {
      els.newBtn = els.head.querySelector('.new-session-btn');
      if (!els.newBtn) {
        els.newBtn = h('button', 'new-session-btn');
        els.newBtn.type = 'button';
        els.newBtn.appendChild(icon('plus'));
        els.newBtn.appendChild(h('span', 'ns-label', 'New chat'));
        els.head.appendChild(els.newBtn);
      }
      els.newBtn.addEventListener('click', () => {
        if (Kimi.ui && Kimi.ui.createSession) Kimi.ui.createSession();
      });
    }

    // footer: connection status + settings
    if (els.foot) {
      els.conn = els.foot.querySelector('.conn-status');
      if (!els.conn) {
        els.conn = h('div', 'conn-status');
        els.connDot = h('span', 'conn-dot offline');
        els.connLabel = h('span', 'conn-label', 'Offline');
        els.conn.appendChild(els.connDot);
        els.conn.appendChild(els.connLabel);
        els.foot.appendChild(els.conn);
      } else {
        els.connDot = els.conn.querySelector('.conn-dot');
        els.connLabel = els.conn.querySelector('.conn-label');
      }
      els.settingsBtn = els.foot.querySelector('.foot-settings-btn');
      if (!els.settingsBtn) {
        els.settingsBtn = iconBtn('foot-settings-btn', 'settings', 'Settings', () => {
          if (Kimi.settingsUI && Kimi.settingsUI.open) Kimi.settingsUI.open();
        });
        els.foot.appendChild(els.settingsBtn);
      }
    }

    // mobile drawer toggle (hidden on desktop via app.css / injected css)
    if (els.chatHeader && !els.chatHeader.querySelector('.sidebar-toggle')) {
      const t = iconBtn('sidebar-toggle', 'panelRight', 'Sessions', () => toggleDrawer(!isOpen()));
      els.chatHeader.insertBefore(t, els.chatHeader.firstChild);
    }
    return els;
  }

  /* ---------- helpers ---------- */
  function isOpen() { return !!(Kimi.state.ui && Kimi.state.ui.sidebarOpen); }

  function setOpen(open) {
    Kimi.state.ui = Kimi.state.ui || {};
    Kimi.state.ui.sidebarOpen = !!open;
    const e = ensure();
    if (e.sidebar) e.sidebar.classList.toggle('drawer-open', !!open);
    const app = q('#app');
    if (app) app.classList.toggle('drawer-open', !!open);
    let backdrop = q('#drawer-backdrop');
    if (open) {
      if (!backdrop) {
        backdrop = h('div', 'drawer-backdrop');
        backdrop.id = 'drawer-backdrop';
        backdrop.addEventListener('click', () => toggleDrawer(false));
        document.body.appendChild(backdrop);
      }
      backdrop.classList.add('show');
    } else if (backdrop) {
      backdrop.classList.remove('show');
    }
    Kimi.bus.emit('ui.sidebar', { open: !!open });
  }

  function toggleDrawer(force) {
    setOpen(typeof force === 'boolean' ? force : !isOpen());
  }

  const RUNNING = { streaming: 1, thinking: 1, toolRunning: 1 };

  function getPinned() {
    const p = Kimi.settings.get('pinned', []);
    return Array.isArray(p) ? p : [];
  }

  function setPinned(ids) {
    Kimi.settings.set('pinned', ids);
  }

  function fmtTime(ts) {
    if (!ts) return '';
    const d = Date.now() - ts;
    if (d < 60e3) return 'now';
    if (d < 3600e3) return Math.floor(d / 60e3) + 'm';
    if (d < 86400e3) return Math.floor(d / 3600e3) + 'h';
    if (d < 7 * 86400e3) return Math.floor(d / 86400e3) + 'd';
    const dt = new Date(ts);
    return (dt.getMonth() + 1) + '/' + dt.getDate();
  }

  function statusDot(session) {
    const dot = h('span', 'sr-dot');
    if (session.status === 'error') dot.classList.add('danger');
    return dot;
  }

  function buildRow(session) {
    const row = h('div', 'sidebar-row');
    row.dataset.id = session.id;
    if (session.id === Kimi.state.activeId) row.classList.add('active');
    row.tabIndex = 0;
    row.setAttribute('role', 'button');

    const status = h('span', 'sr-status');
    if (RUNNING[session.status]) status.appendChild(spinner());
    else status.appendChild(statusDot(session));

    const title = h('span', 'sr-title', session.name || 'New session');
    title.title = session.name || '';

    const meta = h('span', 'sr-meta', fmtTime(session.updatedAt));

    const actions = h('span', 'sr-actions');
    const pinned = getPinned().indexOf(session.id) !== -1;
    const pinBtn = iconBtn('pin-ic', pinned ? 'pin' : 'pinOff', pinned ? 'Unpin' : 'Pin', () => {
      const ids = getPinned();
      const i = ids.indexOf(session.id);
      if (i !== -1) ids.splice(i, 1); else ids.push(session.id);
      setPinned(ids);
      renderList();
    });
    pinBtn.classList.toggle('on', pinned);
    const delBtn = iconBtn('del-ic', 'trash', 'Delete session', () => removeSession(session));
    actions.appendChild(pinBtn);
    actions.appendChild(delBtn);

    row.appendChild(status);
    row.appendChild(title);
    row.appendChild(meta);
    row.appendChild(actions);

    row.addEventListener('click', () => Kimi.sessions.select(session.id));
    row.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); Kimi.sessions.select(session.id); }
    });
    return row;
  }

  function removeSession(session) {
    if (Kimi.ui && Kimi.ui.confirm) {
      Kimi.ui.confirm({
        title: 'Delete session?',
        message: '“' + (session.name || 'Untitled') + '” and its transcript will be removed.',
        okLabel: 'Delete',
        danger: true,
      }).then((ok) => { if (ok) doRemove(session); });
    } else {
      doRemove(session);
    }
  }

  function doRemove(session) {
    Kimi.sessions.remove(session.id);
    if (Kimi.toast) Kimi.toast.success('Session deleted');
  }

  function skeletonRows() {
    const frag = document.createDocumentFragment();
    for (let i = 0; i < 5; i++) {
      frag.appendChild(h('div', 'skeleton-row sidebar'));
    }
    return frag;
  }

  /* ---------- rendering ---------- */
  function renderList() {
    const e = ensure();
    if (!e.list) return;
    e.list.replaceChildren();

    const sessions = Kimi.sessions.list ? Kimi.sessions.list() : (Kimi.state.sessions || []);
    const showSkeleton =
      sessions.length === 0 && Kimi.state.connection === 'connecting';
    if (showSkeleton) {
      e.list.appendChild(skeletonRows());
      return;
    }

    let rows = sessions.slice();
    if (query) {
      const ql = query.toLowerCase();
      rows = rows.filter((s) => (s.name || '').toLowerCase().indexOf(ql) !== -1);
    }
    const pinned = getPinned();
    rows.sort((a, b) => {
      const ap = pinned.indexOf(a.id) !== -1 ? 0 : 1;
      const bp = pinned.indexOf(b.id) !== -1 ? 0 : 1;
      if (ap !== bp) return ap - bp;
      return (b.updatedAt || 0) - (a.updatedAt || 0);
    });

    if (!rows.length) {
      const empty = h('div', 'empty-state sidebar-empty');
      const iconWrap = h('span', 'empty-icon', '');
      iconWrap.appendChild(icon(query ? 'search' : 'chatNew'));
      empty.appendChild(iconWrap);
      empty.appendChild(h('p', 'empty-title', query ? 'No results' : 'No sessions yet'));
      empty.appendChild(h('p', 'empty-hint', query
        ? 'No sessions match “' + query + '”.'
        : 'Start a new chat to begin.'));
      e.list.appendChild(empty);
      return;
    }

    rows.forEach((s) => e.list.appendChild(buildRow(s)));
  }

  function renderConnection(status) {
    const e = ensure();
    if (!e.conn) return;
    const map = {
      online: ['online', 'Online'],
      connecting: ['connecting', 'Connecting…'],
      offline: ['offline', 'Offline'],
    };
    const m = map[status] || map.offline;
    if (e.connDot) {
      e.connDot.className = 'conn-dot ' + m[0];
    }
    if (e.connLabel) e.connLabel.textContent = m[1];
  }

  function markActive() {
    const e = ensure();
    if (!e.list) return;
    const rows = e.list.querySelectorAll('.sidebar-row');
    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const active = r.dataset.id === Kimi.state.activeId;
      r.classList.toggle('active', active);
      r.setAttribute('aria-current', active ? 'true' : 'false');
    }
  }

  /* ---------- public api ---------- */
  const Sidebar = {
    init() {
      ensure();
      renderList();
      renderConnection(Kimi.state.connection);

      Kimi.bus.on('sessions.changed', renderList);
      Kimi.bus.on('session.selected', () => {
        markActive();
        if (window.innerWidth <= 640) setOpen(false);
      });
      Kimi.bus.on('connection.change', (d) => {
        renderConnection(d.status);
        renderList();
      });
    },
    refresh() { renderList(); },
    toggleDrawer(open) { toggleDrawer(open); },
    isOpen() { return isOpen(); },
  };

  Kimi.sidebar = Sidebar;
})();
