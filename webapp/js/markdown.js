/**
 * markdown.js — Kimi.render.{escapeHtml, highlightCode, markdownToHtml}
 * Agent C (render-js) · per ARCHITECTURE.md §3 (render API) / §8 (design language).
 *
 * XSS policy: raw user content is NEVER emitted unescaped. Block parsing runs on
 * the raw text, but every piece of user text is escaped at emission time; only
 * tags produced by this file enter the output. Raw HTML in user input is escaped
 * to text (no passthrough). highlightCode escapes each token before wrapping it.
 *
 * Math ($..$ / $$..$$) is intentionally left as literal text here — it is rendered
 * by render.js via KaTeX auto-render (window.renderMathInElement) once the HTML is
 * in the DOM, and degrades gracefully when KaTeX is absent.
 */
(function () {
  'use strict';

  var Kimi = window.Kimi = window.Kimi || {};
  var render = Kimi.render = Kimi.render || {};

  function extend(dst, src) {
    for (var k in src) if (Object.prototype.hasOwnProperty.call(src, k)) dst[k] = src[k];
    return dst;
  }

  /* ---------------------------------------------------------------- escape */

  var ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return ESC[c]; });
  }

  /* -------------------------------------------------------------- highlight */

  // Token class -> CSS color token (resolves per [data-theme]; dark + light both work)
  var TOK_COLOR = {
    'tok-comment': '--color-text-dim',
    'tok-string': '--color-success',
    'tok-keyword': '--color-accent',
    'tok-number': '--color-warning',
    'tok-var': '--color-warning',
    'tok-tag': '--color-accent',
    'tok-attr': '--color-warning',
    'tok-func': '--color-accent',
    'tok-literal': '--color-warning',
    'tok-prop': '--color-info',
    'tok-selector': '--color-accent',
    'tok-type': '--color-accent',
    'tok-operator': '--color-text-muted',
    'tok-punct': '--color-text-dim',
    'tok-decorator': '--color-success',
    'tok-label': '--color-text-muted'
  };
  var TOK_DEFAULT = '--color-text';

  // Ordered token rules per language. Order matters: the first rule that matches
  // at a position wins (comments before operators, keywords before identifiers…).
  // No rule may contain capturing groups (non-capturing (?:) only).
  var JS_KEYWORDS = 'const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|new|delete|typeof|instanceof|in|of|class|extends|super|this|async|await|try|catch|finally|throw|import|export|from|default|yield|static|get|set|interface|type|enum|implements|private|protected|public|readonly|as|namespace|declare|abstract|override|accessor|satisfies|using|with';
  var PY_KEYWORDS = 'def|class|return|if|elif|else|for|while|break|continue|pass|import|from|as|with|try|except|finally|raise|lambda|yield|global|nonlocal|assert|del|in|is|not|and|or|async|await|match|case|self';
  var BASH_KEYWORDS = 'if|then|else|elif|fi|for|while|until|do|done|case|esac|function|in|select|time|export|local|readonly|return|exit|set|unset|source|alias|declare|echo|printf|cd|pwd|mkdir|rmdir|rm|cp|mv|touch|cat|grep|sed|awk|curl|wget|git|npm|pnpm|yarn|node|python|python3|pip|sudo|sh|bash|zsh|find|ls|head|tail|sort|uniq|wc|chmod|chown|xargs|tar|zip|unzip|make|cmake|npx|docker|kubectl';

  var JS_PARTS = [
    { re: /\/\/[^\n]*/, h: 'tok-comment' },
    { re: /\/\*[\s\S]*?\*\//, h: 'tok-comment' },
    { re: /'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"/, h: 'tok-string' },
    { re: /`(?:[^`\\]|\\.)*`/, h: 'tok-string' },
    { re: /\b(?:true|false|null|undefined|NaN|Infinity)\b/, h: 'tok-literal' },
    { re: /\b0[xX][0-9a-fA-F_]+\b|\b\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?n?\b/, h: 'tok-number' },
    { re: new RegExp('\\b(?:' + JS_KEYWORDS + ')\\b'), h: 'tok-keyword' },
    { re: /\b[A-Za-z_$][\w$]*(?=\s*\()/, h: 'tok-func' },
    { re: /\b[A-Z][A-Za-z0-9_]*\b/, h: 'tok-type' },
    { re: /[+\-*/%=<>!&|^~?:]+/, h: 'tok-operator' },
    { re: /[()[\]{}.,;:]/, h: 'tok-punct' }
  ];

  var PY_PARTS = [
    { re: /#[^\n]*/, h: 'tok-comment' },
    { re: /f?r?u?"""[\s\S]*?"""/, h: 'tok-string' },
    { re: /f?r?u?'''[\s\S]*?'''/, h: 'tok-string' },
    { re: /'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"/, h: 'tok-string' },
    { re: /@[\w.]+/, h: 'tok-decorator' },
    { re: /\b(?:True|False|None)\b/, h: 'tok-literal' },
    { re: /\b0[xX][0-9a-fA-F_]+\b|\b\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?[jJ]?\b/, h: 'tok-number' },
    { re: new RegExp('\\b(?:' + PY_KEYWORDS + ')\\b'), h: 'tok-keyword' },
    { re: /[A-Za-z_]\w*(?=\s*\()/, h: 'tok-func' },
    { re: /[+\-*/%=<>!&|^~]+/, h: 'tok-operator' },
    { re: /[()[\]{}.,;:]/, h: 'tok-punct' }
  ];

  var BASH_PARTS = [
    { re: /#[^\n]*/, h: 'tok-comment' },
    { re: /'[^'\n]*'|"[^"\n]*"/, h: 'tok-string' },
    { re: /\$(?:\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*|[0-9*@#?!$])/, h: 'tok-var' },
    { re: /--?[A-Za-z0-9][A-Za-z0-9_-]*/, h: 'tok-attr' },
    { re: /\b(?:true|false)\b/, h: 'tok-literal' },
    { re: /\b\d+(?:\.\d+)?\b/, h: 'tok-number' },
    { re: new RegExp('\\b(?:' + BASH_KEYWORDS + ')\\b'), h: 'tok-keyword' },
    { re: /[|&;><=()!]+/, h: 'tok-operator' },
    { re: /[()[\]{}.,;:]/, h: 'tok-punct' }
  ];

  var JSON_PARTS = [
    { re: /"(?:[^"\\]|\\.)*"(?=\s*:)/, h: 'tok-prop' },
    { re: /"(?:[^"\\]|\\.)*"/, h: 'tok-string' },
    { re: /\b(?:true|false|null)\b/, h: 'tok-literal' },
    { re: /-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/, h: 'tok-number' },
    { re: /[()[\]{}.,;:]/, h: 'tok-punct' }
  ];

  var HTML_PARTS = [
    { re: /<!--[\s\S]*?-->/, h: 'tok-comment' },
    { re: /<!doctype[^>]*>/i, h: 'tok-keyword' },
    { re: /<\/?[a-zA-Z][a-zA-Z0-9-]*/, h: 'tok-tag' },
    { re: /[a-zA-Z_:][a-zA-Z0-9_.:-]*(?=\s*=)/, h: 'tok-attr' },
    { re: /"[^"]*"|'[^']*'/, h: 'tok-string' },
    { re: /\/?>/, h: 'tok-punct' },
    { re: /&(?:[a-zA-Z0-9#]+);/, h: 'tok-label' },
    { re: /[<>]/, h: 'tok-punct' }
  ];

  var CSS_PARTS = [
    { re: /\/\*[\s\S]*?\*\//, h: 'tok-comment' },
    { re: /"[^"]*"|'[^']*'/, h: 'tok-string' },
    { re: /@[\w-]+/, h: 'tok-keyword' },
    { re: /#[0-9a-fA-F]{3,8}\b/, h: 'tok-number' },
    { re: /\b\d+(?:\.\d+)?(?:px|em|rem|%|s|ms|vh|vw|vmin|vmax|fr|deg|pt|ch|ex|q|cm|mm|in|pc)?\b/, h: 'tok-number' },
    { re: /[.#][\w-]+/, h: 'tok-selector' },
    { re: /[a-zA-Z-]+(?=\s*:)/, h: 'tok-prop' },
    { re: /[()[\]{}.,;:]/, h: 'tok-punct' }
  ];

  function buildLexer(parts) {
    if (!parts || !parts.length) {
      return function (code) { return [{ text: String(code == null ? '' : code) }]; };
    }
    var master = new RegExp(parts.map(function (p) { return '(' + p.re.source + ')'; }).join('|'), 'g');
    var hs = parts.map(function (p) { return p.h; });
    return function (code) {
      var out = [];
      var last = 0;
      var m;
      master.lastIndex = 0;
      while ((m = master.exec(code))) {
        if (m.index > last) out.push({ text: code.slice(last, m.index) });
        var found = false;
        for (var i = 1; i < m.length; i++) {
          if (m[i] !== undefined) { out.push({ text: m[i], h: hs[i - 1] }); found = true; break; }
        }
        last = m.index + m[0].length;
        if (m[0].length === 0) master.lastIndex++; // safety: never stall
        if (!found) break;
      }
      if (last < code.length) out.push({ text: code.slice(last) });
      return out;
    };
  }

  var LEXERS = {};
  LEXERS.js = buildLexer(JS_PARTS);
  LEXERS.javascript = LEXERS.js;
  LEXERS.ts = LEXERS.js;
  LEXERS.typescript = LEXERS.js;
  LEXERS.jsx = LEXERS.js;
  LEXERS.tsx = LEXERS.js;
  LEXERS.node = LEXERS.js;
  LEXERS.py = buildLexer(PY_PARTS);
  LEXERS.python = LEXERS.py;
  LEXERS.bash = buildLexer(BASH_PARTS);
  LEXERS.sh = LEXERS.bash;
  LEXERS.shell = LEXERS.bash;
  LEXERS.zsh = LEXERS.bash;
  LEXERS.console = LEXERS.bash;
  LEXERS.json = buildLexer(JSON_PARTS);
  LEXERS.html = buildLexer(HTML_PARTS);
  LEXERS.htm = LEXERS.html;
  LEXERS.xml = LEXERS.html;
  LEXERS.svg = LEXERS.html;
  LEXERS.css = buildLexer(CSS_PARTS);
  LEXERS.scss = LEXERS.css;
  LEXERS.less = LEXERS.css;
  LEXERS.text = buildLexer([]);

  /**
   * highlightCode(code, lang) -> HTML string (spans). Safe: every token is
   * escapeHtml'd before wrapping. Unknown/absent lang renders plain text.
   */
  function highlightCode(code, lang) {
    var src = String(code == null ? '' : code);
    var l = String(lang || '').toLowerCase().replace(/^language-/, '');
    var lexer = LEXERS[l] || LEXERS.text;
    var toks;
    try { toks = lexer(src); } catch (e) { toks = [{ text: src }]; }
    var out = '';
    for (var i = 0; i < toks.length; i++) {
      var t = toks[i];
      if (t.h) {
        out += '<span class="' + t.h + '" style="color:var(' + (TOK_COLOR[t.h] || TOK_DEFAULT) + ')">' + escapeHtml(t.text) + '</span>';
      } else {
        out += escapeHtml(t.text);
      }
    }
    return out;
  }

  /* --------------------------------------------------------------- markdown */

  // Only http(s)/mailto schemes and scheme-less (relative, #anchor) links pass.
  function sanitizeUrl(u) {
    var m = /^([a-zA-Z][a-zA-Z0-9+.-]*):/.exec(u);
    if (m && !/^(https?|mailto)$/i.test(m[1])) return null;
    return u;
  }

  function splitRow(line) {
    var s = line.trim();
    if (s.charAt(0) === '|') s = s.slice(1);
    if (s.charAt(s.length - 1) === '|') s = s.slice(0, -1);
    return s.split('|').map(function (x) { return x.trim(); });
  }

  function parseTable(lines, start) {
    var header = splitRow(lines[start]);
    var sep = splitRow(lines[start + 1]);
    var aligns = sep.map(function (c) {
      if (/^:?-+:?$/.test(c)) {
        if (c.charAt(0) === ':' && c.charAt(c.length - 1) === ':') return 'center';
        if (c.charAt(0) === ':') return 'left';
        if (c.charAt(c.length - 1) === ':') return 'right';
      }
      return null;
    });
    var html = '<table><thead><tr>';
    for (var i = 0; i < header.length; i++) {
      html += '<th' + (aligns[i] ? ' style="text-align:' + aligns[i] + '"' : '') + '>' + inline(header[i]) + '</th>';
    }
    html += '</tr></thead><tbody>';
    var j = start + 2;
    while (j < lines.length) {
      var row = lines[j].trim();
      if (row === '' || row.indexOf('|') === -1) break;
      var cells = splitRow(lines[j]);
      html += '<tr>';
      for (var k = 0; k < cells.length; k++) {
        html += '<td' + (aligns[k] ? ' style="text-align:' + aligns[k] + '"' : '') + '>' + inline(cells[k]) + '</td>';
      }
      html += '</tr>';
      j++;
    }
    html += '</tbody></table>';
    return { html: html, index: j };
  }

  function parseList(lines, start) {
    var firstM = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(lines[start]);
    var ordered = /^\d+[.)]$/.test(firstM[2]);
    var items = [];
    var idx = start;
    while (idx < lines.length) {
      var m = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(lines[idx]);
      if (!m) break;
      var indent = m[1].length;
      var item = { text: m[3], child: null };
      idx++;
      while (idx < lines.length) {
        var c = lines[idx];
        var cm = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(c);
        if (cm) {
          if (cm[1].length > indent) {
            var sub = parseList(lines, idx);
            if (!item.child) item.child = [];
            item.child.push(sub.html);
            idx = sub.index;
          } else {
            break;
          }
        } else if (/^\s*$/.test(c)) {
          idx++;
          break;
        } else if (c.charAt(0) === ' ' || c.charAt(0) === '\t') {
          item.text += '\n' + c.trim();
          idx++;
        } else {
          break;
        }
      }
      items.push(item);
    }
    var tag = ordered ? 'ol' : 'ul';
    var html = '<' + tag + '>';
    for (var n = 0; n < items.length; n++) {
      var it = items[n];
      html += '<li>' + inline(it.text) + (it.child ? it.child.join('') : '') + '</li>';
    }
    html += '</' + tag + '>';
    return { html: html, index: idx };
  }

  /**
   * Inline transforms. Input is the RAW (un-escaped) text; it is escaped FIRST,
   * then only this file's own tags are inserted. No raw HTML from user content
   * can reach the output.
   */
  function inline(text) {
    var s = escapeHtml(String(text == null ? '' : text));

    // code spans first — their content is protected from all later transforms
    s = s.replace(/`([^`\n]+)`/g, function (_, code) { return '<code>' + code + '</code>'; });

    // images ![alt](url) — sanitized
    s = s.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, function (_, alt, url) {
      var u = sanitizeUrl(url);
      return u ? '<img src="' + u + '" alt="' + alt + '" loading="lazy">' : '![' + alt + '](' + url + ')';
    });

    // links [label](url "title"?) — target=_blank rel=noopener
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)/g, function (_, label, url) {
      var u = sanitizeUrl(url);
      return u ? '<a href="' + u + '" target="_blank" rel="noopener noreferrer">' + label + '</a>' : '[' + label + '](' + url + ')';
    });

    // bare http(s) autolinks
    s = s.replace(/(^|[^\w"'/=])(https?:\/\/[^\s<>"')]+)/g, function (_, pre, url) {
      url = url.replace(/[.,;:!?]+$/, '');
      return pre + '<a href="' + url + '" target="_blank" rel="noopener noreferrer">' + url + '</a>';
    });

    // bold, strike, italic (ordered so ** wins before *)
    s = s.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/~~([^~\n]+)~~/g, '<del>$1</del>');
    s = s.replace(/(^|[\s(])\*([^*\n]+)\*(?=[\s.,:;!?)\]]|$)/g, '$1<em>$2</em>');
    s = s.replace(/(^|[\s(])_([^_\n]+)_(?=[\s.,:;!?)\]]|$)/g, '$1<em>$2</em>');

    // hard break = two trailing spaces; otherwise soft newlines become spaces
    s = s.replace(/ {2,}\n/g, '<br>\n');
    s = s.replace(/\n/g, ' ');
    return s;
  }

  /**
   * markdownToHtml(md, opts) -> HTML string (trusted renderer output).
   * opts.partial: true while streaming — an unterminated fenced block renders as
   * a plain, un-highlighted <pre> so the closing fence can mount the real one.
   * Supports: fenced code (+ language label + highlight), indented code, tables,
   * lists (with nesting), blockquotes, headings, setext headings, hr, paragraphs,
   * inline code, bold/italic/strike, links, autolinks, images (sanitized).
   */
  function markdownToHtml(md, opts) {
    var partial = !!(opts && opts.partial);
    var text = String(md == null ? '' : md).replace(/\r\n?/g, '\n');
    var lines = text.split('\n');
    var out = [];
    var i = 0;
    var para = [];

    function flushPara() {
      if (!para.length) return;
      out.push('<p>' + inline(para.join('\n')) + '</p>');
      para = [];
    }

    while (i < lines.length) {
      var line = lines[i];
      var t = line.trim();

      if (t === '') { flushPara(); i++; continue; }

      // ---- fenced code ----
      var fm = /^(`{3,}|~{3,})\s*([\w.+-]*)\s*$/.exec(t);
      if (fm) {
        flushPara();
        var fence = fm[1];
        var lang = fm[2];
        var buf = [];
        var j = i + 1;
        var closed = false;
        var closerRe = new RegExp('^' + fence.charAt(0) + '{' + fence.length + ',}\\s*$');
        while (j < lines.length) {
          var lt = lines[j].trim();
          if (closerRe.test(lt)) { closed = true; j++; break; }
          buf.push(lines[j]);
          j++;
        }
        i = j;
        if (closed || !partial) {
          var code = buf.join('\n');
          var body = lang ? highlightCode(code, lang) : escapeHtml(code);
          out.push('<pre class="code-block' + (lang ? ' lang-' + escapeHtml(lang.toLowerCase()) : '') + '"><div class="code-head"><span class="code-lang" style="font-family:var(--font-mono);font-size:11px;color:var(--color-text-dim);text-transform:uppercase;letter-spacing:.06em">' + escapeHtml(lang || 'code') + '</span><button type="button" class="copy-btn" data-copy="1">Copy</button></div><code>' + body + '</code></pre>');
        } else {
          out.push('<pre class="code-block partial"><code>' + escapeHtml(buf.join('\n')) + '</code></pre>');
        }
        continue;
      }

      // ---- table (header row + separator row) ----
      if (line.indexOf('|') !== -1 && i + 1 < lines.length &&
          /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$/.test(lines[i + 1])) {
        flushPara();
        var tbl = parseTable(lines, i);
        out.push(tbl.html);
        i = tbl.index;
        continue;
      }

      // ---- ATX heading ----
      var hm = /^(#{1,6})\s+(.+?)\s*#*\s*$/.exec(t);
      if (hm) {
        flushPara();
        var lvl = hm[1].length;
        out.push('<h' + lvl + '>' + inline(hm[2]) + '</h' + lvl + '>');
        i++;
        continue;
      }

      // ---- setext headings (single paragraph line + === / ---) ----
      if (para.length === 1 && /^\s*={2,}\s*$/.test(t)) {
        out.push('<h1>' + inline(para[0]) + '</h1>');
        para = [];
        i++;
        continue;
      }
      if (para.length === 1 && /^\s*-{3,}\s*$/.test(t)) {
        out.push('<h2>' + inline(para[0]) + '</h2>');
        para = [];
        i++;
        continue;
      }

      // ---- horizontal rule ----
      if (/^\s*([-*_])(?:\s*\1){2,}\s*$/.test(t)) {
        flushPara();
        out.push('<hr>');
        i++;
        continue;
      }

      // ---- blockquote ----
      if (/^>\s?/.test(line)) {
        flushPara();
        var q = [];
        while (i < lines.length && /^>\s?/.test(lines[i])) {
          q.push(lines[i].replace(/^>\s?/, ''));
          i++;
        }
        out.push('<blockquote>' + markdownToHtml(q.join('\n'), { partial: partial }) + '</blockquote>');
        continue;
      }

      // ---- indented code (4 spaces / tab), top-level only ----
      if (para.length === 0 && /^(?: {4}|\t)/.test(line)) {
        var cb = [];
        while (i < lines.length) {
          if (/^(?: {4}|\t)/.test(lines[i])) {
            cb.push(lines[i].replace(/^(?: {4}|\t)/, ''));
            i++;
          } else if (/^\s*$/.test(lines[i])) {
            if (cb.length) { cb.push(''); i++; } else { i++; }
            if (i < lines.length && !/^(?: {4}|\t)/.test(lines[i])) break;
          } else {
            break;
          }
        }
        out.push('<pre class="code-block"><code>' + escapeHtml(cb.join('\n')) + '</code></pre>');
        continue;
      }

      // ---- lists ----
      if (/^\s*([-*+]|\d+[.)])\s+/.test(line)) {
        flushPara();
        var lst = parseList(lines, i);
        out.push(lst.html);
        i = lst.index;
        continue;
      }

      // ---- paragraph accumulation ----
      para.push(line);
      i++;
    }

    flushPara();
    return out.join('\n');
  }

  extend(render, {
    escapeHtml: escapeHtml,
    highlightCode: highlightCode,
    markdownToHtml: markdownToHtml
  });
})();
