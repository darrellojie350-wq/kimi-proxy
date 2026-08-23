# mobbin-messaging — streaming AI chat client design spec for Kimi Code CLI WebSocket bridge

**Intent:** Define a lacquer-dark, density-first, clinical mobile-grade web app for consuming Kimi Code CLI streaming responses (text, thinking, tool calls, tool outputs) over a WebSocket bridge, with multi-session support. The design is anchored to the Kimi Web Design System (v1.0) and avoids all AI-slop signifiers (purple gradients, glassmorphism outside the two exemptions, glowing shadows, emoji-as-icons).

---

## 1. Key findings

**Note:** Mobbin was entirely unavailable (all endpoints returned 404 / validation errors during research). Findings are traced to public sources — the Kimi Web Design System, setproduct's AI Chat Anatomy guide, uxpatterns.dev, thefrontkit, and ChatGPT/Perplexity/Claude/Cursor product behaviour. See the final section for the Mobbin outage impact.

| **Finding** | **Source / App** | **Relevance** |
|---|---|---|
| AI chat messages need 7 lifecycle states: queued, thinking/reasoning, streaming, complete, error, regenerating, stopped | setproduct AI Chat Anatomy (2026); ChatGPT, Claude.ai, Perplexity product behaviour | Every assistant message in our WebSocket stream maps to one of these states |
| Full-width messages with subtle background separation (not SMS-style bubbles) are the standard for serious AI chat | setproduct: "Bubbles signal 'casual texting' and undermine tool framing" — Claude.ai, ChatGPT, Cursor use flat full-width | Use Kimi's existing user-bubble recipe (neutral fill, `--radius-lg`, no border) and full-width assistant messages |
| Streaming text needs a caret/alive signal, first-token <800ms, batches in 30-60ms paint windows, and auto-scroll locked within 100px of bottom | setproduct; ChatGPT release notes (iOS faster streaming); thefrontkit | Composer stream must show a blinking caret, buffer partial markdown, and never yank scroll position |
| Thinking blocks are collapsed inline disclosure rows by default — never a side panel | Kimi Web Design System §04; Claude.ai extended thinking; ChatGPT o-series | Adopt Kimi's existing thinking row (k15 bulb icon, "Thinking…" label, collapsible chevron, elapsed seconds) |
| Tool calls render as quiet borderless lines (~24px), one per tool kind, grouped into activity runs with smart summary | Kimi Web Design System §04 (quiet activity lines); Cursor agent panel; Claude Code | WebSocket tool-call frames map into Kimi's bespoke tool-line vocabulary — no cards, no card chrome |
| Consecutive tools + thinking fold into one activity-run row; full turn folds into "Worked Ns" after settle | Kimi Web Design System §04 (TurnFold, ActivityRun) | Turn fold is essential for a multi-session WebSocket client — keeps the transcript navigable |
| Surface layers: page #121212, sidebar #0d0d0d, surface #1f1f1f, raised #292929, well #1f1f1f — all on a 4px grid | Kimi Web Design System §02 tokens | Copy the surface ladder verbatim for the web app |
| Command palette pattern (Cmd+K) is the correct navigation model for a developer tool — Linear, Raycast, Cursor, VS Code | Linear design patterns; Raycast product; Cursor | Skip sidebar-as-primary-nav; use a command palette for session switching, settings, search |
| Loading states: Skeleton (breathing opacity, no gradient), Spinner (plain SVG ring), WorkingIndicator (brand mascot only for chat working state) | Kimi Web Design System §03 (Skeleton, Spinner, WorkingIndicator); uxpatterns.dev AI Loading States | Skeleton for session list initial load; Spinner for inline waits; a phase label ("Connecting…", "Requesting…", "Working…") |
| Error recovery: differentiate provider errors, rate limits, content filters, network drops — never "Something went wrong" | setproduct; thefrontkit; uxpatterns.dev | WebSocket errors map to distinct inline messages with a single recovery action per type |
| Empty state: centered 48px faint icon + title + hint — no blank pages | Kimi Web Design System §03 (EmptyState); setproduct | Empty session list, empty connection screen, empty search results all use the same anatomy |
| Toast: status icon + title + description, status colour only on icon, bottom-right stack | Kimi Web Design System §03 (Toast) | Connection status, errors, undo actions live in the Toast stack |
| Skeleton: 1.6 line-height for prose, reading column capped at 760px, tables at 1040px | Kimi Web Design System §02 (layout tokens); setproduct | Chat prose gets `--p-content-max` 760px; code/tool output gets the full pane width |
| Focus ring: 3px accent-soft spread, `:focus-visible` only — never on mouse click | Kimi Web Design System §02, §09 | Every interactive element (session rows, send button, tool line chevrons) uses the same ring |
| Reduced motion: all durations drop to ~0.001ms via global `@media (prefers-reduced-motion: reduce)` | Kimi Web Design System §02, §09 | Apply globally; the chat working indicator shows its static fallback |

---

## 2. Design decisions to adopt

### WHAT — exact tokens

**Surface palette (dark first, light out of scope for MVP):**
- Page bg: `--color-bg` = #121212
- Sidebar bg: `--color-sidebar-bg` = #0d0d0d
- Raised surface (cards, dialogs): `--color-surface-raised` = #292929
- Surface (panel headers, secondary surfaces): `--color-surface` = #1f1f1f
- Well (code blocks, tool output): `--color-well` = #1f1f1f
- Menu bg: `--color-menu-bg` = rgba(41,41,41,.95) over `--p-menu-backdrop` blur
- Text: `--color-text` = rgba(255,255,255,.84) | `--color-text-muted` = rgba(255,255,255,.56) | `--color-text-faint` = rgba(255,255,255,.42)
- Lines: `--color-line` = rgba(255,255,255,.12) | `--color-subtle` = rgba(255,255,255,.05)
- Accent: `--color-accent` = #1a88ff | `--color-accent-soft` = rgba(26,136,255,.1)
- Success: `--color-success` = #3fb950 | Warning: #d29922 | Danger: #f85149

**Spacing (4px grid):** `--space-1`=4, `--space-2`=8, `--space-3`=12, `--space-4`=16, `--space-5`=20, `--space-6`=24, `--space-8`=32

**Radius:** `--radius-xs`=4, `--radius-sm`=6, `--radius-md`=8, `--radius-lg`=12, `--radius-xl`=16, `--radius-2xl`=20, `--radius-composer`=32 (superellipse 1.5), `--radius-full`=999

**Font:** `--font-ui` = Schibsted Grotesk (UI/body) | `--font-mono` = JetBrains Mono (code/tools)
**Type ramp (Medium = 14px base):** `--ui-t1`=22 (title), `--ui-t2`=16 (subtitle), `--ui-b1`=14 (body strong), `--ui-b2`=14 (body), `--ui-c1`=12 (caption), `--ui-c2`=11 (non-critical)
**Code size:** `--code-font-size` = 12px (standalone code surfaces)

**Motion:** `--ease-out` = cubic-bezier(0.16,1,0.3,1) | `--ease-in-out` = cubic-bezier(0.4,0,0.2,1) | fast=120ms, base=160ms, slow=260ms

**Layout:** `--p-sidebar-w` = 264px | `--p-content-max` = 760px | `--p-content-wide` = 920px | `--p-bp-sm` = 640px | `--p-bp-md` = 980px

### WHY — which app/source

Each token and pattern is lifted from the Kimi Web Design System v1.0 (the product's own design language) — the rationale is "same semantics, same component". The streaming-anatomy patterns (7 states, Stop button, collapse/expand thinking, activity-run folding) are validated against setproduct's AI Chat Anatomy guide and the known behaviour of ChatGPT, Claude.ai, and Cursor.

### WHERE — which component

| Token/Pattern | Where it applies |
|---|---|
| Surface tokens (#121212 → #292929) | Every UI surface: page, sidebar, dialogs, tool cards, composer |
| 4px grid, `--space-*` | All spacing, padding, gaps — no arbitrary pixels |
| Hairline 0.5px (`--color-line`, `--color-subtle`) | Card borders, plane seams, dividers, separator rows |
| `--radius-composer` 32px | The WebSocket message composer shell |
| `--radius-lg` 12px | Message bubbles, tool cards, dropdown menus |
| `--radius-xl` 16px | Dialogs, settings panels, connection info panel |
| `--font-mono` (JetBrains Mono) | Tool call lines, code blocks, thinking elapsed, session timestamps |
| `--ease-out` 160ms | Hover states, show/hide transitions, chevron rotations |
| `--ease-in-out` 260ms | Panel openings, composer focus edge, sidebar width changes |
| 7 message states | Every assistant message in the WebSocket stream |
| Thinking disclosure row | `thinking_start` / `thinking_delta` / `thinking_end` frames |
| Tool quiet line | `tool_start` / `tool_delta` / `tool_end` frames — reads/bashes/edits/globs |
| Activity run folding | Consecutive thinking + tools within one assistant turn |
| Turn fold ("Worked Ns") | After turn settles, before final text |
| Command palette | Cmd+K for session switching, search, settings, model selection |
| Skeleton (breathing opacity) | Session list initial load, reconnection loading |
| Toast stack | Connection drop/reconnect, tool errors, undo actions |
| EmptyState | No sessions, no search results, pre-connection state |

---

## 3. Component recipes

### 3.1 Composer (WebSocket message input)

**Anatomy:** Single raised shell — `--radius-composer` (32px) with `--corner-shape-composer`: superellipse(1.5). 0.5px stable edge (`--color-composer-line`). Fill `--color-composer-bg` (#1f1f1f dark). Focus: low-chroma line-and-accent edge crossfade over 260ms `--ease-in-out`. No halo, no layout shift.

**States:**
- **Idle:** Placeholder text "Message Kimi Code CLI…" at `--color-text-muted`. Send button disabled (opacity:0.5).
- **Focused:** Edge overlay fades in. Send button remains disabled if empty.
- **Has content:** Send button active (neutral `--color-text` fill, `--color-bg` glyph, 32px circle, `--radius-full`).
- **Streaming:** Composer locked (input disabled), send button replaced by Stop button (same 32px circle, danger fill). Stop button sends abort signal to WebSocket. Inline progress phase label: "Requesting…" → "Working…".
- **Error:** Show inline error chip below composer (not a Toast) — "Connection lost" / "Rate limited" with a retry link.

**Motion:** Focus edge fades at 260ms `--ease-in-out`. Composer pop-up menus: 0.97 scale from trigger corner over 160ms, exit 120ms.

### 3.2 Streaming message + typing/streaming indicator

**Anatomy:** Full-width assistant message, no bubble chrome. Flush left with the 760px reading column. Phase label row above the content: "Thinking…" with elapsed seconds (mono, `--color-text-faint`, 12px). Blinking caret (thin vertical bar, same colour as text, 500ms square-wave blink) at the end of streamed text, removed on completion.

**States:**
- **Queued (0–800ms before first token):** Placeholder skeleton — one shimmering text line (breathing opacity 1200ms cycle, no gradient). Phase label: "Requesting…".
- **Thinking / reasoning:** Collapsible disclosure row (Kimi's k15 `thinking` icon, "Thinking…" label, `Ns` elapsed). Content hidden behind chevron. Default collapsed. Row: 24px height, 13px UI text, `--color-text-muted`. Chevron rotates 90° on expand.
- **Streaming:** Tokens arrive. Blinking caret. Markdown rendered incrementally — code blocks show as plain text until closing fence, then syntax-highlighted in a second pass. Batched at 30-60ms paint windows. Phase label: "Working…". Stop button visible at bottom of message stream.
- **Complete:** Caret removed. Phase label replaces with timestamp (12px mono, `--color-text-faint`). Per-message actions appear on hover: copy, regenerate, thumbs up/down.
- **Error:** Message stream stops. Inline error banner (Kimi Banner component, danger variant): "Error: rate limit exceeded" / "Connection lost" / "Content filtered". Single recovery action: Try again / Switch model / Shorten prompt.
- **Stopped (user pressed Stop):** Partial output preserved. "Stopped" label in `--color-warning` (#d29922). Two actions: Continue (resumes generation) / Regenerate (restarts from scratch).
- **Regenerating:** Old response collapses into "Previous response" accordion. New stream begins.

**Auto-scroll contract:** Auto-scroll only when viewport is within 100px of bottom. User scroll-up locks position; show "Jump to latest" floating button (12px UI text, weight 525, down-arrow icon, `--z-sticky`).

### 3.3 Thinking UI

**Anatomy:** Inline, borderless disclosure row in the message stream — never a side panel. Icon: `thinking` registry icon (k15 bulb). Label: "Thinking…" (streaming) / "Thinking process" (settled). Elapsed: `Ns` in mono, `--color-text-faint`, 12px.

**States:**
- **Streaming:** Label breathes (opacity-only, 1600ms cycle, no gradient shimmer). Elapsed ticks up in whole seconds. Row is collapsed by default.
- **Expanded:** Content area shows the raw thinking text (full prose, no markdown rendering, `--color-text-muted`, 13px). Grid-rows animation (`--duration-slow` 260ms). Chevron rotated 90°.
- **Collapsed by turn fold:** Once the stream moves past this thinking block, the row auto-folds itself (even if user expanded it mid-stream).
- **Settled:** Label becomes "Thinking process · Ns". Row remains collapsed. Chevron available for manual expand.

### 3.4 Tool-call row/card

**Anatomy:** One quiet borderless line per tool call (~24px height, same as thinking row). No card chrome, no hover wash. Leading glyph (tool-specific registry icon). Tool-specific content inline. Trailing meta + status dot.

**Row layout (shared):** 13px UI text `--color-text-muted`. Mono content (commands, file paths) at 12px `--code-font-size`. File name = `--color-text` (clickable, opens preview). Duration chip at right edge. Only the chevron (16px) is a disclosure affordance — hugging the line's text, not pushed to the far edge.

**Per-tool composition:**
- **Bash:** Label "Run" + mono command (CSS-truncated) + duration chip + status (✓/✕)
- **Read:** Label "Read" + file name (clickable) + directory · `:line-range` + status
- **Edit:** Label "Edit" + file name + `+N −M` stat + mini diff bar + status
- **Write:** Label "Write" + file name + status
- **Grep:** Label "Search" + pattern in mono + match count + status
- **Glob:** Label "Find" + pattern in mono + file count + status
- **WaitFor:** Label "Wait" + task name + status badge + duration chip

**States:**
- **Running:** Pulsing accent dot (same as Kimi's running status dot, pulsing blue `--color-accent`). Duration ticks up.
- **Settled:** Green ✓ (`--color-success`) or red ✕ (`--color-danger`). Final duration.
- **Expanded:** Detail panel drops below at the line's own left edge. Content: mono output panel (12px, `--color-well` surface, hairline edge, 12-line scroll cap), inline diff, or clickable file list.

**Activity run grouping:** Consecutive tools + thinking fold into ONE activity-run row. Smart summary: "Read 2 files · Ran 3 commands (1 failed) · 26s". Same vocabulary as thinking row (borderless faint text, text-colour hover only, rotating chevron). 30px vertical padding (vs 22px for single lines). Expanded run shows items flat in order, with 8px gap between items.

### 3.5 Session list item

**Anatomy:** Inset rounded pill, ~32px height (font-driven). Structure: status slot (16px fixed width) → title (flex:1, truncate, `user-select: none`) → time (12px mono, `--color-text-faint`) → attention badge → hover actions.

**States:**
- **Default:** `--color-text`, 500 weight. Status slot: running = Spinner sm, unread = 7px accent dot, else empty.
- **Hover:** `--color-hover` wash (#0d0d0d sidebar → rgba(255,255,255,.03)). Time cross-fades to pin/archive IconButtons.
- **Selected:** `--color-selected` (rgba(255,255,255,.1)) — neutral, no accent tint, no border, no weight change.
- **Active (WebSocket connected):** Green 7px status dot in the slot.
- **Disconnected:** Grey dot + "Disconnected" label in `--color-text-faint`.

**No top-level sidebar:** Sessions are accessed via Cmd+K command palette. The session list is a panel within the palette, not a permanent sidebar rail. This deviates from Kimi Web's sidebar but follows the Linear/Raycast/Cursor model appropriate for a web app that may be used in a narrow browser window.

### 3.6 Command palette

**Anatomy:** Floating dialog (Kimi Dialog primitive, `--radius-xl`, `--shadow-xl`, sm 360px width). Frosted glass surface (`--color-menu-bg` over `--p-menu-backdrop` blur). Boxed search Input at top (22px inset, autofocused). Result list below (flex:1, owns scroll, 4px 8px padding). Shortcut bar at bottom (Kbd keycaps + 12px faint labels).

**Trigger:** Cmd+K (Ctrl+K on non-macOS). Same binding as Kimi Web's sidebar search, but opens a palette instead.

**Sections:**
- **Sessions:** Recent sessions by recency, each showing title + first 40 chars of last prompt. Select to switch session.
- **Actions:** "New session", "Settings", "Connection info", "Disconnect", "Clear session".
- **Search:** Type to filter all sections. Fuzzy match on session titles.

**States:**
- **Open:** Animates in (fade + 0.97 scale, 160ms `--ease-out`). Backdrop: 28% neutral overlay.
- **Empty query:** Shows recent sessions + action list.
- **Has query:** Filters results, highlights matched characters with semibold weight.
- **No results:** Centered faint "No results" line.
- **Loading:** Spinner sm in the search row while debounce fires.

### 3.7 Loading skeleton (session list)

**Anatomy:** Three rows of skeleton shapes, each matching the session list item anatomy (32px tall, 16px status slot + truncated title area + 12px time area). Breathing opacity animation (1200ms cycle, `--ease-in-out`). No gradient shimmer — opacity only, per Kimi's no-gradient-text rule.

**States:**
- **Initial load:** Shown on app start while WebSocket connects and session list loads. Three skeleton rows.
- **Refreshing:** Existing session list stays visible, skeleton rows appended at bottom (or not shown — stale data is better than flash).
- **Error:** Skeleton replaced by EmptyState error variant: warning icon + "Failed to load sessions" + retry button.

### 3.8 Empty state

**Anatomy:** Centered in the available space. 48px faint registry icon (`--color-text-faint`). Title (14px, `--color-text`, weight 500). Hint (13px, `--color-text-muted`). No button by default. Uses Kimi's `EmptyState` primitive.

**Variants:**
- **No sessions:** `message` icon + "No sessions yet" + "Start a new session from the command palette (Cmd+K)"
- **Search no results:** `search` icon + "No sessions match" + "Try a different search term"
- **Disconnected:** `wifi-off` icon (or `alert-triangle`) + "Not connected" + "Waiting for connection…" (auto-resolve)
- **Error:** `alert-triangle` icon + "Could not connect" + "Check that Kimi Code CLI is running" + "Retry" ghost button

### 3.9 Toast

**Anatomy:** Fixed bottom-right stack. Each toast: status icon (status colour only) + title + description. `--radius-lg`, `--shadow-menu`, `--color-surface-raised` background. 0.5px hairline. Self-timed (8s default, hover pauses).

**Types:**
- **Connected:** Success icon + "Connected to Kimi Code CLI" + optional server info
- **Disconnected:** Warning icon + "Disconnected" + "Attempting to reconnect…"
- **Error:** Danger icon + "Error" + specific message (rate limit, network, tool failure)
- **Undo:** Action toast variant (top-center pill, 48px below top edge): "Session archived" + "Undo" accent button + "Settings" link

**Motion:** Slide in from right edge (160ms `--ease-out`). Stack pushes older toasts up. Dismiss on click or timeout.

---

## 4. Anti-patterns to avoid

1. **Purple gradients, glassmorphism, glowing shadows** — "AI tell" signifiers. The Kimi Web Design System explicitly bans these (no-gradient-text, no-glassmorphism, no-color-glow rules). The only glassmorphism exemptions are floating menu surfaces (menus, listboxes, dropdowns) and the sticky TopBar — carry those exemptions exactly, nothing more.

2. **SMS-style bubbles** — Round colourful chat bubbles signal "casual texting" and undermine the developer-tool framing. Use Kimi's existing user-bubble recipe (neutral fill, `--radius-lg`, no border, no shadow) and full-width assistant messages.

3. **Fake typing animation** — Never throttle a fast model to "feel human". Users prefer fast and honest. Show the blinking caret and stream tokens as they arrive.

4. **No Stop button during streaming** — The user must always be able to abort a bad response. The Stop button is non-negotiable (setproduct #1 anti-pattern).

5. **Auto-scroll that fights the user** — Lock scroll position the instant the user scrolls up. Show "Jump to latest" instead of yanking the viewport.

6. **Hiding errors as generic "Something went wrong"** — Differentiate provider errors, rate limits, content filters, network drops. Each gets a distinct message and recovery action.

7. **No conversation history** — Sessions persist across page refreshes. The session list is the first thing the user sees (via Cmd+K).

8. **Modal-locking the chat during streaming** — The user can navigate, open the command palette, or start composing the next prompt while the current message streams.

9. **Silent context truncation** — If the WebSocket bridge truncates or summarizes context, show a clear marker — "Earlier messages summarized" — never silently drop turns.

10. **Emoji as functional icons** — Kimi's icon registry is the single source for all functional icons. Emoji is content only (session titles, messages). The no-emoji-icon rule is enforced.

11. **Gradient shimmer loading** — Skeleton uses breathing opacity only, per Kimi's no-gradient-text rule and the `Skeleton` primitive spec.

12. **Accent-tinted selection** — Selection means "where I am" (sidebar rows, list pickers). Use `--color-selected` (neutral), never accent-tinted. Accent blue is reserved for actions — primary buttons and focus rings.

---

## 5. Top 10 takeaways

1. **Copy the Kimi surface ladder verbatim:** #121212 page, #0d0d0d sidebar, #1f1f1f surface, #292929 raised, #1f1f1f well. This is the design system — don't invent new greys.

2. **7 message states, not 2:** Every assistant message goes through queued → thinking → streaming → complete (or error → stopped → regenerating). Design each state. The gap between "streaming" and "done" is where most AI chat UIs feel janky.

3. **Thinking is an inline collapsed row, never a side panel:** Use Kimi's existing thinking disclosure pattern (k15 icon, "Thinking…" label, chevron, elapsed seconds). Default collapsed, expands in place.

4. **Tool calls are quiet borderless lines, not cards:** Each tool kind (Bash, Read, Edit, Grep, Glob, Write, WaitFor) composes its own line. No card chrome, no hover wash, 24px height, 13px text. Group consecutive tools into activity-run rows.

5. **Turn fold is essential:** After an assistant turn settles, everything before the final text block folds into one "Worked Ns" row. This keeps the transcript navigable across multi-minute WebSocket sessions.

6. **Sticky composer, never floating:** The composer is docked at the bottom with `--z-sticky`. The message stream gets bottom padding equal to the live composer height. The Stop button sits at the bottom of the stream, near the composer.

7. **Command palette (Cmd+K) for navigation, not a sidebar:** The app is a web page that may run in a narrow browser window. Linear/Raycast-style command palette is more appropriate than a permanent sidebar rail. Session list lives inside the palette.

8. **Streaming contract:** First token <800ms, batch DOM updates at 30-60ms, blinking caret, auto-scroll only within 100px of bottom, Stop button always visible during streaming, buffer incomplete markdown, defer code block rendering.

9. **Error differentiation:** Every WebSocket error type (rate limit, provider error, content filter, network drop, disconnect, context overflow) gets a distinct inline message, not a generic Toast. Each error carries exactly one recovery action.

10. **Accessibility from day one:** `:focus-visible` only (3px accent-soft ring), `aria-live="polite"` on streaming content, keyboard path for every action (Cmd+K, Escape, Enter, arrows), WCAG AA contrast (4.5:1 body text), reduced motion respected globally, disabled at opacity:0.5 uniformly.

---

## 6. Mobbin outage impact statement

Mobbin was entirely unavailable during research (all endpoints — `search_screens`, `search_flows`, `search_apps`, `quick_search`, `get_filters`, `popular_apps` — returned 404 or validation errors). The Mobbin-based research plan was replaced with:
- Firecrawl web search and scrape for product UI patterns (setproduct, uxpatterns.dev, thefrontkit)
- Direct reading of the Kimi Web Design System v1.0 (1349-line spec, fully ingested)
- Known product behaviour from ChatGPT, Claude.ai, Perplexity, Cursor, Linear, Raycast

The resulting spec is grounded in the Kimi design system first and external AI chat UX research second. The spec would benefit from a follow-up Mobbin pass to validate per-app screen-level details once the Mobbin API recovers.

---

## Summary

This spec defines a dark-first, density-restrained, clinical web app for streaming Kimi Code CLI WebSocket responses. It copies the Kimi Web Design System surface tokens, spacing, typography, and motion verbatim. The chat interface follows the 7-state AI message lifecycle (queued → thinking → streaming → complete/error/stopped/regenerating), with thinking as inline collapsed rows, tool calls as quiet borderless lines, and consecutive work folded into activity-run summaries. Navigation uses a Cmd+K command palette (Linear/Raycast model) rather than a permanent sidebar. The composer is sticky-docked, streaming shows a blinking caret with markdown buffering, and every error differentiates cause and recovery action. Anti-patterns from the AI-slop era (purple gradients, SMS bubbles, fake typing, no stop button, silent errors) are explicitly banned. The spec is actionable per component — anatomy, states, motion, tokens, and rationale are specified for composer, streaming message, thinking UI, tool-call row, session list item, command palette, loading skeleton, empty state, and toast. Mobbin was unavailable; the spec is grounded in the Kimi design system and AI chat UX research instead.