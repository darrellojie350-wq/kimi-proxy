/* Kimi Proxy Web — js/composer.js  (ui-js)
 * Composer dock per ARCHITECTURE.md §4: 32px superellipse shell, auto-growing
 * textarea (Enter send / Shift+Enter newline), attach strip (paste/drag),
 * mode pills (YOLO/Plan/Auto → bridge config), thinking-effort pill,
 * model pill dropdown, send↔stop swap while streaming, context ring.
 * Builds inside the contract id #composer-wrap; uses only contract classes
 * (.composer-shell, .composer-toolbar, .composer-input, .pill*, .model-pill,
 * .send-btn, .stop-btn, .attach-btn, .context-ring, .composer-footer). */
(function () {
  'use strict';

  const Kimi = window.Kimi;
  const q = (sel) => document.querySelector(sel);

  const DEFAULT_MODELS = [
    'kimi',
    'chatanywhere:gpt-4.1-nano',
    'chatanywhere:gpt-4.1-mini',
    'chatanywhere:gpt-4.1-4o',
    'deepseek:deepseek-chat',
  ];
  const THINK_LEVELS = ['off', 'quick', 'deep'];
  const RUNNING = { streaming: 1, thinking: 1, toolRunning: 1 };

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
  const files = []; // {name, size}
  const _ringC = 2 * Math.PI * 15; // context-ring circumference (r=15)
  let _wired = false;

  function makePills() {
    const pills = h('div', 'comp-pills');
    els.pillYolo = h('button', 'pill pill-yolo');
    els.pillYolo.type = 'button';
    els.pillYolo.appendChild(icon('bolt'));
    els.pillYolo.appendChild(h('span', 'pill-label', 'YOLO'));
    els.pillPlan = h('button', 'pill pill-plan');
    els.pillPlan.type = 'button';
    els.pillPlan.appendChild(icon('target'));
    els.pillPlan.appendChild(h('span', 'pill-label', 'Plan'));
    els.pillAuto = h('button', 'pill pill-auto');
    els.pillAuto.type = 'button';
    els.pillAuto.appendChild(icon('sparkles'));
    els.pillAuto.appendChild(h('span', 'pill-label', 'Auto'));
    els.pillThink = h('button', 'pill pill-think');
    els.pillThink.type = 'button';
    els.pillThink.appendChild(icon('thinking'));
    els.pillThink.appendChild(h('span', 'pill-label', 'Think: off'));
    els.modelPill = h('button', 'model-pill');
    els.modelPill.type = 'button';
    els.modelPill.appendChild(icon('sliders'));
    els.modelPill.appendChild(h('span', 'model-pill-label', 'kimi'));
    els.modelPill.appendChild(icon('chevronDown'));
    pills.appendChild(els.pillYolo);
    pills.appendChild(els.pillPlan);
    pills.appendChild(els.pillAuto);
    pills.appendChild(els.pillThink);
    pills.appendChild(els.modelPill);
    return pills;
  }

  function makeActions() {
    const actions = h('div', 'composer-actions');
    els.attach = h('button', 'attach-btn');
    els.attach.type = 'button';
    els.attach.title = 'Attach files';
    els.attach.setAttribute('aria-label', 'Attach files');
    els.attach.appendChild(icon('paperclip'));

    const ringWrap = h('span', 'context-ring-wrap');
    els.ring = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    els.ring.setAttribute('viewBox', '0 0 36 36');
    els.ring.setAttribute('class', 'context-ring');
    els.ring.setAttribute('aria-hidden', 'true');
    const bg = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    bg.setAttribute('cx', '18'); bg.setAttribute('cy', '18'); bg.setAttribute('r', '15');
    bg.setAttribute('fill', 'none');
    bg.setAttribute('stroke', 'currentColor');
    bg.setAttribute('stroke-width', '2');
    bg.setAttribute('opacity', '0.15');
    els.ringFg = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    els.ringFg.setAttribute('cx', '18'); els.ringFg.setAttribute('cy', '18'); els.ringFg.setAttribute('r', '15');
    els.ringFg.setAttribute('fill', 'none');
    els.ringFg.setAttribute('stroke', 'var(--color-accent)');
    els.ringFg.setAttribute('stroke-width', '2');
    els.ringFg.setAttribute('stroke-linecap', 'round');
    els.ringFg.setAttribute('transform', 'rotate(-90 18 18)');
    els.ringFg.setAttribute('stroke-dasharray', _ringC.toFixed(2));
    els.ringFg.setAttribute('stroke-dashoffset', _ringC.toFixed(2));
    els.ring.appendChild(bg);
    els.ring.appendChild(els.ringFg);
    ringWrap.appendChild(els.ring);

    els.send = h('button', 'send-btn');
    els.send.type = 'button';
    els.send.title = 'Send (Enter)';
    els.send.setAttribute('aria-label', 'Send');
    els.send.appendChild(icon('send'));
    els.stop = h('button', 'stop-btn');
    els.stop.type = 'button';
    els.stop.title = 'Stop';
    els.stop.setAttribute('aria-label', 'Stop');
    els.stop.appendChild(icon('stop'));
    els.stop.hidden = true;

    actions.appendChild(els.attach);
    actions.appendChild(ringWrap);
    actions.appendChild(els.send);
    actions.appendChild(els.stop);
    return actions;
  }

  function makeFooter() {
    const footer = h('div', 'composer-footer');
    footer.appendChild(kbd('↵'));
    footer.appendChild(h('span', 'hint', ' send'));
    footer.appendChild(kbd('⇧↵'));
    footer.appendChild(h('span', 'hint', ' newline'));
    footer.appendChild(kbd('⌘K'));
    footer.appendChild(h('span', 'hint', ' palette'));
    return footer;
  }

  /* ---------- composer shell (build-if-missing, wire-once) ---------- */
  function ensure() {
    if (els.shell) return els;
    const wrap = q('#composer-wrap');
    if (!wrap) return els;
    els.wrap = wrap;

    const existing = wrap.querySelector('.composer-shell');
    if (existing && existing.querySelector('.composer-input')) {
      // Agent A provided a shell with a textarea — adopt it and fill gaps.
      els.shell = existing;
      els.ta = existing.querySelector('.composer-input');
      els.inputRow = existing.querySelector('.composer-input-row');
      els.send = existing.querySelector('.send-btn');
      els.stop = existing.querySelector('.stop-btn');
      els.attach = existing.querySelector('.attach-btn');
      els.ring = existing.querySelector('.context-ring');
      els.ringFg = els.ring ? els.ring.querySelector('circle:last-child') : null;
      els.strip = existing.querySelector('.attachments-strip');
      if (!els.strip) {
        els.strip = h('div', 'attachments-strip');
        els.strip.hidden = true;
        existing.insertBefore(els.strip, existing.firstChild);
      }
      els.pills = existing.querySelector('.comp-pills');
      if (!els.pills) {
        const toolbar = existing.querySelector('.composer-toolbar');
        const target = toolbar || existing;
        els.pills = makePills();
        if (toolbar) toolbar.appendChild(els.pills);
        else target.insertBefore(els.pills, els.strip.nextSibling || null);
      }
      els.actions = existing.querySelector('.composer-actions');
      if (!els.actions) {
        els.actions = makeActions();
        (existing.querySelector('.composer-input-row') || existing).appendChild(els.actions);
      }
      els.footer = existing.querySelector('.composer-footer');
      if (!els.footer) {
        els.footer = makeFooter();
        existing.appendChild(els.footer);
      }
      wire();
      return els;
    }

    // No usable shell — build the full structure.
    els.shell = existing || h('div', 'composer-shell');
    if (els.shell.childNodes.length) els.shell.replaceChildren();

    els.strip = h('div', 'attachments-strip');
    els.strip.hidden = true;

    const toolbar = h('div', 'composer-toolbar');
    els.pills = makePills();
    toolbar.appendChild(els.pills);

    els.inputRow = h('div', 'composer-input-row');
    els.ta = h('textarea', 'composer-input');
    els.ta.rows = 1;
    els.ta.placeholder = 'Ask Kimi anything…';
    els.ta.setAttribute('aria-label', 'Message');

    els.actions = makeActions();

    els.inputRow.appendChild(els.ta);
    els.inputRow.appendChild(els.actions);

    els.footer = makeFooter();

    els.shell.appendChild(els.strip);
    els.shell.appendChild(toolbar);
    els.shell.appendChild(els.inputRow);
    els.shell.appendChild(els.footer);
    if (!existing) wrap.appendChild(els.shell);

    wire();
    return els;
  }

  /* ---------- model list ---------- */
  function models() {
    const m = Kimi.settings.get('models', null);
    return Array.isArray(m) && m.length ? m : DEFAULT_MODELS;
  }

  /* ---------- mode pills ---------- */
  function modeOf(s) {
    if (!s) return 'auto';
    if (s.yolo) return 'yolo';
    if (s.planMode) return 'plan';
    return 'auto';
  }

  function applyMode(s, mode) {
    if (!s) return;
    if (mode === 'yolo') { s.yolo = true; s.planMode = false; }
    else if (mode === 'plan') { s.planMode = true; s.yolo = false; }
    else { s.yolo = false; s.planMode = false; }
    sendConfig(s, mode);
    refreshPills(s);
  }

  function sendConfig(s, mode) {
    if (!s || Kimi.bridge.status !== 'online') return;
    Kimi.bridge.send({
      type: 'config',
      sessionId: s.id,
      yolo: !!s.yolo,
      planMode: !!s.planMode,
      model: s.model || null,
    });
    if (mode && Kimi.toast) {
      if (mode === 'yolo') Kimi.toast.info('YOLO mode — tools auto-run');
      else if (mode === 'plan') Kimi.toast.info('Plan mode — approval required');
      else Kimi.toast.info('Auto mode');
    }
  }

  function refreshPills(s) {
    if (!els.pills) return;
    const m = modeOf(s);
    const set = (pill, on) => {
      pill.classList.toggle('active', !!on);
      pill.setAttribute('aria-pressed', on ? 'true' : 'false');
    };
    set(els.pillYolo, m === 'yolo');
    set(els.pillPlan, m === 'plan');
    set(els.pillAuto, m === 'auto');
    const level = (s && s.thinkingEffort) || Kimi.settings.get('thinkEffort', 'off');
    els.pillThink.querySelector('.pill-label').textContent = 'Think: ' + level;
  }

  /* ---------- model pill + dropdown ---------- */
  function openModelMenu() {
    closeModelMenu();
    const menu = h('div', 'model-menu');
    menu.setAttribute('role', 'listbox');
    const s = Kimi.sessions.current();
    const cur = s && s.model ? s.model : (Kimi.settings.get('defaultModel', 'kimi') || 'kimi');
    models().forEach((m) => {
      const item = h('button', 'model-menu-item' + (m === cur ? ' active' : ''), m);
      item.type = 'button';
      item.setAttribute('role', 'option');
      item.addEventListener('click', () => {
        closeModelMenu();
        setModel(m);
      });
      menu.appendChild(item);
    });
    menu.style.minWidth = Math.max(160, (els.modelPill.offsetWidth || 160)) + 'px';
    els.shell.appendChild(menu);
    els.modelMenu = menu;
    setTimeout(() => {
      document.addEventListener('click', onDocClick, true);
    }, 0);
  }

  function closeModelMenu() {
    document.removeEventListener('click', onDocClick, true);
    if (els.modelMenu) {
      els.modelMenu.remove();
      els.modelMenu = null;
    }
  }

  function onDocClick(e) {
    if (els.modelMenu && !els.modelMenu.contains(e.target) && !els.modelPill.contains(e.target)) {
      closeModelMenu();
    }
  }

  function setModel(m) {
    const s = Kimi.sessions.current();
    if (s) {
      s.model = m;
      sendConfig(s, null);
      Kimi.bus.emit('sessions.changed');
    } else {
      Kimi.settings.set('defaultModel', m);
    }
    updateModelLabel();
    if (Kimi.toast) Kimi.toast.success('Model switched to ' + m);
  }

  function updateModelLabel() {
    if (!els.modelPill) return;
    const s = Kimi.sessions.current();
    const label = els.modelPill.querySelector('.model-pill-label');
    if (label) label.textContent = (s && s.model) || Kimi.settings.get('defaultModel', 'kimi');
  }

  /* ---------- thinking effort ---------- */
  function cycleThink(s) {
    if (!s) return;
    const cur = s.thinkingEffort || Kimi.settings.get('thinkEffort', 'off');
    const next = THINK_LEVELS[(THINK_LEVELS.indexOf(cur) + 1) % THINK_LEVELS.length];
    s.thinkingEffort = next;
    Kimi.settings.set('thinkEffort', next);
    refreshPills(s);
    if (Kimi.toast) Kimi.toast.info('Thinking effort: ' + next);
  }

  /* ---------- textarea ---------- */
  function autoGrow() {
    const ta = els.ta;
    if (!ta) return;
    ta.style.height = 'auto';
    const max = 10 * 22; // ~10 lines
    ta.style.height = Math.min(ta.scrollHeight, max) + 'px';
    ta.style.overflowY = ta.scrollHeight > max ? 'auto' : 'hidden';
    updateSendState();
  }

  function updateSendState() {
    if (!els.send) return;
    const s = Kimi.sessions.current();
    const running = s && RUNNING[s.status];
    const empty = !els.ta.value.trim() && !files.length;
    const disabled = !!(running || empty);
    els.send.classList.toggle('disabled', disabled);
    els.send.setAttribute('aria-disabled', disabled ? 'true' : 'false');
  }

  /* ---------- send / stop ---------- */
  function send(text) {
    let content = typeof text === 'string' ? text.trim() : (els.ta ? els.ta.value.trim() : '');
    if (!content) return;

    if (files.length) {
      const head = 'Attachments:\n' + files.map((f) => '- ' + f.name).join('\n') + '\n\n';
      content = head + content;
    }

    let s = Kimi.sessions.current();
    if (!s) {
      if (Kimi.ui && Kimi.ui.createSession) Kimi.ui.createSession();
      s = Kimi.sessions.current();
    }
    if (!s) {
      if (Kimi.toast) Kimi.toast.error('No session available');
      return;
    }

    if (Kimi.bridge.status !== 'online') {
      if (Kimi.toast) Kimi.toast.error('Bridge offline — cannot send');
      return;
    }

    // auto-title from first prompt (matches kimi behavior)
    if (/^New session/.test(s.name || '')) {
      const title = content.replace(/\s+/g, ' ').slice(0, 48);
      Kimi.sessions.rename(s.id, title);
    }

    // bridge.send('prompt') appends the user msg + assistant placeholder,
    // sets status=streaming and emits sessions.changed (bridge.js side effects).
    Kimi.bridge.send({ type: 'prompt', sessionId: s.id, content: content });

    if (els.ta) els.ta.value = '';
    files.length = 0;
    renderStrip();
    autoGrow();
    if (els.ta) els.ta.focus();
  }

  function stop() {
    const s = Kimi.sessions.current();
    if (!s) return;
    if (Kimi.bridge.status !== 'online') return;
    Kimi.bridge.send({ type: 'interrupt', sessionId: s.id });
  }

  /* ---------- send/stop swap ---------- */
  function refreshRunState() {
    if (!els.send || !els.stop) return;
    const s = Kimi.sessions.current();
    const running = !!(s && RUNNING[s.status]);
    els.send.hidden = running;
    els.stop.hidden = !running;
    updateSendState();
    updateRing(s);
  }

  /* ---------- context ring ---------- */
  function updateRing(s) {
    if (!els.ringFg) return;
    const count = (s && s.messageCount) || 0;
    const progress = Math.min(1, count / 100);
    els.ringFg.setAttribute('stroke-dashoffset', (_ringC * (1 - progress)).toFixed(2));
    const color = progress >= 1 ? 'var(--color-danger)'
      : progress >= 0.8 ? 'var(--color-warning)'
        : 'var(--color-accent)';
    els.ringFg.setAttribute('stroke', color);
    els.ring.title = count + ' messages · context ring';
  }

  /* ---------- attachments ---------- */
  function addFiles(list) {
    if (!list || !list.length) return;
    for (let i = 0; i < list.length; i++) {
      const f = list[i];
      if (!f || !f.name) continue;
      if (files.some((x) => x.name === f.name)) continue;
      files.push({ name: f.name, size: f.size || 0 });
    }
    renderStrip();
  }

  function removeFile(name) {
    const i = files.findIndex((f) => f.name === name);
    if (i !== -1) files.splice(i, 1);
    renderStrip();
  }

  function renderStrip() {
    if (!els.strip) return;
    els.strip.replaceChildren();
    els.strip.hidden = files.length === 0;
    files.forEach((f) => {
      const chip = h('span', 'attach-chip');
      chip.appendChild(icon('file'));
      chip.appendChild(h('span', 'chip-name', f.name));
      const rm = h('button', 'chip-remove');
      rm.type = 'button';
      rm.title = 'Remove';
      rm.appendChild(icon('close'));
      rm.addEventListener('click', () => removeFile(f.name));
      chip.appendChild(rm);
      els.strip.appendChild(chip);
    });
    if (files.length) {
      const clear = h('button', 'chip-clear', 'Clear all');
      clear.type = 'button';
      clear.addEventListener('click', () => { files.length = 0; renderStrip(); });
      els.strip.appendChild(clear);
    }
    autoGrow();
  }

  function wire() {
    if (_wired) return;
    _wired = true;

    // textarea
    els.ta.addEventListener('input', autoGrow);
    els.ta.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) {
        e.preventDefault();
        send();
      }
    });
    els.ta.addEventListener('paste', (e) => {
      if (e.clipboardData && e.clipboardData.files && e.clipboardData.files.length) {
        e.preventDefault();
        addFiles(e.clipboardData.files);
      }
    });

    // drag & drop
    els.shell.addEventListener('dragover', (e) => {
      e.preventDefault();
      els.shell.classList.add('drag');
    });
    els.shell.addEventListener('dragleave', () => els.shell.classList.remove('drag'));
    els.shell.addEventListener('drop', (e) => {
      e.preventDefault();
      els.shell.classList.remove('drag');
      if (e.dataTransfer && e.dataTransfer.files) addFiles(e.dataTransfer.files);
    });

    // actions
    if (els.send) els.send.addEventListener('click', send);
    if (els.stop) els.stop.addEventListener('click', stop);
    if (els.attach) {
      els.attach.addEventListener('click', () => {
        if (!els.fileInput) {
          els.fileInput = h('input', 'attach-file-input');
          els.fileInput.type = 'file';
          els.fileInput.multiple = true;
          els.fileInput.style.display = 'none';
          document.body.appendChild(els.fileInput);
          els.fileInput.addEventListener('change', () => {
            addFiles(els.fileInput.files);
            els.fileInput.value = '';
          });
        }
        els.fileInput.click();
      });
    }

    // pills
    if (els.pillYolo) els.pillYolo.addEventListener('click', () => applyMode(Kimi.sessions.current(), 'yolo'));
    if (els.pillPlan) els.pillPlan.addEventListener('click', () => applyMode(Kimi.sessions.current(), 'plan'));
    if (els.pillAuto) els.pillAuto.addEventListener('click', () => applyMode(Kimi.sessions.current(), 'auto'));
    if (els.pillThink) els.pillThink.addEventListener('click', () => cycleThink(Kimi.sessions.current()));
    if (els.modelPill) {
      els.modelPill.addEventListener('click', (e) => {
        e.stopPropagation();
        if (els.modelMenu) closeModelMenu(); else openModelMenu();
      });
    }

    // bus
    Kimi.bus.on('session.selected', onSessionChange);
    Kimi.bus.on('sessions.changed', onSessionChange);
    Kimi.bus.on('session.status', (d) => {
      if (!d || d.sessionId !== (Kimi.state.activeId || '')) return;
      refreshRunState();
    });
    Kimi.bus.on('message.delta', (d) => {
      if (!d || d.sessionId !== (Kimi.state.activeId || '')) return;
      updateRing(Kimi.sessions.current());
    });
  }

  function onSessionChange() {
    const s = Kimi.sessions.current();
    refreshPills(s);
    updateModelLabel();
    refreshRunState();
    closeModelMenu();
  }

  /* ---------- public api ---------- */
  const Composer = {
    init() {
      ensure();
      onSessionChange();
    },
    send(text) { send(text); },
    interrupt() { stop(); },
    setMode(mode) { applyMode(Kimi.sessions.current(), mode); },
    setModel(m) { setModel(m); },
    openModelMenu() { openModelMenu(); },
    refresh() { onSessionChange(); },
  };

  Kimi.composer = Composer;
})();
