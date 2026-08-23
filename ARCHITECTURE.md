# Kimi Proxy Web — Architecture Contract

> Single-page **PWA** (no build step) that talks to the kimi-proxy bridge over WebSocket.
> This document is the single source of truth for parallel build agents. Read it fully before writing any code. Do not deviate from names/signatures here — other agents depend on them.

## 1. Constraints

- **Zero build step.** Plain HTML + CSS + JS served statically (GitHub Pages). No npm, no bundler, no framework. Plain `<script>` tags in load order.
- **ES5-safe-ish modern JS** — use `const/let`, arrow functions, classes are fine; no JSX, no modules (`import/export` FORBIDDEN). Globals live on `window.Kimi`.
- **Dark-first.** Light theme via `[data-theme="light"]` on `<html>`.
- **Icons**: inline SVG, 24×24 grid, `currentColor`, 1.8px stroke (kimi icon language). Provided via `Kimi.icons.<name>` (see §6). NEVER use emoji as icons.
- Fonts: UI `"Schibsted Grotesk", system-ui, sans-serif`; code `"JetBrains Mono", ui-monospace, monospace`. Load both via Google Fonts `<link>` with system fallbacks.
- Math: KaTeX via CDN (`katex` + `auto-render`), degrade gracefully if not loaded.

## 2. File layout & ownership (swarm)

| Agent | Files | Responsibility |
|---|---|---|
| **A (shell/css)** | `index.html`, `manifest.webmanifest`, `sw.js`, `css/tokens.css`, `css/app.css`, `assets/icon-192.png`, `assets/icon-512.png` | DOM skeleton with EXACT ids/classes from §7, all styling, PWA plumbing. Generate 2 simple PNG icons (solid accent square with "K" — use Bash+python or write a tiny SVG→png via available tools; a plain PNG is fine). |
| **B (infra)** | `js/icons.js`, `js/kimi.js`, `js/bridge.js`, `js/toast.js` | Icon registry, state store + event bus, WebSocket client (protocol §5), toast system. |
| **C (render)** | `js/markdown.js`, `js/render.js` | Markdown→HTML (code highlight, KaTeX), message/thinking/tool-call/tool-output renderers, activity-run + turn-fold. |
| **D (ui)** | `js/sidebar.js`, `js/composer.js`, `js/settings.js`, `js/palette.js`, `js/app.js` | Session sidebar, composer (attachments, model picker, mode pills), settings modal, ⌘K command palette, bootstrap + keyboard shortcuts + wiring. |

Load order in `index.html`: `kimi.js → icons.js → bridge.js → toast.js → markdown.js → render.js → sidebar.js → composer.js → settings.js → palette.js → app.js`. All deferred (`<script defer>`).

## 3. Global API — `window.Kimi`

```js
window.Kimi = {
  version: '0.1.0',
  state: {            // reactive-ish store; ui updates via bus events
    sessions: [],     // Session[]
    activeId: null,
    connection: 'offline' | 'connecting' | 'online',
    settings: {...},  // persisted localStorage 'kimi.settings'
    ui: { sidebarOpen: false, paletteOpen: false, ... },
  },
  bus: { on(evt, fn), off(evt, fn), emit(evt, data) },   // synchronous pub/sub
  bridge: {
    connect(url), disconnect(), send(obj),
    status,                          // 'offline' | 'connecting' | 'online'
    autoReconnect: true,
  },
  sessions: {
    create(name?), select(id), rename(id, name), remove(id),
    list(), get(id), export(id, format),  // export = download .md/.json
    current(),
  },
  render: {
    markdownToHtml(md) -> string,
    message(role, content, opts) -> HTMLElement,
    thinkingRow(deltaText, state) -> HTMLElement,
    toolCallLine(tc) -> HTMLElement,
    toolOutputBlock(entry) -> HTMLElement,
    activityRun(items) -> HTMLElement,
    escapeHtml(s) -> string,
    highlightCode(code, lang) -> string,
  },
  settings: { get(k, dflt), set(k, v), toggle(k) },       // auto-persists
  toast: { show(msg, kind='info', opts), success(msg), error(msg), info(msg) },
  palette: { open(), close(), setItems(items), isOpen() },
  shortcuts: { register(combo, desc, fn) },               // combo e.g. 'mod+n'
  icons: { <name>: '<svg>…</svg>' },
}
```

### Session model (app-side)

```js
Session = {
  id, name, workDir, status,            // 'idle' | 'streaming' | 'thinking' | 'toolRunning' | 'error'
  model, yolo, planMode,
  createdAt, updatedAt, messageCount,
  messages: [Msg],                      // local transcript
  tools: [ToolEntry],                   // tool-call activity for current/last turn
  kimiSessionId,                        // resume id (opaque)
}
Msg = { id, role: 'user'|'assistant'|'system', content, thinking?, toolCalls?, ts, streaming? }
ToolEntry = { id, name, arguments, status: 'running'|'success'|'failed'|'pending', output?, startedAt, durationMs }
```

### Bus events (names are THE contract)

| Event | data | Emitted by |
|---|---|---|
| `connection.change` | `{status}` | bridge |
| `sessions.changed` | — | sessions (any mutation) |
| `session.selected` | `{id}` | sessions/select, sidebar, palette |
| `session.created` | `{session}` | bridge |
| `session.deleted` | `{sessionId}` | bridge |
| `message.delta` | `{sessionId, msgId, delta}` | render/bridge |
| `thinking.delta` | `{sessionId, msgId, delta}` | bridge |
| `tool.call` | `{sessionId, toolCallId, name, arguments}` | bridge |
| `tool.output` | `{sessionId, toolCallId, output}` | bridge |
| `tool.status` | `{sessionId, toolCallId, status}` | bridge |
| `turn.complete` | `{sessionId, code, durationMs}` | bridge |
| `session.status` | `{sessionId, status}` | bridge |
| `bridge.error` | `{message}` | bridge |
| `ui.sidebar` | `{open}` | sidebar/app |
| `ui.palette` | `{open}` | palette/app |
| `toast` | `{message, kind}` | toast |

## 4. CSS contract

File `css/tokens.css` defines ALL variables on `:root` (dark defaults) + `[data-theme="light"]` overrides. Component styles live in `css/app.css`.

### Tokens (kimi design system, verbatim values)

```css
:root {
  /* color ladder (dark) */
  --color-bg: #121212;        --color-chrome: #0d0d0d;   --color-well: #1f1f1f;
  --color-raised: #292929;    --color-hairline: rgba(255,255,255,.08);
  --color-text: #e6e6e6;      --color-text-muted: #9a9a9a;  --color-text-dim: #6b6b6b;
  --color-accent: #1a88ff;    --color-accent-soft: rgba(26,136,255,.14);
  --color-success: #3fb950;   --color-warning: #d29922;  --color-danger: #f85149;  --color-info: #58a6ff;
  --color-surface-overlay: #1a1a1a;
  /* light */
  --color-bg-l: #ffffff; --color-chrome-l: #f9fbfc; --color-well-l: #f3f5f8;
  --color-raised-l: #ffffff; --color-hairline-l: rgba(0,0,0,.08);
  --color-text-l: #1a1a1a; --color-text-muted-l: #5f6b7a; --color-accent-l: #1783ff;
  /* spacing 4px grid */
  --space-1: 4px; --space-1-5: 6px; --space-2: 8px; --space-3: 12px;
  --space-4: 16px; --space-5: 20px; --space-6: 24px; --space-8: 32px;
  /* radius */
  --radius-xs: 4px; --radius-sm: 6px; --radius-md: 8px; --radius-lg: 12px;
  --radius-xl: 16px; --radius-2xl: 20px; --radius-composer: 32px; --radius-full: 999px;
  /* type */
  --font-ui: "Schibsted Grotesk", system-ui, -apple-system, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, SFMono-Regular, monospace;
  --fs-c1: 11px; --fs-b2: 13px; --fs-b1: 14px; --fs-t2: 16px; --fs-t1: 18px; --fs-t0: 22px;
  /* motion */
  --ease-out: cubic-bezier(.16,1,.3,1); --ease-in-out: cubic-bezier(.4,0,.2,1);
  --dur-fast: 120ms; --dur-base: 160ms; --dur-slow: 260ms;
  /* elevation: hairlines only, no glow */
  --shadow-menu: 0 8px 24px rgba(0,0,0,.35);
  /* z */
  --z-sticky: 100; --z-dropdown: 200; --z-overlay: 300; --z-modal: 400; --z-toast: 600; --z-tooltip: 650;
  /* layout */
  --sidebar-w: 264px; --content-max: 760px; --content-wide: 920px;
}
[data-theme="light"] { --color-bg: var(--color-bg-l); --color-chrome: var(--color-chrome-l);
  --color-well: var(--color-well-l); --color-raised: var(--color-raised-l);
  --color-hairline: var(--color-hairline-l); --color-text: var(--color-text-l);
  --color-text-muted: var(--color-text-muted-l); --color-accent: var(--color-accent-l); }
```

### Layout anatomy (the 5-track grid)

- `#app` — full-viewport grid: `grid-template-columns: var(--sidebar-w) 1fr` (desktop); right `#work-panel` (460px) optional, toggled.
- `#sidebar` — chrome surface; contains `#sidebar-head` (logo + new-session btn), `#session-search`, `#session-list`, `#sidebar-foot` (connection status + settings btn).
- `#main` — column: `#chat-header` (sticky, title + model pill + connection dot + actions), `#chat-scroll` (messages, `max-width: var(--content-max)`, centered), `#composer-wrap` (sticky bottom).
- `#palette` — ⌘K overlay (fixed, top 20%, centered, width min(560px, 92vw)).
- `#settings-modal`, `#confirm-dialog`, `#toast-stack` (bottom-right), `#approval-card` (floating, above composer).
- Mobile (≤640px): sidebar becomes drawer with `.drawer-open` overlay backdrop; composer toolbar wraps.

### Key component classes (app.css) — exact names for D to use

```
.sidebar-row (session item: .sr-title, .sr-meta, .sr-actions, .pin-ic)
.search-input, .kbd
.composer-shell (radius-composer, superellipse corner shape optional), .composer-toolbar, .composer-input (textarea),
  .pill (mode pills: .pill-yolo, .pill-plan, .pill-auto, .pill-think), .model-pill, .send-btn, .stop-btn,
  .attach-btn, .context-ring (svg circle), .composer-footer (kbd hints)
.msg (user/assistant), .msg-user-bubble, .msg-assistant, .msg-head, .msg-meta, .msg-content
.thinking-row (collapsed, expands in place), .thinking-body
.tool-line (quiet borderless), .tool-line-icon, .tool-line-name, .tool-line-status (dot .dot-running/.dot-ok/.dot-fail), .tool-line-args
.activity-run (summary row, expands), .turn-fold ("Worked Ns")
.tool-output-well, .terminal-well, .diff-view, .diff-add, .diff-del, .code-block, .code-head, .copy-btn
.empty-state, .welcome-hero
.skeleton-row (breathing opacity)
.toast, .toast-error, .toast-success, .toast-info
.approval-card, .approval-actions
.banner (inline error/reconnect banner at top of chat)
.avatar, .brand-mark
```

`@media (prefers-reduced-motion: reduce)` — set all durations to `0.001ms` globally (except `transition-delay`).

## 5. Bridge wire protocol (server.js, port 8765) — THE contract

JSON objects. Client→Server:

```json
{"type":"ping","ts":123}
{"type":"session.create","name":"My Session","workDir":null,"model":null}
{"type":"session.list"}
{"type":"session.delete","sessionId":"..."}
{"type":"session.rename","sessionId":"...","name":"New"}
{"type":"prompt","sessionId":"...","content":"prompt text"}
{"type":"interrupt","sessionId":"..."}
{"type":"config","sessionId":"...","yolo":true,"planMode":false,"model":"..."}
```

Server→Client:

```json
{"type":"connected"}
{"type":"pong","ts":123}
{"type":"session.list","sessions":[Session]}
{"type":"session.created","session":Session}
{"type":"session.deleted","sessionId":"..."}
{"type":"session.renamed","sessionId":"...","session":Session}
{"type":"status","sessionId":"...","status":"streaming|idle|thinking","session":Session?}
{"type":"content.delta","sessionId":"...","delta":"text"}
{"type":"thinking.delta","sessionId":"...","delta":"text"}
{"type":"tool.call","sessionId":"...","toolCallId":"call_...","name":"Bash","arguments":{...}}
{"type":"tool.output","sessionId":"...","toolCallId":"call_...","output":"text"}
{"type":"tool.status","sessionId":"...","toolCallId":"call_...","status":"success|failed"}
{"type":"turn.complete","sessionId":"...","code":0,"durationMs":10615}
{"type":"error","sessionId":"...","message":"..."}
```

Bridge = kimi CLI per prompt with `-r <resume>` for continuation. Tool calls AUTO-run (prompt mode). `bridge.js` must: on open send `ping`; wait for `connected`; heartbeat every 15s; auto-reconnect with exponential backoff (1s→2s→4s→…max 30s); on reconnect, re-send `session.list`; emit `connection.change`.

## 6. Icon registry (`js/icons.js`)

`Kimi.icons = { ... }` — inline SVG strings, `viewBox="0 0 24 24"`, `fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"`. REQUIRED names: `plus, chatNew, send, stop, settings, sliders, search, chevronDown, chevronRight, chevronUp, close, check, copy, download, undo, trash, pin, pinOff, folder, file, fileText, fileEdit, code, terminal, globe, gitFork, archive, dots, thinking (k15 bulb: circle + rays), bolt, target, clock, key, keyboard, sun, moon, sparkles, pause, play, external, shield, alert, info, checkCircle, xCircle, drag, panelRight, history, expand, collapse, arrowUp, arrowDown, paperclip, image, refresh, link, user, robot`. (Draw simple, consistent 1.8px stroke glyphs; k15 bulb = circle with 3 short rays top-right.)

## 7. index.html skeleton (Agent A — exact ids)

```html
<html lang="en" data-theme="dark">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>Kimi Proxy</title>
  <meta name="theme-color" content="#0d0d0d">
  <link rel="manifest" href="manifest.webmanifest">
  <link rel="icon" href="assets/icon-192.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Schibsted+Grotesk:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
  <link rel="stylesheet" href="css/tokens.css"><link rel="stylesheet" href="css/app.css">
</head>
<body>
  <div id="app">
    <aside id="sidebar">…(head/search/list/foot)…</aside>
    <main id="main">
      <header id="chat-header">…</header>
      <div id="banner-slot"></div>
      <div id="chat-scroll"><div id="chat-list"></div></div>
      <div id="composer-wrap">…composer-shell…</div>
    </main>
    <aside id="work-panel" hidden>…</aside>
  </div>
  <div id="palette" hidden>…</div>
  <div id="settings-modal" hidden>…</div>
  <div id="confirm-dialog" hidden>…</div>
  <div id="toast-stack"></div>
  <div id="approval-card" hidden></div>
  <script defer src="js/kimi.js"></script> … (order §2)
</body>
```

## 8. Design language (do / don't)

- **Do**: lacquer dark, 0.5px hairlines, restrained whitespace, scarce accent (only: focus rings, active states, status running dots, primary buttons, links), JetBrains Mono for all code/tool surfaces, compact mono tool-line heads, breathing-opacity loading (never gradient shimmer), inline collapsed thinking with ticking seconds, turn folds, 120/160/260ms ease-out motion.
- **Don't** (AI tells): purple gradients, glassmorphism (except dropdown menus), colored glows/shadows, emoji icons, "Boost your productivity" copy, spinning-loader-overuse (use skeleton rows), SMS-style bubbles (assistant messages are full-width), fake typing dots (use real streaming caret).

## 9. P0 scope (must work end-to-end this build)

1. Connect to bridge (default `ws://<location.hostname>:8765`, configurable) + status + reconnect.
2. Session create/select/rename/delete; sidebar list; localStorage persistence of sessions + transcript.
3. Prompt → streaming content in chat with markdown + code highlight + KaTeX.
4. Thinking row (collapse/expand, ticking seconds).
5. Tool call lines (icon, args, status dot) + expandable output (terminal/file/diff rendering).
6. Activity-run grouping + turn fold.
7. Stop/interrupt button; YOLO/Plan/Auto mode pills (sent via config).
8. ⌘K palette (sessions + actions); core shortcuts (⌘N, ⌘K, ⌘,, ⌘↑/↓, Esc).
9. Settings modal: bridge URL, theme, font size, default mode/model; toasts; PWA (manifest+sw); empty state; skeleton loading; responsive.
10. Direct-API fallback backend: bridge v2 at port 9876 (`kimi-bridge.js`) selectable in settings (model dropdown), for when kimi CLI bridge is down.

P1: attachments (paste/drag → send as file paths to kimi via prompt prefix), session export, message edit/delete, session search, pinning, archive, model picker per session, thinking effort, context ring, diff view for Edit/Write, image output render. P2: branching, message search, shortcuts remap, system theme.

## 10. Testing

After swarm completes, parent runs a local server (`python3 -m http.server`) and verifies with agent-browser: load page, connect, create session, send prompt, observe streaming/tool events live against the local bridge (8765). Then deploy to GitHub Pages via workflow and re-verify over HTTPS.

## 11. Deliverables per agent

- Agent A: index.html (full DOM per §7), manifest.webmanifest (name "Kimi Proxy", theme #0d0d0d, display standalone), sw.js (cache-first for same-origin static, network-first for fonts; version cache name), css/tokens.css, css/app.css (complete design per §4/§8 — all classes listed must exist), 2 PNG icons (write a minimal Python script to generate solid `#1a88ff`-ish squares with a simple "K"; no image tools available, generate programmatically).
- Agent B: js/kimi.js (state + bus + sessions store + settings + shortcuts registry + bootstrap `Kimi.init()`), js/icons.js, js/bridge.js, js/toast.js.
- Agent C: js/markdown.js (GFM-ish: code fences w/ highlight via simple tokenizer or no-dep highlighter, tables, lists, blockquote, inline code, bold/italic, links, `$`/`$$` KaTeX via auto-render if present; XSS-safe: escapeHtml first then sanitize), js/render.js (all renderers per §3 signatures).
- Agent D: js/sidebar.js, js/composer.js, js/settings.js, js/palette.js, js/app.js (init wiring: `Kimi.init()` on DOMContentLoaded, keyboard shortcuts, resize behavior, connection auto-start with persisted URL).

Each agent: write ONLY its files. Read ARCHITECTURE.md, research/*.md (esp. kimi-design-system.md, mobbin-ai-chat.md) first. Verify your files parse (node --check for js; open html mentally for structure). Do not touch others' files. Report files written + any contract deviations in your summary.
