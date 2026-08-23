# mobbin-motion-loading — Loading states, streaming indicators, and motion vocabulary for the Kimi Code Proxy WebSocket client

## Key findings

### 1. Chat streaming loading patterns (ai-chat-setproduct, northbase, aiverse)
- **ChatGPT**: pulsing single black dot while streaming; "Answer now" escape during thinking; stop button replaces send (black square). Message stream ~768px max-width. (northbase, setproduct, aiverse)
- **Claude**: small filled square caret; "Thinking…" → "Thinking process · Ns" collapsible row; beige thought-process background; branded orange sunburst loading; left-aligned AI text, right-aligned user. (northbase, setproduct)
- **Perplexity**: multi-step status labels ("Searching", "Reviewing sources · N", "Working..."), rotating logo, shimmer, source countdown, streaming text. ~720px max-width. (aiverse, northbase)
- **Kimi Web**: `WorkingIndicator` (小蓝 mascot) for chat working state only; phases: "Requesting…" → "Working…". Plain `Spinner` (SVG ring) for everything else. Thinking: inline disclosure row with k15 bulb icon, breathing opacity (no gradient, no shimmer), elapsed seconds tick, "Thinking process · Ns" after settle. (kimi doc §02, §04)
- **70% of code-capable systems use split-view** (Claude Artifact 50/50, ChatGPT Canvas 35/65 chat-to-preview, v0 collapsible). (northbase)
- **50% of systems use minimal loading**: dots, spinners, or branded animations. (northbase)
- **6 of 12 systems describe what AI is doing**: action-specific status text ("Building tables", "Searching for tech news today"). (northbase)

### 2. Thinking/reasoning disclosure (northbase, setproduct, kimi doc)
- **4 of 12 systems expose AI reasoning, always collapsed by default**: Claude "Thought process" (beige bg), v0 real-time streaming thinking + "Worked for 30s" badge, Retool numbered steps. (northbase)
- **Kimi**: thinking = inline borderless disclosure row in message stream; k15 bulb icon; "Thinking…" label breathes (opacity only, **never gradient shimmer**); whole seconds tick; after settle → "Thinking process · Ns". Collapsed by default, expands in place with grid-rows animation + 90° chevron. (kimi doc §04)
- **Kimi tool calls**: quiet borderless lines (~24px row), 13px UI text, 12px mono for code/meta. Three tiers: tool line (lightest) → activity run (medium, consecutive activity folds to one smart-summary row) → sub-agent card. (kimi doc §04)

### 3. Skeleton loading patterns (NN/g, kimi doc, setproduct)
- **Kimi skeleton**: "breathing opacity animation (no gradients), composed into titles / text lines / avatars." (kimi doc §03)
- **NN/g**: skeleton screens best for full-page loads <10s; spinners for single modules 2-10s; progress bars for >10s; <1s no indicator. Avoid frame-display skeletons (just header/footer). Animated skeletons can be distracting. (nngroup)
- **Raycast**: command palette floating surface with elevation shadow stack (Level 5: rgba(0,0,0,.5) 0 0 0 2px + rgba(255,255,255,.19) 0 0 14px). Surface ladder: canvas → surface → surface-elevated → surface-card. (open-design.ai)
- **Linear**: "Don't compete for attention you haven't earned" — sidebar a few notches dimmer, softer borders, fewer separators. "Structure should be felt not seen." (linear.app)

### 4. Stop/send button conventions (northbase, setproduct, kimi doc)
- **83% of systems replace Send with square Stop** during generation. ChatGPT black square, Claude orange square, GitHub Copilot red, v0 adds "Stop" text label. (northbase)
- **Kimi**: send button is 32px circle, disabled while empty or "starting spinner". Send replaced… (implicitly) — the stop mechanism uses the standard pattern. (kimi doc §04)

### 5. Typing indicator origin (ux.stackexchange, aiverse)
- **Three-dot typing indicator** originated at IBM in 1997 for the "someone is typing" signal. Reduces perceived wait time. (aiverse, ux.stackexchange)
- **WhatsApp/iMessage/Slack/Facebook Messenger**: animated 3-dot pattern. (chatboq)
- **ChatGPT**: pulsing dot (single). **Claude**: thin filled square caret. **Cursor**: thin vertical bar. (setproduct)

### 6. Motion design principles (kimi doc, material, spectrum, fluent)
- **Kimi motion tokens**: ease-out cubic-bezier(0.16,1,0.3,1), ease-in-out cubic-bezier(0.4,0,0.2,1), fast 120ms, base 160ms, slow 260ms, spin 700ms, flash 1200ms. (kimi doc §02)
- **Reduced motion**: Kimi drops all durations to ~0.001ms, WorkingIndicator mascot renders static fallback. (kimi doc §02)
- **Material**: informative, focused, expressive. (m2.material.io)
- **UX in Motion**: easing, offset & delay, transformation, overlay, parenting. (medium UX in Motion)
- **Linear**: warmer gray palette, cooler-blue tint removed, compact tabs, reduced icon usage, smaller icon sizes, removed colored team icon backgrounds. (linear.app)

### 7. Action bar conventions (northbase, setproduct)
- **50% of systems use 4-5 icon compact action bar**: Claude (Copy, thumbs up/down, Regenerate); GitHub Copilot (feedback first, then Copy, Regenerate); Retool (thumbs only). (northbase)
- **80%+ use paired thumbs up/down, always adjacent.** (northbase)

### 8. Empty state (kimi doc, setproduct)
- **Kimi EmptyState**: 48px faint icon + title + hint, centered placeholder. (kimi doc §03)
- **Kimi jump-to-latest**: 12px UI text weight 525, full down-arrow icon. (kimi doc §04)

---

## Design decisions to adopt

### A. Streaming message indicator (the "alive" signal)
- **WHAT**: A blinking filled-square caret (2px × 2px, `--color-accent` #1a88ff dark, 0.5s square-wave blink via CSS `animation: 0.5s step-end infinite`). Rendered after the last visible token.
- **WHY**: Claude.ai uses a small filled square, ChatGPT a pulsing dot — both work. The filled square is the most unambiguous "more is coming" signal. (setproduct, northbase)
- **WHERE**: Chat stream — appended to the last assistant message while streaming.

### B. Queued state (first-token latency)
- **WHAT**: A placeholder row matching the assistant message layout: one skeleton line (12px tall, 60% width, `--color-subtle` rgba(255,255,255,.05) dark, breathing opacity 0.3→0.6 over 1.2s ease-in-out). No spinner, no progress bar.
- **WHY**: Kimi's skeleton uses breathing opacity only (no gradients). NN/g says <1s needs no indicator, 2-10s needs skeleton. The queued window is 200ms–2s — a single shimmering line is sufficient. (kimi doc §03, nngroup, setproduct)
- **WHERE**: Chat stream, first assistant message placeholder before first token arrives.

### C. Thinking/reasoning row
- **WHAT**: Inline borderless disclosure row within the message stream. Anatomy: 16px k15/thinking registry icon (muted) + "Thinking…" label (13px UI text, `--color-text-muted`) + elapsed seconds counter (12px mono, `--color-text-faint`). Chevron-right (16px, `--color-text-faint`) rotates 90° on expand. The label breathes via opacity only (0.5→1 over 1.6s ease-in-out, never a gradient shimmer). On settle, label becomes "Thinking process · Ns" (Ns = final elapsed). Collapsed by default. Grid-rows animation (`--duration-slow` 260ms, `--ease-in-out`).
- **WHY**: Kimi §04 spec is the exact reference. Matches Claude's "Thought process" pattern (collapsible, collapsed by default). (kimi doc §04, northbase)
- **WHERE**: Chat stream, between user message and assistant response.

### D. Tool call row/activity line
- **WHAT**: Borderless quiet line (~24px row height). Leading tool glyph (16px, muted) + localized action label (13px UI, `--color-text-muted`) + tool-specific content (mono 12px for commands, `--color-text-muted`) + trailing status dot (accent pulsing = running, green ✓ = done, red ✗ = failed, all 7px) + optional duration chip (12px, `--color-text-faint`). No hover wash, no card chrome. Chevron (16px, muted) as disclosure affordance. Expanded detail hangs below at same left edge.
- **WHY**: Kimi §04 tool call spec exactly. Three tiers: tool line (lightest) → activity run (medium, consecutive calls fold to one summary row) → sub-agent card. (kimi doc §04)
- **WHERE**: Chat stream, between tool calls. Consecutive activity folds into one activity-run row.

### E. Activity run summary row
- **WHAT**: A single row (30px, 8px vertical padding) that aggregates consecutive thinking + tool calls. Smart summary: "Read 2 files · Ran 5 commands (1 failed) · 26s". The failure clause in danger red. Total span faint at tail. Row shares thinking row language (borderless, faint text, text-colour only hover, rotating chevron) but with roomier padding. While streaming, summary turns live (current action + cumulative stats + ticking seconds). On settle, row folds itself back.
- **WHY**: Kimi §04 activity run spec. (kimi doc §04)
- **WHERE**: Chat stream, replaces individual tool call blocks during consecutive tool activity.

### F. Turn fold row
- **WHAT**: After an assistant turn settles, everything before the final text block folds into a single bare row: "Worked 4m57s" (no glyph, no summary sentence). The row expands into folded blocks in order. Text-only turns render no fold row.
- **WHY**: Kimi §04 turn fold spec. (kimi doc §04)
- **WHERE**: Chat stream, after assistant turn completes.

### G. Skeleton loading (session list, sidebar, initial load)
- **WHAT**: Breathing opacity animation (0.3→0.6 over 1.2s, `--ease-in-out`). Composed of placeholder shapes: title lines (12px tall, 60% width), text lines (8px tall, 40-80% width), avatar circles (32px), and card rectangles (full width, 80px tall). All use `--color-subtle` rgba(255,255,255,.05) dark fill. NO gradient shimmer, NO colored pulses.
- **WHY**: Kimi §03 Skeleton spec: "breathing opacity animation (no gradients), following the no-gradient-text rule." NN/g confirms animated skeletons help perceived performance but must avoid distracting animations. (kimi doc §03, nngroup)
- **WHERE**: Session sidebar initial load, session list loading (empty state → skeleton → populated), panels loading content.

### H. Stop generating button
- **WHAT**: The Send button (32px circle, `--color-text` fill, `--color-bg` glyph) transforms into a square Stop button (32px, `--color-danger` fill #f85149, white square icon). Only visible during streaming. Disappears the moment generation ends.
- **WHY**: Northbase: 83% of systems replace Send with square Stop. Kimi uses a 32px send circle. GitHub Copilot uses red, ChatGPT uses black, Claude uses orange. Danger red matches Kimi's existing `--color-danger` (#f85149). (northbase, kimi doc §04)
- **WHERE**: Composer send button, during streaming.

### I. Loading state for sections (models, settings, panels)
- **WHAT**: Kimi `Spinner` (plain SVG ring, 16px, `--color-accent` #1a88ff, rotation 700ms per cycle). Centered in the container. No label unless the wait is >2s (then 12px muted text below).
- **WHY**: Kimi §02: "Spinner (plain SVG ring) — used for button loading, app startup, and general inline waits." WorkingIndicator is reserved for the chat working state only. (kimi doc §02)
- **WHERE**: Model picker loading, settings page loading, panel loading, any non-chat loading state.

### J. Empty state
- **WHAT**: Centered placeholder: 48px faint icon (`--color-text-muted`, `--p-ic-lg`) + title (14px, `--color-text`) + hint (12px, `--color-text-muted`). No illustrations, no color.
- **WHY**: Kimi §03 EmptyState spec. (kimi doc §03)
- **WHERE**: Empty session list, empty search results, empty panel.

### K. Toast notification
- **WHAT**: Status icon (18px, `--p-ic-lg` — color only on the icon, never on the background) + title (13px, `--color-text`) + description (12px, `--color-text-muted`). Self-timed 8s default, hover pauses. `--z-toast` (600), `--shadow-md`, `--radius-lg`.
- **WHY**: Kimi §03 Toast spec: "status color appears only on the icon, avoiding large colored areas." ActionToast variant (top-center pill) for undoable actions. (kimi doc §03)
- **WHERE**: Connection status, errors, confirmations, undo actions (sidebar archive, session actions).

### L. Motion vocabulary
- **WHAT**: Standard token set: `--ease-out` cubic-bezier(0.16,1,0.3,1) for enter/hover/expand, `--ease-in-out` cubic-bezier(0.4,0,0.2,1) for panel width/layout, `--duration-fast` 120ms for press/focus, `--duration-base` 160ms for hover/show/hide, `--duration-slow` 260ms for dialog/sheet/layout, `--duration-spin` 700ms for spinner. Reduced motion: all durations → ~0.001ms.
- **WHY**: Kimi §02 motion tokens exactly. (kimi doc §02)
- **WHERE**: All interactive elements, transitions, and motion.

### M. Sidebar loading and density
- **WHAT**: Sidebar at `--color-sidebar-bg` (#0d0d0d dark), 264px default width, dense list (4px vertical padding between rows, 32px row height). Row height font-driven (title line-height leading-tight ≈16px, total ≈32px). Skeleton placeholder: 3-4 rows of breathing opacity lines.
- **WHY**: Kimi sidebar spec: dense list rhythm, surface-deep below page level. Linear: "sidebar a few notches dimmer than main content." (kimi doc §02, §08; linear.app)
- **WHERE**: Session sidebar, workspace list.

### N. Jump-to-latest during streaming
- **WHAT**: Floating button (12px UI text weight 525, full down-arrow icon) appears at the bottom of the message stream when the user has scrolled up during streaming. Click scrolls to the latest message. Auto-scroll only when viewport is within 100px of bottom.
- **WHY**: Kimi §04 jump-to-latest spec + setproduct auto-scroll rule. (kimi doc §04, setproduct)
- **WHERE**: Chat stream, during streaming when user scrolls up.

### O. Command palette loading
- **WHAT**: A floating panel (frosted glass menu surface, `--color-menu-bg`, `--radius-lg`, `--shadow-menu`). Search input at top (bare, 38px). Results list below: shows skeleton rows (3-4 breathing opacity lines) while loading, then real results. Keyboard: ↑↓ to navigate, Enter to select, Esc to close. No spinner; the skeleton replaces the results area.
- **WHY**: Raycast's command palette is the reference for fast, simple, delightful. Kimi's flush picker anatomy (§09) defines the search row + result list pattern. The skeleton follows Kimi's breathing opacity. (kimi doc §09, raycast.com)
- **WHERE**: Command palette (Cmd+K), slash commands, mention autocomplete.

---

## Component recipes

### Recipe 1: Composer
```
┌─ superellipse(1.5) 32px radius ───────────────────────────────┐
│  [model pill] [thinking toggle] [permission mode]  │  [+ add]  │
│  ┌─────────────────────────────────────────────────┐  │          │
│  │ Message Kimi, / to run a command…               │  │  [send]  │
│  └─────────────────────────────────────────────────┘  │  32px ○  │
│  [work pills: goal | bash | plan | todo]               │          │
└───────────────────────────────────────────────────────────────┘
```
- **States**: idle (empty, send disabled `opacity:.5`), composing (send enabled), uploading (send disabled, spinner in place of send), streaming (send → stop, square danger-red icon)
- **Motion**: focus crossfade line+accent edge over 260ms ease-in-out; send button slide-in on content; menus pop from trigger (0.97 scale, 160ms entry, 120ms exit)
- **Tokens**: bg `--color-composer-bg`, line `--color-composer-line`, send bg `--color-send-bg`, send icon `--color-send-icon`

### Recipe 2: Streaming message with typing indicator
```
┌────────────────────────────────────────────────────────────────┐
│  I looked at the code and found that the auth module uses…     │
│  session cookies. The JWT migration would involve:             │
│  1. Adding jsonwebtoken dependency                             │
│  2. Creating verify() and sign() helpers…                     ██  │
│                                                   [stop] [send]│
└────────────────────────────────────────────────────────────────┘
```
- **Caret**: 2px × 2px filled square, `--color-accent`, 0.5s step-end blink
- **Queued state**: single skeleton line (60% width, 12px tall, breathing opacity)
- **Error state**: message shows partial content + "Stream interrupted" banner (danger-soft bg, `--color-danger` text, "Continue" + "Regenerate" actions)
- **Motion**: text streams in; no reflow on every token — batch into 30-60ms paint windows; auto-scroll only when within 100px of bottom

### Recipe 3: Thinking UI
```
┌─ [💭 k15 icon] Thinking…  12s  [▶ chevron] ─┐  ← collapsed
├─ [💭 k15 icon] Thinking process · 12s [▼] ─┤  ← expanded
│  I need to first understand the auth module…  │
│  The user wants JWT tokens, so I'll…          │
└───────────────────────────────────────────────┘
```
- **States**: streaming (label breathes opacity, seconds tick), settled ("Thinking process · Ns", foldable), expanded (shows reasoning text in prose, 13px UI, `--color-text-muted`)
- **Motion**: label breathing opacity 0.5→1 over 1.6s ease-in-out; expand/collapse grid-rows 260ms ease-in-out; chevron rotates 90° over 160ms ease-out
- **Tokens**: all text `--color-text-muted`, icon `--color-text-faint`, no background, no card shell

### Recipe 4: Tool call row
```
┌─ [▶] Read  session.ts  src/auth :12-45  0.3s  ● ─┐  ← collapsed
├─ 12 │ export function verify(token: string) {      │  ← expanded
│  13 │   return jwt.verify(token, getSecret());     │
│  14 │ }                                            │
└────────────────────────────────────────────────────┘
```
- **States**: running (accent pulsing dot), done (green ✓), failed (red ✗), expanded (shows tool output with syntax highlighting)
- **Types**: Bash (command in mono), Read (file name + directory + line range), Edit (file + +A −D), Grep (pattern + match count), Search (pattern + results), Write (file name), WaitFor (task name + status badge)
- **Motion**: expand/collapse grid-rows 260ms ease-in-out; status dot pulse 700ms spin while running
- **Tokens**: 13px UI text, 12px mono for code, row ~24px, chevron 16px

### Recipe 5: Session list item
```
┌─ [○ or ◉]  Refactor auth module to use JWT  2m ago  [📌][📦] ┐
└────────────────────────────────────────────────────────────────┘
```
- **States**: selected (neutral `--color-selected` fill, no accent), unread (7px accent dot), running (Spinner sm), hover (actions cross-fade)
- **Skeleton**: 3-4 breathing opacity lines matching the row layout
- **Tokens**: 32px row height, `--sb-*` alignment, `--color-sidebar-bg` #0d0d0d

### Recipe 6: Skeleton loading
```
┌─ Session sidebar skeleton ─────────────────────────────────────┐
│  ┌─ 32px ─────────────────────────────────────────────────┐   │
│  │  [○]  ████████████████████                    [⋯]     │   │
│  │  [○]  ████████████████████████████             [⋯]     │   │
│  │  [○]  ████████████████                         [⋯]     │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```
- **Variants**: title line (12px tall, 60% width), text line (8px tall, 40-80% width), avatar circle (32px), card rectangle (full width, 80px), session row (32px full width)
- **Motion**: breathing opacity 0.3→0.6 over 1.2s ease-in-out, all elements in sync (no staggered shimmer)
- **Tokens**: all fill `--color-subtle` rgba(255,255,255,.05), `--radius-sm` 6px for rounded rects

### Recipe 7: Empty state
```
┌─ Empty state ──────────────────────────────────────────────────┐
│                        [ 48px icon ]                           │
│                     No chats yet                               │
│          Click "New chat" to start a conversation              │
│                        [New chat]                              │
└────────────────────────────────────────────────────────────────┘
```
- **Tokens**: icon `--p-ic-lg` 20px visual (`--color-text-muted`), title 14px `--color-text`, hint 12px `--color-text-muted`, 48px icon container

### Recipe 8: Toast
```
┌─ Toast (bottom-right stack) ───────────────────────────────────┐
│  [ℹ️]  Connected to server                                    │
│        The local server is responding normally                 │
└────────────────────────────────────────────────────────────────┘
```
- **Variants**: info (neutral), success (green icon), warning (orange icon), danger (red icon). ActionToast variant: top-center pill, "Undo" inline button.
- **Motion**: slide in from right 260ms ease-out, slide out 160ms ease-in, self-timed 8s default
- **Tokens**: `--z-toast` 600, `--shadow-md`, `--radius-lg`, color only on icon

### Recipe 9: Command palette
```
┌─ Command palette (frosted glass) ───────────────────────────────┐
│  [🔍]  Search commands and files…                     [⌘K]    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  [▶]  /read     Read a file from the workspace            │ │
│  │  [▶]  /edit     Edit a file                               │ │
│  │  [▶]  /bash     Run a shell command                       │ │
│  │  [▶]  /search   Search text in the workspace              │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ↓ 4 of 12 results                                            │
└────────────────────────────────────────────────────────────────┘
```
- **States**: loading (skeleton rows replace results), empty ("No results for…"), results (12px UI rows, 13px label, muted description), error (danger text)
- **Motion**: pop in 0.97 scale 160ms ease-out from trigger, exit 120ms ease-in; results fade in 120ms
- **Tokens**: `--color-menu-bg`, `--radius-lg`, `--shadow-menu`

---

## Anti-patterns to avoid

1. **Gradient shimmer on skeletons** — Kimi explicitly bans gradient text/fills (`no-gradient-text`). Use breathing opacity only. (kimi doc §07)
2. **Fake typing animation that throttles output** — Don't artificially slow fast models to "feel human". ChatGPT stopped doing this. (setproduct, aiverse)
3. **Percentage progress bars during streaming** — No progress to report; fake bars break trust. (setproduct)
4. **Frame-display skeletons** — Just header/footer with no content wireframe is equivalent to a spinner. (nngroup)
5. **No stop button during generation** — Inexcusable. Every streaming state must have a stop affordance. (setproduct, northbase)
6. **Auto-scroll that fights the user** — Lock scroll position when user scrolls up. Show jump-to-latest button. (setproduct, kimi doc §04)
7. **Collapsing errors into generic "Something went wrong"** — Show what happened, why, and the recovery action. (setproduct)
8. **Bubble-shaped messages (SMS style)** — Signals "messenger", undermines tool framing. Full-width flat messages with subtle background. (setproduct)
9. **Hiding the model name** — Every assistant message should show which model produced it. (setproduct, northbase)
10. **Glassmorphism on loading states** — Glassmorphism is banned except for menus and the TopBar. (kimi doc §07)

---

## Top 10 takeaways

1. **Kimi design system is the foundation**: breathing-opacity skeletons (no gradients), plain SVG Spinner vs 小蓝 WorkingIndicator, inline borderless thinking rows, quiet tool call lines, unified motion tokens — all transfer directly.
2. **Streaming caret is non-negotiable**: a 2px filled square (Claude style) blinking at 0.5s step-end. Without it, a paused stream looks finished.
3. **Queued state needs a skeleton line, not a spinner**: 200ms-2s of empty space is worse than a shimmering placeholder line.
4. **Thinking is always collapsed by default**: inline disclosure row with k15 icon, breathing opacity label, elapsed seconds, "Thinking process · Ns" after settle.
5. **Tool calls are quiet borderless lines, not cards**: ~24px row height, 13px UI text, tool-specific content, trailing status dot. Consecutive activity folds into one summary row.
6. **Stop button replaces Send**: square danger-red icon, visible only during streaming, hidden the moment generation ends.
7. **Skeleton = breathing opacity only**: 0.3→0.6 over 1.2s ease-in-out, `--color-subtle` fill, no gradient shimmer, no colored animation.
8. **Motion vocabulary is tokenized**: ease-out (0.16,1,0.3,1) for enter/hover, ease-in-out (0.4,0,0.2,1) for layout, fast 120ms, base 160ms, slow 260ms, spin 700ms.
9. **Reduced motion is one-line CSS**: all durations → ~0.001ms, WorkingIndicator mascot → static fallback.
10. **Empty and error states are minimal**: 48px faint icon + title + hint; never hide error specifics (what, why, recovery action).

---

## Summary

This spec defines loading states, streaming indicators, and motion vocabulary for the Kimi Code Proxy WebSocket client, grounded in the official Kimi Web Design System (1349 lines) and cross-referenced against 12 AI chat products (ChatGPT, Claude, Perplexity, Gemini, Grok, Copilot, v0, Notion AI, Linear, Raycast, Cursor, GitHub Copilot) via the Northbase study (233 instances), the aiverse perceived-performance analysis, the setproduct AI chat interface field guide, NN/g skeleton screen research, and Linear's design refresh principles. The core decisions: breathing-opacity skeletons (no gradients, no shimmer), a 2px filled-square streaming caret, an inline borderless thinking disclosure row with elapsed seconds, quiet borderless tool call lines with three visual-weight tiers (tool line → activity run → sub-agent card), a danger-red stop button that replaces the send button during streaming, and a unified motion token set (ease-out/ease-in-out, 120/160/260/700ms durations). All specifications are directly traceable to their source apps and validated against the Kimi design system's color tokens, radii, spacing scale, motion tokens, and component contract.