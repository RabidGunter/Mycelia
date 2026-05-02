"""
Generate UI-DESIGN-BRIEF.pdf — the document for outsourcing UI/UX design
work on Mycelia. Covers per-screen specifications, component library,
color + typography, motion spec, mobile-first design rules, and
deliverables expected from a UI designer.

Style matches the other briefs (Helvetica, plain headings, numbered
lists, tables for tight reference data, no graphics).
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
)
from reportlab.lib import colors

OUTPUT_PATHS = [
    r"C:\Users\fonte\Documents\Mycelia\docs\UI-DESIGN-BRIEF.pdf",
    r"C:\Users\fonte\Downloads\Mycelia - UI Design Brief.pdf",
]

# ---------- Styles ---------------------------------------------------------

styles = getSampleStyleSheet()

H1 = ParagraphStyle(
    "H1", parent=styles["Heading1"],
    fontName="Helvetica", fontSize=18, leading=22,
    spaceBefore=18, spaceAfter=10, textColor=colors.black,
)
H2 = ParagraphStyle(
    "H2", parent=styles["Heading2"],
    fontName="Helvetica", fontSize=14, leading=18,
    spaceBefore=14, spaceAfter=6, textColor=colors.black,
)
H3 = ParagraphStyle(
    "H3", parent=styles["Heading3"],
    fontName="Helvetica", fontSize=11, leading=14,
    spaceBefore=8, spaceAfter=4, textColor=colors.HexColor("#555555"),
)
BODY = ParagraphStyle(
    "Body", parent=styles["BodyText"],
    fontName="Helvetica", fontSize=11, leading=15,
    spaceAfter=6, alignment=TA_LEFT, textColor=colors.black,
)
LIST_ITEM = ParagraphStyle(
    "ListItem", parent=BODY,
    leftIndent=20, bulletIndent=8, spaceAfter=3,
)


def P(text):
    return Paragraph(text, BODY)


def heading(text, level=2):
    return Paragraph(text, [None, H1, H2, H3][level])


def numbered(items):
    return [Paragraph(f"{i}. {item}", LIST_ITEM) for i, item in enumerate(items, 1)]


def bullets(items):
    return [Paragraph(f"• {item}", LIST_ITEM) for item in items]


def table(rows, col_widths):
    t = Table(rows, colWidths=col_widths)
    t.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#eeeeee")),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return t


# ---------- Content -------------------------------------------------------

story = []

# Title + intro
story.append(heading("Mycelia — UI Design Brief", level=1))
story.append(P(
    "This document briefs UI/UX designers on the visual design and motion "
    "specs for Mycelia. Mycelia is a cozy mushroom-cultivation Roblox "
    "game in the Bee Swarm Simulator longevity lineage. The UI is the "
    "player's primary point of interaction — every economic decision, "
    "every recipe discovery, every social interaction goes through a "
    "panel you'll design. UI quality is a primary retention lever."
))
story.append(P(
    "What you deliver: visual mockups (Figma / Photoshop / Sketch — your "
    "tool of choice), a color/typography spec doc, exported asset PNGs "
    "at the resolutions specified per screen, a motion spec describing "
    "transition timing + easing curves, and an accessibility audit. The "
    "scripter then wires your designs into Roblox UI primitives."
))
story.append(P(
    "What you do NOT deliver: Roblox UI implementation code (Frame, "
    "TextButton, UICorner, UIPadding instances), animation scripts, or "
    "data binding logic. Those are scripter scope — a separate brief."
))

# Project context
story.append(heading("Project context", level=2))
story.append(P(
    "Mycelia targets ages 9-16 primarily but designed to retain players "
    "into adulthood. Mobile is the primary platform (60%+ of Roblox "
    "playtime is mobile). Desktop and console are secondary but must work."
))
story.append(P(
    "Player session structure: 5-15 minutes for casual sessions, 60+ "
    "minutes for engaged players. Daily check-in habit is the design goal. "
    "UI must be approachable enough for a 5-min player to accomplish a "
    "task without confusion AND deep enough for a 60-min player to feel "
    "they're navigating real complexity (potion recipes, trade economics, "
    "spirit collection, biome unlocks)."
))

# Visual direction
story.append(heading("Visual direction", level=2))
story.append(P(
    "Cozy, hand-painted, slightly desaturated. Think Stardew Valley's UI "
    "but designed for Roblox mobile screens. Warmth + readability + a "
    "consistent illustrated quality across every panel. UI must NOT feel "
    "like a generic Roblox shop interface — that's the bar to clear."
))
story.append(P("Locked-in design rules across all UI surfaces:"))
story.extend(bullets([
    "Cozy color palette (see Colors section). Cream backgrounds, warm earth-toned accents, soft greens. Avoid pure white, pure black, oversaturated primaries.",
    "Hand-painted illustration style on all icons + panel art. NOT flat / Material Design / iOS system icons. The visual should feel like a children's book illustration.",
    "Rounded corners (UICorner radius 8-16px depending on element size). No sharp 90-degree edges anywhere except very intentional accents.",
    "Soft shadows / glows under panels and buttons. Subtle drop-shadow with high blur, low opacity. Panels feel like they're floating gently above the world, not stamped on top.",
    "Typography: warm sans-serif for body (Gotham family or similar — reads well at small sizes), serif accent for titles (e.g., Lora, Merriweather). NEVER Comic Sans or Papyrus.",
    "Iconography: line-art with subtle fills, not solid silhouettes. A mushroom icon should feel like a sketch with color washes, not a logo.",
    "Mobile-first sizing. 44pt minimum tap target. 16pt minimum body text. Single-thumb reach: most-used controls go in the bottom 60% of the screen.",
    "Motion is gentle. No bouncing, no flashing, no rapid color shifts. Tweens use ease-out curves; durations 150-300ms. Reduced-motion mode disables all non-essential animation.",
]))

story.append(heading("Reference aesthetics", level=3))
story.extend(bullets([
    "Stardew Valley — UI panels, color palette, font choice.",
    "Animal Crossing: New Horizons — soft UI, warm accents, mobile-friendly readability.",
    "Bee Swarm Simulator — for understanding what works at Roblox mobile thumbnail scale.",
    "Adopt Me! — for the cozy + kid-friendly tone without being saccharine.",
    "Children's book illustration aesthetic in general (Quentin Blake-ish, Beatrix Potter-ish) for icon style.",
]))

# Mobile rules
story.append(heading("Mobile-first design rules — non-negotiable", level=2))
story.extend(bullets([
    "Every interactive element ≥ 44×44pt tap target. This is iOS HIG and Material Design's shared rule for thumbs.",
    "Test every screen on a 6.1-inch reference device (iPhone 15 / Pixel 8 size) before sign-off. If a desktop user can read a panel but a phone user squints, redesign.",
    "Bottom-heavy layouts. Critical actions in the bottom 60% of the screen, where the thumb naturally rests. Top of screen = passive info (notifications, status), not actions.",
    "Modals fill 85-92% of screen width on mobile (vs ~50% on desktop). Use UIScale or AspectRatio constraints so the design adapts.",
    "Text contrast: minimum 4.5:1 (WCAG AA) for body text on cards, 3:1 for large text. Pre-validate with a contrast checker before exporting.",
    "Avoid hover-only affordances. Mobile has no hover. Long-press is acceptable as a secondary interaction.",
    "Avoid horizontal swipe gestures for navigation; the right-edge of mobile screens is a system back gesture on iOS and Android. Use bottom buttons instead.",
    "Account for the notch / Dynamic Island / Roblox topbar. The Roblox topbar reserves the top ~36px of screen space. Your designs should sit BELOW that bar.",
]))

# Color palette
story.append(heading("Color palette", level=2))
story.append(P("Locked-in core palette. Designers may extend with shades + tints but must not introduce new hue families without a discussion."))

color_table = [
    ["Token", "Use", "Hex", "Notes"],
    ["bg-card-warm", "Default panel background", "#F8F1E4", "Cream; never pure white"],
    ["bg-card-deep", "Modal overlay panels (elevated)", "#EFE5D2", "Slightly deeper cream"],
    ["bg-card-dark", "Trading UI / serious moments", "#2E2A26", "Dark warm brown"],
    ["bg-overlay", "Behind modal (full-screen dim)", "#0E0C09 @ 65% alpha", "Dark, never pure black"],
    ["text-primary", "Body text on warm cards", "#3A2E22", "Warm dark brown"],
    ["text-secondary", "Hints / captions on cards", "#7A6753", "Mid warm grey"],
    ["text-on-dark", "Body on dark cards", "#F4ECDA", "Cream on brown"],
    ["accent-moss", "Primary action / CTA buttons", "#6E9A4F", "Warm moss green"],
    ["accent-amber", "Discovery / reward / highlight", "#D9A23B", "Honey amber"],
    ["accent-coral", "Destructive / warning", "#C66E5C", "Soft warm coral"],
    ["accent-violet", "Brewing / magical / potions", "#7C5BA0", "Muted purple"],
    ["accent-teal", "Water / koi / cool moments", "#4F8C8C", "Soft teal"],
    ["tier-common", "Common rarity dot", "#C9C9C9", "Cool grey"],
    ["tier-uncommon", "Uncommon rarity dot", "#7AC97F", "Soft green"],
    ["tier-rare", "Rare rarity dot", "#5099D8", "Soft blue"],
    ["tier-epic", "Epic rarity dot", "#A266CC", "Soft violet"],
    ["tier-legendary", "Legendary rarity dot", "#E6B23A", "Warm gold"],
    ["tier-mythic", "Mythic rarity dot", "#E55895", "Warm pink"],
]
story.append(table(color_table, [1.4 * inch, 2.0 * inch, 1.5 * inch, 2.0 * inch]))
story.append(Spacer(1, 8))

# Typography
story.append(heading("Typography", level=2))
story.extend(bullets([
    "Headline serif: Lora Bold (or similar warm serif). Use for modal titles, hero text on cards. 18-24pt range.",
    "Body sans-serif: Gotham Medium (Roblox Studio's GothamMedium font is the default family — use it). 14-18pt range.",
    "Body italic: Gotham MediumItalic. Use for hints / flavor text / captions.",
    "Numerics: Gotham Bold for emphasis on coin counts, inventory totals, etc. Same family for visual cohesion.",
    "Use no more than 3 distinct font sizes within any single panel. Hierarchy comes from weight + color, not multiplied size.",
    "Line height: 1.4x for body text minimum. Cozy reading needs space.",
]))

# Component library
story.append(PageBreak())
story.append(heading("Component library — atoms", level=1))
story.append(P(
    "Reusable components used across multiple screens. Designer ships ONE "
    "definitive version of each; the scripter implements once and reuses. "
    "Variant states (default / hover / active / disabled) provided for each."
))

story.append(heading("Buttons", level=2))
story.extend(bullets([
    "Primary CTA — accent-moss background, text-on-dark text. Used for confirm / submit actions. ~120-160px wide × 44px tall, rounded 8px corners. Default state slightly elevated; pressed state slightly recessed.",
    "Secondary — bg-card-deep background, text-primary text. Used for cancel / less-emphasized actions. Same dimensions.",
    "Tertiary / link — text-only with text-primary color, underline on hover. No background. For 'forgot something?' style optional actions.",
    "Destructive — accent-coral background, text-on-dark text. For drop-item / leave-faction / delete confirmations.",
    "Disabled state — 40% opacity overlay, no hover effect, cursor reverts to default.",
    "Toggle button — pill-shape, accent-moss when active, bg-card-deep when inactive. Used for filter chips, settings toggles.",
]))

story.append(heading("Cards", level=2))
story.extend(bullets([
    "Item card — bg-card-warm background, ~80×80px to ~120×120px depending on grid density. Corner radius 8px. Soft drop shadow. Holds a thumbnail icon + small label.",
    "List row — full-width within parent panel, ~56-72px tall. Bg-card-warm with 1px bottom border in a slightly deeper warm tone for separation.",
    "Hero card — bg-card-warm, ~360×120px. Used for currently-tracked-quest, featured spirit, or active effect at top of HUD.",
    "Empty-state card — same bg as item card but text-secondary text in italic, e.g., 'No mushrooms in inventory. Harvest some to start brewing.'",
]))

story.append(heading("Modals + overlays", level=2))
story.extend(bullets([
    "Modal panel — centered card on top of bg-overlay. ~85% screen width on mobile, ~480px max width on desktop. Has a title bar at the top with a close X.",
    "Bottom sheet — alternative modal style for mobile only. Slides up from bottom; covers ~70% screen height. Used for pickers (Plant species, Brew ingredients, etc.) where a centered modal would feel intrusive.",
    "Toast — small floating notification, ~280×56px, anchored top-center. Slides in from above, auto-dismisses after 3-5s.",
    "Tooltip — small caption-style overlay attached to a hovered/long-pressed item. Shows item name + 1-line description. Bg-card-dark with text-on-dark text.",
]))

story.append(heading("Chips + tags", level=2))
story.extend(bullets([
    "Active effect chip — small pill-shape (~120-180×28px), accent-themed (blue for speed, green for growth, orange for wild yield, etc.). Has icon + name + countdown timer.",
    "Rarity dot — small (12px) circle, color from tier palette. Inline with item names anywhere in the UI.",
    "Filter chip — toggle pill (~80×32px), accent-moss when active.",
    "Status badge — small (~44×20px) rectangle anchored to a card corner. Used for 'NEW!' on undiscovered species, 'x99' on stack counts, etc.",
]))

# HUD layout
story.append(PageBreak())
story.append(heading("HUD — always-visible UI", level=1))
story.append(P(
    "The HUD is the player's persistent control surface. It must NOT "
    "obscure the world; design panels that hug the screen edges and "
    "leave the central viewing area free."
))

story.append(heading("Top-left stack (information)", level=3))
story.extend(bullets([
    "Stats card (top): Coins count + Inventory total. Hero card style. ~200×70px. Coin icon + number, then below it inventory icon + number.",
    "Action button row (below stats): horizontal row of 5-6 round icon buttons (Backpack, Pokedex, Brewing Journal, Quests, Trading, Shop, Settings). ~44×44px each, 8px gaps. Each is a tappable button that opens its respective modal.",
    "Active effects strip (below buttons): vertical stack of active effect chips. Maximum 5 visible (overflow scrolls).",
]))

story.append(heading("Top-right stack (notifications)", level=3))
story.extend(bullets([
    "Tracked quest widget: pinned objective summary. ~280×80px hero card. Shows quest name + objective progress (e.g., '3/5 Brown Caps harvested') + small XP indicator. Tappable to open Quest Journal.",
    "Notification toast stack: when toasts appear, they stack vertically below the tracked quest. Each toast is a small card with a brief icon + message.",
]))

story.append(heading("Bottom-center (mobile only)", level=3))
story.extend(bullets([
    "Mobile control overlay: jump button + action button. Roblox's default mobile controls — designer reviews defaults but doesn't replace them.",
]))

story.append(heading("Bottom-right", level=3))
story.extend(bullets([
    "Chat bubble icon: small (~44×44px) chat icon. Tappable to open chat. Roblox's default chat works; designer styles the icon to match Mycelia palette.",
]))

# Per-screen specs
story.append(PageBreak())
story.append(heading("Per-screen specifications", level=1))

# 1. Backpack
story.append(heading("1. Backpack / Inventory", level=2))
story.append(P(
    "Browse and manage all items the player owns. The most-opened panel "
    "in the game — design for fast scanning + recognition."
))
story.append(P("Layout:"))
story.extend(bullets([
    "Tab strip at top (horizontal): All / Mushrooms / Potions / Spores / Substrates / Additives / Recipes / Spirit Items / Cosmetics / Tools / Quest. 11 tabs total. Use scrolling tab strip on mobile (tabs slide horizontally with momentum).",
    "Filter bar (below tabs): toggle chips for Common / Uncommon / Rare / Epic + a sort dropdown (by name / by rarity / by recently obtained / by sell value).",
    "Grid: 4×8 = 32 slots default per category. Each slot is an item card (~80×80px) with thumbnail + count badge in the corner if stack > 1. Empty slots are visible (bg-card-warm with 50% opacity).",
    "Slot interactions: short-tap shows tooltip with name + description; long-press opens action menu (Drop / Use / Trade / Inspect).",
    "Bottom: stack overflow indicator if > 32 of a category exist (e.g., '47 / 32 — Inventory full!'). Inventory expansion gamepass ad below if applicable.",
]))
story.append(P("Mobile-specific: tabs scroll horizontally with momentum + snap. Grid slot size shrinks to 4×6 on small screens to keep tap targets ≥ 44pt."))

# 2. Pokedex
story.append(heading("2. Pokedex (mushroom collection)", level=2))
story.append(P(
    "Browseable catalog of all 60 launch species. Discovered species "
    "show full info; undiscovered show as silhouettes."
))
story.append(P("Layout:"))
story.extend(bullets([
    "Header: 'Discovered: X / 60' counter prominently. Progress bar visualizing fraction.",
    "Filter row (below header): All / Common / Uncommon / Rare / Epic / Legendary / Mythic / Seasonal. Same chip style as backpack.",
    "Sort dropdown: by tier / by name / by recently discovered / by sell price.",
    "Card grid: each species is a square card (~120×120px) with thumbnail + name + tier dot. Discovered species: full-color thumbnail. Undiscovered: silhouette in tier color, name shown as '???'.",
    "Tap a card to open detail view: large thumbnail, full description, sell price, where to find (biome / substrate hints), known recipes that use it.",
]))

# 3. Brewing Journal
story.append(heading("3. Brewing Journal (potion catalog)", level=2))
story.append(P("Same shape as Pokedex but for potions (20 launch potions)."))
story.extend(bullets([
    "Header: 'Discovered: X / 20' counter.",
    "Filter row: All / Buffs / Tools / Cosmetic / Forest Interaction.",
    "Card grid: ~120×120 per potion card. Discovered: full info (name, rarity dot, effect summary, owned count). Undiscovered: '???' with tier dot if hinted (e.g., 'You've heard rumors of a Common-tier potion brewed from BrownCap...').",
    "Tap a card to open detail view: name, description, effect (e.g., 'Walk speed +30% for 30s'), owned count, recipes that produce it (only if Settings.showPotionHints = true).",
]))

# 4. Brewing UI (cauldron)
story.append(heading("4. Brewing UI (cauldron picker)", level=2))
story.append(P(
    "Triggered when player presses E at the cauldron. The most "
    "interactive panel — design for speed of repeated use."
))
story.extend(bullets([
    "Title bar: 'Cauldron' + close X.",
    "Method buttons row (top): 4 buttons — Steep / Boil / Ferment / Dry-grind. Mutually exclusive selection (only one active at a time). Selected = accent-moss highlighted; unselected = bg-card-deep.",
    "Ingredient list (scrolling middle): one row per mushroom species the player owns. Each row shows tier color dot + species name + 'inv 5 / picked 2' counter on the right.",
    "Tap a row to add 1 ingredient (counter increments). Tap a row already at max (inventory cap or 5 picked total) to clear back to 0.",
    "Selected ingredients summary (below ingredient list): horizontal display of picked ingredients. e.g., 'BrownCap × 3, FairyCup × 1'.",
    "Bottom: Brew button (accent-moss, prominent) + Cancel button. Brew is greyed out until method is selected and ≥ 1 ingredient picked.",
    "Recent brews mini-strip (top, optional): last 3 brews with their results. Helps players remember what they've tried.",
]))

# 5. Plant picker
story.append(heading("5. Plant picker", level=2))
story.append(P("Triggered when player presses E at an empty plot."))
story.extend(bullets([
    "Title bar: 'Plant a Spore Patch' + close X.",
    "Filter chips: All / by tier / by substrate compatibility (with this plot's current substrate).",
    "Species list (scrolling): each row shows tier dot + species name + plant cost (in coins) + small icon indicating substrate compatibility (green check / yellow warning / red X). Greyed-out rows for species the player can't afford or hasn't discovered.",
    "Plot info card (top): shows the plot's current substrate, moisture, light, host tree, pH. Player can change substrate from here (consumes a substrate item from inventory).",
    "Bottom: Plant button (accent-moss) — disabled until a species is selected.",
]))

# 6. Potion drawer
story.append(heading("6. Potion drawer (consume picker)", level=2))
story.append(P("Triggered by tapping the Potions HUD button."))
story.extend(bullets([
    "Title bar: 'My Potions' + close X.",
    "Tab row: 'Active' (potions currently affecting you) / 'Inventory' (potions you own).",
    "List rows: name + tier dot + effect summary + owned count + tap-to-consume button. Inert potions (no effect) appear greyed-out with 'No effect yet' label.",
    "Active tab: shows currently-running effects with countdown timer. Tap to see details.",
]))

# 7. Active Effects HUD strip
story.append(heading("7. Active Effects strip (HUD chip stack)", level=2))
story.append(P(
    "Lives in the top-left HUD stack. Shows currently-active timed effects "
    "from potions + spirit bonuses (and future weather buffs)."
))
story.extend(bullets([
    "Vertical stack of chips, max 5 visible (overflow scrolls).",
    "Each chip: icon + name + countdown ('Speed 1.3× — 0:24'). Color-coded by effect kind.",
    "Permanent (untimed) bonuses from spirits: shown without countdown, indicated by a small pin icon.",
]))

# 8. Toasts
story.append(heading("8. Toast notification system", level=2))
story.extend(bullets([
    "All toasts: ~280×56px floating cards, top-center anchored. Slide in from above (200ms ease-out), hold for 3-5s, fade out (300ms).",
    "Toast types — design distinct visual styles:",
    "  Discovery toast (potion / species / spirit) — amber accent. Title 'Discovered:' + item name. Plays a brief sound.",
    "  Reward toast (coins / item gained) — moss accent. '+25 coins'. Subtle.",
    "  Negative toast (brew fizzled / inventory full) — coral accent. Brief one-line message.",
    "  Quest progress toast — teal accent. Quest name + objective tick (e.g., '3/5 → 4/5').",
    "Stacking: when multiple toasts fire in quick succession, they queue vertically below the tracked-quest widget. Max 4 visible at once; older ones fade out faster to make room.",
]))

# 9. Settings menu
story.append(heading("9. Settings menu", level=2))
story.extend(bullets([
    "Modal layout: tabs on left for Audio / Display / Accessibility / Account / About.",
    "Audio tab: master/music/SFX/ambient sliders (0-100%); Mute When Tabbed Out toggle.",
    "Display tab: graphics quality preset (Auto / Low / Med / High); camera sensitivity slider; UI scale slider.",
    "Accessibility tab: Reduced Motion toggle; Color-Blind Friendly Mode dropdown (Off / Protanopia / Deuteranopia / Tritanopia); large-text toggle; high-contrast mode.",
    "Account tab: hut access level (Private / Friends Only / Public); sign-out (placeholder for now).",
    "About tab: game version, credits, support links.",
]))

# 10. Shop UI (per-merchant variant)
story.append(heading("10. Shop UI (used by all merchants)", level=2))
story.append(P(
    "One shared component. Each merchant configures it via data — what "
    "they buy + what they sell + price modifiers. Designer ships ONE shop "
    "panel design that adapts to each merchant's inventory."
))
story.extend(bullets([
    "Header: NPC portrait + greeting line (e.g., 'Welcome back, traveler.').",
    "Tab strip: Sell / Buy.",
    "Sell tab: list of player's inventory items the merchant accepts, with per-item sell price and +/- quantity selector. 'Sell All' / 'Sell Selected' buttons at the bottom + total payout summary.",
    "Buy tab: merchant's inventory with prices and +/- quantity selector. Cards show name + thumbnail + price + Buy button. Greyed out if player can't afford.",
    "Top-right corner: player's current coin balance + inventory space remaining.",
    "Each merchant variant changes only the portrait + greeting + which items appear; the panel structure stays identical.",
]))

# 11. Trading UI
story.append(PageBreak())
story.append(heading("11. Trading UI (player-to-player)", level=2))
story.append(P(
    "Two players see synchronized panels. The most spec-sensitive UI in "
    "the game — clarity here prevents player confusion that becomes "
    "support tickets and trust issues."
))
story.extend(bullets([
    "Layout (centered modal, ~92% screen width):",
    "  Left column — my backpack (categorized, scrollable). Tap an item to move it to my offering slot.",
    "  Center top — my offering area: 2×5 = 10 item slots + coin offering input box (digit-only).",
    "  Center middle — city tax indicator showing % cut (default 5%, adjustable in Constants). Visible to both players.",
    "  Center bottom — their offering area (read-only): 2×5 slots + their coin offering displayed.",
    "  Right column — their backpack (read-only — I can see what they have but can't touch).",
    "Bottom: Offer / Accept / Deny buttons. Button label changes based on state:",
    "  Initial: 'Offer'",
    "  Waiting for other player: 'Waiting…' (greyed)",
    "  After both offered: 'Accept'",
    "  Waiting for other player to accept: 'Waiting…' (greyed)",
    "Anti-confusion notes: when their offer changes, briefly highlight the changed slot so I notice. Show 'Trade pending' state clearly. Failed-trade messages must explain WHY it failed (distance, decline, disconnect).",
]))

# 12. Travel UI
story.append(heading("12. Travel UI", level=2))
story.append(P("Triggered when talking to the Travel Coordinator NPC."))
story.extend(bullets([
    "Modal: 'Where to?' header + 7 biome cards (one per biome).",
    "Each biome card: hero illustration (biome-themed art) + name + brief description + travel cost + status badge.",
    "Status badges: 'Locked' (grey) with requirement / 'Unlocked' (default) / 'You are here' (highlighted with accent-moss ring).",
    "Locked biomes are visible (greyed 50%) so players see what's ahead.",
    "Tap an unlocked biome → confirm prompt: 'Travel to Misty Hollow? Your inventory comes with you. Travel cost: 25 coins.'",
]))

# 13. Player Stalls
story.append(heading("13. Player Stalls (rented shops)", level=2))
story.append(P("Phase 2 feature. Players rent stalls in the Trading Post."))
story.extend(bullets([
    "Stall management modal: tabs for 'My Stall' (manage inventory + listings) / 'Visit Stalls' (browse other players').",
    "My Stall: list of items in stall + add/remove buttons + per-item price input + auction toggle (with min bid + duration).",
    "Visit Stalls: scrollable list of stalls owned by other players. Each card shows owner name + featured items.",
    "Tap a stall card → opens stall detail view with all listings + Buy buttons.",
]))

# 14. Quest Journal
story.append(heading("14. Quest Journal", level=2))
story.extend(bullets([
    "Tabs: Active / Completed / Available.",
    "Active tab: each quest is a card showing title + NPC + objective progress (with progress bar) + reward preview + 'Track' toggle.",
    "Completed tab: read-only history with date completed.",
    "Available tab: quests offered by NPCs the player can currently access. Each card shows the giving NPC + biome + brief description + 'Talk to <NPC>' hint.",
    "Tracked quest widget on HUD updates when a quest is set as tracked.",
]))

# 15. NPC Dialogue
story.append(heading("15. NPC Dialogue", level=2))
story.append(P("Chat-bubble style at the bottom of the screen."))
story.extend(bullets([
    "Layout: bottom 30% of screen. NPC portrait on the left (~80×80px circular), text bubble on the right with their dialogue.",
    "Continue button (bottom-right) advances to the next line.",
    "Response options (when present): 2-4 buttons stacked vertically below the bubble. Each button is a player-perspective response.",
    "Close X (top-right) dismisses the dialogue (some critical lines lock the close until a response is chosen).",
]))

# 16. Player Profile
story.append(heading("16. Player Profile", level=2))
story.extend(bullets([
    "Modal: player avatar + name at top. Below: stats grid (Total Renown / Mushrooms Discovered / Potions Brewed / Spirits Owned / Hours Played).",
    "Reputation breakdown: vertical list of NPCs with rep bars. Hover/tap an NPC to see their friendship tier.",
    "Achievement badges: grid of unlocked badges below stats.",
]))

# 17. Hut decoration UI
story.append(heading("17. Hut decoration UI (Phase 3)", level=2))
story.extend(bullets([
    "Triggered inside the player's hut by tapping a 'Decorate' HUD button.",
    "Bottom-sheet picker: tabs for furniture types (Wall / Floor / Tabletop / Hanging / Magic). Drag-and-drop or tap a category to filter.",
    "Tapping an unlocked decoration shows ghost preview that follows cursor; tap on a valid anchor to place.",
    "Long-press a placed decoration to remove (returns to inventory).",
    "Hut Settings sub-modal: change wall color, floor texture, lighting cycle, public/friends-only/private access.",
]))

# Motion + animation spec
story.append(PageBreak())
story.append(heading("Motion + animation spec", level=1))
story.append(P(
    "Motion is gentle, never alarming. Use these defaults across all UI; "
    "deviations require justification."
))
story.extend(bullets([
    "Modal open: panel fades in (200ms) + scales from 95% to 100% (200ms ease-out). Overlay dims simultaneously (250ms).",
    "Modal close: reverse — scales to 95% + fades out (180ms). Overlay clears (220ms).",
    "Bottom sheet open: slides up from below (250ms ease-out). Close: slides down (200ms ease-in).",
    "Toast in: slides from above (200ms ease-out) + fades in (200ms).",
    "Toast out: fades out (300ms ease-in). No slide.",
    "Button hover (desktop): subtle lift (1-2px translateY) + slight color shift (100ms).",
    "Button press: brief depress (1px translateY) + color darken (80ms).",
    "Tab switch: content cross-fades between tabs (150ms).",
    "Discovery glow effect (when player discovers a new species/potion): card scales briefly to 105% and back (400ms ease-in-out) + accent-amber glow flashes around the border.",
    "Reduced motion mode: all of the above become instant (0ms duration). Color shifts still happen; only positional/scale animation is disabled.",
]))

# Accessibility
story.append(heading("Accessibility", level=2))
story.extend(bullets([
    "WCAG AA contrast minimum: 4.5:1 for body text, 3:1 for large text. Pre-validate all designs.",
    "Color-blind safe: never convey information by color alone. Rarity is shown with both color dot AND text label. Effect chips show icon + text + color.",
    "Reduced Motion: a Settings toggle that disables all positional/scale animation. Tween durations become 0; cross-fades become instant cuts.",
    "Large Text mode: optional Settings toggle that increases body text from 14pt → 18pt across all panels.",
    "High Contrast mode: optional alternative palette with greater contrast (cream → white, dark brown → black).",
    "Focus states (for keyboard navigation): clear 2px accent-moss outline on the currently-focused element. Important for desktop accessibility.",
]))

# Deliverables
story.append(PageBreak())
story.append(heading("Deliverables expected", level=1))
story.append(P("In rough priority order — earlier items unblock dependent design work."))

deliverables_table = [
    ["#", "Deliverable", "Phase", "Notes"],
    ["1", "Color + typography spec doc", "Pre-Alpha (now)", "Locked-in tokens, used by everything"],
    ["2", "Component library (atoms): buttons, cards, modals, chips", "Pre-Alpha (now)", "Designer ships definitive variants of each"],
    ["3", "HUD layout mockup", "Pre-Alpha (now)", "All persistent UI elements"],
    ["4", "Backpack panel mockup", "Phase 1", "Most-opened panel; design for speed"],
    ["5", "Pokedex panel mockup", "Phase 1", "Card grid + filter chips"],
    ["6", "Brewing UI mockup (cauldron)", "Phase 1", "Method buttons + ingredient picker"],
    ["7", "Brewing Journal mockup", "Phase 1", "Card grid for potions"],
    ["8", "Plant picker mockup", "Phase 1", "Species selection + plot info card"],
    ["9", "Potion drawer mockup", "Phase 1", "Active vs Inventory tabs"],
    ["10", "Active effects chip designs (10 effect-kind variants)", "Phase 1", "Color-coded per kind"],
    ["11", "Toast system (4 variant styles)", "Phase 1", "Discovery / Reward / Negative / Quest progress"],
    ["12", "Settings menu mockup", "Phase 1", "Audio / Display / Accessibility / Account / About"],
    ["13", "Shop UI mockup (one shared design)", "Phase 2", "Used by all merchants via data config"],
    ["14", "Trading UI mockup", "Phase 2", "The most spec-sensitive panel"],
    ["15", "Travel UI mockup", "Phase 1+", "7 biome cards, locked + unlocked states"],
    ["16", "Player Stalls mockup", "Phase 2", "My Stall + Visit Stalls tabs"],
    ["17", "Quest Journal + tracked-quest widget", "Phase 2", "Active / Completed / Available tabs"],
    ["18", "NPC dialogue UI mockup", "Phase 2", "Chat-bubble + portrait + responses"],
    ["19", "Player Profile mockup", "Phase 3", "Stats grid + reputation breakdown"],
    ["20", "Hut decoration UI mockup", "Phase 3", "Bottom-sheet picker"],
    ["21", "Asset pack export (PNG / 9-slice)", "Per-screen", "@1x and @2x for mobile"],
    ["22", "Motion spec document", "Phase 1", "Tween durations, easing curves, per-screen"],
    ["23", "Accessibility audit report", "Phase 3", "Contrast, color-blind, reduced motion validation"],
]
story.append(table(deliverables_table, [0.3 * inch, 3.0 * inch, 1.0 * inch, 2.5 * inch]))
story.append(Spacer(1, 8))

# File format expectations
story.append(heading("File format expectations", level=2))
story.extend(bullets([
    "Mockups: Figma (preferred) or PSD / XD / Sketch. Designer chooses tool, ships exported PNGs alongside.",
    "Asset exports: PNG with transparent background, @1x AND @2x resolution. 9-slice exports (with stretch zones marked) for any element used at variable sizes — buttons, panels, scroll bars.",
    "Color spec: shipped as a Figma-style file or a Markdown doc with hex values + named tokens.",
    "Motion spec: Markdown doc OR Figma annotations describing duration + easing for every transition.",
]))

# Coordination
story.append(heading("Coordinating with the scripter", level=2))
story.extend(bullets([
    "The scripter implements your designs in Roblox UI primitives (Frame, ImageLabel, TextButton, UICorner, UIPadding, UIListLayout, etc.). They don't need vector math — they need pixel sizes and a clear hierarchy.",
    "Provide layouts as flat layer trees. Indicate parent-child relationships clearly. The scripter creates the hierarchy in code.",
    "Provide explicit pixel sizes for every element. Roblox UI uses UDim2 (Scale + Offset combinations); the scripter handles that conversion. You provide intent: 'this card is 280px wide, 80px tall, with 16px padding.'",
    "Provide explicit padding + spacing values. 'List items have 8px gap between them, 16px outer padding from container.' The scripter uses UIListLayout to enforce.",
    "Avoid CSS-only effects (gradients, blurs, complex shadows) — Roblox UI supports a subset. Provide bitmap fallbacks for anything Roblox can't natively render. Specifically: Roblox supports rounded corners (UICorner), gradients (UIGradient), strokes (UIStroke), simple shadows via stretched-image-with-shadow exports. Most other CSS effects need to be baked into PNG.",
    "Specify all states upfront: default, hover, active, pressed, disabled. The scripter wires these once you've defined them.",
    "When in doubt, draw it. A diagram or annotated screenshot saves an hour of back-and-forth.",
]))

# Final notes
story.append(heading("Final notes for designers", level=2))
story.extend(bullets([
    "Mycelia targets a multi-year operational lifecycle. The UI you ship will be used by hundreds of thousands of players for years — invest in the craft.",
    "The cozy aesthetic is uncontested on Roblox right now. Don't drift toward the visual conventions of Bee Swarm Simulator (which is more bright/saturated) or Adopt Me (which leans iOS-Material). Mycelia's UI should look like a illustrated storybook, not a generic Roblox shop.",
    "Read the project's design doc at docs/DESIGN.md for broader vision.",
    "Read the SCRIPTING-ORDER.pdf for the gameplay systems your UI is wrapping. Understanding what each panel actually DOES helps you design panels that serve the gameplay rather than fight it.",
    "Read the WORLD-DESIGN-BRIEF.pdf for the world aesthetic — your UI should harmonize with it. Same warm-cream palette, same hand-painted feel. They're sister documents.",
]))

# ---------- Build --------------------------------------------------------

import copy

for path in OUTPUT_PATHS:
    doc = SimpleDocTemplate(
        path,
        pagesize=letter,
        leftMargin=0.85 * inch,
        rightMargin=0.85 * inch,
        topMargin=0.85 * inch,
        bottomMargin=0.85 * inch,
        title="Mycelia - UI Design Brief",
        author="RabidGunter",
    )
    doc.build(copy.deepcopy(story))
    print(f"Wrote {path}")
