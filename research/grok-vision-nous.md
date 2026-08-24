# Grok App Screens — Vision Analysis (Nous)


## grok-chat-detail  (patterns: Empty State,Home,Chat Bot,Chat Detail)

Got it, let's break this down step by step, super granular, like a real iOS design spec for Grok's home screen, premium focus.

First, let's start with the overall layout structure top to bottom, with exact measurements (using iOS standard points, relative to 393px wide iPhone 15 Pro viewport, which is the target here since it's an iPhone screenshot):
1.  **Status Bar (Topmost, 48pt height total, safe area inset top 47pt/16px on 15 Pro)**:
    - Left: Time "9.41", 17pt SF Pro Text/Regular weight, black (#000000)
    - Right: Signal icon (17x17pt, light gray #8E8E93), WiFi icon (17x17pt, same gray), Battery icon (26x12pt, green fill #34C759, black border)
2.  **Top Navigation Header (48pt height, below status bar, padded 16pt left/right, 12pt top/bottom within header)**
    - Left: Hamburger menu (3 horizontal lines, 24x24pt, dark gray #1C1C1E, 2pt stroke weight, 4pt line spacing)
    - Center: Model selector "Grok 3 >", left aligned with orange dot (8pt circle #FF6B00, 4pt gap to text), text 17pt SF Pro Display/Semibold, black, right chevron 12x12pt, 4pt gap from text
    - Right: Edit/compose icon (pencil, 22x22pt, dark gray #1C1C1E, 2pt stroke weight)
3.  **Mode Selector Card Grid (96pt total height, 16pt gap from header, horizontal scroll, each card 90x80pt, 12pt gap between cards, left padded 16pt, right padded 16pt)**
    - Each card: Rounded square, 16pt border-radius, white fill (#FFFFFF), 1pt border #E5E5EA (subtle, only visible on scroll when shadow doesn't touch edge), 8pt internal padding, center aligned content
    - 4 visible cards, labels below each:
      1.  Assistant: Smiley face icon (44x44pt, 2pt stroke, dark gray #1C1C1E), label 12pt SF Pro Text/Medium, centered 2pt below icon
      2.  Storyteller: Open book icon (44x44pt, 2pt stroke, same gray), label same as above
      3.  Kids Story Time: 2 stick figures (adult + child, 44x44pt, 2pt stroke, same gray), "KIDS" superscript 8pt SF Pro Text/Semibold #007AFF, 1pt above main label, main label same 12pt medium, line breaks at "Story / Time"
      4.  Kids Trivia Game: Trophy icon (44x44pt, 2pt stroke, same gray), "KIDS" superscript same as above, main label line breaks "Trivia / Game"
    - *Overlay prompt above grid, 36pt height, 32pt below top header, centered*: Sound wave icon (16x16pt, light gray #8E8E93, 3 bars), text "Tap a mode to activate Voice" 16pt SF Pro Text/Regular, light gray, 8pt gap between icon and text
4.  **Mid Spacer (flex fill, empty white #FFFFFF background, no content)
5.  **Input Bar (Sticky bottom, 108pt height from home indicator top, 16pt padding left/right, 16pt gap from input field bottom to home indicator (4pt height home indicator bar))
    - Input field: Rounded rectangle, 28pt border-radius, fill #F2F2F7 (light system gray 6), 16pt padding left/right, 12pt top/bottom internal padding
    - Placeholder: "Ask Anything" 17pt SF Pro Text/Regular, medium gray #8E8E93
    - Input chips (left side, 8pt gap from placeholder):
      1.  Attachment chip: R

---

## grok-paywall  (patterns: Subscription & Paywall)

Got it, let's break this down step by step, super specific for a design spec, like the user asked. First, start with the top to bottom layout structure with exact measurements, right?
First, the screen is an iOS app (you can tell by the status bar, home indicator) full viewport, dark mode, all the measurements are relative to 44pt safe areas? Wait no, let's get exact top to bottom, with safe areas first, because iOS status bar is dynamic, but let's note the status bar first, then each section with height, spacing.
Wait first, (1) Layout structure top-to-bottom with measurements. Let's start with the full viewport, it's a dark themed paywall screen, no navigation bar except the skip button at the top right.
First, top status bar: 9.41 (time) on left, signal, wifi, battery icons on right. The status bar height for iOS is 54pt on dynamic island, 47pt otherwise? Wait no, but in the screenshot, the status bar is at the very top, 9.41 is left, the status icons right, skip button is *below* the status bar, right? Wait no, look at the screenshot: 9.41 is at the very top, then below that, right side is Skip button, then the title "SuperGrok" is below that. Wait no, let's count the spacing:
Wait first, the full screen: all elements are centered horizontally, full width content, 20pt horizontal padding (standard iOS content padding, right? Let's confirm: all the text is aligned, so left/right padding is 20pt, that's standard.
Let's structure (1) layout top to bottom with measurements (in pt, iOS standard, since it's an iOS app):
1. Status Bar Area: 47pt height (standard iPhone status bar without dynamic island, if dynamic island it's 54pt, we can note that). Content within status bar: 9.41 (SF Pro Display time, 17pt semibold) left-aligned, 24pt from left edge. Status icons (signal, wifi, battery) right-aligned, 24pt from right edge.
2. Top Action Area: 8pt spacing below status bar, height of Skip button is 30pt, width is 64pt, right-aligned, 20pt from right edge. Skip button padding: 12pt horizontal, 6pt vertical.
3. Hero Title Section: 56pt spacing below Skip button. Hero text "SuperGrok": SF Pro Display, 56pt heavy weight, centered, full width text. 12pt spacing below hero title.
4. Subhead Section: "Unlock advanced capabilities" subhead: SF Pro Display, 21pt medium weight, centered, 12pt horizontal padding (wait no, full width, but text is centered, 20pt horizontal padding so it wraps if needed, which it doesn't here).
5. Features List Section: 32pt spacing below subhead. Features list items are left-aligned? Wait no, wait the icons are on left, text next to them, centered? Wait no, look at the screenshot: the star icons are left-aligned, then the text is left-aligned, but the whole block is centered? Wait no, let's check: the text "Guaranteed access to Grok 3" is aligned with the star icons, and the left edge of the text is 20pt from screen left, same as the skip button right edge? No, wait no, the content is padded 20pt left and right, yes. So features

---

## grok-welcome  (patterns: Welcome & Get Started)

Got it, let's break this down step by step, starting with what I see in the screenshot, making sure every detail is captured as a design spec.
First, layout structure top to bottom. Let's start with the top status bar first, then the screen elements, then the bottom attribution.
First, the device context is iOS, so status bar is at the very top. Status bar height: iOS standard is 44pt for the dynamic island area, right? Wait, the time is 9.41 at top left, signal, wifi, battery at top right. The time is 9.41, sans-serif, white, ~15pt weight? Wait no, iOS status bar text is usually SF Pro, regular, 15pt? Wait no, wait the time here is 9.41, it's white, top left, within the status bar. Then the Skip button is at top right, below the status bar? Wait no, look at the position: the Skip button is in the upper right of the screen, below the status bar. Let's map the vertical positions properly.
Wait full screen layout:
1. **Top Status Bar (iOS System)**: Height = 54pt (includes safe area inset for dynamic island / notch). Left aligned: time "9.41", white, SF Pro Display, 15pt, medium weight. Right aligned (from left to right): cellular signal icon, WiFi icon, battery icon, all white, system standard iOS status bar icon size, ~20pt. This is system UI, not part of the app's custom design, but included for context.
2. **App Header (below status bar)**: Height ~52pt. Right-aligned, pill-shaped Skip button: background is dark gray (#2A2A2A, 16% opacity black overlay on the background), rounded corners 20pt. Text "Skip" is white, SF Pro, 16pt, medium weight, 12pt horizontal padding inside the pill, 8pt vertical padding? Wait no, the pill height is ~32pt? Wait no, looking at the skip button: it's a small pill, top right, so y position is ~80pt from top, x is right aligned with 16pt margin from right edge.
3. **Brand Section (below header)**: Total height from top of Grok text to bottom of tagline is ~220pt.
   - "Grok" logo text: Centered horizontally, y position ~180pt from top. Font is custom display sans-serif, all caps? No, it's uppercase, very bold, white, 96pt, heavy weight (900). No letter spacing, tight kerning.
   - Tagline "Understand the universe_": Centered horizontally, y position ~280pt from top, below the logo with 32pt vertical spacing between logo bottom and tagline top. Text is light gray (#A0A0A0), SF Pro Display, 20pt, regular weight, 0pt letter spacing. Note the trailing underscore at the end of the tagline.
4. **Decorative Element (below tagline)**: A curved horizon line effect, looks like a retro synthwave grid that curves up to meet the center of the screen, creating a horizon illusion. It's a subtle grid with fine white lines (1px, 10% opacity white) on a black background, fading in opacity as it goes up the curve. The lowest point of the curve is at ~360pt from top, centered horizontally, width spans 100% of the screen. The grid is very subtle, adds depth without being distracting.
5. **Authentication Buttons Section (below decorative

---

## grok-share  (patterns: Share,Media Editor)

Got it, let's break this down step by step, super precise, like a real iOS design spec. First, start with the overall context: this is an iOS app screenshot, first the top status bar, then the app header, the mode selector, then the modal sheet for sharing audio, then the bottom app footer.

First part: Layout structure top-to-bottom, with measurements. Wait, first note this is an iPhone screen, standard safe areas, right? Let's start from the very top:

1.  **System Status Bar (iOS native, top safe area, 48pt height standard)**
    - Left: Time "9.41" (SF Pro Display, 17pt, medium weight, black text on light gray background)
    - Right: 3 status icons: cellular signal (filled, 4 bars), Wi-Fi filled, battery (80%+ filled, black) all SF icons, 14pt, black
    - Background: Light off-white/very light gray, #F2F2F7 (iOS system background 6, light mode)
    - Safe area inset top: ~47pt, standard for iOS 15+ iPhones.

2.  **App Top Navigation Bar (below status bar, 44pt height, full width)**
    - Left: Hamburger menu icon (22pt square icon, 2pt stroke weight, rounded 6pt ends, black, #000000)
    - Center: Voice mode selector pill: [orange dot (6pt diameter, solid #FF453A)] + "Ara" text (SF Pro Text, 16pt semibold, black #000000) + "voice" chip (pill shape, 24pt height, 34pt width, light gray fill #E5E5EA, text 13pt medium #6E6E73, 8pt corner radius) + right chevron (> 12pt, black, 10pt padding to right edge of pill)
    - Right: Edit icon (pen/square, 22pt, 2pt stroke, black, 10pt padding to right edge of nav bar)
    - Background: Same #F2F2F7 as status bar, no separator line (matches iOS translucent nav bar style, or flat light background here)

3.  **Mode Selector Carousel (below nav bar, 120pt height, full width, horizontal scroll)**
    - Background: Same #F2F2F7
    - 5 visible mode chips, each 84pt width (square, 84x84pt), 12pt horizontal spacing between them, 20pt top padding from nav bar bottom, 28pt bottom padding before modal
    - Each chip has: 60x60pt rounded square card, 24pt corner radius, white fill #FFFFFF, 1pt subtle border #E5E5EA, inner content 12pt padding
      - Chip 1 (selected): Icon is smiley face (24pt, black #000000, thin stroke 1.5pt, rounded 4pt), label "Assistant" below chip (SF Pro Text 12pt medium, black #000000, 4pt spacing below chip)
      - Chip 2: Icon is open book (24pt, dark gray #3A3A3C), label "Storyteller"
      - Chip3: Icon is adult + child figures (24pt, dark gray #3A3A3C), label "Kids Story Time"
      - Chip4: Icon is trophy (24pt, dark gray #3A3A3C), label "Kids Trivia Game"
      - Chip5 (partial): Label "Mo" cut off, right side clipped

4.  **Share Audio Modal Sheet (covers bottom ~75% of screen, full width, rounded top corners)**
    - This is a bottom sheet, standard iOS style, rounded top corners 20pt radius, top edge has 34pt drag handle (the light gray bar at the very bottom of the full screenshot? Wait no, wait the drag handle for the modal is the small horizontal bar at the bottom center of

---

## grok-pricing  (patterns: Subscription & Paywall,Pricing)

Got it, let's break this down step by step, super detailed like a real iOS design spec, first I need to get every element right, top to bottom, no assumptions, only what's visible.

First, 1. Layout Structure top to bottom, with measurements. Wait, first note the overall screen is a full-screen modal/upsell sheet, right? It's a vertical stack, dark background, standard iOS safe areas. Let's start from the very top:

First, status bar area (iOS system, 44pt top safe area? Wait no, first the screen top is system status bar: 9:41 time on left, system icons (signal, wifi, battery) on right, that's standard iOS 17+ status bar, occupies ~44pt top safe area, no custom UI here except the status bar content.

Then below that, top action area: right-aligned Skip button, that's in the top safe area, right? Let's get dimensions: Skip is a pill button, 90pt wide, 36pt height, 12pt horizontal padding inside, 10pt from right screen edge, 12pt below top status bar (so y position ~44 + 12 = 56pt from top of screen). Font is SF Pro Rounded? Wait no, the text is white, 17pt, semibold? Wait no, look: Skip is gray text? Wait no, the Skip button has a dark gray background, white text, right? Wait the background is dark, so the Skip button is a translucent dark gray pill, maybe 12% opacity black background, 1px light gray border? Wait let's get that right.

Then the main header section: centered, vertically stacked. First "SuperGrok" title: that's 42pt? Wait no, SF Pro Display Bold? Wait no, iOS uses SF Pro, the large title is 34pt? Wait no, no, this is a large prominent title, let's see: SuperGrok is 38pt, SF Pro Bold, white (#FFFFFF), centered, 24pt below the Skip button (so y = 56 +24 = 80pt from top). Then below that, the subhead: "Try Free for 3 Days" — 24pt, SF Pro Regular, white, 8pt gap between title and subhead, and "Free" is orange accent, weight is Semibold there, right? Wait yes, "Free" is highlighted orange, rest of the text is white. The entire header section is 24pt top padding, 16pt bottom padding before the features card.

Next, the Features card: that's a rounded rectangle, 20pt corner radius, fills 90% of screen width, centered, so left/right margins 5% each (20pt on 414pt wide screen). The card background is translucent dark gray, like 15% opacity black, 1px 20% white border (subtle, blurred background? Wait no, it's a frosted glass? Wait no, the background is solid dark gray with low opacity, no blur? Wait the background behind it is the dark abstract image, so the card has a slight blur? Wait no, the screenshot shows the card is a solid dark gray, rounded, with icons on the left, text on right, 5 feature rows, each with 20pt vertical padding? Wait each feature row: left icon container, 40x40pt, 12pt border radius, dark gray (20% opacity black) background, white icon, 16pt gap between icon and text. Then the text: main feature title is 17pt SF Pro Semibold, white, subtext is 15pt SF Pro Regular, 60% white (light gray), 6pt gap between title and sub

---

## grok-chat-bot  (patterns: Chat Bot,Chat Detail)

Got it, let's break this down step by step, first confirming this is the Grok iOS app, right? First I need to go top to bottom, get exact measurements, colors, every component, spacing, typography, icons, motion, premium cues.

First, start with the overall layout structure top to bottom, with measurements. Let's start with the status bar first: that's the topmost system bar, height is 47px standard iOS dynamic island bar, right? Time is 9.41 at left, status icons (signal, wifi, battery) at right, that's standard.

Then the header bar: below status bar, height 44px? Wait no, let's calculate: header has left hamburger menu, center Grok 3 title, right edit icon. Let's get exact vertical positions:
1. Status Bar: 0-47px (top of screen to bottom of system status area, standard iOS with dynamic island/notch height ~47px). Background is the app's primary background, light mode here.
2. App Header Bar: 47px to 91px (height 44px, centered vertically in this band). Elements: left is 24px from left edge, 24x24px hamburger (3 lines, 2px stroke weight). Center is Grok 3: the orange dot is 6px diameter, then "Grok 3" text 17px semibold, then > chevron 12px, so total center group is ~120px wide, perfectly centered. Right edge: edit icon 20x20px, 24px from right edge, same 2px stroke weight as hamburger, rounded square? Wait no, it's a pencil in a square, 2px stroke, square is 20x20, 4px corner radius? Wait no, look at the screenshot, the edit icon is a square with rounded corners, 2px stroke, pencil inside.
3. Mode Selector Row: 91px to 214px (height 123px total). This row has 5 mode cards, first 4 visible, 5th cut off at right. Let's get card dimensions: each card is 76px wide, 76px tall, 16px corner radius, background is #F5F5F7 (light gray, 1px border? No, wait they are flat, no border, background is slightly lighter than the main background? Wait main background is #FAFAFA, right? The cards are #FFFFFF? Wait no, wait the cards are white with very subtle shadow? Wait no, look: the cards are rounded squares, 16px corner radius, fill is white? Wait no, the background of the app is off-white #FAFAFA, the cards are #FFFFFF, 1px? No, no border, just elevation, very subtle drop shadow, 0 2px 8px rgba(0,0,0,0.04) maybe? Let's check spacing between cards: 12px gap between each card, first card is 20px from left edge, then each subsequent card is 12px after the prior. Let's list each card:
- Assistant card: 76x76px, 16px corner radius, fill #FFFFFF, center icon 28x28px, gray stroke (2px), smiley face icon, label "Assistant" below, 13px regular weight, #1D1D1F (dark gray, almost black) text, 8px gap between icon and label, so total card height 76px: icon takes ~36px, 8px gap, label 13px, so 36+8+13=57, centered, so top and bottom padding of (76-57)/2 = 9.5px, ~10px.
- Storyteller card: same 76x76px, same fill, same style, icon is open book, 2px gray stroke, label "Storyteller" 13px regular, same spacing.
- Kids Story Time card: same card size, icon is adult + child f

---

## grok-loading — DOWNLOAD FAILED

---
