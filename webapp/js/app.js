/* Kimi Proxy Web — js/app.js  (ui-js)
 * Bootstrap + wiring: DOMContentLoaded → Kimi.init(), then everything else.
 *  - keyboard shortcuts (mod+n, mod+k, mod+,, mod+up/down, escape)
 *  - bridge auto-connect to persisted URL (default ws://host:8765)
 *  - chat scroll autoscroll with pause-on-scroll-up + jump-to-latest
 *  - bus → chat-list rendering (message/thinking/tool deltas, turn folding)
 *  - banner on reconnect/error, responsive sidebar drawer, empty states,
 *    approval-card placeholder, confirm-dialog helper.
 * Renders into the contract ids #chat-list / #chat-header / #banner-slot /
 * #approval-card / #confirm-dialog and reuses Kimi.render.* for content. */
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

  const RUNNING = { streaming: 1, thinking: 1, toolRunning: 1 };

  /* ---------- runtime bookkeeping (per-session live turns) ---------- */
  const _turns = {};      // sessionId -> live turn {el, msgId, real, tools, toolEls, toolsSec, msgEl, thinkEl, thinking, thinkStart}
  const _renderTimers = {}; // sessionId -> debounce timer
  let _seq = 0;
  let _confirmResolve = null;
  let _wasOnline = false;

  const els = {};
  function ensure() {
    if (els.chatList) return els;
    els.app = q('#app');
    els.main = q('#main');
    els.chatList = q('#chat-list');
    els.chatScroll = q('#chat-scroll');
    els.chatHeader = q('#chat-header');
    els.bannerSlot = q('#banner-slot');
    els.approval = q('#approval-card');
    els.confirm = q('#confirm-dialog');
    return els;
  }

  /* ================================================================== */
  /* Injected styles for UI-owned dynamic classes (tokens only).        */
  /* Contract classes (.sidebar-row, .msg, .tool-line, .pill, .send-btn, */
  /* .empty-state, .skeleton-row, .banner, .approval-card, .toast, .kbd, */
  /* .avatar, .brand-mark …) are styled by Agent A in css/app.css.       */
  /* ================================================================== */
  function injectStyles() {
    if (q('#kimi-ui-styles')) return;
    const st = document.createElement('style');
    st.id = 'kimi-ui-styles';
    st.textContent = [
      '.sidebar-toggle{display:none;align-items:center;justify-content:center;width:32px;height:32px;border:0;background:transparent;color:var(--color-text-muted);border-radius:var(--radius-md);}',
      '.sidebar-toggle:hover{background:var(--color-hover);}',
      '.drawer-backdrop{position:fixed;inset:0;background:var(--color-scrim,rgba(0,0,0,.6));opacity:0;pointer-events:none;transition:opacity var(--dur-base) var(--ease-out);z-index:calc(var(--z-sticky) - 1);}',
      '.drawer-backdrop.show{opacity:1;pointer-events:auto;}',
      '.spinner{display:inline-flex;animation:kimi-spin var(--dur-spin,700ms) linear infinite;color:var(--color-text-muted);}',
      '@keyframes kimi-spin{to{transform:rotate(360deg);}}',
      '.sr-status{display:inline-flex;align-items:center;justify-content:center;width:16px;flex:none;}',
      '.sr-dot{width:7px;height:7px;border-radius:50%;background:var(--color-text-dim);}',
      '.sr-dot.danger{background:var(--color-danger);}',
      '.conn-status{display:flex;align-items:center;gap:8px;min-width:0;flex:1;}',
      '.conn-dot{width:7px;height:7px;border-radius:50%;background:var(--color-text-dim);flex:none;}',
      '.conn-dot.online{background:var(--color-success);}',
      '.conn-dot.connecting{background:var(--color-warning);}',
      '.conn-label{font-size:12px;color:var(--color-text-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
      '.icon{display:inline-flex;align-items:center;justify-content:center;}',
      '.icon svg{width:16px;height:16px;}',
      '.turn-tools{display:flex;flex-direction:column;}',
      '.attachments-strip{display:flex;flex-wrap:wrap;gap:8px;padding:0 8px 8px;}',
      '.attach-chip{display:inline-flex;align-items:center;gap:6px;height:28px;padding:0 8px 0 10px;background:var(--color-well);border:0.5px solid var(--color-hairline);border-radius:999px;font-size:12px;color:var(--color-text-muted);max-width:220px;}',
      '.attach-chip .chip-name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
      '.chip-remove{display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;border:0;background:transparent;color:var(--color-text-dim);border-radius:50%;cursor:pointer;}',
      '.chip-remove:hover{color:var(--color-text);background:var(--color-hover);}',
      '.chip-clear{border:0;background:transparent;color:var(--color-text-muted);font-size:12px;cursor:pointer;}',
      '.chip-clear:hover{color:var(--color-text);}',
      '.comp-pills{display:flex;align-items:center;gap:6px;flex-wrap:wrap;}',
      '.pill.active{background:var(--color-accent-soft);color:var(--color-accent);}',
      '.model-menu{position:absolute;bottom:calc(100% + 8px);left:0;z-index:var(--z-dropdown);min-width:180px;max-height:260px;overflow:auto;background:var(--color-menu-bg);backdrop-filter:blur(12px);border:0.5px solid var(--color-hairline);border-radius:var(--radius-lg);padding:4px;box-shadow:var(--shadow-menu);}',
      '.model-menu-item{display:block;width:100%;text-align:left;padding:8px 12px;border:0;background:transparent;color:var(--color-text-muted);font-family:var(--font-mono);font-size:12px;border-radius:var(--radius-sm);cursor:pointer;}',
      '.model-menu-item:hover{background:var(--color-hover);color:var(--color-text);}',
      '.model-menu-item.active{background:var(--color-selected);color:var(--color-text);}',
      '.composer-input-row{display:flex;align-items:flex-end;gap:8px;padding:0 12px 10px;}',
      '.composer-input{flex:1;min-width:0;resize:none;border:0;outline:none;background:transparent;color:var(--color-text);font-family:var(--font-ui);font-size:14px;line-height:22px;max-height:220px;padding:0;}',
      '.composer-input::placeholder{color:var(--color-text-dim);}',
      '.composer-actions{display:flex;align-items:center;gap:2px;flex:none;}',
      '.context-ring-wrap{position:relative;display:inline-flex;width:36px;height:36px;align-items:center;justify-content:center;margin-right:-2px;}',
      '.context-ring{width:36px;height:36px;position:absolute;inset:0;pointer-events:none;}',
      '.composer-footer{display:flex;align-items:center;gap:4px;padding:0 12px 8px;color:var(--color-text-dim);font-size:11px;}',
      '.composer-footer .hint{color:var(--color-text-dim);}',
      '.jump-latest{position:absolute;right:16px;bottom:16px;z-index:var(--z-sticky);display:none;align-items:center;gap:6px;height:32px;padding:0 12px;border:0.5px solid var(--color-hairline);background:var(--color-raised);color:var(--color-text-muted);border-radius:999px;font-size:12px;cursor:pointer;box-shadow:var(--shadow-menu);}',
      '.jump-latest.show{display:inline-flex;}',
      '.jump-latest:hover{color:var(--color-text);}',
      '#chat-scroll{position:relative;min-height:0;}',
      '.starter-row{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin-top:16px;}',
      '.starter-chip{height:28px;padding:0 14px;border:0.5px solid var(--color-hairline);background:transparent;color:var(--color-text-muted);border-radius:999px;font-size:13px;cursor:pointer;transition:background var(--dur-base) var(--ease-out);}',
      '.starter-chip:hover{background:var(--color-hover);color:var(--color-text);}',
      '.empty-actions{display:flex;gap:8px;justify-content:center;margin-top:16px;}',
      '#palette{position:fixed;inset:0;z-index:var(--z-overlay);display:none;align-items:flex-start;justify-content:center;padding:18vh 4vw 0;}',
      '#palette[hidden]{display:none !important;}',
      '#palette:not([hidden]){display:flex;}',
      '.palette-box{width:min(560px,92vw);background:var(--color-menu-bg);backdrop-filter:blur(16px);border:0.5px solid var(--color-hairline);border-radius:var(--radius-xl);box-shadow:var(--shadow-menu);overflow:hidden;display:flex;flex-direction:column;}',
      '.palette-head{display:flex;align-items:center;gap:10px;padding:0 14px;height:46px;border-bottom:0.5px solid var(--color-hairline);}',
      '.palette-search-icon{color:var(--color-text-dim);}',
      '.palette-input{flex:1;min-width:0;border:0;outline:none;background:transparent;color:var(--color-text);font-size:15px;caret-color:var(--color-accent);}',
      '.palette-input::placeholder{color:var(--color-text-dim);}',
      '.palette-list{max-height:min(56vh,420px);overflow:auto;padding:6px;}',
      '.palette-group{padding:8px 12px 4px;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:var(--color-text-dim);}',
      '.palette-row{display:flex;align-items:center;gap:10px;height:44px;padding:0 12px;border-radius:var(--radius-md);cursor:pointer;}',
      '.palette-row.active{background:var(--color-selected);}',
      '.palette-row.active .pr-label{color:var(--color-text);}',
      '.pr-icon{color:var(--color-text-dim);flex:none;}',
      '.pr-label{font-size:13px;color:var(--color-text-muted);flex:0 1 auto;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
      '.pr-desc{margin-left:auto;font-size:12px;color:var(--color-text-dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:180px;}',
      '.palette-foot{display:flex;align-items:center;gap:8px;padding:8px 14px;border-top:0.5px solid var(--color-hairline);font-size:11px;color:var(--color-text-dim);}',
      '.palette-empty{padding:32px;text-align:center;color:var(--color-text-dim);font-size:13px;}',
      '#settings-modal{position:fixed;inset:0;z-index:var(--z-modal);display:none;align-items:center;justify-content:center;background:var(--color-scrim,rgba(0,0,0,.6));padding:16px;}',
      '#settings-modal[hidden]{display:none !important;}',
      '#settings-modal:not([hidden]){display:flex;}',
      '.settings-box{width:min(520px,92vw);max-height:86vh;overflow:auto;background:var(--color-raised);border:0.5px solid var(--color-hairline);border-radius:var(--radius-xl);box-shadow:var(--shadow-menu);}',
      '.settings-head{display:flex;align-items:center;justify-content:space-between;padding:14px 16px;border-bottom:0.5px solid var(--color-hairline);}',
      '.settings-title{font-size:15px;font-weight:600;color:var(--color-text);margin:0;}',
      '.settings-body{padding:8px 16px;}',
      '.settings-section{padding:12px 0;border-bottom:0.5px solid var(--color-subtle);}',
      '.settings-section:last-of-type{border-bottom:0;}',
      '.settings-section h3{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:var(--color-text-dim);margin:0 0 8px;}',
      '.field{display:flex;flex-direction:column;gap:6px;margin-bottom:12px;}',
      '.field-label{font-size:13px;color:var(--color-text-muted);}',
      '.field-row{display:flex;gap:8px;}',
      '.field-row .text-input{flex:1;min-width:0;}',
      '.text-input,.select-input{height:34px;padding:0 10px;background:var(--color-well);border:0.5px solid var(--color-hairline);border-radius:var(--radius-md);color:var(--color-text);font-size:13px;outline:none;}',
      '.text-input:focus,.select-input:focus{box-shadow:0 0 0 3px var(--color-accent-soft),0 0 0 1px var(--color-accent);}',
      '.select-input option{background:var(--color-raised);}',
      '.stepper{display:inline-flex;align-items:center;gap:4px;align-self:flex-start;}',
      '.stepper-btn{width:32px;height:32px;border:0.5px solid var(--color-hairline);background:var(--color-well);color:var(--color-text-muted);border-radius:var(--radius-md);font-size:15px;cursor:pointer;}',
      '.stepper-btn:hover{color:var(--color-text);background:var(--color-hover);}',
      '.stepper-value{min-width:76px;text-align:center;font-size:13px;color:var(--color-text);}',
      '.danger-btn{height:32px;padding:0 14px;border:0.5px solid var(--color-danger);background:transparent;color:var(--color-danger);border-radius:var(--radius-md);font-size:13px;cursor:pointer;}',
      '.danger-btn:hover{background:rgba(248,81,73,.1);}',
      '.btn.ghost-btn{height:34px;padding:0 14px;border:0.5px solid var(--color-hairline);background:var(--color-well);color:var(--color-text-muted);border-radius:var(--radius-md);font-size:13px;cursor:pointer;}',
      '.btn.ghost-btn:hover{color:var(--color-text);}',
      '.settings-foot{display:flex;justify-content:space-between;align-items:center;padding:12px 16px;border-top:0.5px solid var(--color-hairline);}',
      '.version{font-size:12px;color:var(--color-text-muted);}',
      '.version-hint{font-size:11px;color:var(--color-text-dim);}',
      '#confirm-dialog{position:fixed;inset:0;z-index:calc(var(--z-modal) + 1);display:none;align-items:center;justify-content:center;background:var(--color-scrim,rgba(0,0,0,.6));padding:16px;}',
      '#confirm-dialog[hidden]{display:none !important;}',
      '#confirm-dialog:not([hidden]){display:flex;}',
      '.confirm-box{width:min(400px,92vw);background:var(--color-raised);border:0.5px solid var(--color-hairline);border-radius:var(--radius-xl);padding:20px;box-shadow:var(--shadow-menu);}',
      '.confirm-title{font-size:15px;font-weight:600;color:var(--color-text);margin:0 0 8px;}',
      '.confirm-msg{font-size:13px;line-height:1.5;color:var(--color-text-muted);margin:0 0 20px;}',
      '.confirm-actions{display:flex;justify-content:flex-end;gap:8px;}',
      '.confirm-actions .btn-ok{height:32px;padding:0 16px;border:0;border-radius:var(--radius-md);font-size:13px;cursor:pointer;color:#fff;background:var(--color-accent);}',
      '.confirm-actions .btn-ok.danger{background:var(--color-danger);}',
      '.confirm-actions .btn-cancel{height:32px;padding:0 16px;border:0.5px solid var(--color-hairline);background:transparent;color:var(--color-text-muted);border-radius:var(--radius-md);font-size:13px;cursor:pointer;}',
      '.banner-dismiss{border:0;background:transparent;color:currentColor;opacity:.7;cursor:pointer;display:inline-flex;padding:2px;}',
      '@media (max-width:640px){.sidebar-toggle{display:inline-flex;}.palette-foot{display:none;}}',
      '@media (max-width:640px){#settings-modal{align-items:flex-end;}#settings-modal .settings-box{border-radius:var(--radius-2xl) var(--radius-2xl) 0 0;max-height:90vh;}}',
      '@media (prefers-reduced-motion:reduce){.spinner{animation-duration:.001ms;}}',
    ].join('\n');
    document.head.appendChild(st);
  }

  /* ================================================================== */
  /* Banner                                                             */
  /* ================================================================== */
  function showBanner(kind, text, action) {
    ensure();
    if (!els.bannerSlot) return;
    els.bannerSlot.replaceChildren();
    const b = h('div', 'banner banner-' + kind);
    b.appendChild(icon(kind === 'error' ? 'alert' : 'info', 'banner-icon'));
    b.appendChild(h('span', 'banner-text', text));
    if (action) {
      const a = h('button', 'banner-action', action.label);
      a.type = 'button';
      a.addEventListener('click', action.run);
      b.appendChild(a);
    }
    const x = h('button', 'banner-dismiss');
    x.type = 'button';
    x.setAttribute('aria-label', 'Dismiss');
    x.appendChild(icon('close'));
    x.addEventListener('click', () => { els.bannerSlot.replaceChildren(); });
    b.appendChild(x);
    els.bannerSlot.appendChild(b);
  }

  function clearBanner() {
    ensure();
    if (els.bannerSlot) els.bannerSlot.replaceChildren();
  }

  /* ================================================================== */
  /* Empty states                                                       */
  /* ================================================================== */
  function renderEmptyState() {
    ensure();
    if (!els.chatList) return;
    const s = Kimi.sessions.current();

    if (!s) {
      // no sessions — welcome hero with connection hint
      els.chatList.replaceChildren();
      const box = h('div', 'empty-state welcome-hero');
      const ic = h('span', 'empty-icon', '');
      ic.appendChild(icon('sparkles'));
      box.appendChild(ic);
      box.appendChild(h('p', 'empty-title', 'Kimi Proxy'));
      box.appendChild(h('p', 'empty-hint',
        Kimi.state.connection === 'online'
          ? 'Connected to bridge. Start a new chat to begin.'
          : 'Waiting for the bridge — start a chat when connected.'));
      const acts = h('div', 'empty-actions');
      const b = h('button', 'btn ghost-btn', 'New chat');
      b.type = 'button';
      b.addEventListener('click', () => createSession());
      acts.appendChild(b);
      if (Kimi.state.connection !== 'online') {
        const r = h('button', 'btn ghost-btn', 'Retry connection');
        r.type = 'button';
        r.addEventListener('click', () => Kimi.bridge.connect(Kimi.settings.get('bridgeUrl') || defaultBridgeUrl()));
        acts.appendChild(r);
      }
      box.appendChild(acts);
      els.chatList.appendChild(box);
      return;
    }

    if (!s.messages || !s.messages.length) {
      // empty session — render.js emptyState (welcome hero + starters)
      const box = (Kimi.render && Kimi.render.emptyState) ? Kimi.render.emptyState() : buildFallbackEmpty();
      els.chatList.replaceChildren();
      const nb = box.querySelector('.new-chat-btn');
      if (nb) nb.addEventListener('click', () => createSession());
      const chips = box.querySelectorAll('.starter-chip');
      for (let i = 0; i < chips.length; i++) {
        chips[i].addEventListener('click', () => {
          if (Kimi.composer) Kimi.composer.send(chips[i].dataset.prompt || chips[i].textContent);
        });
      }
      const modeCards = box.querySelectorAll('.mode-card');
      for (let i = 0; i < modeCards.length; i++) {
        modeCards[i].addEventListener('click', () => {
          if (Kimi.composer) Kimi.composer.send(modeCards[i].dataset.prompt || '');
        });
      }
      els.chatList.appendChild(box);
      return;
    }

    renderTranscript(s);
  }

  function buildFallbackEmpty() {
    const box = h('div', 'empty-state');
    const ic = h('span', 'empty-icon', '');
    ic.appendChild(icon('chatNew'));
    box.appendChild(ic);
    box.appendChild(h('p', 'empty-title', 'Start a conversation'));
    box.appendChild(h('p', 'empty-hint', 'Ask about the codebase, debug an error, or plan a feature.'));
    const starters = h('div', 'starter-row');
    ['Explain this codebase', 'Debug an error', 'Plan a feature'].forEach((t) => {
      const c = h('button', 'starter-chip', t);
      c.type = 'button';
      c.addEventListener('click', () => { if (Kimi.composer) Kimi.composer.send(t); });
      starters.appendChild(c);
    });
    box.appendChild(starters);
    return box;
  }

  /* ================================================================== */
  /* Transcript rendering (composes Kimi.render.* pieces)               */
  /* ================================================================== */
  function isLive(s) {
    return !!(s && RUNNING[s.status]);
  }

  function isPlaceholder(m) {
    return !!(m && m.role === 'assistant' && m.streaming && !(m.content || '').trim());
  }

  function buildTurnEl(s, msg, settled) {
    const turn = h('div', 'turn');
    turn.dataset.msgId = msg.id;
    if (msg.thinking) {
      turn.appendChild(Kimi.render.thinkingRow(msg.thinking, {
        streaming: !settled && !!msg.streaming,
        durationMs: msg.thinkingDuration || 0,
      }));
    }
    const tools = msg.toolCalls || [];
    if (tools.length) {
      const sec = h('div', 'turn-tools');
      if (Kimi.render.activityRun) sec.appendChild(Kimi.render.activityRun(tools));
      else tools.forEach((tc) => sec.appendChild(Kimi.render.toolCallLine(tc)));
      turn.appendChild(sec);
    }
    turn.appendChild(Kimi.render.message(msg.role, msg.content, {
      streaming: !settled && !!msg.streaming,
      model: s.model,
      ts: msg.ts,
      msgId: msg.id,
    }));
    if (settled && msg.turnDuration && Kimi.render.turnFold) {
      turn.appendChild(Kimi.render.turnFold(msg.turnDuration));
    }
    return turn;
  }

  function renderTranscript(s) {
    ensure();
    if (!els.chatList) return;
    if (!s) { renderEmptyState(); return; }

    const list = els.chatList;
    list.replaceChildren();

    const live = _turns[s.id];
    if (live && isLive(s)) {
      for (let i = 0; i < (s.messages || []).length; i++) {
        const m = s.messages[i];
        if (m.id === live.msgId) break;
        if (isPlaceholder(m)) continue;
        list.appendChild(buildTurnEl(s, m, true));
      }
      list.appendChild(live.el);
      return;
    }

    if (!s.messages || !s.messages.length) { renderEmptyState(); return; }

    s.messages.forEach((m) => {
      if (!isPlaceholder(m)) list.appendChild(buildTurnEl(s, m, true));
    });
    scrollBottom(false);
  }

  function renderMsgContent(s, msg, turn) {
    if (turn.msgEl && typeof turn.msgEl.update === 'function') {
      turn.msgEl.update(msg.content, { streaming: !!msg.streaming, model: s.model, ts: msg.ts });
      return;
    }
    const mc = Kimi.render.message(msg.role, msg.content, {
      streaming: !!msg.streaming,
      model: s.model,
      ts: msg.ts,
      msgId: msg.id,
    });
    if (turn.msgEl) turn.el.replaceChild(mc, turn.msgEl);
    else {
      turn.msgEl = mc;
      turn.el.appendChild(mc);
    }
  }

  function newTurn(s, msgId) {
    const t = {
      el: h('div', 'turn'),
      msgId: msgId || 'live-' + (++_seq),
      real: !!msgId,
      tools: [],
      toolEls: {},       // toolCallId -> element (render.js toolCallLine)
      toolsSec: null,
      msgEl: null,
      thinkEl: null,     // render.js thinkingRow element
      thinking: '',
      thinkStart: 0,
    };
    t.el.dataset.msgId = t.msgId;
    _turns[s.id] = t;
    ensure();
    els.chatList.appendChild(t.el);
    return t;
  }

  function liveTurn(s, msgId) {
    let t = _turns[s.id];
    if (!t) {
      t = newTurn(s, msgId);
    } else if (msgId && !t.real) {
      t.msgId = msgId;
      t.real = true;
      t.el.dataset.msgId = msgId;
    }
    return t;
  }

  function ensureToolsSec(t) {
    if (t.toolsSec) return t.toolsSec;
    t.toolsSec = h('div', 'turn-tools');
    t.el.insertBefore(t.toolsSec, t.msgEl || null);
    return t.toolsSec;
  }

  // render.js thinkingRow self-ticks its elapsed seconds and manages its own
  // open/close; we only create/update it (elapsedMs, per render.js stateInfo).
  function renderThinkingRow(t, streaming) {
    const state = {
      streaming: streaming,
      elapsedMs: t.thinkStart ? (Date.now() - t.thinkStart) : 0,
    };
    if (!t.thinkEl) {
      t.thinkEl = Kimi.render.thinkingRow(t.thinking, state);
      t.el.insertBefore(t.thinkEl, t.toolsSec || t.msgEl || null);
    } else if (typeof t.thinkEl.update === 'function') {
      t.thinkEl.update(t.thinking, state);
    } else {
      const row = Kimi.render.thinkingRow(t.thinking, state);
      t.el.replaceChild(row, t.thinkEl);
      t.thinkEl = row;
    }
  }

  function findMsg(s, msgId) {
    return (s.messages || []).find((m) => m.id === msgId) || null;
  }

  function autoscroll() {
    ensure();
    if (!els.chatScroll) return;
    const c = els.chatScroll;
    if (c.scrollHeight - c.scrollTop - c.clientHeight < 100) {
      scrollBottom(false);
    } else {
      updateJumpPill();
    }
  }

  function scrollBottom(smooth) {
    ensure();
    if (!els.chatScroll) return;
    els.chatScroll.scrollTo({ top: els.chatScroll.scrollHeight, behavior: smooth ? 'smooth' : 'auto' });
    updateJumpPill();
  }

  function updateJumpPill() {
    ensure();
    let pill = q('#jump-latest');
    const c = els.chatScroll;
    if (!c) return;
    const near = c.scrollHeight - c.scrollTop - c.clientHeight < 100;
    if (!pill) {
      if (near) return;
      pill = h('button', 'jump-latest');
      pill.id = 'jump-latest';
      pill.appendChild(icon('arrowDown'));
      pill.appendChild(h('span', null, 'Latest'));
      pill.addEventListener('click', () => scrollBottom(true));
      els.chatScroll.appendChild(pill);
    }
    pill.classList.toggle('show', !near);
  }

  /* ================================================================== */
  /* Bus wiring                                                         */
  /* ================================================================== */
  function wireBus() {
    Kimi.bus.on('connection.change', (d) => {
      const st = d && d.status;
      if (st === 'online') {
        clearBanner();
        if (_wasOnline) { if (Kimi.toast) Kimi.toast.info('Reconnected to bridge'); }
        else { if (Kimi.toast) Kimi.toast.success('Connected to server'); }
        _wasOnline = true;
        renderEmptyState();
      } else if (st === 'connecting') {
        showBanner('info', 'Connecting to bridge…');
      } else if (st === 'offline') {
        _wasOnline = false;
        showBanner('error', 'Connection lost — reconnecting…', {
          label: 'Retry',
          run: () => Kimi.bridge.connect(Kimi.settings.get('bridgeUrl') || defaultBridgeUrl()),
        });
      }
    });

    Kimi.bus.on('bridge.error', (d) => {
      const msg = (d && d.message) || 'Bridge error';
      showBanner('error', msg);
      if (Kimi.toast) Kimi.toast.error(msg);
    });

    Kimi.bus.on('session.selected', (d) => {
      if (!d) return;
      updateHeader();
      renderEmptyState();
    });

    Kimi.bus.on('session.created', (d) => {
      if (!d || !d.session) return;
      if (_pendingCreate) {
        _pendingCreate = false;
        Kimi.sessions.select(d.session.id);
      }
    });

    Kimi.bus.on('sessions.changed', () => {
      // active session may have been removed
      const cur = Kimi.sessions.current();
      if (!cur && Kimi.state.activeId && Kimi.sessions.list && Kimi.sessions.list().length) {
        Kimi.sessions.select(Kimi.sessions.list()[0].id);
        return;
      }
      updateHeader();
      const active = Kimi.sessions.current();
      if (active && !isLive(active)) {
        renderEmptyState();
        updateJumpPill();
      } else if (active && isLive(active) && !_turns[active.id]) {
        // prompt just sent: show the user message while awaiting the first token
        renderEmptyState();
      }
    });

    Kimi.bus.on('message.delta', (d) => {
      if (!d) return;
      const s = Kimi.sessions.get(d.sessionId);
      if (!s) return;
      const msg = findMsg(s, d.msgId);
      if (!msg) { renderEmptyState(); return; }
      if (Kimi.state.activeId !== s.id) return;
      msg.streaming = true;
      const turn = liveTurn(s, d.msgId);
      clearTimeout(_renderTimers[s.id]);
      _renderTimers[s.id] = setTimeout(() => {
        if (!_turns[s.id]) return;
        renderMsgContent(s, msg, _turns[s.id]);
        autoscroll();
      }, 60);
    });

    Kimi.bus.on('thinking.delta', (d) => {
      if (!d) return;
      const s = Kimi.sessions.get(d.sessionId);
      if (!s) return;
      if (Kimi.state.activeId !== s.id) return;
      const turn = liveTurn(s, d.msgId || null);
      if (!turn.thinkStart) turn.thinkStart = Date.now();
      turn.thinking += d.delta || '';
      renderThinkingRow(turn, true);
      autoscroll();
    });

    Kimi.bus.on('tool.call', (d) => {
      if (!d) return;
      const s = Kimi.sessions.get(d.sessionId);
      if (!s) return;
      const turn = liveTurn(s, null);
      const tc = { id: d.toolCallId, name: d.name, arguments: d.arguments || {}, status: 'running', startedAt: Date.now() };
      turn.tools.push(tc);
      const el = Kimi.render.toolCallLine(tc);
      turn.toolEls[tc.id] = el;
      ensureToolsSec(turn).appendChild(el);
      autoscroll();
    });

    Kimi.bus.on('tool.output', (d) => {
      if (!d) return;
      const s = Kimi.sessions.get(d.sessionId);
      if (!s) return;
      const turn = _turns[s.id];
      if (!turn) return;
      const tc = turn.tools.find((x) => x.id === d.toolCallId);
      if (!tc) return;
      tc.output = d.output;
      const el = turn.toolEls[d.toolCallId];
      if (el && typeof el.setOutput === 'function') el.setOutput(d.output);
    });

    Kimi.bus.on('tool.status', (d) => {
      if (!d) return;
      const s = Kimi.sessions.get(d.sessionId);
      if (!s) return;
      const turn = _turns[s.id];
      if (!turn) return;
      const tc = turn.tools.find((x) => x.id === d.toolCallId);
      if (!tc) return;
      tc.status = d.status;
      tc.durationMs = Date.now() - (tc.startedAt || Date.now());
      const el = turn.toolEls[d.toolCallId];
      if (el && typeof el.setStatus === 'function') el.setStatus(d.status);
    });

    Kimi.bus.on('session.status', (d) => {
      if (!d) return;
      const s = Kimi.sessions.get(d.sessionId);
      if (!s) return;
      s.status = d.status;
      updateWorkIndicator();
      if (d.status === 'idle' || d.status === 'error') finalizeTurn(s, d);
    });

    Kimi.bus.on('turn.complete', (d) => {
      if (!d) return;
      const s = Kimi.sessions.get(d.sessionId);
      if (!s) return;
      if (d.code && d.code !== 0 && Kimi.toast) {
        Kimi.toast.error('Turn failed (code ' + d.code + ')');
      }
      if (d.durationMs) s._lastDurationMs = d.durationMs;
      updateWorkIndicator();
      finalizeTurn(s, d);
    });
  }

  /* ---------- Grok-style live "Working" indicator ---------- */
  function updateWorkIndicator() {
    const el = document.getElementById('work-indicator');
    if (!el) return;
    const s = Kimi.sessions.current && Kimi.sessions.current();
    const busy = s && (s.status === 'streaming' || s.status === 'thinking' || s.status === 'toolRunning');
    const label = el.querySelector('.wi-label');
    if (busy) {
      el.hidden = false;
      el.classList.add('active');
      if (label) {
        label.textContent = s.status === 'thinking' ? 'Thinking' : (s.status === 'toolRunning' ? 'Running tools' : 'Working');
      }
    } else {
      el.hidden = true;
      el.classList.remove('active');
    }
  }

  /* ---------- turn finalization ---------- */
  function finalizeTurn(s, d) {
    const turn = _turns[s.id];
    if (!turn) return;

    // kill the thinking self-timer before it gets detached
    if (turn.thinkEl && turn.thinkEl.destroy) turn.thinkEl.destroy();

    let msg = turn.real ? findMsg(s, turn.msgId) : null;
    if (!msg) {
      // tool/thinking-only turn: bind to the current assistant message so the
      // tools survive the sessions.changed re-render below.
      const msgs = s.messages || [];
      for (let i = msgs.length - 1; i >= 0; i--) {
        if (msgs[i].role === 'assistant') { msg = msgs[i]; break; }
      }
    }
    if (msg) {
      msg.streaming = false;
      if (turn.tools.length) msg.toolCalls = turn.tools.slice();
      if (turn.thinking) msg.thinking = turn.thinking;
      if (turn.thinkStart) msg.thinkingDuration = Math.max(1, Date.now() - turn.thinkStart);
      msg.turnDuration = (d && d.durationMs) || s._lastDurationMs || 0;
    }

    if (msg) {
      const settled = buildTurnEl(s, msg, true);
      if (turn.el.parentNode) turn.el.parentNode.replaceChild(settled, turn.el);
    } else {
      // turn with only thinking/tools and no assistant text
      const t = h('div', 'turn');
      if (turn.thinking) {
        t.appendChild(Kimi.render.thinkingRow(turn.thinking, {
          streaming: false,
          durationMs: turn.thinkStart ? (Date.now() - turn.thinkStart) : 0,
        }));
      }
      if (turn.tools.length) {
        const sec = h('div', 'turn-tools');
        if (Kimi.render.activityRun) sec.appendChild(Kimi.render.activityRun(turn.tools));
        else turn.tools.forEach((tc) => sec.appendChild(Kimi.render.toolCallLine(tc)));
        t.appendChild(sec);
      }
      if (turn.el.parentNode) turn.el.parentNode.replaceChild(t, turn.el);
    }

    delete _turns[s.id];
    s.status = s.status === 'error' ? 'error' : 'idle';
    Kimi.bus.emit('sessions.changed');
    updateJumpPill();
  }

  /* ================================================================== */
  /* Header                                                             */
  /* ================================================================== */
  function ensureHeader() {
    ensure();
    if (!els.chatHeader) return;
    if (!els.chatTitle) {
      els.chatTitle = els.chatHeader.querySelector('.chat-title') || els.chatHeader.querySelector('#chat-title');
      if (!els.chatTitle) {
        els.chatTitle = h('h1', 'chat-title', 'Kimi Proxy');
        els.chatTitle.id = 'chat-title';
        els.chatHeader.appendChild(els.chatTitle);
      }
    }
    if (!els.headerActions) {
      els.headerActions = els.chatHeader.querySelector('.header-actions');
      if (!els.headerActions) {
        els.headerActions = h('div', 'header-actions');
        els.chatHeader.appendChild(els.headerActions);
      }
    }
    if (!els.headerConn) {
      els.headerConn = h('span', 'conn-dot offline');
      els.headerActions.insertBefore(els.headerConn, els.headerActions.firstChild);
    }
    if (!els.headerPalette) {
      const b = h('button', 'icon-btn header-palette');
      b.type = 'button';
      b.title = 'Command palette (⌘K)';
      b.setAttribute('aria-label', 'Command palette');
      b.innerHTML = Kimi.icons.search || '';
      b.addEventListener('click', () => Kimi.palette.open());
      els.headerActions.appendChild(b);
      els.headerPalette = b;
    }
    if (!els.headerSettings) {
      const b = h('button', 'icon-btn header-settings');
      b.type = 'button';
      b.title = 'Settings (⌘,)';
      b.setAttribute('aria-label', 'Settings');
      b.innerHTML = Kimi.icons.settings || '';
      b.addEventListener('click', () => Kimi.settingsUI.open());
      els.headerActions.appendChild(b);
      els.headerSettings = b;
    }
  }

  function updateHeader() {
    ensureHeader();
    if (!els.chatTitle) return;
    const s = Kimi.sessions.current();
    els.chatTitle.textContent = s ? (s.name || 'New session') : 'Kimi Proxy';
    const st = Kimi.state.connection;
    if (els.headerConn) {
      els.headerConn.className = 'conn-dot ' + (st === 'online' ? 'online' : st === 'connecting' ? 'connecting' : 'offline');
    }
  }

  /* ================================================================== */
  /* Keyboard shortcuts                                                 */
  /* Kimi.init() (kimi.js) already binds document keydown to            */
  /* Kimi.shortcuts.handleKey; we register combos there and add only a  */
  /* fallback Escape listener (handleKey skips non-mod combos while     */
  /* typing in editable elements, but Escape must still close modals).  */
  /* ================================================================== */
  function wireShortcuts() {
    if (!Kimi.shortcuts || !Kimi.shortcuts.register) return;
    Kimi.shortcuts.register('mod+n', 'New session', () => createSession());
    Kimi.shortcuts.register('mod+k', 'Command palette', () => (Kimi.palette.isOpen() ? Kimi.palette.close() : Kimi.palette.open()));
    Kimi.shortcuts.register('mod+,', 'Settings', () => Kimi.settingsUI.open());
    Kimi.shortcuts.register('mod+up', 'Previous session', () => stepSession(-1));
    Kimi.shortcuts.register('mod+down', 'Next session', () => stepSession(1));
    Kimi.shortcuts.register('escape', 'Close overlays', handleEscape);

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !e.defaultPrevented) {
        handleEscape();
      }
    });
  }

  function handleEscape() {
    if (Kimi.palette.isOpen()) { Kimi.palette.close(); return; }
    if (Kimi.settingsUI.isOpen()) { Kimi.settingsUI.close(); return; }
    if (_confirmResolve) { resolveConfirm(false); return; }
    if (Kimi.sidebar && Kimi.sidebar.isOpen() && window.innerWidth <= 640) {
      Kimi.sidebar.toggleDrawer(false);
    }
  }

  function stepSession(dir) {
    const list = Kimi.sessions.list ? Kimi.sessions.list() : (Kimi.state.sessions || []);
    if (!list.length) return;
    const cur = Kimi.state.activeId;
    let idx = list.findIndex((s) => s.id === cur);
    if (idx === -1) idx = -1;
    const next = list[(idx + dir + list.length) % list.length];
    Kimi.sessions.select(next.id);
  }

  /* ================================================================== */
  /* Sessions                                                           */
  /* ================================================================== */
  let _pendingCreate = false;

  function createSession() {
    if (Kimi.bridge.status === 'online') {
      _pendingCreate = true;
      Kimi.bridge.send({ type: 'session.create', name: null, workDir: null, model: null });
      return null;
    }
    const s = Kimi.sessions.create('New session');
    Kimi.sessions.select(s.id);
    return s;
  }

  function defaultBridgeUrl() {
    const proto = location.protocol === 'https:' ? 'wss://' : 'ws://';
    return proto + (location.hostname || 'localhost') + ':8765';
  }

  /* ================================================================== */
  /* Confirm dialog                                                     */
  /* ================================================================== */
  function ensureConfirm() {
    ensure();
    if (!els.confirm) return null;
    if (els.confirmBox) return els.confirm;
    els.confirmBox = h('div', 'confirm-box');
    els.confirmTitle = h('h3', 'confirm-title', 'Are you sure?');
    els.confirmMsg = h('p', 'confirm-msg', '');
    const actions = h('div', 'confirm-actions');
    els.confirmCancel = h('button', 'btn-cancel', 'Cancel');
    els.confirmCancel.type = 'button';
    els.confirmOk = h('button', 'btn-ok', 'Confirm');
    els.confirmOk.type = 'button';
    actions.appendChild(els.confirmCancel);
    actions.appendChild(els.confirmOk);
    els.confirmBox.appendChild(els.confirmTitle);
    els.confirmBox.appendChild(els.confirmMsg);
    els.confirmBox.appendChild(actions);
    els.confirm.appendChild(els.confirmBox);

    els.confirmCancel.addEventListener('click', () => resolveConfirm(false));
    els.confirmOk.addEventListener('click', () => resolveConfirm(true));
    els.confirm.addEventListener('click', (e) => {
      if (e.target === els.confirm) resolveConfirm(false);
    });
    return els.confirm;
  }

  function resolveConfirm(value) {
    if (!_confirmResolve) return;
    const r = _confirmResolve;
    _confirmResolve = null;
    if (els.confirm) {
      els.confirm.hidden = true;
      document.body.classList.remove('modal-open');
    }
    r(value);
  }

  function confirm(opts) {
    const elRoot = ensureConfirm();
    if (!elRoot) return Promise.resolve(true);
    els.confirmTitle.textContent = (opts && opts.title) || 'Are you sure?';
    els.confirmMsg.textContent = (opts && opts.message) || '';
    els.confirmOk.textContent = (opts && opts.okLabel) || 'Confirm';
    els.confirmCancel.textContent = (opts && opts.cancelLabel) || 'Cancel';
    els.confirmOk.classList.toggle('danger', !!(opts && opts.danger));
    elRoot.hidden = false;
    document.body.classList.add('modal-open');
    return new Promise((resolve) => { _confirmResolve = resolve; });
  }

  /* ================================================================== */
  /* Approval card placeholder                                          */
  /* ================================================================== */
  function ensureApprovalCard() {
    ensure();
    if (!els.approval) return;
    if (els.approval.childNodes.length) return;
    const card = h('div', 'approval-card');
    card.appendChild(h('p', 'approval-title', 'Approval required'));
    card.appendChild(h('p', 'approval-msg', 'This action needs confirmation before it runs.'));
    const actions = h('div', 'approval-actions');
    const deny = h('button', 'btn-cancel', 'Deny');
    deny.type = 'button';
    const ok = h('button', 'btn-ok', 'Approve');
    ok.type = 'button';
    actions.appendChild(deny);
    actions.appendChild(ok);
    card.appendChild(actions);
    els.approval.appendChild(card);
  }

  /* ================================================================== */
  /* Bootstrap                                                          */
  /* ================================================================== */
  function init() {
    if (Kimi._uiReady) return;
    Kimi._uiReady = true;

    if (typeof Kimi.init === 'function') Kimi.init();

    injectStyles();
    ensure();
    ensureHeader();
    ensureConfirm();
    ensureApprovalCard();

    if (Kimi.sidebar && Kimi.sidebar.init) Kimi.sidebar.init();
    if (Kimi.composer && Kimi.composer.init) Kimi.composer.init();
    if (Kimi.settingsUI && Kimi.settingsUI.init) Kimi.settingsUI.init();
    if (Kimi.palette && Kimi.palette.init) Kimi.palette.init();

    wireBus();
    wireShortcuts();

    // chat scroll: pause auto-scroll when the user scrolls up
    if (els.chatScroll) {
      els.chatScroll.addEventListener('scroll', updateJumpPill);
    }
    window.addEventListener('resize', () => {
      if (window.innerWidth > 640 && Kimi.sidebar && Kimi.sidebar.isOpen()) {
        Kimi.sidebar.toggleDrawer(false);
      }
    });

    // auto-connect to persisted bridge URL
    const url = Kimi.settings.get('bridgeUrl') || defaultBridgeUrl();
    if (Kimi.bridge && Kimi.bridge.connect) Kimi.bridge.connect(url);

    renderEmptyState();
    updateHeader();
  }

  /* ---------- public api ---------- */
  Kimi.ui = {
    createSession: createSession,
    confirm: confirm,
    openSettings() { if (Kimi.settingsUI) Kimi.settingsUI.open(); },
    listShortcuts() {
      const items = (Kimi.shortcuts && Kimi.shortcuts._items) || [];
      return items.map((s) => ({ combo: s.combo, desc: s.desc }));
    },
    prevSession() { stepSession(-1); },
    nextSession() { stepSession(1); },
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
