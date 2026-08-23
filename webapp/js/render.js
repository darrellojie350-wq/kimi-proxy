/**
 * render.js — Kimi.render DOM renderers (message, thinkingRow, toolCallLine,
 * toolOutputBlock, activityRun, turnFold, emptyState, skeletonRow, errorCard).
 * Agent C (render-js) · per ARCHITECTURE.md §3 (renderer signatures) / §4 (classes).
 *
 * Builds DOM with a tiny h() helper (createElement-based, no innerHTML for
 * dynamic content except trusted renderer output). Sub-elements not listed in
 * §4 carry inline styles via CSS custom properties so they are legible regardless
 * of shell-agent app.css coverage.
 */
(function () {
  'use strict';

  var Kimi = window.Kimi = window.Kimi || {};
  var render = Kimi.render = Kimi.render || {};
  var R = render;

  function extend(dst, src) {
    for (var k in src) if (Object.prototype.hasOwnProperty.call(src, k)) dst[k] = src[k];
    return dst;
  }

  /* ------------------------------------------------------- inject keyframes */

  function injectAnimations() {
    if (typeof document === 'undefined' || document.getElementById('kimi-render-style')) return;
    var st = document.createElement('style');
    st.id = 'kimi-render-style';
    st.textContent = [
      '@keyframes kimi-caret-blink{0%,45%{opacity:1}50%,95%{opacity:0}100%{opacity:1}}',
      '@keyframes kimi-breathe{0%,100%{opacity:.56}50%{opacity:.84}}',
      '@keyframes kimi-pulse-dot{0%,100%{opacity:1}50%{opacity:.35}}',
      '@keyframes kimi-skeleton{0%,100%{opacity:.4}50%{opacity:.85}}',
      '.kimi-caret{display:inline-block;width:1px;height:1em;background:var(--color-accent);margin-left:2px;vertical-align:-2px;animation:kimi-caret-blink 1s steps(1) infinite}',
      '.kimi-breathe{animation:kimi-breathe 1.2s ease-in-out infinite}',
      '.kimi-pulse{animation:kimi-pulse-dot .7s ease-in-out infinite}',
      '.kimi-skel{animation:kimi-skeleton 1.5s ease-in-out infinite}',
      '@media (prefers-reduced-motion: reduce){.kimi-caret,.kimi-breathe,.kimi-pulse,.kimi-skel{animation:none}}'
    ].join('\n');
    document.head.appendChild(st);
  }
  injectAnimations();

  /* --------------------------------------------------------------- h() DOM */

  function h(tag, attrs, children) {
    var el = document.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        if (!Object.prototype.hasOwnProperty.call(attrs, k)) continue;
        var v = attrs[k];
        if (v == null || v === false) continue;
        if (k === 'class') { el.className = v; }
        else if (k === 'style') {
          if (typeof v === 'string') el.setAttribute('style', v);
          else for (var p in v) if (Object.prototype.hasOwnProperty.call(v, p) && v[p] != null) el.style[p] = v[p];
        }
        else if (k === 'dataset') { for (var d in v) if (Object.prototype.hasOwnProperty.call(v, d)) el.dataset[d] = v[d]; }
        else if (k === 'attrs') { for (var a in v) if (Object.prototype.hasOwnProperty.call(v, a)) el.setAttribute(a, v[a]); }
        else if (k === 'html') { el.innerHTML = v; } // trusted renderer output only
        else if (k === 'on') { for (var e in v) if (Object.prototype.hasOwnProperty.call(v, e)) el.addEventListener(e, v[e]); }
        else if (k.slice(0, 2) === 'on' && typeof v === 'function') { el.addEventListener(k.slice(2), v); }
        else { el.setAttribute(k, v); }
      }
    }
    if (children != null) {
      if (!Array.isArray(children)) children = [children];
      for (var c = 0; c < children.length; c++) {
        var ch = children[c];
        if (ch == null || ch === false) continue;
        if (ch.nodeType) el.appendChild(ch);
        else el.appendChild(document.createTextNode(String(ch)));
      }
    }
    return el;
  }

  /* ------------------------------------------------------- icon helper */

  function icon(name, size, colorVar) {
    var svgStr = (Kimi.icons && Kimi.icons[name]) || (Kimi.icons && Kimi.icons.code) || '';
    var holder = h('span', {
      class: 'kimi-icon',
      'aria-hidden': 'true',
      style: { display: 'inline-flex', flex: 'none', width: size + 'px', height: size + 'px', color: colorVar ? 'var(' + colorVar + ')' : 'inherit' }
    });
    if (svgStr) {
      var wrap = document.createElement('span');
      wrap.innerHTML = svgStr;
      var svg = wrap.firstElementChild;
      if (svg) {
        svg.setAttribute('width', String(size));
        svg.setAttribute('height', String(size));
        svg.setAttribute('focusable', 'false');
        holder.appendChild(svg);
      }
    }
    return holder;
  }

  /* ------------------------------------------------------- formatters */

  function fmtDur(ms) {
    var s = Math.max(0, Math.round((ms || 0) / 1000));
    if (s < 60) return s + 's';
    var m = Math.floor(s / 60);
    var r = s % 60;
    return r ? m + 'm ' + r + 's' : m + 'm';
  }

  function fmtTime(ts) {
    try { return new Date(ts || Date.now()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); }
    catch (e) { return ''; }
  }

  function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

  /* ------------------------------------------------------- tool helpers */

  var TOOL_ICONS = {
    bash: 'terminal', terminal: 'terminal', shell: 'terminal',
    read: 'file', file: 'file', view: 'file',
    write: 'fileEdit', edit: 'fileEdit', append: 'fileEdit',
    glob: 'search', grep: 'search',
    ls: 'folder', list: 'folder',
    websearch: 'globe', web_search: 'globe',
    fetchurl: 'link', fetch: 'link', url: 'link',
    todo: 'checkCircle', task: 'checkCircle',
    kimi: 'robot', agent: 'robot', subagent: 'robot',
    image: 'image', draw: 'image',
    think: 'thinking', plan: 'target', prompt: 'chatNew'
  };

  function toolIcon(name) {
    var n = String(name || '').toLowerCase().replace(/[\s_-]/g, '');
    return TOOL_ICONS[n] || 'code';
  }

  var TOOL_LABELS = {
    bash: 'Run', terminal: 'Run', shell: 'Run',
    read: 'Read', file: 'Read', view: 'Read',
    write: 'Write', edit: 'Edit', append: 'Write',
    glob: 'List', grep: 'Search',
    ls: 'List', list: 'List',
    websearch: 'Web search', web_search: 'Web search',
    fetchurl: 'Fetch', fetch: 'Fetch', url: 'Fetch',
    todo: 'Todo', kimi: 'Agent', image: 'Image'
  };

  function toolLabel(name) {
    var n = String(name || '').toLowerCase().replace(/[\s_-]/g, '');
    return TOOL_LABELS[n] || cap(name || 'tool');
  }

  function toolArgs(tc) {
    var a = tc.arguments || {};
    var name = String(tc.name || '').toLowerCase();
    if (name === 'bash' || name === 'shell' || name === 'terminal') return a.command || a.cmd || a.script || '';
    if (name === 'read' || name === 'write' || name === 'edit' || name === 'file' || name === 'view' || name === 'append') {
      var p = a.filePath || a.path || a.file || '';
      var ln = a.startLine != null || a.endLine != null ? ':' + (a.startLine != null ? a.startLine : '') + '-' + (a.endLine != null ? a.endLine : '') : '';
      return p + ln;
    }
    if (name === 'grep') return a.pattern || a.query || '';
    if (name === 'glob') return a.pattern || (a.paths && a.paths.join(', ')) || '';
    if (name === 'ls' || name === 'list') return a.path || (a.paths && a.paths.join(', ')) || '';
    if (name === 'websearch' || name === 'search') return a.query || '';
    if (name === 'fetchurl' || name === 'fetch') return a.url || a.uri || '';
    if (name === 'todo') return a.task || a.title || '';
    try { var j = JSON.stringify(a); return j && j.length > 80 ? j.slice(0, 80) + '\u2026' : (j || ''); } catch (e) { return ''; }
  }

  var KIND_LABEL = { read: 'Read', write: 'Write', edit: 'Edit', bash: 'Bash', grep: 'Search', glob: 'List', websearch: 'Web search', fetchurl: 'Fetch', todo: 'Todo' };

  function summarize(items) {
    var byName = {};
    var order = [];
    var failedN = 0;
    var totalMs = 0;
    items.forEach(function (it) {
      var name = String(it.name || 'tool').toLowerCase().replace(/[\s_-]/g, '');
      if (!byName[name]) { byName[name] = { n: 0, failed: 0 }; order.push(name); }
      byName[name].n++;
      if (it.status === 'failed' || it.status === 'error') byName[name].failed++;
      if (it.durationMs) totalMs += it.durationMs;
    });
    var segs = order.map(function (n) {
      var o = byName[n];
      var label = KIND_LABEL[n] || cap(n);
      if (o.n > 1) return label + ' ' + o.n;
      return label;
    });
    // count total failures
    for (var k in byName) if (Object.prototype.hasOwnProperty.call(byName, k)) failedN += byName[k].failed;
    return { text: segs.join(' \u00b7 '), failed: failedN, time: totalMs > 0 ? fmtDur(totalMs) : '' };
  }

  /* ------------------------------------------------------- status helper */

  function statusElFor(status) {
    var s = h('span', { class: 'tool-line-status' });
    var st = String(status || 'pending').toLowerCase();
    if (st === 'running' || st === 'pending') {
      s.className = 'tool-line-status status-running';
      s.appendChild(h('span', { class: 'dot dot-running kimi-pulse', style: { width: '6px', height: '6px', borderRadius: '50%', background: 'var(--color-accent)', display: 'inline-block' } }));
    } else if (st === 'success' || st === 'done' || st === 'completed') {
      s.className = 'tool-line-status status-success dot-ok';
      s.appendChild(icon('check', 14, '--color-success'));
    } else if (st === 'failed' || st === 'error') {
      s.className = 'tool-line-status status-failed dot-fail';
      s.appendChild(icon('xCircle', 14, '--color-danger'));
    } else {
      s.className = 'tool-line-status status-idle';
    }
    return s;
  }

  /* ------------------------------------------------------- math + copy */

  function renderMath(el) {
    try {
      if (window.renderMathInElement && window.katex) {
        window.renderMathInElement(el, { delimiters: [
          { left: '$$', right: '$$', display: true },
          { left: '$', right: '$', display: false },
          { left: '\\(', right: '\\)', display: false },
          { left: '\\[', right: '\\]', display: true }
        ], throwOnError: false });
      }
    } catch (e) { /* graceful degrade */ }
  }

  function wireCopy(root) {
    var btns = root.querySelectorAll('.copy-btn[data-copy]');
    for (var i = 0; i < btns.length; i++) {
      var btn = btns[i];
      if (btn.dataset.wired) continue;
      btn.dataset.wired = '1';
      btn.addEventListener('click', function () {
        var pre = this.closest('.code-block');
        var codeEl = pre && pre.querySelector('code');
        var text = codeEl ? codeEl.textContent : '';
        var done = function () {
          var old = this.textContent;
          this.textContent = 'Copied';
          setTimeout(function () { this.textContent = old; }.bind(this), 1200);
        }.bind(this);
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done.bind(this), done.bind(this));
        } else {
          var ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed'; ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.select();
          try { document.execCommand('copy'); } catch (e) { /* noop */ }
          document.body.removeChild(ta);
          done.bind(this)();
        }
      });
    }
  }

  /* =========================================================== RENDERERS */

  /**
   * message(role, content, opts) -> HTMLElement
   * role: 'user' | 'assistant' | 'system'
   * opts: { model, ts, streaming, error, msgId, sessionId }
   * Returns element with .msg-[role] + .msg-content (markdown rendered) and
   * a streaming caret when opts.streaming is true. Methods: el.update(md, o2).
   */
  function message(role, content, opts) {
    opts = opts || {};
    var streaming = !!opts.streaming;
    var msg = h('div', { class: 'msg msg-' + role, 'data-msg-id': opts.msgId || '', 'data-role': role });

    if (role === 'user') {
      var bubble = h('div', { class: 'msg-user-bubble' });
      bubble.innerHTML = (R.markdownToHtml || function (s) { return (R.escapeHtml || function (x) { return x; })(s); })(String(content || ''), { partial: streaming });
      msg.appendChild(bubble);
      var meta = h('div', { class: 'msg-meta' });
      if (opts.model) meta.appendChild(h('span', { class: 'msg-model', style: { fontFamily: 'var(--font-mono)', fontSize: '12px', fontWeight: '500', color: 'var(--color-text-muted)' } }, opts.model));
      meta.appendChild(h('span', { class: 'msg-ts', style: { fontFamily: 'var(--font-mono)', fontSize: '12px', color: 'var(--color-text-dim)', marginLeft: '8px' } }, fmtTime(opts.ts)));
      msg.appendChild(meta);
    } else if (role === 'system') {
      msg.appendChild(h('div', { class: 'msg-system-inner', style: { textAlign: 'center', fontSize: '13px', color: 'var(--color-text-muted)', padding: '8px 0' } }, String(content || '')));
    } else {
      // assistant
      var head = h('div', { class: 'msg-head' });
      var modelLabel = opts.model || (Kimi.state && Kimi.state.settings && Kimi.state.settings.model) || 'kimi';
      head.appendChild(h('span', { class: 'msg-model', style: { fontFamily: 'var(--font-mono)', fontSize: '12px', fontWeight: '500', color: 'var(--color-text-muted)' } }, modelLabel));
      head.appendChild(h('span', { class: 'msg-ts', style: { fontFamily: 'var(--font-mono)', fontSize: '12px', color: 'var(--color-text-dim)', marginLeft: '8px' } }, fmtTime(opts.ts)));
      msg.appendChild(head);

      var contentEl = h('div', { class: 'msg-content', attrs: opts.streaming ? { 'aria-live': 'polite' } : {} });
      if (streaming) contentEl.classList.add('is-streaming');
      contentEl.innerHTML = (R.markdownToHtml || function (s) { return (R.escapeHtml || function (x) { return x; })(s); })(String(content || ''), { partial: streaming });
      msg.appendChild(contentEl);
      wireCopy(contentEl);
      if (R.markdownToHtml) renderMath(contentEl);

      if (streaming) msg.appendChild(h('span', { class: 'stream-caret kimi-caret' }));

      if (opts.error) {
        msg.appendChild((R.errorCard || function (m) { return h('div', { style: { color: 'var(--color-danger)' } }, m); })(opts.error));
      }
    }

    msg.update = function (md, o2) {
      o2 = o2 || {};
      streaming = !!(o2.streaming != null ? o2.streaming : opts.streaming);
      if (role === 'assistant') {
        contentEl.innerHTML = (R.markdownToHtml || function (s) { return (R.escapeHtml || function (x) { return x; })(s); })(String(md || ''), { partial: streaming });
        wireCopy(contentEl);
        if (R.markdownToHtml) renderMath(contentEl);
        var caret = msg.querySelector('.stream-caret');
        if (streaming && !caret) msg.appendChild(h('span', { class: 'stream-caret kimi-caret' }));
        if (!streaming && caret) caret.remove();
        if (streaming) contentEl.classList.add('is-streaming'); else contentEl.classList.remove('is-streaming');
      }
    };
    msg.setStreaming = function (v) { if (role === 'assistant') msg.update(content, { streaming: v }); };
    msg.setError = function (errMsg) { if (opts.error) { var ec = msg.querySelector('.error-card'); if (ec) ec.remove(); } msg.appendChild((R.errorCard || function (m) { return h('div', { style: { color: 'var(--color-danger)' } }, m); })(errMsg)); };
    return msg;
  }

  /**
   * thinkingRow(deltaText, state) -> HTMLElement
   * state: 'streaming' | 'settled' | { streaming: bool, durationMs: number }
   * Inline collapsed row with bulb icon, breathing label, ticking seconds.
   * Returns element with methods: el.update(delta, state), el.settle(durationMs),
   * el.expand(), el.collapse(), el.destroy().
   * Auto-collapses on settle (per design: "folds itself back").
   */
  function thinkingRow(deltaText, state) {
    var info = stateInfo(state);
    var streaming = info.streaming;
    var startTs = Date.now();
    var timer = null;

    function stateInfo(st) {
      if (st && typeof st === 'object') return { streaming: !!st.streaming, elapsedMs: st.elapsedMs || st.durationMs || 0, durationMs: st.durationMs || st.elapsedMs || 0 };
      return { streaming: st === 'streaming' || st === 'running', elapsedMs: 0, durationMs: 0 };
    }

    var wrap = h('div', { class: 'thinking-row', attrs: { 'data-expanded': 'false' } });
    var btn = h('button', {
      type: 'button', class: 'thinking-toggle',
      attrs: { 'aria-expanded': 'false' },
      on: { click: function () { toggleBody(); } },
      style: { display: 'flex', alignItems: 'center', gap: '6px', width: '100%', background: 'none', border: 'none', padding: '2px 0', cursor: 'pointer', color: 'inherit', font: 'inherit', textAlign: 'left' }
    });
    btn.appendChild(icon('thinking', 16, '--color-text-muted'));
    var label = h('span', { class: 'thinking-label', style: { fontSize: '13px', color: 'var(--color-text-muted)' } });
    var sec = h('span', { class: 'thinking-sec', style: { fontFamily: 'var(--font-mono)', fontSize: '12px', color: 'var(--color-text-dim)', marginLeft: '4px' } });
    btn.appendChild(label);
    btn.appendChild(sec);
    var chev = icon('chevronDown', 14, '--color-text-dim');
    chev.style.transition = 'transform .16s var(--ease-in-out)';
    chev.style.marginLeft = 'auto';
    btn.appendChild(chev);

    var body = h('div', {
      class: 'thinking-body',
      style: { display: 'grid', gridTemplateRows: '0fr', transition: 'grid-template-rows .26s var(--ease-in-out)', overflow: 'hidden' }
    });
    var inner = h('div', { style: { overflow: 'hidden', minHeight: '0' } });
    if (deltaText) inner.innerHTML = (R.markdownToHtml || function (s) { return (R.escapeHtml || function (x) { return x; })(s); })(String(deltaText || ''), { partial: streaming });
    body.appendChild(inner);
    wrap.appendChild(btn);
    wrap.appendChild(body);

    var bodyOpen = false;
    function toggleBody() {
      bodyOpen = !bodyOpen;
      body.style.gridTemplateRows = bodyOpen ? '1fr' : '0fr';
      wrap.setAttribute('data-expanded', String(bodyOpen));
      btn.setAttribute('aria-expanded', String(bodyOpen));
      chev.style.transform = bodyOpen ? 'rotate(180deg)' : '';
    }

    function startTimer() {
      if (timer) return;
      timer = setInterval(function () {
        sec.textContent = fmtDur(Date.now() - startTs);
      }, 1000);
    }
    function stopTimer() {
      if (timer) { clearInterval(timer); timer = null; }
    }

    function renderState() {
      if (streaming) {
        label.textContent = 'Thinking\u2026';
        label.classList.add('kimi-breathe');
        sec.textContent = '';
        startTimer();
        if (!bodyOpen) toggleBody(); // keep open while streaming
      } else {
        label.classList.remove('kimi-breathe');
        stopTimer();
        var dur = info.durationMs || (Date.now() - startTs);
        label.textContent = 'Thinking process \u00b7 ' + fmtDur(dur);
        sec.textContent = '';
        // auto-collapse on settle (design: "folds itself back")
        if (bodyOpen) toggleBody();
      }
    }

    renderState();

    wrap.update = function (d, st) {
      deltaText = d;
      info = stateInfo(st);
      streaming = info.streaming;
      if (d) inner.innerHTML = (R.markdownToHtml || function (s) { return (R.escapeHtml || function (x) { return x; })(s); })(String(d), { partial: streaming });
      renderState();
    };
    wrap.settle = function (durationMs) {
      streaming = false;
      info.streaming = false;
      info.durationMs = durationMs || (Date.now() - startTs);
      renderState();
    };
    wrap.expand = function () { if (!bodyOpen) toggleBody(); };
    wrap.collapse = function () { if (bodyOpen) toggleBody(); };
    wrap.destroy = function () { stopTimer(); };
    return wrap;
  }

  /**
   * toolCallLine(tc) -> HTMLElement
   * tc: ToolEntry { id, name, arguments, status, output?, startedAt, durationMs }
   * Quiet borderless 24px row with icon, action label, collapsed args, status
   * dot, expandable detail. Methods: el.update(tc2), el.setStatus(st),
   * el.setOutput(out), el.expand(), el.collapse(), el.destroy().
   */
  function toolCallLine(tc) {
    tc = tc || {};
    var wrap = h('div', { class: 'tool-call', style: { marginTop: '2px' }, 'data-tool-id': tc.id || '', 'data-tool-status': tc.status || 'pending' });
    var row = h('button', {
      type: 'button', class: 'tool-line',
      attrs: { 'aria-expanded': 'false' },
      style: { display: 'flex', alignItems: 'center', gap: '8px', width: '100%', background: 'none', border: 'none', padding: '3px 0', cursor: 'pointer', color: 'inherit', font: 'inherit', textAlign: 'left' }
    });
    var iconEl = icon(toolIcon(tc.name), 16, '--color-text-faint');
    iconEl.className = 'tool-line-icon';
    var nameEl = h('span', { class: 'tool-line-name', style: { fontSize: '13px', fontWeight: '500', color: 'var(--color-text-muted)', flex: 'none', whiteSpace: 'nowrap' } }, toolLabel(tc.name));
    var argsEl = h('span', { class: 'tool-line-args', style: { fontFamily: 'var(--font-mono)', fontSize: '12px', color: 'var(--color-text-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', minWidth: '0', flex: '1 1 auto' } }, toolArgs(tc));
    var durEl = h('span', { class: 'tool-line-duration', style: { fontFamily: 'var(--font-mono)', fontSize: '11px', color: 'var(--color-text-dim)', flex: 'none', marginLeft: '4px' } });
    var stEl = statusElFor(tc.status);
    var chev = icon('chevronDown', 14, '--color-text-dim');
    chev.style.transition = 'transform .16s var(--ease-in-out)';
    chev.style.flex = 'none';
    row.appendChild(iconEl); row.appendChild(nameEl); row.appendChild(argsEl); row.appendChild(durEl); row.appendChild(stEl); row.appendChild(chev);

    var detail = h('div', {
      class: 'tool-line-detail',
      style: { display: 'grid', gridTemplateRows: '0fr', transition: 'grid-template-rows .26s var(--ease-in-out)', overflow: 'hidden' }
    });
    var detailInner = h('div', { style: { overflow: 'hidden', minHeight: '0' } });
    detail.appendChild(detailInner);
    wrap.appendChild(row);
    wrap.appendChild(detail);

    var open = false;
    var built = false;

    function refreshStatus() {
      while (stEl.firstChild) stEl.removeChild(stEl.firstChild);
      stEl.className = 'tool-line-status';
      var st = String(tc.status || 'pending').toLowerCase();
      if (st === 'running' || st === 'pending') {
        stEl.classList.add('status-running');
        stEl.appendChild(h('span', { class: 'dot dot-running kimi-pulse', style: { width: '6px', height: '6px', borderRadius: '50%', background: 'var(--color-accent)', display: 'inline-block' } }));
      } else if (st === 'success' || st === 'done' || st === 'completed') {
        stEl.classList.add('status-success', 'dot-ok');
        stEl.appendChild(icon('check', 14, '--color-success'));
      } else if (st === 'failed' || st === 'error') {
        stEl.classList.add('status-failed', 'dot-fail');
        stEl.appendChild(icon('xCircle', 14, '--color-danger'));
      } else {
        stEl.classList.add('status-idle');
      }
      durEl.textContent = (st === 'success' || st === 'failed') && tc.durationMs ? fmtDur(tc.durationMs) : '';
      wrap.setAttribute('data-tool-status', st);
    }

    function buildDetail() {
      detailInner.innerHTML = '';
      if (R.toolOutputBlock) detailInner.appendChild(R.toolOutputBlock(tc));
    }

    function toggle() {
      open = !open;
      detail.style.gridTemplateRows = open ? '1fr' : '0fr';
      row.setAttribute('aria-expanded', String(open));
      chev.style.transform = open ? 'rotate(180deg)' : '';
      if (open && !built) { buildDetail(); built = true; }
    }

    row.addEventListener('click', toggle);

    refreshStatus();

    wrap.update = function (tc2) {
      tc = tc2;
      // replace icon
      var newIcon = icon(toolIcon(tc.name), 16, '--color-text-faint');
      newIcon.className = 'tool-line-icon';
      iconEl.parentNode.replaceChild(newIcon, iconEl);
      iconEl = newIcon;
      // update name, args
      nameEl.textContent = toolLabel(tc.name);
      argsEl.textContent = toolArgs(tc);
      refreshStatus();
      if (open) { buildDetail(); built = true; }
    };
    wrap.setStatus = function (st) { tc.status = st; refreshStatus(); if (open) { buildDetail(); built = true; } };
    wrap.setOutput = function (out) { tc.output = out; if (open) { buildDetail(); built = true; } };
    wrap.expand = function () { if (!open) toggle(); };
    wrap.collapse = function () { if (open) toggle(); };
    wrap.destroy = function () { row.removeEventListener('click', toggle); };
    return wrap;
  }

  /**
   * toolOutputBlock(entry) -> HTMLElement
   * Renders the expanded output of a tool call: terminal well for Bash, diff
   * view for Edit/Write, file preview with line numbers for Read, list for
   * Glob, table-ish for Grep, plain mono for others.
   */
  function toolOutputBlock(entry) {
    entry = entry || {};
    var name = String(entry.name || '').toLowerCase().replace(/[\s_-]/g, '');
    var out = String(entry.output || '');
    var well = h('div', { class: 'tool-output-well', style: { fontFamily: 'var(--font-mono)', fontSize: '12px', lineHeight: '1.5', maxHeight: '300px', overflow: 'auto', background: 'var(--color-well)', borderRadius: '6px', border: '0.5px solid var(--color-hairline)', marginTop: '4px' } });

    if (!out) {
      well.appendChild(h('div', { style: { color: 'var(--color-text-dim)', padding: '8px 12px' } }, 'No output'));
      return well;
    }

    if (name === 'bash' || name === 'terminal' || name === 'shell') {
      well.appendChild(terminalWell(entry));
    } else if (name === 'edit' || name === 'write' || name === 'append') {
      well.appendChild(diffView(entry));
    } else if (name === 'read' || name === 'file' || name === 'view') {
      well.appendChild(filePreview(entry));
    } else if (name === 'glob' || name === 'ls' || name === 'list') {
      well.appendChild(pathList(entry));
    } else if (name === 'grep' || name === 'search') {
      well.appendChild(grepView(entry));
    } else if (name === 'websearch' || name === 'web_search' || name === 'fetchurl' || name === 'fetch' || name === 'url') {
      well.appendChild(monoWell(entry));
    } else {
      well.appendChild(monoWell(entry));
    }
    return well;
  }

  function terminalWell(entry) {
    var box = h('div', { class: 'terminal-well', style: { padding: '8px 12px' } });
    var cmd = entry.arguments && entry.arguments.command;
    if (cmd) {
      box.appendChild(h('div', { class: 'term-cmd', style: { color: 'var(--color-text-muted)', marginBottom: '6px', whiteSpace: 'pre-wrap', wordBreak: 'break-all' } }, '> ' + cmd));
    }
    box.appendChild(h('pre', { class: 'term-out', style: { margin: '0', whiteSpace: 'pre-wrap', wordBreak: 'break-word', color: 'var(--color-text)' } }, String(entry.output || '')));
    return box;
  }

  function diffView(entry) {
    var box = h('div', { class: 'diff-view', style: { padding: '0' } });
    var lines = String(entry.output || '').split('\n');
    lines.forEach(function (line) {
      if (line.slice(0, 3) === '+++' || line.slice(0, 3) === '---') {
        box.appendChild(h('div', { class: 'diff-line diff-head', style: { padding: '0 12px', color: 'var(--color-text-dim)', fontSize: '11px', lineHeight: '1.6' } }, line));
      } else if (line[0] === '@' && line[1] === '@') {
        box.appendChild(h('div', { class: 'diff-line diff-hunk', style: { padding: '0 12px', color: 'var(--color-info)', lineHeight: '1.6' } }, line));
      } else if (line[0] === '+' && line[1] !== '+') {
        box.appendChild(h('div', { class: 'diff-line diff-add', style: { padding: '0 12px', background: 'rgba(63,185,80,.08)', color: 'var(--color-success)', lineHeight: '1.6' } }, line));
      } else if (line[0] === '-' && line[1] !== '-') {
        box.appendChild(h('div', { class: 'diff-line diff-del', style: { padding: '0 12px', background: 'rgba(248,81,73,.08)', color: 'var(--color-danger)', lineHeight: '1.6' } }, line));
      } else {
        box.appendChild(h('div', { class: 'diff-line diff-ctx', style: { padding: '0 12px', color: 'var(--color-text-muted)', lineHeight: '1.6' } }, line));
      }
    });
    return box;
  }

  function filePreview(entry) {
    var box = h('div', { class: 'file-preview', style: { padding: '4px 0' } });
    var path = entry.arguments && (entry.arguments.filePath || entry.arguments.path || entry.arguments.file);
    if (path) {
      box.appendChild(h('div', { class: 'fp-head', style: { fontFamily: 'var(--font-mono)', fontSize: '11px', color: 'var(--color-text-muted)', padding: '4px 12px', borderBottom: '0.5px solid var(--color-hairline)' } }, path));
    }
    var lines = String(entry.output || '').split('\n');
    var grid = h('div', { class: 'fp-grid', style: { display: 'grid', gridTemplateColumns: '3.5em 1fr', fontFamily: 'var(--font-mono)', fontSize: '12px', lineHeight: '1.5' } });
    lines.forEach(function (l, idx) {
      grid.appendChild(h('span', { class: 'fp-num', style: { color: 'var(--color-text-dim)', textAlign: 'right', paddingRight: '8px', paddingLeft: '8px', userSelect: 'none' } }, String(idx + 1)));
      grid.appendChild(h('span', { class: 'fp-line', style: { color: 'var(--color-text)', whiteSpace: 'pre-wrap', wordBreak: 'break-all' } }, l));
    });
    box.appendChild(grid);
    return box;
  }

  function pathList(entry) {
    var box = h('div', { class: 'path-list', style: { padding: '8px 12px' } });
    var lines = String(entry.output || '').split('\n').filter(Boolean);
    lines.forEach(function (p) {
      box.appendChild(h('div', { class: 'path-item', style: { color: 'var(--color-text)', lineHeight: '1.6', whiteSpace: 'pre-wrap' } }, p));
    });
    return box;
  }

  function grepView(entry) {
    var box = h('div', { class: 'grep-view', style: { padding: '4px 0' } });
    var lines = String(entry.output || '').split('\n');
    lines.forEach(function (l) {
      if (!l) return;
      var m = /^([^:]+):(\d+):(\d+):(.*)$/.exec(l) || /^([^:]+):(\d+):(.*)$/.exec(l);
      if (m) {
        var file = m[1], lineNo = m[2], col = m[3], content = m[4] != null ? m[4] : '';
        var row = h('div', { class: 'grep-row', style: { display: 'grid', gridTemplateColumns: 'minmax(0,1fr) 4em minmax(0,2fr)', gap: '0 8px', padding: '1px 12px', lineHeight: '1.6' } });
        row.appendChild(h('span', { class: 'grep-file', style: { color: 'var(--color-text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' } }, file));
        row.appendChild(h('span', { class: 'grep-loc', style: { color: 'var(--color-text-dim)', textAlign: 'right' } }, m[4] != null ? lineNo + ':' + col : lineNo));
        row.appendChild(h('span', { class: 'grep-content', style: { color: 'var(--color-text)', whiteSpace: 'pre-wrap', wordBreak: 'break-all' } }, m[4] != null ? content : col));
        box.appendChild(row);
      } else {
        box.appendChild(h('div', { class: 'grep-line', style: { color: 'var(--color-text-muted)', padding: '1px 12px', lineHeight: '1.6' } }, l));
      }
    });
    return box;
  }

  function monoWell(entry) {
    var box = h('div', { class: 'mono-well', style: { padding: '8px 12px' } });
    box.appendChild(h('pre', { style: { margin: '0', whiteSpace: 'pre-wrap', wordBreak: 'break-word', color: 'var(--color-text)' } }, String(entry.output || '')));
    return box;
  }

  /**
   * activityRun(items) -> HTMLElement
   * items: ToolEntry[]
   * Groups ≥2 consecutive tool calls into a smart-summary row ("Read 2 · Bash 3").
   * Single item renders as a plain toolCallLine.
   * Methods: el.update(items2), el.expand(), el.collapse().
   */
  function activityRun(items) {
    items = items || [];
    if (items.length < 2) {
      return items.length ? R.toolCallLine(items[0]) : h('span');
    }
    var wrap = h('div', { class: 'activity-run' });
    var running = items.some(function (it) { return it.status === 'running' || it.status === 'pending'; });
    var sum = summarize(items);

    var btn = h('button', {
      type: 'button', class: 'activity-run-toggle',
      'aria-expanded': String(!running),
      style: { display: 'flex', alignItems: 'center', gap: '6px', width: '100%', background: 'none', border: 'none', padding: '4px 0', cursor: 'pointer', color: 'inherit', font: 'inherit', textAlign: 'left' }
    });
    var firstIcon = icon(toolIcon(items[0] && items[0].name), 14, running ? '--color-accent' : '--color-text-faint');
    if (running) firstIcon.classList.add('kimi-breathe');
    btn.appendChild(firstIcon);
    var sumEl = h('span', { class: 'activity-run-summary', style: { fontSize: '13px', color: 'var(--color-text-muted)', flex: '1' } }, sum.text);
    btn.appendChild(sumEl);
    if (sum.failed) {
      btn.appendChild(h('span', { class: 'activity-run-fail', style: { fontSize: '12px', color: 'var(--color-danger)', fontFamily: 'var(--font-mono)' } }, ' \u00b7 ' + sum.failed + ' failed'));
    }
    if (sum.time) {
      btn.appendChild(h('span', { class: 'activity-run-time', style: { fontFamily: 'var(--font-mono)', fontSize: '11px', color: 'var(--color-text-dim)' } }, ' \u00b7 ' + sum.time));
    }
    var chev = icon('chevronDown', 14, '--color-text-dim');
    chev.style.transition = 'transform .16s var(--ease-in-out)';
    btn.appendChild(chev);

    var body = h('div', {
      class: 'activity-run-body',
      style: { display: 'grid', gridTemplateRows: running ? '1fr' : '0fr', transition: 'grid-template-rows .26s var(--ease-in-out)', overflow: 'hidden' }
    });
    var bodyInner = h('div', { style: { overflow: 'hidden', minHeight: '0' } });
    items.forEach(function (it) { if (R.toolCallLine) bodyInner.appendChild(R.toolCallLine(it)); });
    body.appendChild(bodyInner);

    wrap.appendChild(btn);
    wrap.appendChild(body);

    var open = running;
    chev.style.transform = open ? 'rotate(180deg)' : '';

    btn.addEventListener('click', function () {
      open = !open;
      body.style.gridTemplateRows = open ? '1fr' : '0fr';
      btn.setAttribute('aria-expanded', String(open));
      chev.style.transform = open ? 'rotate(180deg)' : '';
    });

    wrap.update = function (items2) {
      items = items2 || [];
      running = items.some(function (it) { return it.status === 'running' || it.status === 'pending'; });
      sum = summarize(items);
      sumEl.textContent = sum.text;
      if (running && !open) { open = true; body.style.gridTemplateRows = '1fr'; btn.setAttribute('aria-expanded', 'true'); chev.style.transform = 'rotate(180deg)'; }
      // rebuild body
      bodyInner.innerHTML = '';
      items.forEach(function (it) { if (R.toolCallLine) bodyInner.appendChild(R.toolCallLine(it)); });
    };
    wrap.expand = function () { if (!open) btn.click(); };
    wrap.collapse = function () { if (open) btn.click(); };
    return wrap;
  }

  /**
   * turnFold(durationMs) -> HTMLElement
   * "Worked 12s" fold row.
   */
  function turnFold(durationMs) {
    return h('div', { class: 'turn-fold', attrs: { 'data-duration-ms': String(durationMs || 0) } },
      h('span', { style: { fontFamily: 'var(--font-mono)', fontSize: '12px', color: 'var(--color-text-dim)' } }, 'Worked ' + fmtDur(durationMs)));
  }

  /**
   * emptyState() -> HTMLElement
   * Centered welcome hero with sparkles icon, title, hint, new-chat button,
   * and starter suggestion chips (data-prompt for app.js wiring).
   */
  function emptyState() {
    var box = h('div', { class: 'empty-state' });
    var hero = h('div', { class: 'welcome-hero', style: { textAlign: 'center', padding: '48px 16px 24px' } });
    hero.appendChild(icon('sparkles', 48, '--color-text-dim'));
    hero.appendChild(h('h2', { style: { fontSize: '18px', fontWeight: '600', color: 'var(--color-text)', margin: '16px 0 4px' } }, 'Start a conversation'));
    hero.appendChild(h('p', { style: { fontSize: '14px', color: 'var(--color-text-muted)', margin: '0 0 20px', lineHeight: '1.5' } }, 'Ask anything \u2014 Kimi Code will think, read files, and run commands.'));
    // primary new-chat button
    hero.appendChild(h('button', { type: 'button', class: 'new-chat-btn', style: { display: 'inline-flex', alignItems: 'center', gap: '6px', padding: '8px 20px', borderRadius: '999px', border: 'none', background: 'var(--color-text)', color: 'var(--color-bg)', fontFamily: 'var(--font-ui)', fontWeight: '600', fontSize: '14px', cursor: 'pointer' } }, 'New chat'));
    box.appendChild(hero);

    var chips = h('div', { class: 'starter-chips', style: { display: 'flex', gap: '8px', justifyContent: 'center', flexWrap: 'wrap', padding: '0 16px 32px' } });
    ['Explain this codebase', 'Plan a feature', 'Debug an error'].forEach(function (p) {
      chips.appendChild(h('button', {
        type: 'button', class: 'starter-chip',
        dataset: { prompt: p },
        style: { padding: '6px 14px', borderRadius: '999px', border: '0.5px solid var(--color-hairline)', background: 'var(--color-well)', color: 'var(--color-text-muted)', fontFamily: 'var(--font-ui)', fontSize: '13px', cursor: 'pointer', whiteSpace: 'nowrap' }
      }, p));
    });
    box.appendChild(chips);
    return box;
  }

  /**
   * skeletonRow() -> HTMLElement
   * Breathing placeholder (title line + 3 text lines). aria-hidden.
   */
  function skeletonRow() {
    var row = h('div', { class: 'skeleton-row', attrs: { 'aria-hidden': 'true' }, style: { padding: '12px 0' } });
    var widths = [0.6, 1, 1, 0.8];
    widths.forEach(function (w, i) {
      var line = h('div', {
        class: 'skeleton-line kimi-skel',
        style: { height: i === 0 ? '14px' : '12px', width: (w * 100) + '%', maxWidth: i === 0 ? '260px' : '100%', background: 'var(--color-raised)', borderRadius: '4px', marginTop: i === 0 ? '0' : '8px' }
      });
      row.appendChild(line);
    });
    return row;
  }

  /**
   * errorCard(msg) -> HTMLElement
   * Inline error card with alert icon, error title, message, and a "Try again"
   * button. Methods: el.setAction(fn) to wire the retry button.
   */
  function errorCard(msg, title) {
    title = title || 'Error';
    var card = h('div', { class: 'error-card', attrs: { role: 'alert' }, style: { display: 'flex', gap: '10px', alignItems: 'flex-start', padding: '12px 14px', borderRadius: '12px', backgroundColor: 'var(--color-raised)', border: '0.5px solid var(--color-hairline)', margin: '8px 0' } });
    card.appendChild(icon('alert', 18, '--color-danger'));
    var body = h('div', { style: { flex: '1', minWidth: '0' } });
    body.appendChild(h('div', { style: { fontWeight: '600', fontSize: '13px', color: 'var(--color-text)' } }, title));
    body.appendChild(h('div', { style: { fontSize: '13px', color: 'var(--color-text-muted)', marginTop: '2px', lineHeight: '1.4' } }, String(msg || '')));
    card.appendChild(body);
    var actBtn = h('button', { type: 'button', class: 'error-card-action', style: { flex: 'none', padding: '4px 12px', borderRadius: '6px', border: '0.5px solid var(--color-hairline)', background: 'transparent', color: 'var(--color-accent)', fontFamily: 'var(--font-ui)', fontSize: '13px', fontWeight: '500', cursor: 'pointer', whiteSpace: 'nowrap' } }, 'Try again');
    card.appendChild(actBtn);
    card.setAction = function (fn) {
      actBtn.addEventListener('click', fn);
    };
    return card;
  }

  /* ============================================================= EXPORT */

  extend(render, {
    h: h,
    icon: icon,
    message: message,
    thinkingRow: thinkingRow,
    toolCallLine: toolCallLine,
    toolOutputBlock: toolOutputBlock,
    activityRun: activityRun,
    turnFold: turnFold,
    emptyState: emptyState,
    skeletonRow: skeletonRow,
    errorCard: errorCard,
    renderMath: renderMath,
    wireCopy: wireCopy,
    fmtDur: fmtDur,
    fmtTime: fmtTime
  });
})();