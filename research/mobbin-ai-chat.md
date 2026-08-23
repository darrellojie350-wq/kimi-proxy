# mobbin-ai-chat — Design spec for a premium, dark-first Kimi Code CLI client web app: streaming responses/thinking/tool calls over WebSocket, multi-session, "web APK" polish, built on the Kimi Web design system.

> **Research provenance.** Mobbin API was unreachable during this run (all `/api/content/search-screens`, `/api/searchable-apps/*`, `/api/filter-tags/*` routes return 404; the mobbin-mcp repo is archived). Findings below are therefore traced to **real apps via documented teardowns + the Kimi Web Design System doc (read in full, 1349 lines)** — setproduct's AI-chat anatomy/patterns field guide, aiuxplayground's ChatGPT/Claude/Perplexity/Gemini composer teardowns (pattern names like "Tool Switching in Composer", "Prompt Starters" map 1:1 to Mobbin's screen_patterns/flow_actions taxonomy), Linear's own redesign posts, intuitionlabs' 7-tool UI comparison, thefrontkit's streaming/session practices, and Perplexity's official help. Where a token is given, it comes from the Kimi design system (`kimi.txt`) and is the single source of truth.

## 1. Key findings

- **Dark elevation = lighter, chrome darker than content.** Kimi Web: page `#121212`, sidebar/chrome one step *below* page `#0d0d0d`, wells one step *above* `#1f1f1f`, raised `#292929`; Linear's redesign: same inverted-L chrome with "the chrome never sits brighter than the reading surface". → the session column and headers must read darker than the transcript.
- **Full-width messages, not bubbles, are the current best practice** for serious AI chat (Claude.ai, ChatGPT, Cursor all moved to flat full-width with subtle differentiation — setproduct). The one exception is the user message: Kimi keeps a neutral bubble (`BubbleGray #292929` dark, radius-lg, no border, no shadow) so turns still parse at a glance.
- **The message stream is the entire product.** Max-width 720–768px (Claude 768 / ChatGPT 768 / Perplexity 720 — setproduct), line-height ~1.6, 65–80 chars/line; everything else (sidebar, headers, composer) exists to serve it.
- **Streaming is a joint design+engineering problem**: first token < 800ms or show a queued state; blinking caret is the cheapest "alive" signal (Cursor: thin bar; Claude: filled square; ChatGPT: pulsing dot); buffer markdown and **defer code blocks until the closing fence**; batch renders into 30–60ms paint windows; auto-scroll only within 100px of the bottom, else show a Jump-to-latest pill (Perplexity gets this right — setproduct).
- **Thinking is an inline collapsed disclosure, never a side panel** (Kimi): bulb glyph + breathing "Thinking…" label (opacity only, no shimmer) + ticking elapsed seconds; collapses by default; folds itself back once the stream moves past. Claude signals thinking with an ellipsis animation; o-series/Gemini show a separate reasoning phase — collapsed by default, labeled honestly ("Thinking", never "Working on it").
- **Tool calls are quiet activity lines, not cards** (Kimi): one borderless ~24px line per call — glyph, tool-specific content (file name as a button, mono command, match count, diff stats), trailing status — expanding in place for details. Consecutive activity folds into one smart-summary row ("Read 2 files · Ran 5 commands (1 failed) · 26s"); a settled turn folds everything before its final text into "Worked Ns". Only question/approval get a floating attention card.
- **Status vocabulary is one shared system**: running = pulsing accent dot, done = green ✓, failed = red ✗ — at the line's right edge. Never invent a second vocabulary for tool rows vs. session rows vs. work pills.
- **Composer = calm default + progressive disclosure** (ChatGPT teardown): an empty bar that invites typing; modes (plan / yolo / thinking) appear as removable chips showing scope *before* send; pre-send contracts (placeholder + starters swap per mode) only for modes that change cost/latency. Kimi: one 32px superellipse(1.5) shell, 32px full-round transparent toolbar controls, and exactly one persistent filled control — Send, inverted text-fill, never accent.
- **Session management is table stakes**: auto-saved history in a left rail, per-session title + timestamp + status, search across sessions, rename in place, pin/archive hover actions (ChatGPT sidebar: recents pinned, infinite scroll, rename; Claude: Projects groups; Kimi: workspace groups + attention badges). Show model name on every assistant message.
- **Trust signals are non-negotiable**: Perplexity made numbered inline citations the baseline for factual claims; every message labels its model; errors name the class (rate-limit/content-filter/network) + one recovery action; context truncation is announced, never silent; code blocks always have a copy button with transient ✓.
- **Command palette is the power-user spine** (Raycast): ⌘K, modalPanel activation that doesn't steal the host app, searchable rows with kbd hints, keyboard-first; Kimi's flush picker anatomy = boxed input + full-height result list + shortcut bar with Kbd keycaps.
- **Density and restraint are the brand**: 4px grid, one hairline width (0.5px) for every border, 7 radius steps, finite type ramp, no gradient text / no color glow / no glassmorphism except floating menus, no emoji as icons, disabled = opacity .5 (Kimi style rules; Linear: "limit chrome, neutral + timeless").

## 2. Design decisions to adopt

**Shell & layout**
- 5-track grid: `264px` session sidebar | resize handle | conversation (reading column `760px` max) | handle | optional right panel `460px` (file/tool-output detail). Header height `48px` with 0.5px bottom hairline (--panel-head-h). Mobile ≤640px: single column, sidebar becomes a drawer, dialogs become bottom Sheets.
- Dark-first, lacquer: page `#121212`, sidebar & panel heads `#0d0d0d`, wells `#1f1f1f`, raised surfaces `#292929`; text `rgba(255,255,255,.84)` / muted `.56` / faint `.38`; lines `rgba(255,255,255,.12)` (structural) and `.05` (subtle, quiet dividers); selected fill `rgba(255,255,255,.1)` — neutral, never accent-tinted.
- Accent KMBlue `#1a88ff` used *scarce*: primary buttons, links, focus ring, active marks, running status dot. Status palette: success `#3fb950`, warning `#d29922`, danger `#f85149`. Focus ring: `0 0 0 3px rgba(26,136,255,.1)` (+1px accent for strong).
- Type: UI = Schibsted Grotesk (fallback system), code/tools = JetBrains Mono (self-hosted, offline). Base 14px (Medium step); prose 16px/1.6 in the stream; stream chrome rows 13px UI; mono 12px (reads level next to 13px); timestamps 12px weight 500.

**Message stream** (`chat surface`)
- Assistant messages: full-width, no bubble, flush left with the reading column. User messages: Kimi bubble — `#292929` fill, radius `12px`, no border/shadow, metadata row 8px below (12px/500).
- Stream max-width `760px`, content scrolls internally (min-height:0; min-width:0 everywhere).
- Per-turn: thinking row (inline, collapsed) → activity rows → final text → per-message action row on hover (copy/regenerate/edit; always visible on touch).
- Model label on every assistant message: muted 12px mono `kimi-k2 · thinking` beside the timestamp.

**Colors WHERE** — token table (dark-first; light pair given for completeness)

| Token | Dark | Light | Use |
|---|---|---|---|
| --bg | #121212 | #ffffff | page |
| --sidebar-bg | #0d0d0d | #f9fbfc | session rail, panel heads (below page in dark) |
| --surface | #1f1f1f | #f5f5f5 | wells, cards, tool-output panels |
| --surface-raised | #292929 | #ffffff | raised card, dialog, composer |
| --text | rgba(255,255,255,.84) | rgba(0,0,0,.9) | body |
| --text-muted | rgba(255,255,255,.56) | rgba(0,0,0,.6) | secondary |
| --text-faint | rgba(255,255,255,.38) | rgba(0,0,0,.45) | timestamps, aux glyphs |
| --line | rgba(255,255,255,.12) | rgba(0,0,0,.13) | dividers/borders (0.5px) |
| --subtle | rgba(255,255,255,.05) | rgba(0,0,0,.05) | quiet separators |
| --selected | rgba(255,255,255,.1) | rgba(0,0,0,.05) | "where I am" fills |
| --accent | #1a88ff | #1783ff | primary action/link/focus/active |
| --success/--warning/--danger | #3fb950 / #d29922 / #f85149 | #0e7a38 / #a9610a / #c0392b | status only |
| --font-mono | JetBrains Mono | same | code, commands, diffs, meta |

**Spacing/radius/motion**: 4px grid (4/8/12/16/20/24/32); radius `4/6/8/12/16/20/999`; composer `32px` superellipse(1.5). Motion: press 120ms, hover 160ms, dialog/layout 260ms; ease-out `cubic-bezier(.16,1,.3,1)` for enter/hover, ease-in-out `cubic-bezier(.4,0,.2,1)` for width/layout; spinner 700ms; honor `prefers-reduced-motion` globally (~0.001ms, static fallbacks).

## 3. Component recipes

### Composer (dock)
- **Anatomy**: one raised shell `--surface-raised`, radius `32px` + superellipse(1.5), 0.5px hairline (`--line`); rest fill `#1f1f1f`; focus = low-chroma line-and-accent overlay fading in over 260ms ease-in-out (no halo, no layout shift). Inside: mode pills row (plan / yolo / thinking / permission — each a neutral `--surface` chip: 14px icon + label + × to disarm), input (auto-grows to ~10 lines then scrolls, first-line indent = pill width), right toolbar with 32px full-round transparent IconButtons (hover = neutral wash, open = accent-soft), Send = the *only* filled control: 32px circle, inverted `--text` fill + `--bg` glyph (never accent), disabled (opacity .5) exactly when submit would no-op (empty draft, upload in flight, starting spinner).
- **States**: default / hover (wash) / focus-within (hairline+accent crossfade) / mode-armed (chips visible) / streaming (Send → Stop square) / disabled / attachment strip (thumbnails + chips inside the card above input, cap 2 rows, scroll; clear-all 22px quiet badge).
- **Motion**: pill menu pop 0.97 scale + 2px trigger-shift over 160ms in / 120ms out; attachment slide via grid rows 260ms. Composer floats over the transcript; content bottom padding = live dock height (never overlap the last message).
- **WHERE**: main chat dock; on ≤640px stays docked, rises with keyboard (visual viewport `--app-height` budget, never dvh).

### Streaming message + typing/streaming indicator
- **Anatomy**: full-width assistant block; streamed text renders in an `aria-live="polite"` region (`aria-atomic=false`, debounced announcements); a 1px `--text` caret (opacity 0.6) blinks at the tail (blink ~1s, off under reduced motion) while streaming; buffered markdown — code blocks render as plain mono until the closing fence, then a second-pass syntax highlight (github-dark theme) mounts; copy button appears on code blocks immediately (transient ✓ 1200ms).
- **States**: queued (request in flight, ~200ms–2s: bare 12px "Requesting…" label + 700ms Spinner sm, never a % bar) → streaming (caret + auto-scroll if within 100px of bottom; `Stop` replaces `Send`) → complete (caret off, per-message actions reveal) → stopped (partial text kept, "Continue" + "Regenerate" pair) → error (inline card below the message: danger-soft fill, error class + one-line cause + exactly one recovery action) → regenerating (old reply kept in a navigable variants carousel).
- **Motion**: none per token — batch renders into 30–60ms paint windows; scroll is smooth (CSS) only on auto-follow; jump-to-latest pill (12px/525, full down-arrow glyph) fades in/out 160ms.
- **WHERE**: chat surface; also mirrors into the optional right-panel transcript for sub-agent turns.

### Thinking UI
- **Anatomy**: inline, borderless disclosure row, flush left, 22–24px tall — k15 bulb glyph (14px, faint) + label "Thinking…" while streaming / "Thinking process · Ns" once settled; whole-row `<button>` with `aria-expanded`, 16px chevron hugging the text (never far edge).
- **States**: streaming (label breathes — opacity only, no gradient shimmer — and whole seconds tick beside it; body forced open) / collapsed (default; folds itself back when the stream moves past, even if user expanded mid-stream) / expanded (body hangs below at the row's left edge: interim text/plan in the reading column).
- **Motion**: expand via grid-rows 0fr→1fr over 260ms ease-in-out + 90° chevron rotation; header animates text color on hover 160ms only; no card shell ever.
- **WHERE**: inside the turn, above tool activity; never a side panel; sub-agent inspector view keeps it pinned open (caption-style head).

### Tool-call row / card
- **Anatomy (default = quiet line, tier ①)**: one borderless ~24px row — 14px glyph (faint) → tool action label (Run/Read/Edit/Write/Search…, muted 13px) → tool-specific content (file name as a real `--text` button + directory + `:line` range or `+N −M` stat with a mini segmented bar; Bash: full mono command, CSS-truncated + duration chip `0.8s`; Grep: pattern in mono + match count) → trailing status (running = pulsing accent dot, done = green ✓, failed = red ✗). No card chrome, no hover wash; chevron is the only disclosure affordance.
- **States**: running (dot pulses 700ms; content live) / done / failed / expanded (detail hangs at the line's left edge: mono output panel — `--surface` well, hairline, 12-line scroll cap — or inline diff or clickable match/file list; syntax highlight mounts lazily on first expand).
- **Fold rules (tier ②)**: ≥2 consecutive activity items fold into ONE smart-summary row (30px tall, 8px vertical padding): "Read 2 files · Ran 5 commands (1 failed) · 26s" — per-kind counts in first-appearance order, failure clause in danger red, span faint at tail; expands into the flat item list; stays open while live, folds itself back on settle. **Tier ④ decision cards**: only question/approval — floating neutral raised card (hairline + radius-lg + soft shadow, no color band), plain dark 16px title head, hairline footer with number-keyed actions (chip + kbd hint) leading to one accent primary.
- **WHERE**: chat stream; task notifications (background bash/sub-agent settle) are status cards that punch out of the fold, never fold.

### Session list item
- **Anatomy**: inset rounded pill inside the sidebar's 12px gutter — `status slot (16px) → title → time → attention badge → hover actions (pin/archive)`, all on one font-driven ~32px row (title line-height 1.25); padding 8px 8px, radius `6px`; hover = neutral wash, active/selected = neutral selected fill (never accent-tinted, no border, no weight change). Grouped under workspace heads: `folder icon → name` (500 muted), collapsible, kebab + "+" on hover.
- **States**: running (Spinner sm in status slot) / unread (7px accent dot) / needs-answer (Badge sm info) / needs-approval (Badge sm warning) / aborted (Badge sm danger) — one status at a time, precedence approval › question › running › aborted › unread; idle shows time (mono 12px faint). Hover actions (IconButton sm ×2, pin/archive) cross-fade over the time; archive is immediate + ActionToast with Undo.
- **Motion**: row background transitions 120ms; hover cluster fades 160ms; drag-to-pin with drop frame; pinned section collapsible (label chevron, persisted).
- **WHERE**: session sidebar + pinned head; also the flat variant with cwd sub-line for the workspace home.

### Command palette (⌘K)
- **Anatomy**: flush picker dialog (radius-xl, `--shadow-xl`, 28% neutral backdrop) — one boxed `38px` input inset to align with the head title, full-height result list (rows 8px 12px padding, radius-md: 14px icon + name 14/20 medium-when-current + muted meta line 12/18 + trailing kbd keycaps), shortcut bar footer (Kbd caps + 12px faint labels, groups split by "·", aria-hidden). Slash commands (`/compact`, `/plan`, `/goal`, `/model`) resolve in the same surface.
- **States**: default / searching (Spinner sm in the input row, ~800ms debounce) / no-results (centered faint line) / keyboard row (↑↓ move, Enter runs, Esc closes; hover and keyboard selection share one highlight); rows show match emphasis by ink only (semibold, never background).
- **Motion**: open fade + slight scale over 160ms from the trigger corner; focus ring on the boxed input only.
- **WHERE**: global (⌘K / Ctrl K keycaps in the sidebar search row); Raycast-style — opening must not steal the app's prior state when closed.

### Loading skeleton
- **Anatomy**: composed of title lines + text lines + avatar blocks; **breathing opacity** (opacity 0.55↔1, ~1.4s loop) — no gradients, no shimmer (Kimi no-gradient rule); skeleton blocks use `--subtle` fill on `--surface` wells. App startup: centered plain Spinner (SVG ring, 700ms) — never the mascot for non-chat waits.
- **States**: page-level first render (sidebar rows + transcript blocks), detail expand (12-line mono panel skeleton), reconnect banner (hairline + muted text, not a skeleton).
- **WHERE**: session list, transcript backfill, right-panel file preview, dialog lists.
- **Motion**: 160ms fade-in of the skeleton surface; reduced-motion = static blocks.

### Empty state
- **Anatomy**: centered column — quiet 48px status icon (faint) → title (16px/525) → one-line hint (13px muted) → primary Button. Chat empty state: prompt starters (3 dismissible suggestion chips above the composer, 28px pill: transparent + muted → hover wash; teach jobs without a product tour) + workspace attachment card tucked under the composer (radius 0 0 20px 20px, `--color-hover` at 60%, quiet capsule trigger).
- **States**: no sessions ("No chats yet · Click New chat…"), no results, no workspace, disconnected bridge (warning icon + reconnect action) — never a blank pane.
- **WHERE**: sidebar list, chat surface, right panel, settings lists.

### Toast
- **Anatomy**: `status icon (20px, colored) + title + description` — status color appears only on the icon; toast = raised `--surface-raised` card, hairline, radius-lg, `--shadow-md`, bottom-right stack, self-timed 8s (hover pauses), `--z-toast 600`. Undoable actions use the **ActionToast**: a pill floating top-center below the 48px header — one-line sentence + inline accent `<button>` actions + close (e.g. "Chat archived · Undo / Settings").
- **States**: info / success / warning / danger; transient only — persistent problems live in the transcript (inline error cards), not toasts.
- **Motion**: slide/fade in 160ms ease-out, out 120ms; parent re-keys to reset the timer; stack shifts 160ms.

## 4. Anti-patterns to avoid

1. **AI-slop chrome**: purple/blue gradients, glassmorphism on cards/dialogs/toasts, glowing shadows, endlessly looping mascot animations, emoji as functional icons — all flagged as AI tells by the Kimi system. Glassmorphism is allowed *only* on floating menus and the sticky top bar.
2. **Fake typing that throttles a fast model** (ChatGPT did this, stopped; users prefer fast and honest).
3. **Generic errors**: "Something went wrong" with no class + no recovery action — name rate-limit / content-filter / network and give one action (Try again / Switch model / Shorten).
4. **No stop button** during generation — users must be able to abort mid-stream; stop replaces send, disappears the moment streaming ends.
5. **Auto-scroll that fights the user** — never yank the viewport when the user scrolled up; lock position + Jump-to-latest.
6. **SMS-style bubbles everywhere** — round colorful bubbles read as casual texting and undermine the tool framing; assistant content is full-width.
7. **Silent context truncation** — announce compaction/summarization with a visible marker; warn at ~80% context (Kimi's "Context usage 82% · consider /compact").
8. **Modal-locking the chat while streaming** — let the user compose the next prompt mid-stream; never disable navigation.
9. **Buried model selector** — every assistant message carries its model label; switching is one click away, not in Settings.
10. **Layout thrash on every token** — re-rendering per token, reflowing code blocks mid-fence, unstabilized scroll; batch paints, defer code fences, `min-height:0` grid children.
11. **Progress bars and fake percentages** during thinking/queued — there is no progress to report; use honest labels + elapsed time.
12. **Disclaimers as walls of text** and undismissible "Related" chips; show once in the welcome state, never per-message.
13. **Undersized touch targets** (<44px on touch) and no keyboard path for send/stop/copy/regenerate (Cmd+Enter send, Shift+Enter newline, Esc dismiss).

## 5. Top 10 takeaways

1. Dark-first lacquer ladder: `#121212` page, `#0d0d0d` chrome/sidebar (below the page), `#1f1f1f` wells, `#292929` raised; hairlines 0.5px everywhere; accent KMBlue `#1a88ff` used scarcer than you think.
2. Assistant messages are full-width in a 760px reading column; only the user message is a neutral bubble (`#292929`, radius-lg).
3. First token < 800ms or show a queued label; blinking caret always present while streaming; stop button replaces send; batch renders 30–60ms.
4. Thinking is an inline collapsed disclosure row with breathing label + elapsed seconds — never a side panel, never a shimmer.
5. Tool calls are quiet ~24px activity lines with a unified status vocabulary (pulsing accent / green ✓ / red ✗); consecutive activity folds into one smart-summary row; only question/approval get a floating card.
6. Composer is one 32px superellipse shell: calm default, mode pills as removable scope chips, one filled Send (inverted, never accent).
7. Session sidebar at 264px: list-style New chat + bare search with ⌘K keycaps, 32px session rows (status → title → time → badge → hover pin/archive), neutral "where I am" selection.
8. Model label + numbered citations on every assistant message; errors name the class and give one recovery action; context truncation is announced.
9. ⌘K command palette = flush picker: boxed input + result list + Kbd shortcut bar; keyboard-first with visible focus rings everywhere.
10. Density and restraint are the brand: 4px grid, 7 radius steps, 120/160/260ms motion, no gradients, no glow, no emoji icons, reduced-motion respected globally.

---

## Summary (10 lines)

This spec defines a premium WebSocket client for Kimi Code CLI — dark-first, multi-session, mobile-polished — using the Kimi Web design system as its token source of truth and researched patterns from Claude.ai, ChatGPT, Perplexity, Gemini, Linear, Raycast, and Cursor. Layout is a 264px session rail (one step darker than the page) + a 760px reading column + optional 460px detail panel, 48px hairline headers. The stream is full-width with a neutral user bubble, a blinking caret and <800ms first-token contract, inline collapsed thinking, and quiet expandable tool-call lines that fold into smart-summary runs. The composer is a single 32px superellipse shell with removable mode chips and one inverted-fill Send. Sessions persist with status dots, badges, search, rename, pin and archive; ⌘K opens a Raycast-style flush picker. All loading uses breathing skeletons and a plain spinner; toasts are icon-led and transient, errors live inline in the transcript. Motion runs on 120/160/260ms tokens with reduced-motion respected. Everything converges on the anti-slop rules: no purple gradients, no glassmorphism beyond menus, no glow, no emoji icons. Mobbin's API was unreachable during research (404s, archived client) — findings are traced to real apps via documented teardowns plus the full Kimi design-system doc.
