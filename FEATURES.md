# Kimi Proxy — 100 Features & Use Cases

> Premium web app for Kimi Code CLI over WebSocket bridge.
> Dark-first · lacquer · restrained · clinical · power-user.

---

## 1. Core Session Management (10)

1. **Quick Session Start** — Blank session with one click. Use case: jump straight into a new conversation.
2. **Session Resume** — Pick any previous session and continue right where it left off. Use case: pick up a complex debugging session from yesterday.
3. **Session List** — Left sidebar lists all sessions with title, date, message count. Use case: see all your work at a glance.
4. **Session Search** — ⌘+F or click search bar — filter sessions by title or content snippet. Use case: find that conversation about the auth bug.
5. **Session Rename** — Inline rename (double-click title). Use case: "frontend-pr-review" vs "Session 2024-03-15".
6. **Session Pin** — Pin important sessions to the top of the list. Use case: keep ongoing projects easily accessible.
7. **Session Archive** — Archive old sessions (hide from main list, searchable). Use case: clean up without losing history.
8. **Session Delete** — Remove session with confirmation. Use case: discard test/temp chats.
9. **Session Export** — Export session as Markdown / JSON / ZIP. Use case: share a debugging session with a teammate or save to docs.
10. **Session Branching** — Fork a session at any message to try a different approach. Use case: "what if I ask it to refactor differently?"

## 2. Message Streaming & Rendering (12)

11. **Real-time Token Streaming** — Assistant response streams token-by-token over WebSocket into the UI. Use case: see the answer forming in real time, zero waiting.
12. **Auto-scroll on Stream** — Chat scrolls down as new tokens arrive; pause-on-scroll-up. Use case: read the latest output without manual scrolling.
13. **Stop Generation** — Square stop button replaces Send while streaming — kill the current turn. Use case: saw a wrong direction, stop it mid-response.
14. **Markdown Rendering** — Full GitHub-flavored markdown: headings, lists, tables, blockquotes, bold/italic. Use case: read formatted responses naturally.
15. **Code Block Highlighting** — Syntax-highlighted fenced code blocks with language label. Use case: read Python/JS/TS/Rust code clearly.
16. **Copy Code Block** — One-click copy button on every code block. Use case: grab the command or snippet without selecting.
17. **Inline LaTeX** — $...$ and $$...$$ math rendered with KaTeX (CDN). Use case: share formulas, algorithms, or research math.
18. **User Message Editing** — Edit your last message and resend (triggers new response). Use case: fix a typo in the prompt without re-typing everything.
19. **Message Deletion** — Delete individual messages. Use case: remove a sensitive or irrelevant message from the transcript.
20. **Long Message Clamp** — Overlong messages clamp at 10 lines with alpha-fade + "Show more" toggle. Use case: huge paste doesn't dominate the chat.
21. **Streaming Caret** — Blinking caret at the end of the streaming text while tokens arrive. Use case: visual cue that generation is still in progress.
22. **Streaming Latency Badge** — Tiny "· 2.3s" stamp next to completed turns. Use case: see how fast the bridge/Kimi is responding.

## 3. Thinking Experience (8)

23. **Inline Thinking Disclosure** — Collapsed "Thinking· 4.2s" row between messages — expand to see the full reasoning. Use case: peek at the model's reasoning without it dominating the transcript.
24. **Live Thinking Timer** — During streaming, elapsed seconds tick beside the thinking label. Use case: see how long it's been reasoning.
25. **Thinking Bulb Icon** — Kimi k15 bulb icon on the thinking row (—color-accent pulse while active). Use case: immediate visual recognition of thinking state.
26. **Thinking Delta Streaming** — Reasoning tokens arrive as they're generated, not all at once. Use case: watch the reasoning form in real-time.
27. **Auto-collapse on Stream End** — Thinking row auto-folds once the turn completes (if user didn't expand it). Use case: keep the transcript compact by default.
28. **Thinking Skip** — Ability to skip/stop thinking and jump to the final response. Use case: too long a reasoning chain, just want the answer.
29. **Thinking Effort Selector** — Per-session setting: off / quick / deep. Use case: quick questions skip deep reasoning; complex tasks use full depth.
30. **Expanded Thinking View** — Full-width, monospace, scrolled reasoning text when expanded. Use case: thoroughly read the model's chain of thought.

## 4. Tool Call System (12)

31. **Quiet Tool Call Lines** — Each tool call renders as a compact, borderless line (24px). Use case: see what the agent is doing without visual clutter.
32. **Per-Tool Icons** — Bash → terminal, Read → file, Write → pencil, Glob → search, etc. Use case: instantly recognize the tool type.
33. **Tool Call Status Dots** — Pulsing blue (running) / green (done) / red (failed) dot. Use case: at-a-glance status of each tool.
34. **Tool Arguments Preview** — Collapsed inline view of the tool's arguments (command, file path). Use case: see what the agent is about to do.
35. **Tool Output Expand** — Click to expand tool call → show full stdout/stderr. Use case: inspect long command output only when needed.
36. **Activity Run Grouping** — Consecutive thinking + tool calls fold into one "Activity run" summary row. Use case: "Read 3 files, ran 2 commands, searched 1 pattern" → one line.
37. **Turn Fold** — When a turn settles, everything before the final text folds into "Worked 14s" — one bare label. Use case: keep the transcript clean; only expand when you need details.
38. **Tool Error Highlight** — Failed tool calls get a red status dot + error message snippet. Use case: immediately see which tool failed and why.
39. **Tool Call Timing** — Each tool call shows elapsed time next to its status (e.g., "Bash· 0.8s"). Use case: see which tools are slow.
40. **Tool Approve/Deny UI** — In non-yolo mode, a floating approval card appears for each tool call: approve / deny / always-allow. Use case: manually approve file writes or commands.
41. **Tool Output Rendering** — Tool output rendered as: terminal for Bash, file preview for Read/Edit, syntax-highlighted code, search results for Grep, table data. Use case: consume tool output in its natural format.
42. **Tool Approval Remember** — "Always allow" checkbox persists per tool in the session. Use case: trust Read/Glob, but confirm Write/Edit.

## 5. Tool Output Rendering (8)

43. **Terminal Output** — Bash output rendered in a monospace well with dark background, scrollable. Use case: read command output as it would appear in a terminal.
44. **File Diff View** — Edit/Write tool outputs show a diff (+/- lines with green/red gutter). Use case: see exactly what changed in the file.
45. **File Preview** — Read tool output shows the file content with syntax highlighting + line numbers. Use case: review code the agent read.
46. **Search Results Table** — Grep output shows results in a table: file path, line number, matched line. Use case: navigate search results efficiently.
47. **Glob Results List** — File listing as a clickable list of paths. Use case: see what files matched the pattern.
48. **Web Content Preview** — FetchURL/WebSearch results show page title, URL, and content snippet. Use case: review web sources without leaving the chat.
49. **Image Output** — Tool-generated images (charts, screenshots) rendered inline. Use case: see the rendered image the agent created.
50. **Tool Output Collapse** — Long outputs default-collapsed with "Show N lines" label. Use case: don't let a 2000-line command output dominate the transcript.

## 6. Connection & Bridge (8)

51. **WebSocket Connection** — Persistent connection to the kimi-proxy bridge. Use case: real-time bidirectional communication.
52. **Auto-Reconnect** — Exponential backoff on disconnect, reconnects automatically. Use case: survive network blips and VPS restarts.
53. **Connection Status Indicator** — Green dot (connected) / yellow (connecting) / red (disconnected) in the header. Use case: at-a-glance bridge status.
54. **Bridge URL Config** — User-configurable WebSocket URL in Settings. Use case: switch between localhost, prod VPS, or staging.
55. **Heartbeat / Ping** — 15s ping to keep the connection alive. Use case: prevent timeout from reverse proxies or load balancers.
56. **Multi-Provider Fallback** — Bridge auto-fails over providers (chatanywhere → local-8789 → local-8765). Use case: if one provider is down, the next one answers.
57. **Connection Security** — Detect mixed-content (HTTPS page → ws:// bridge) and show a helpful error. Use case: protect users from browser blocks.
58. **Session Persistence** — Sessions survive page reloads (localStorage/IndexedDB). Use case: refresh the page and your sessions are still there.

## 7. Permission & Safety (6)

59. **YOLO Mode** — Auto-approve regular tool calls. Use case: quick, fluid interactions for trusted tasks.
60. **Auto Mode** — Fully autonomous, no questions asked. Use case: batch processing, unattended sessions.
61. **Plan Mode** — Start in plan mode: agent plans first, then executes. Use case: complex tasks that need upfront design.
62. **Permission Indicator** — Badge in the composer toolbar showing current mode: YOLO / Auto / Plan / Ask. Use case: always know what level of autonomy is active.
63. **Tool Approval Card** — Floating card for manual tool approval: shows tool name, args, approve/deny buttons. Use case: review each tool call before allowing it.
64. **Session-level Permission Config** — Per-session yolo/plan/auto override. Use case: sensitive project gets Ask mode, scratchpad gets YOLO.

## 8. UI/UX & Navigation (12)

65. **Dark-First Theme** — Lacquer-black (#121212) canvas, charcoal chrome (#0d0d0d), dark wells (#1f1f1f). Use case: reduce eye strain, look premium.
66. **Light Theme** — Clean light mode (#ffffff) with subtle gray hierarchy. Use case: daytime use or personal preference.
67. **264px Session Sidebar** — Session list, pinned, search, new-session button. Use case: navigate all sessions quickly.
68. **Responsive Layout** — 3 breakpoints (640 / 980 / 1200px): mobile → drawer sidebar, tablet → condensed, desktop → full 5-track grid. Use case: works on phone, tablet, and wide monitor.
69. **Command Palette** — ⌘+K or ⌘+P: search sessions, switch modes, run commands, open settings. Use case: keyboard-driven navigation, never touch the mouse.
70. **Keyboard Shortcuts** — ⌘N new session, ⌘W close, ⌘+↑/↓ prev/next session, ⌘K palette, ⌘, settings, Escape close. Use case: power-user speed.
71. **Mobile Drawer** — Sidebar becomes a slide-in drawer on mobile, backdrop overlay. Use case: full chat width on small screens.
72. **Loading Skeleton** — Breathing-opacity skeleton rows while the bridge connects or first message loads. Use case: communicate loading without a spinner.
73. **Empty States** — Welcome screen when no sessions exist: "Start a new session to begin". Use case: guide, don't show a blank page.
74. **Toast Notifications** — Bottom-right toasts for connection events, errors, copy success. Use case: non-blocking feedback.
75. **Keyboard Shortcuts Modal** — ⌘+/ or "?" button → full shortcuts reference. Use case: discoverability for power features.
76. **Hairline Visual Language** — 0.5px borders, no heavy shadows, elevation via hairlines + subtle z-elevation. Use case: clean, clinical, premium look.

## 9. Power User Features (8)

77. **Composer History** — ↑/↓ to cycle through recent prompts. Use case: re-run a similar command without retyping.
78. **Multi-Line Composer** — Shift+Enter for newlines, auto-grow up to 200px. Use case: compose long, detailed prompts.
79. **Composer Attachments** — Drag-drop or paste files into the composer → send as context. Use case: attach a log file or screenshot for the agent to analyze.
80. **Composer Context Ring** — Circular progress indicator around the Send button showing context usage. Use case: know when you're approaching the context limit.
81. **Model Picker** — Dropdown in composer toolbar: switch model per session. Use case: use a cheap model for quick questions, a powerful one for complex work.
82. **Thinking Effort Picker** — Linked model + thinking-effort dropdown (cascading). Use case: pair each model with its appropriate thinking depth.
83. **Session Workspace** — Per-session working directory, set from the bridge or config. Use case: different projects stay in their own directories.
84. **Message Search** — Search within the current session's messages (⌘+F). Use case: find that specific line the agent said about the database connection.

## 10. Settings & Configuration (8)

85. **Bridge URL** — Text input to set the WebSocket endpoint. Use case: point at localhost, VPS, or staging.
86. **Theme Selector** — Dark / Light / System (follow OS preference). Use case: personal preference + automatic.
87. **Font Size** — Slider or stepper: small / medium / large / x-large. Use case: accessibility + personal preference.
88. **Default Mode** — Global default: YOLO / Auto / Plan / Ask. Use case: set your preferred interaction style.
89. **Default Model** — Default model for new sessions. Use case: always start with your preferred model.
90. **Keyboard Shortcuts Remap** — Customize keybindings. Use case: muscle memory from other tools.
91. **Session Export Format** — Choose export format (Markdown / JSON / ZIP). Use case: different export needs for different audiences.
92. **Clear All Sessions** — Bulk delete all sessions with a confirmation dialog. Use case: reset for a demo or fresh start.

## 11. Premium Polish (10)

93. **PWA Support** — Install as a standalone app (manifest.json, service worker, offline). Use case: "feels like a real app" — dock icon, fullscreen, no browser chrome.
94. **Splash Screen** — Branded splash on load while the bridge connects. Use case: polished first impression, sets the tone.
95. **Smooth Transitions** — Page transitions, panel slides, message appear animations (120-260ms, ease-out). Use case: fluid, responsive feel.
96. **Reduced Motion** — Respects prefers-reduced-motion: all durations drop to ~0.001ms. Use case: vestibular disorder accessibility.
97. **Focus Ring** — Unified blue focus ring (0 0 0 3px accent-soft) on all interactive elements. Use case: keyboard accessibility + visual consistency.
98. **Touch Targets ≥ 44px** — All interactive elements on mobile meet 44px minimum. Use case: thumb-friendly touch targets.
99. **Error Recovery** — Graceful error states: reconnection banner, inline error cards, session recovery. Use case: never lose work due to a transient error.
100. **Keyboard Shortcut Showcase** — Tooltips on buttons show their keyboard shortcut (e.g., "New session (⌘N)"). Use case: discover shortcuts organically.

## 12. Deployment & Infrastructure (5)

101. **GitHub Pages Deploy** — Deploy to GitHub Pages via CI/CD for a live link. Use case: share the app URL, test on any device.
102. **PWA Install Prompt** — Browser prompts "Install Kimi Proxy?" on first visit (after criteria met). Use case: one tap to install as a standalone app.
103. **APK Build** — Build Android APK via Capacitor / TWA for native install. Use case: distribute as a real Android app (for download).
104. **Service Worker Cache** — Cache assets + session data for offline viewing. Use case: browse past sessions even without internet.
105. **Version Info** — Version badge in settings + update check. Use case: know which version is running, prompt for updates.

---

> 105 features across 12 categories. Every feature traces back to a real user need: fluid streaming, premium dark design, power-user keyboard-first workflows, and the full Kimi CLI experience (thinking, tools, permissions, sessions) in a browser.