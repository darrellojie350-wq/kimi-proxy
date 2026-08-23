# kimi-design-system — Design spec for the Kimi Code CLI WebSocket bridge client

A dark-first, dense, restrained web client for the Kimi Code CLI streaming protocol: multi-session chat, real-time streaming of thinking + tool calls + tool outputs, mobile-app-grade polish ("web APK"). Visual foundation: Kimi Web design system (lacquer-dark, density-first, 0.5px hairlines, scarce blue accent, JetBrains Mono for code/tools), cross-referenced with Linear (dark-first, keyboard-first, near-black canvas), Raycast (command palette, 0.08s transitions, Kbd keycaps), and AI-chat interface conventions (caret streaming, inline thinking, docked composer, 760px reading column).

---

## Key findings

### Kimi Web design system (primary source)
Read the full 1349-line Kimi Web Design System v1.0 doc. Core tokens: `#121212` / `#1f1f1f` / `#292929` dark ladder, `#0d0d0d` for chrome/sidebar, `#1a88ff` accent, `#3fb950`/`#d29922`/`#f85149` statuses. 0.5px hairlines everywhere — no shadows for elevation in dark, the hairline IS the edge. 4px grid. 32px superellipse composer. 760px reading column. Tool calls render as quiet borderless lines (24px, 13px UI + 12px mono), stacked into activity-run folds. Thinking is an inline disclosure row, never a side panel. The chat working indicator uses a breathing opacity animation, never a gradient shimmer.

### Linear (dark-first, keyboard-first, surface ladder)
Linear's DESIGN.md (`voltagent/awesome-design-md`) reveals a near-black canvas `#010102` with a four-step surface ladder (canvas → surface-1 → surface-2 → surface-3 → surface-4). Hierarchy through surface lightness, not shadows. Single lavender accent `#5e6ad2` — used only for brand mark, primary CTA, focus ring. 4px grid, 8px/12px/16px radii, 14px body at 400 weight. Depth is carried by surface + hairline borders, never drop shadows. The Linear redesign blog post confirms: dark-first, light mode is the variant.

### Raycast (command palette, 0.08s transitions, Kbd)
Raycast DESIGN.md (`Khalidabdi1/design-ai`) documents a dark obsidian window `#1C1C1E`, red-orange accent `#FF6363` used only for active row title + caret. Transitions: `0.08s ease` — the fastest in any surveyed system. Result rows: 44px, 16px horizontal padding, 8px radius, hover `#3A3A3C`. Section headers: 11px uppercase 600 weight, muted. Kbd badges: 11px, 500 weight, `#3A3A3C` background, 0.5px border. Fixed 640px window width. No decorative illustrations, no gradients, no primary buttons — every action is keyboard-triggered.

### AI chat interface conventions (streaming, thinking, layout)
Setproduct blog "Designing AI chat interfaces" confirms: streaming text with a blinking caret is the cheapest "alive" signal. The caret must persist during streaming and disappear on settle. Two-pane standard: left rail + center column capped at 720–768px + optional right panel. Anti-pattern: SMS-style round bubbles — they signal "casual texting" and undermine the tool framing. Thefrontkit's AI UX Kit: use a visible stop button during generation, render text immediately but defer code block rendering until the closing fence arrives. AI messages: left-aligned, neutral background, with a model icon instead of user avatar.

### Terminal aesthetics (CLI-to-web translation)
Terminal UI design system patterns: monospace for code/commands, dark background, minimal chrome, command-line syntax patterns. The terminal aesthetic is defined by: monospace typography, near-black background, high information density, minimal decoration, and keyboard-first interaction. Grok Build's CLI aesthetic (xAI, 2026) is a terminal coding agent with subagents — the stream-of-tool-calls pattern is inherently terminal-like.

### Mobbin
Mobbin MCP server returned 404 on all search endpoints (API paths changed). No screen-level data was collected. Web sources substituted.

---

## Design decisions to adopt

### Color tokens (dark-first, from Kimi Web + Linear)

| Token | Dark value | Usage | Source |
|-------|-----------|-------|--------|
| `--color-bg` | `#121212` | Page background | Kimi Web |
| `--color-bg-deep` | `#0d0d0d` | Sidebar, panel headers, chrome framing | Kimi Web (chrome below page in dark) |
| `--color-surface` | `#1f1f1f` | Panel/sidebar/card fill | Kimi Web |
| `--color-surface-raised` | `#292929` | Dialogs, floating cards, inputs | Kimi Web |
| `--color-well` | `#1f1f1f` | Code blocks, tool-output panels | Kimi Web |
| `--color-text` | `rgba(255,255,255,0.84)` | Body text | Kimi Web |
| `--color-text-muted` | `rgba(255,255,255,0.56)` | Secondary text, placeholders | Kimi Web |
| `--color-text-faint` | `rgba(255,255,255,0.30)` | Metadata, timestamps | Kimi Web |
| `--color-line` | `rgba(255,255,255,0.12)` | Dividers, card borders — 0.5px | Kimi Web |
| `--color-subtle` | `rgba(255,255,255,0.05)` | Tertiary separators, hairline | Kimi Web |
| `--color-selected` | `rgba(255,255,255,0.10)` | Neutral selected row fill — never accent-tinted | Kimi Web (matching Linear's "where I am" ≠ accent) |
| `--color-hover` | `rgba(255,255,255,0.05)` | Row hover wash | Kimi Web |
| `--color-accent` | `#1a88ff` | KMBlue — primary action, focus ring, link, streaming indicator | Kimi Web |
| `--color-accent-soft` | `rgba(26,136,255,0.12)` | Focus ring, subtle accent fill | Kimi Web |
| `--color-success` | `#3fb950` | Completed, passed | Kimi Web |
| `--color-warning` | `#d29922` | Pending, warning | Kimi Web |
| `--color-danger` | `#f85149` | Error, failed | Kimi Web |
| `--color-menu-bg` | `rgba(41,41,41,0.95)` | Floating menu, frosted glass | Kimi Web |
| `--color-scrim` | `rgba(0,0,0,0.60)` | Dialog backdrop — 28% neutral | Kimi Web |

**Why:** Linear's surface ladder + Kimi's lacquer-dark palette gives the most restrained, professional canvas. The single KMBlue accent is used sparingly — only for the primary action, focus rings, and the streaming "alive" signal. Selection reads as "where I am" (neutral fill), never accent-tinted. This mirrors Linear's scarce-lavender philosophy.

### Typography (from Kimi Web + JetBrains Mono)

- **UI font:** `--font-ui`: self-hosted "Schibsted Grotesk Variable", falls back to "Inter", system-ui, sans-serif. (Inter is the closest free substitute for Schibsted Grotesk.)
- **Mono font:** `--font-mono`: "JetBrains Mono Variable", "JetBrains Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace. **Used for all tool calls, commands, code, diffs, duration chips, and metadata.**
- **Base size:** 14px at Medium font scale. User-adjustable via 4 steps (small/medium/large/xlarge).
- **UI ramp:** 13px body (--ui-b2), 12px caption (--ui-c1), 22px title cap (--ui-t1).
- **Code size:** 12px at Medium — one step below body text, because JetBrains Mono's x-height reads larger.
- **Weights:** 400 (regular), 500 (medium/emphasis), 600 (section labels). No 650/750.
- **Line heights:** 1.25 for headings (tight), 1.5 for UI (normal), 1.6 for chat prose.

**Why:** Kimi Web's font stack. Mono for all tool/command content matches the terminal aesthetic. The 13px/12px pairing for tool lines (from Kimi doc §04) creates a three-tier hierarchy by color, not size: prose in text, tool lines in muted, thinking/captions in faint.

### Layout (three-column, docked composer)

- **Sidebar:** 264px default (`--p-sidebar-w`), `#0d0d0d` background (one step below page in dark — chrome never brighter than reading surface). Session list, search, pinned sessions.
- **Conversation:** max-width 760px reading column (`--p-content-max`), centered in the remaining space. Never wider — the column makes streaming text scannable.
- **Right panel:** 460px optional preview panel (file preview, diff, sub-agent detail). Snaps open with no animation.
- **Composer dock:** fixed at bottom, 32px superellipse radius, `#1f1f1f` fill, 0.5px hairline, `--z-sticky`. The dock floats over the transcript; content receives bottom padding equal to the dock's live height.
- **Breakpoints:** `--p-bp-sm` 640px (mobile: sidebar collapses to drawer, dialogs become sheets), `--p-bp-md` 980px (narrow/wide).
- **Hairline separators:** 0.5px for every structural edge — card rims, plane seams, header dividers, list rows. No shadow-only elevation in dark.

**Why:** Kimi Web's shell layout. The 760px reading column is the standard for AI chat interfaces (ChatGPT, Claude, Perplexity all use ~720-768px). The #0d0d0d sidebar in dark matches Linear's "chrome below the page" — the sidebar reads as a darker plane, never competing with the conversation.

### Motion (from Kimi Web + Raycast)

| Token | Value | Usage |
|-------|-------|-------|
| `--ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | Enter, hover, expand |
| `--ease-in-out` | `cubic-bezier(0.4, 0, 0.2, 1)` | Panel width, layout |
| `--duration-fast` | 120ms | Press, focus |
| `--duration-base` | 160ms | Hover, show/hide |
| `--duration-slow` | 260ms | Dialog, sheet, fold animation |
| `--duration-spin` | 700ms | Spinner rotation |
| **Streaming caret blink** | 1s period | Blinking cursor at end of streaming text |
| **Thinking breathing** | 1.2s period | Opacity pulse on "Thinking…" label |
| **Skeleton breathing** | 1.5s period | Opacity fade on skeleton blocks |
| **Reduced motion** | `@media (prefers-reduced-motion: reduce)` | All durations → 0.001ms, except hover-intent gates |

**Why:** Kimi Web's motion tokens. The 1s caret blink is the universal streaming convention (setproduct). The 1.2s thinking breathing is slower than the skeleton (1.5s) so the user can distinguish "thinking" from "loading". Reduced motion follows Kimi's global rules.

### Icons & spacing (from Kimi Web)

- **Icon sizes:** 14px (sm), 16px (md), 20px (lg). All glyphs from the Kimi icon set (24x24 source grid, `currentColor`, 1.8px stroke). Status dots use CSS `border-radius: 50%`, not SVG.
- **Spacing grid:** 4px base. Key steps: 4 (space-1), 8 (space-2), 12 (space-3), 16 (space-4), 20 (space-5), 24 (space-6), 32 (space-8).
- **Radii:** 4px (xs), 6px (sm), 8px (md), 12px (lg), 16px (xl), 20px (2xl), 32px superellipse(1.5) (composer), 999px (full/pill).
- **Focus ring:** 3px spread, `--color-accent-soft` + `0 0 0 1px --color-accent` for strong. Applied via `:focus-visible` only — never on mouse click.

---

## Component recipes

### 1. Composer

**Anatomy:** Raised container (`#292929` fill, `--radius-composer` 32px superellipse(1.5), 0.5px `--color-line` hairline). ProseMirror contenteditable input (or textarea during migration). Toolbar: model pill (left), permission pill, mode pills (plan/goal), send button (right). Attachment strip inside above input.

**States:**
- **Rest:** Neutral shadow + hairline. No added glow.
- **Focus:** Crossfade a low-chroma accent edge overlay over `--duration-slow` with `--ease-in-out`. The shadow stays unchanged — no layout shift, no halo.
- **Disabled:** Send button at `opacity: 0.5` while input is empty or upload is in flight.

**Controls:** All 32px full-round geometry, transparent at rest, `--color-hover` wash on hover. Send button is the sole filled control: `--color-text` fill with `--color-bg` glyph (never accent). Disabled: `rgba(255,255,255,0.12)` fill.

**Why:** Kimi Web's composer spec verbatim. The superellipse and neutral fill keep the dock from competing with the message stream.

### 2. Streaming message (assistant reply)

**Anatomy:** Neutral bubble (`#292929` fill, `--radius-lg`, no border, no shadow). Left-aligned. Model icon (16px) leading. Content: streamed Markdown, rendered incrementally — text streams immediately, code blocks deferred until the closing fence. **Blinking caret** (1px vertical bar, `--color-accent`, 1s blink period) at end of the streamed text while streaming — disappears on settle.

**Streaming indicator (does not replace the message):** A separate "Requesting…" / "Working…" phase label shown while the first token hasn't arrived yet. Once the reply starts, the label disappears and the caret takes over.

**States:**
- **Awaiting first token:** WorkingIndicator phase label (mascot or "Requesting…").
- **Streaming:** Message bubble rendering with blinking caret. Stop button visible at the bubble's trailing edge.
- **Settled:** Caret gone. Full rendered Markdown. Timestamp appears.
- **Error:** `--color-danger` border on the bubble, error message inline, retry button.

**Why:** Setproduct + Kimi doc §04. The neutral bubble (not accent-tinted) makes the reading surface calm. The caret is the cheapest "alive" signal. Deferred code blocks prevent FOUC from partial fence rendering.

### 3. Thinking indicator

**Anatomy:** Inline borderless disclosure row in the message stream. 24px height (font-driven: 16px chevron + 4px padding × 2). Leading glyph: k15 bulb (thinking icon, 16px, `--color-text-muted`). Label: "Thinking…" while streaming, "Thinking process · Ns" after settle. **Breathing animation:** `opacity` pulses between 0.56 and 0.84 over 1.2s while streaming — never a gradient shimmer.

**States:**
- **Streaming:** "Thinking…" label breathing, elapsed seconds ticking beside it (incrementing every second).
- **Settled:** "Thinking process · 12s" — final duration, no breathing. Chevron rotates 90° on expand.
- **Collapsed by default.** Expands in place with `grid-rows` animation (`--duration-slow`).
- **Folds itself back** once the stream moves past it, even if the user expanded mid-stream.

**Why:** Kimi doc §04 verbatim. The inline disclosure row keeps the stream scannable — thinking is a caption, not a card. The opacity-only breathing avoids the gradient-shimmer AI tell.

### 4. Tool-call row (quiet activity line)

**Anatomy:** One borderless line per tool call. 24px height (font-driven). No card chrome, no hover wash. Structure: leading tool glyph (16px, `--color-text-faint`) → action label (Run / Read / Edit / Write…, 13px, `--color-text-muted`) → tool-specific content (mono command, file name with button, pattern) → trailing meta (duration chip, status dot).

**Per tool kind:**
- **Bash:** Glyph + "Run" + truncated mono command → duration chip (12px mono, `--color-text-faint`).
- **Read/Edit/Write:** Glyph + action label + file name button (`--color-text`, the one interactive element) → directory + `:line-range` or `+N −M` diff stat → status.
- **Grep:** Glyph + "Search" + mono pattern → match count.
- **Glob/Ls:** Glyph + action label + truncated path list.
- **Todo:** Glyph + "Todo" + active task title → done/total progress bar.

**States:**
- **Default:** One line, truncated. Chevron (16px) at end — not pushed to far edge, hugs the text like the thinking row.
- **Hover:** Text colour change only on the file-name button — no row wash, no card shell.
- **Expanded:** Detail hangs below at the line's own left edge. Mono output panel (`--color-well` fill, hairline, 12-line scroll cap), or syntax-highlighted diff, or clickable match/file list.
- **Running:** Pulsing accent dot. Settled: green ✓ / red ✗.

**Why:** Kimi doc §04 tool-call rendering. The quiet line makes the stream read as an activity log, not a pile of widgets. Three tiers of hierarchy by colour: text in prose, tool lines in muted, thinking/captions in faint.

### 5. Activity run (folded consecutive activity)

**Anatomy:** Consecutive thinking + tool calls fold into ONE smart-summary row. 30px height (8px vertical padding, vs 4px for quiet lines). Borderless faint text row, text-colour hover only, rotating chevron. Summary: "Read 2 files · Ran 5 commands (1 failed) · 26s". Failure clause in `--color-danger`. Total span faint at the tail.

**States:**
- **Streaming through the run:** Row stays expanded, summary turns live (current action + cumulative stats + ticking seconds).
- **Settled:** Row folds itself back. Expanded content shows all items flat in order, each with in-row details intact.
- **Lone step:** Renders standalone — no fold.
- **Glyph:** Current step's icon breathing while running, green ✓ / red ✕ once settled.

**Why:** Kimi doc §04 activity-run fold. The 30px row keeps presence between prose paragraphs. "≥2 steps" rule prevents a single tool call from getting a fold wrapper.

### 6. Session list item

**Anatomy:** Inset rounded pill, 32px height (font-driven: title at `--leading-tight` ≈16px + 8px padding × 2). Structure: status slot (16px fixed width) → title (flex:1, truncate) → time (12px mono, `--color-text-faint`) → hover actions (pin + archive, IconButton sm).

**States:**
- **Default:** Neutral fill on `--color-sidebar-bg`.
- **Hover:** `--color-hover` wash.
- **Active/selected:** `--color-selected` — neutral, no accent, no border, no weight change.
- **Running:** Spinner sm in status slot.
- **Unread:** 7px accent dot in status slot.
- **Attention Badge:** Info (needs answer) / warning (needs approval) / danger (aborted) — replaces the status slot.
- **Hover actions:** Pin + archive IconButtons cross-fade over the time on row hover (absolutely positioned, no height jitter).

**Why:** Kimi doc §08 session row spec. The 32px rhythm matches the sidebar's dense list. The status/accent/attention hierarchy is driven by the SessionDisplayStatus enum.

### 7. Command palette (Cmd+K)

**Anatomy:** Frosted glass panel (`--color-menu-bg`, `--radius-lg`, `--shadow-menu`). Search bar: transparent, 16px input, `--color-accent` caret, 16px leading search icon. Result list: 44px rows (Raycast standard), 8px radius, 16px horizontal padding, 13px label + 12px muted description. Kbd keycaps at trailing edge (11px, `#3A3A3C` background, 0.5px border, `--radius-sm`). Section headers: 11px uppercase 600 weight, `--color-text-faint`.

**States:**
- **Empty:** Last-used commands shown as recent section.
- **Typing:** Results filtered live. No debounce animation — immediate.
- **Active row:** `--color-selected` fill, label at `--color-text-strong`.
- **No results:** Centered faint "No matching commands" message.

**Why:** Raycast's command palette grammar + Kimi's menu surface. 44px rows are the standard for command palettes (Raycast, VS Code, Linear). The 11px uppercase section headers match Raycast's density.

### 8. Loading skeleton

**Anatomy:** A breathing placeholder block composed of: title line (60% width, 14px height), text lines (100% width, 12px height, 3 lines), avatar circle (32px). No gradient — only opacity animation.

**Animation:** `opacity` pulses between 0.30 and 0.60 over 1.5s with `--ease-in-out`. Same breathing applied to all skeleton blocks — no staggered animation, no shimmer sweep.

**Variants:**
- **Message skeleton:** 3 text lines + avatar, full-width within the 760px column.
- **Sidebar skeleton:** 5 session row pills (32px each), spaced 4px apart.
- **Tool-call skeleton:** 2 quiet lines (24px each), 12px mono placeholders.

**Why:** Kimi Web's skeleton spec (no gradient text rule). Animated skeletons reduce perceived duration by 60% (NN/g). The uniform 1.5s breathing is slower than the thinking indicator to avoid confusion.

### 9. Empty state

**Anatomy:** Centered in the available space. 48px faint icon (`--color-text-faint`), 16px title (`--color-text-muted`), 12px hint text (`--color-text-faint`). No border, no card.

**Variants:**
- **No sessions:** "No sessions yet" + "Start a new chat to begin" + New Chat button.
- **No messages in session:** "Start a conversation" + placeholder suggestions.
- **No search results:** "No results for "query"" + "Try a different search term."
- **No tool output:** "No output" (faint, one-line, for empty tool-call expansions).

**Why:** Kimi Web's EmptyState primitive. The 48px icon + two-line text pattern keeps it quiet and clinical — no illustration, no gradient, no "boost your productivity" copy.

### 10. Toast

**Anatomy:** Bottom-right stack. Each toast: status icon (18px, colour-coded by status) + title + description. `#292929` raised surface, `--radius-lg`, `--shadow-menu` (three-layer neutral shadow <4% opacity), 0.5px hairline.

**Variants:**
- **Info:** `--color-accent` icon. "Connected to server" / "Context usage 82%".
- **Success:** `--color-success` icon. "Session archived" / "Model switched".
- **Warning:** `--color-warning` icon. "Rate limit approaching".
- **Error:** `--color-danger` icon. "Connection lost" / "Request failed".
- **Action toast (undo):** Top-center pill. 8s self-timed, hover pauses. Inline `<button>` for undo, "or view in Settings" link.

**States:**
- **Enter:** Slide up + fade, `--duration-slow` `--ease-out`.
- **Exit:** Fade out, `--duration-base`.
- **Hover:** Pauses self-timer.
- **Stack:** Newest at bottom. Up to 3 visible; older ones collapse.

**Why:** Kimi Web's Toast spec. The status colour appears only on the icon — no large colored areas. The action toast is the archiving undo pattern.

---

## Anti-patterns to avoid

1. **Purple gradients, glassmorphism, glowing shadows** — These are "AI tells" (Kimi doc §01). The two exceptions are the TopBar `.frost` variant and floating menu surfaces (`--color-menu-bg` with `--p-menu-backdrop` blur). No other component may use `backdrop-filter`.

2. **SMS-style round bubbles** — "Bubbles signal 'messenger' and undermine the tool framing" (setproduct). Use neutral pills with uniform `--radius-lg`, no directional tails, no accent-tinted user bubbles.

3. **Accent-tinted selection** — "Accent is reserved for the primary action, focus rings, and links" (Kimi doc §06). "Where I am" (sidebar rows, list pickers) uses `--color-selected` — a neutral fill, never accent-tinted.

4. **Emoji as functional icons** — Emoji inside user content (session titles, messages) is fine. Emoji in chrome is forbidden (Kimi doc §02).

5. **Gradient text / shimmer loading** — No gradient text, no shimmer sweep skeleton. Loading animations use opacity only (Kimi doc §07, no-gradient-text rule).

6. **Hardcoded hex colors / font names** — Every color comes from a `--color-*` token. Every font from `--font-ui` / `--font-mono`. No `color: #333` or `font-family: 'Inter'` in component styles.

7. **Font weights 650/750** — Converge on 400/500/600. No stray weights.

8. **Shadows as the sole elevation in dark** — In dark, shadows fade on near-black surfaces. A floating layer's edge IS its hairline (Kimi doc §02). Never ship a shadow-only floating surface.

9. **Separate thinking side panel** — Thinking is an inline disclosure row, never a side panel (Kimi doc §04).

10. **"Boost your productivity"-style marketing copy** — Calm, clinical, never exaggerated. The UI is for developers who are already using the tool.

---

## Top 10 takeaways

1. **Dark-first, never light-first.** The canvas is `#121212`, chrome sits at `#0d0d0d` (below-page in dark). Light mode is the variant, not the default.

2. **Single KMBlue accent.** Used only for: primary action, focus ring, link, streaming caret. Selection is always neutral.

3. **0.5px hairlines everywhere.** Every structural edge is a hairline. No shadows for elevation in dark — the hairline IS the edge.

4. **JetBrains Mono for all code/tools/commands.** 12px at Medium. UI font is Schibsted Grotesk (or Inter) at 13px. No mixing.

5. **760px reading column.** The message stream is capped at 760px. Never wider. The sidebar is 264px, right panel is 460px.

6. **Tool calls are quiet borderless lines.** 24px height, three tiers of hierarchy by colour (text → muted → faint), not size. No card chrome.

7. **Thinking is an inline disclosure row.** 24px borderless line, opacity breathing, elapsed seconds tick, collapsed by default. Never a side panel.

8. **Streaming caret at end of text.** 1px vertical bar, `--color-accent`, 1s blink period. The cheapest "alive" signal. Disappears on settle.

9. **Consecutive activity folds into a summary row.** 30px smart-summary row (30px, not 24px). "Read 2 files · Ran 5 commands · 26s". Only for ≥2 steps.

10. **Keyboard-first, mouse-optional.** Every clickable action has a keyboard equivalent. Cmd+K palette, session navigation, tool-call expansion, and composer commands all keyboard-accessible. Focus ring via `:focus-visible` only.

---

**Summary:** This design spec adapts the Kimi Web design system (1349-line v1.0 spec) to the Kimi Code CLI WebSocket client, cross-referenced with Linear's dark-first surface-ladder philosophy, Raycast's command-palette density and 0.08s transitions, and AI-chat interface conventions for streaming, thinking, and tool-call rendering. The result is a lacquer-dark, density-first web app with a single KMBlue accent, 0.5px hairlines, JetBrains Mono for all code/tools, a 760px reading column, quiet borderless tool-call lines, inline thinking disclosure, and a blinking streaming caret. Every component — composer, streaming message, thinking indicator, tool-call row, activity run, session list item, command palette, loading skeleton, empty state, and toast — is specified with anatomy, states, motion, and the anti-patterns that the design deliberately avoids. Mobbin was unavailable (404 on all endpoints); web sources substituted for cross-app pattern references.