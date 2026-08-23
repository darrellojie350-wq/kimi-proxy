/* ============================================================================
 * Kimi Proxy Web — toast system (Agent B / infra-js)
 * Kimi.toast: show(msg, kind, opts), success/error/info helpers.
 * Icon-led per design system; stack bottom-right, auto-dismiss 8s, hover pauses.
 * Contract: ARCHITECTURE.md §3 (toast API) + §4 (toast classes).
 * ========================================================================== */
(function () {
  'use strict';

  var K = window.Kimi;
  if (!K) throw new Error('kimi.js must load before toast.js');

  var DEFAULT_DURATION = 8000;
  var MAX_VISIBLE = 3;

  /* icon map — keyed by kind */
  var ICON_MAP = {
    info: 'info',
    success: 'checkCircle',
    error: 'xCircle',
    warning: 'alert',
  };

  /* --------------------------------------------------------------- helpers */

  function h(tag, attrs, children) {
    var el = document.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        if (k === 'className') { el.className = attrs[k]; }
        else if (k === 'dataset') {
          for (var dk in attrs.dataset) el.dataset[dk] = attrs.dataset[dk];
        } else { el.setAttribute(k, attrs[k]); }
      }
    }
    if (children) {
      for (var i = 0; i < children.length; i++) {
        var c = children[i];
        if (typeof c === 'string') el.appendChild(document.createTextNode(c));
        else if (c) el.appendChild(c);
      }
    }
    return el;
  }

  function getStack() {
    var stack = document.getElementById('toast-stack');
    if (!stack) {
      stack = h('div', { id: 'toast-stack', className: 'toast-stack' });
      document.body.appendChild(stack);
    }
    return stack;
  }

  /* --------------------------------------------------------------- internal */

  var activeToasts = [];

  function removeToast(el, timer) {
    if (timer) clearTimeout(timer);
    var idx = activeToasts.indexOf(el);
    if (idx > -1) activeToasts.splice(idx, 1);
    if (el.parentNode) {
      el.style.opacity = '0';
      el.style.transform = 'translateY(8px)';
      setTimeout(function () {
        if (el.parentNode) el.parentNode.removeChild(el);
      }, 120);
    }
    // trim stack to max visible
    trimStack();
  }

  function trimStack() {
    var stack = getStack();
    while (stack.children.length > MAX_VISIBLE) {
      var oldest = stack.children[0];
      if (oldest) {
        var idx = activeToasts.indexOf(oldest);
        if (idx > -1) activeToasts.splice(idx, 1);
        stack.removeChild(oldest);
      }
    }
  }

  /* ---------------------------------------------------------------- public */

  var toast = {
    show: function (msg, kind, opts) {
      kind = kind || 'info';
      opts = opts || {};
      var duration = opts.duration != null ? opts.duration : DEFAULT_DURATION;
      var iconName = ICON_MAP[kind] || 'info';
      var iconSvg = K.icons[iconName] || '';
      var title = opts.title || '';

      var body = h('div', { className: 'toast-body' });
      if (title) body.appendChild(h('div', { className: 'toast-title' }, [title]));
      body.appendChild(h('div', { className: 'toast-desc' }, [String(msg)]));

      var iconEl = h('span', { className: 'toast-icon', 'aria-hidden': 'true' });
      if (iconSvg) iconEl.innerHTML = iconSvg;

      var closeBtn = h('button', {
        className: 'toast-close', 'aria-label': 'Dismiss',
        onclick: function () { removeToast(el, timer); },
      });
      closeBtn.innerHTML = K.icons.close || '×';

      var el = h('div', {
        className: 'toast toast-' + kind,
        role: 'status',
        'aria-live': 'polite',
      }, [iconEl, body, closeBtn]);

      // action button
      if (opts.action && opts.action.label) {
        var actionBtn = h('button', {
          className: 'toast-action',
          onclick: function (e) {
            e.stopPropagation();
            if (opts.action.onClick) opts.action.onClick();
            removeToast(el, timer);
          },
        }, [opts.action.label]);
        body.appendChild(actionBtn);
      }

      var timer = null;
      if (duration > 0) {
        timer = setTimeout(function () { removeToast(el, timer); }, duration);
      }

      // hover pause / resume
      el.addEventListener('mouseenter', function () { if (timer) { clearTimeout(timer); timer = null; } });
      el.addEventListener('mouseleave', function () {
        if (!timer && duration > 0) {
          timer = setTimeout(function () { removeToast(el, timer); }, duration);
        }
      });

      // click to dismiss
      el.addEventListener('click', function (e) {
        if (e.target === el || e.target.className === 'toast-body') {
          removeToast(el, timer);
        }
      });

      getStack().appendChild(el);
      activeToasts.push(el);
      trimStack();

      // emit on bus so D can observe
      K.bus.emit('toast', { message: msg, kind: kind });

      return el;
    },

    success: function (msg, opts) { return toast.show(msg, 'success', opts); },
    error: function (msg, opts) { return toast.show(msg, 'error', opts); },
    info: function (msg, opts) { return toast.show(msg, 'info', opts); },
    warning: function (msg, opts) { return toast.show(msg, 'warning', opts); },
  };

  K.toast = toast;
})();