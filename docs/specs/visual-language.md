# Mycelia — Visual Language

The single source of truth for color, typography, and motion across all UI and world surfaces. Every screen in `src/client/` and every styled world Part should pull tokens from this doc (or the matching `Constants.UI` table once that lands in code).

This is a **spec**, not a brief: the values here are exact and shippable. Fold any new design decision back into this file before code merges.

---

## Vision

> Hand-painted, slightly desaturated cozy aesthetic. Studio Ghibli forest scenes meets cottagecore. — *DESIGN.md*

Practical translation:
- **Warm earth tones** as the base, not greys. Cream parchment + mossy ink instead of white + black.
- **Desaturated greens** for the dominant brand color — verdant but never neon.
- **Jewel accents reserved for rarity and magic.** Common items live in earth; legendaries glow.
- **No pure black, no pure white** anywhere except for icons or 1-pixel highlights.
- **Mobile-first contrast.** All text must hit WCAG AA on its surface.

---

## Brand palette (game-wide)

These are the foundation. Every other palette in this doc derives from or harmonizes with these.

| Token | Hex | Usage |
|---|---|---|
| `forest.ink` | `#2B3A2E` | Primary text, deepest brand shadow |
| `forest.deep` | `#3F5538` | Headings, dark UI accents |
| `forest.mid` | `#4A6440` | **Primary brand color** (buttons, active states, brand stamp) |
| `forest.sage` | `#8FA478` | Secondary brand, dividers on dark, common-tier rarity |
| `forest.mist` | `#C9D1B8` | Subtle backgrounds, hover states |
| `parchment.cream` | `#F4ECDC` | **Default UI surface** (panels, cards) |
| `parchment.mist` | `#EDE3D0` | Slightly recessed surface (input wells, table rows alt) |
| `parchment.bone` | `#FAF6EB` | Elevated surface (modal background, top-nav) |
| `bark.warm` | `#6B4F3A` | Wood/natural element accent (frames, plot UI) |
| `bark.dark` | `#3E2D22` | Wood shadow / inset borders |
| `spore.gold` | `#C9A04E` | **Currency** (coins). Also success/celebration. |
| `spore.amber` | `#D9A85C` | Warning, daily-bonus badge |
| `dusk.blue` | `#6B8FA8` | Info, trade-pending state |
| `barn.red` | `#B85F5F` | Error, danger (muted — never neon red) |

**Pairing rule:** never put pure `forest.ink` text on pure `parchment.bone`. Use `forest.deep` on `bone`, or `forest.ink` on `cream`. The 1-step softening keeps the cottagecore feel.

---

## Rarity tiers

Mushrooms, potions, spirits, and items all share this scale. Used for borders, badges, and tier-colored text in the Brewing Journal, trade UI, and shop catalogs.

The progression goes **earthy → refined → magical → ethereal**. New players should feel commons are humble; veterans should feel mythics are otherworldly.

| Tier | Hex | Companion (light bg) | Mood |
|---|---|---|---|
| Common | `#8FA478` | `#E5EAD9` | Earthy sage, unassuming |
| Uncommon | `#6B8FA8` | `#D8E3EA` | Dusty blue, slightly refined |
| Rare | `#B07AA1` | `#EBDDE6` | Muted lilac, first whisper of magic |
| Epic | `#D9866A` | `#F5DCD0` | Warm sienna, fire-glow |
| Legendary | `#E5C547` | `#F8EFC1` | Luminous gold, radiant |
| Mythic | `#9C68D4 → #5C9BD5` | `#E2D5F0` | **Iridescent gradient.** Violet → cyan, animated where possible. |

Rarity colors are saturated more than the brand palette by design — they're meant to read instantly at thumbnail size (the `DESIGN.md` rule about distinct icons).

**Mythic gradient:** linear, violet `#9C68D4` at 0% → cyan `#5C9BD5` at 100%, angle 135°. Animate hue-rotate at 0.05Hz on item cards for a subtle shimmer.

---

## Biome palettes

Each biome has its own atmosphere — Lighting + Atmosphere settings should match these. UI surfaces tinted to a biome (HUD background while travelling, biome banner, etc.) use the **mist** color of that biome at 90% opacity.

### Starter Glade
*Sun-dappled meadow, golden hour.*
- Sky/atmosphere: `#E8E1CA` warm cream haze
- Foliage primary: `#6B8E5C`
- Foliage shadow: `#3F5538`
- Accent (sun rays): `#F1D596`
- UI tint: `#EDE3D0`

### Misty Hollow
*Rainforest, perpetual cool drizzle, violet undertones.*
- Sky/atmosphere: `#C4C8D4` cool grey-violet
- Foliage primary: `#5B6B7A`
- Water: `#7A8B9A`
- Accent (lichen glow): `#A2B5C4`
- UI tint: `#E2E5EC`

### Frostroot Pass
*Snowy alpine, pale blue-white, low warm sun.*
- Sky/atmosphere: `#E8EEF2`
- Snow: `#F4F8FB`
- Stone: `#6B859E`
- Accent (warm hut light): `#E0A878`
- UI tint: `#E8EEF2`

### Sunken Grove
*Swamp, moss-mauve, weird saturation.*
- Sky/atmosphere: `#5C5F4A`
- Foliage primary: `#4A5B4C`
- Water (muddy): `#7A6B4F`
- Accent (alchemy glint): `#B8A5D8`
- UI tint: `#D9D6C4`

### Old Growth
*Ancient forest, deep amber-shadow, towering.*
- Sky/atmosphere: `#5A4F3D` (canopy-filtered low light)
- Foliage primary: `#2F3F2B`
- Bark: `#3E2D22`
- Accent (legendary glow): `#B8923E`
- UI tint: `#E5DCC6`

### Glimmerwood
*Bioluminescent, night-only, deep blue with neon-soft greens.*
- Sky/atmosphere: `#1A2434`
- Foliage shadow: `#2D3A4D`
- Bioluminescent green: `#9DE5C8`
- Bioluminescent cyan: `#7EC4E0`
- UI tint: `#26334A` (DARK MODE — UI flips to dark scheme in this biome)

### Lost Cathedral
*Ruined sacred stone, weathered gold, mythic.*
- Sky/atmosphere: `#8E867D`
- Stone: `#5C5651`
- Moss: `#6B7A5E`
- Accent (event glow): `#C2A75D`
- UI tint: `#D8D2C8`

---

## UI surface tokens (light theme — default)

The Shop UI, Brewing Journal, HUD, etc. all consume these. Glimmerwood biome flips to a dark variant — tokens defined under "Dark theme" below.

| Token | Hex | Usage |
|---|---|---|
| `ui.bg` | `#F4ECDC` | Page / modal backdrop fill |
| `ui.surface` | `#FAF6EB` | Cards, panels (slight elevation over bg) |
| `ui.surface.recessed` | `#EDE3D0` | Input wells, table row hover |
| `ui.surface.raised` | `#FFFFFF` (4% opacity overlay) | Modal foreground over surface |
| `ui.divider` | `#D4C9B0` | Hairline borders, table dividers |
| `ui.text.primary` | `#2B3A2E` | Body text |
| `ui.text.secondary` | `#6B6557` | Captions, helper text |
| `ui.text.muted` | `#9A8F7E` | Disabled / placeholder |
| `ui.accent.primary` | `#4A6440` | Primary CTAs (Buy, Sell, Confirm) |
| `ui.accent.primary.hover` | `#3F5538` | Pressed/hover state |
| `ui.accent.gold` | `#C9A04E` | Coin amounts, currency icons |
| `ui.success` | `#6B8E5C` | Toast / inline confirmation |
| `ui.warning` | `#D9A85C` | Soft warning banner |
| `ui.error` | `#B85F5F` | Inline error, destructive button |
| `ui.info` | `#6B8FA8` | Tooltip, info badge |
| `ui.shadow` | `rgba(43,58,46,0.12)` | Card drop shadow |

### Dark theme (Glimmerwood + future night cycles)
| Token | Hex |
|---|---|
| `ui.bg` | `#1A2434` |
| `ui.surface` | `#26334A` |
| `ui.text.primary` | `#E8EEF2` |
| `ui.accent.primary` | `#9DE5C8` |
| (others scale proportionally — TBD when first dark-theme screen ships) |

---

## Typography

**Roblox built-in fonts only** (no asset uploads in Phase 2). Mobile readability rules drive the choices.

| Role | Roblox font | Size (mobile) | Size (desktop) | Weight |
|---|---|---|---|---|
| Display H1 | `Merriweather` | 28pt | 36pt | Bold |
| Display H2 | `Merriweather` | 22pt | 28pt | Regular |
| Section heading | `Nunito` | 18pt | 22pt | Bold |
| Body | `Nunito` | 14pt | 16pt | Regular |
| Body emphasis | `Nunito` | 14pt | 16pt | Bold |
| Caption | `Nunito` | 12pt | 13pt | Regular |
| Currency / numeric | `Inconsolata` | 16pt | 18pt | Bold |
| Buttons | `Nunito` | 16pt | 16pt | Bold |

**Why these:**
- **Merriweather** — soft serif, cottagecore-evocative without being twee. Reserved for headers + display moments (witch dialogue lines, "Brewing Complete!" flourish).
- **Nunito** — rounded sans, modern but warm. Highly readable on mobile. Default for everything functional.
- **Inconsolata** — monospaced. Currency stays aligned in trade UIs and shop totals; tabular figures avoid visual jitter when amounts change.

**Line height:** 1.4× font size for body, 1.2× for headings. Letter-spacing 0 (avoid the default Roblox 0.5px default — looks loose).

---

## Iconography & shape

- **Corner radius:** 12px on cards, 8px on buttons/inputs, 4px on small chips. Never sharp 0px corners — they fight the cozy feel.
- **Icons:** outlined (2px stroke), color = `ui.text.secondary` by default; filled variants used only for active/selected states.
- **Line weight:** never below 1.5px on UI elements at base scale (1.0 mobile UI scale).
- **Shadows:** single soft shadow only, `0 4 12 ui.shadow`. Never stack shadows. Glimmerwood uses an inverted glow (color-shifted bioluminescent green) instead of a shadow.

---

## Motion

| Token | Duration | Easing | Use case |
|---|---|---|---|
| `motion.micro` | 80ms | linear | Button press feedback, color flash |
| `motion.short` | 200ms | quad-out | Tooltip appear, chip toggle |
| `motion.medium` | 350ms | quad-out | Modal slide-in, panel open |
| `motion.long` | 600ms | quint-out | Scene transition, biome wipe |
| `motion.discovery` | 1200ms | back-out | Recipe-discovered moment, rare-drop reveal |

**Reduced motion:** if `UserGameSettings.ReducedMotion` ever becomes available on Roblox, multiply all durations by 0.5 and clamp `motion.discovery` to 300ms with no overshoot.

---

## Spacing system

8pt grid. All paddings, margins, gaps multiples of 4 (preferring 8, 16, 24, 32).

| Token | Value | Usage |
|---|---|---|
| `space.xs` | 4 | Inline gap (icon-to-text) |
| `space.sm` | 8 | Card internal padding bottom edge |
| `space.md` | 16 | Default padding inside cards/panels |
| `space.lg` | 24 | Section gap inside a panel |
| `space.xl` | 32 | Top-level layout gap, modal margin |
| `space.2xl` | 48 | Hero/empty-state padding |

**Mobile tap targets: 44pt minimum.** A button visually rendered at 32pt high must extend its hit-area to 44pt with invisible padding.

---

## Surface elevation

- **Level 0 (page)**: `ui.bg`. No shadow.
- **Level 1 (cards)**: `ui.surface`. Shadow `0 2 6 ui.shadow`.
- **Level 2 (modal/dialog)**: `ui.surface.raised`. Shadow `0 8 24 ui.shadow`. Page dimmed by `rgba(43,58,46,0.4)` overlay.
- **Level 3 (toast/floating)**: `ui.surface`. Shadow `0 12 32 ui.shadow`. Slides up from bottom on mobile.

---

## Light & particle direction (world)

Carries from the world into UI panels (e.g., a brewing-discovery glow uses these particle defaults).

- **Spore drift:** off-white `#F4ECDC` particles, size 0.2–0.6 studs, drift speed 0.3 studs/sec, lifetime 8s. Always present in inhabited biomes.
- **Pollen glow:** `#E5C547` (legendary gold) particles, size 0.3 studs, attached to mid-tier+ wild mushrooms.
- **Firefly:** `#9DE5C8` (Glimmerwood cyan), only in Glimmerwood + Old Growth at night.
- **Mist plane:** screen-space fog, color = current biome's `mist` token, density 0.001 base, peaks at 0.003 in Misty Hollow + dawn/dusk.

---

## Tokens reference (codeable)

When the first UI module reads from `Constants.UI`, populate it from this doc:

```lua
Constants.UI = {
    color = {
        forest = { ink="#2B3A2E", deep="#3F5538", mid="#4A6440", sage="#8FA478", mist="#C9D1B8" },
        parchment = { cream="#F4ECDC", mist="#EDE3D0", bone="#FAF6EB" },
        bark = { warm="#6B4F3A", dark="#3E2D22" },
        accent = { gold="#C9A04E", amber="#D9A85C", duskBlue="#6B8FA8", barnRed="#B85F5F" },
    },
    rarity = {
        Common    = "#8FA478",
        Uncommon  = "#6B8FA8",
        Rare      = "#B07AA1",
        Epic      = "#D9866A",
        Legendary = "#E5C547",
        Mythic    = { from="#9C68D4", to="#5C9BD5" }, -- gradient
    },
    typography = {
        display     = { font=Enum.Font.Merriweather, size=28, weight=Enum.FontWeight.Bold },
        heading     = { font=Enum.Font.Nunito,       size=18, weight=Enum.FontWeight.Bold },
        body        = { font=Enum.Font.Nunito,       size=14, weight=Enum.FontWeight.Regular },
        caption     = { font=Enum.Font.Nunito,       size=12, weight=Enum.FontWeight.Regular },
        numeric     = { font=Enum.Font.Inconsolata,  size=16, weight=Enum.FontWeight.Bold },
    },
    motion = { micro=0.08, short=0.20, medium=0.35, long=0.60, discovery=1.20 },
    space  = { xs=4, sm=8, md=16, lg=24, xl=32, xxl=48 },
    radius = { card=12, button=8, chip=4 },
}
```

---

## Conventions

- **Never hardcode hex codes in logic files.** Pull from `Constants.UI.color.*`.
- **Never use Roblox default colors** (the bright palette in Studio's color picker) without translating through this palette first.
- **Never mix two rarity colors on the same surface.** A trade UI showing a Common-vs-Mythic offer uses one rarity color per side; the surface itself stays neutral.
- **One accent per screen.** A page that's primarily about "Buy" uses `forest.mid` as its CTA color; the same page won't also feature `bark.warm` as a competing CTA.

---

## What this doc doesn't yet cover (TODO as needs arise)

- Per-screen layout templates (shop, journal, trading post, expedition lobby)
- Component anatomy (button states, input states, toast variants)
- Loading/empty/error state visual recipes
- Localization metrics (do strings expand 30% in DE/FR — does the layout still hold?)
- Accessibility: colorblind palette overrides for rarity tiers (Common/Uncommon/Rare are too close on red-green deficient vision — needs a checked-pattern variant)

Add sections as Phase 2 work surfaces these gaps. Don't add empty headers ahead of demand.

---

*Last touched: 2026-05-02. Status: foundation locked; per-screen layouts and component anatomy added as each screen ships.*
