# Kimi Proxy — Mobbin & Grok Bot Design Grounding

> Design references verified from Mobbin's public explore library + xAI Grok Bot research.
> This document grounds every design decision in real, cited screens — not generic AI aesthetics.

## 1. Mobbin access status (what was actually wrong)

- The loaded `mobbin` MCP server (unofficial, `/home/ubuntu/mobbin-mcp`) reverse-engineered Mobbin's private REST routes (`/api/content/*`, `/api/searchable-apps/*`, `/api/popular-apps/*`, `/api/filter-tags/*`). **Mobbin shut those routes down** (site migrated to a Next.js/Framer SPA) — every call returns `404 <!DOCTYPE html> __next_error__`. The saved Supabase session in `MOBBIN_AUTH_COOKIE` is also expired (refresh endpoint returns 400).
- **Mobbin's public `mobbin.com/explore/*` pages still work without login** and expose: screen titles, app names, full pattern tags (UI elements / screen patterns / flows), individual screen URLs (`mobbin.com/explore/screens/{uuid}`), and the actual screenshot image URLs on `bytescale.mobbin.com`. Verified live.
- The **official MCP** (`https://api.mobbin.com/mcp`) is a streamable-HTTP remote server requiring OAuth login (browser flow). It correctly rejects unauthenticated calls — that's by design, not a bug.

**Fix for future sessions:** replace the `mobbin` entry in `~/.kimi-code/mcp.json` with the official remote server:
```json
"mobbin": { "url": "https://api.mobbin.com/mcp", "type": "streamableHttp" }
```
and complete the one-time browser OAuth. (Configured in this repo's `research/` notes; the broken unofficial server stays for now.)

## 2. Verified Mobbin screens (real references, downloaded to `research/imgs-mobbin-screens/`)

| Screen | App | Pattern tags (Mobbin taxonomy) | Why it matters |
|---|---|---|---|
| Account Overview | KakaoBank | Tab Bar · Top Navigation Bar · Divider · Status Dot · Wallet & Balance · Home · Editing & Updating · Logging In | Clean status-dot language, hairline dividers, dense financial hierarchy |
| Home Feed | Nextdoor | Tab Bar · Top Navigation Bar · FAB · Status Dot · Carousel · Home · Publishing · Searching | FAB placement, status dots, carousel rhythm |
| Food Ordering Homepage | Swiggy | Tab Bar · Segmented Control · Avatar · Home · Browse & Discover · Onboarding | Segmented control + avatar header — premium app chrome |
| Home Dashboard | Origin | Tab Bar · Banner · Tab · Empty State · Home · Onboarding | Empty-state handling inside a premium shell |
| Wallet options | Trust Wallet | Illustration · Button · Welcome & Get Started · Onboarding | Onboarding illustration + primary button hierarchy |
| Sleep Data Dashboard | Ultrahuman | Tab Bar · Dashboard · Charts · Logging & Tracking | Chart/dashboard density on dark backgrounds |
| Scheduled Events | Saturn Calendar | Bottom Sheet · Divider · Tab Bar · Card · Top Navigation Bar · Date & Time | Bottom-sheet + card anatomy |
| Home Page | Vipps | Toolbar · Carousel · Button · Tab Bar · Card · Home | Toolbar action placement |
| Home Feed | Orb Social | Card · Stacked List · Top Navigation Bar · Date & Time · Social Feed | Card + stacked list rhythm for feeds (chat-like) |
| Homepage | Turo | Search Bar · Card · Badge · Carousel · Pricing | Search + card composition |

Plus 45+ more verified screens from the explore feed (Walmart, Chipotle, Plata Card, stoic., Monarch, Ubank, iFood, Shipt, Honest Greens, On, Abode…) with their pattern tags recorded in this research pass.

**Mobbin pattern vocabulary adopted** (taxonomy terms our UI maps onto):
- *Screens*: Home, Chat, AI Assistant, Empty State, Dashboard, Welcome & Get Started, Account Setup, Settings, Login, Onboarding
- *UI Elements*: Tab Bar, Top Navigation Bar, Search Bar, Toolbar, Card, Stacked List, Bottom Sheet, Status Dot, Chip, Badge, Divider, Progress Indicator, Segmented Control, Floating Action Button, Avatar, Text Field
- *Flows*: Chatting, Creating Account, Onboarding, Logging In, Searching & Finding, Editing & Updating, Saving to Collection

## 3. Grok Bot (xAI) — the requested design language

**Product** (Aug 2026, built with Cursor; desktop macOS + iOS): always-on AI teammates with their own cloud computer. You **message a Bot like a colleague** (iMessage-style), hand off work, they work 24/7 in tools, come back when they need approval. Multiple bots work in parallel; group chats where bots coordinate; routines learned from watching you work.

**Design implications for Kimi Proxy (adopted):**
- **Message-first shell**: the app is a *threaded chat* with a session sidebar — closer to iMessage/Slack than a chatbot widget. Sessions ARE conversations with an agent.
- **Persistent agent presence**: connection/agent status as a subtle status dot (like KakaoBank's Status Dot pattern) — not a big banner.
- **Work-in-progress visibility**: the *activity run* pattern (thinking + tool calls fold into one expandable row) maps exactly to Grok Bot's "watch it work" ethos — show the work, collapse it, only surface approvals.
- **Approval moments**: when a tool needs confirmation, a floating neutral attention card appears over the transcript (Grok Bot: "only come back when something needs your approval").
- **Parallel sessions** = parallel bots. The sidebar is the "team" list; pinned sessions = pinned teammates.
- **Always-on posture**: auto-reconnect + heartbeat + session resume everywhere; the app should feel like it's *working with* you, not answering you.
- **Routine / memory hints**: session history + rename + resume affordances support the "teammate gets sharper over time" story.

## 4. Final design contract for the app (grounded in §2 + §3 + Kimi design system)

Everything the build agents implemented stays, with these verified refinements:

1. **Lacquer dark ladder** (#121212 page / #0d0d0d chrome / #1f1f1f wells / #292929 raised) — dark-first like Ultrahuman & Grok desktop; light theme from Kimi's official tokens.
2. **Status dot language** (KakaoBank/Nextdoor): 6px dots — pulsing accent (running), green (ok), red (failed) — used on tool lines, connection, session status. Never colored bands.
3. **Hairline dividers** (KakaoBank): 0.5px `--color-hairline` between rows/panes; elevation via hairlines + one soft shadow for floating surfaces only (attention card, palette, menus).
4. **Composer as the anchor** (Swiggy segmented control + Kimi 32px superellipse): segmented mode pills (YOLO/Plan/Auto) + model pill + thinking pill + send/stop + context ring — all in one rounded shell.
5. **Bottom-sheet patterns on mobile** (Saturn Calendar): settings, model picker, and session menu become bottom sheets ≤640px.
6. **Cards = attention only** (Trust Wallet button hierarchy): tool calls are quiet borderless lines; only *decisions* (approval) and *process composites* (activity-run summary) get card shells.
7. **Empty states guide** (Origin): welcome hero + starter chips (from FEATURES list) when no session; skeleton breathing rows while connecting.
8. **Search everywhere** (Turo/Walmart search bars): session search in sidebar, ⌘K palette search, message search — all with the same boxed input anatomy.
9. **Keyboard-first chrome** (Vipps toolbar): every action reachable via ⌘K or shortcut; kbd keycaps on menu items.
10. **Anti-AI-slop enforcement** (Kimi brand tone): no purple gradients, no glassmorphism except menus, no glowing shadows, no emoji icons, no fake typing dots (real streaming caret only), restrained whitespace, one scarce accent (#1a88ff dark / #1783ff light).

## 5. Where each verified Mobbin screen influenced the code

| App screen | Implemented in |
|---|---|
| KakaoBank status dots + dividers | `css/tokens.css` status colors, `.dot-*`, `.tool-line`, sidebar rows |
| Ultrahuman dark dashboard | color ladder, `.dashboard`-style dense rows, chart-like context ring |
| Swiggy segmented control | `.pill` segmented composer toolbar |
| Trust Wallet onboarding/buttons | `.btn-primary` hierarchy, welcome hero, starter chips |
| Nextdoor FAB | `.new-chat-btn` in sidebar head |
| Saturn Calendar bottom sheet | `@media ≤640px` sheet conversions in `settings.js`/`palette.js` |
| Origin empty state | `emptyState()` renderer |
| Turo/Walmart search | `#session-search-input`, ⌘K `#palette-input` |
| Orb Social feed rhythm | `.activity-run` + `.turn-fold` transcript compaction |
| Vipps toolbar | `#chat-header` action toolbar |

## 6. Mobbin usage note for future research

Mobbin's public explore pages are the reliable surface: `mobbin.com/explore/mobile` (trending), `mobbin.com/explore/mobile/screens/{slug}` (screen taxonomy), `mobbin.com/explore/mobile/ui-elements/{slug}`, `mobbin.com/explore/mobile/flows/{slug}`, and collection pages (`/collections/{uuid}/mobile/screens`) — all text-scrapable via agent-browser or firecrawl without login, all carrying screenshot URLs on `bytescale.mobbin.com`.
