# Mycelia — Visual References

Curated reference board for the cottagecore + Ghibli aesthetic Mycelia targets. Pair with [docs/specs/visual-language.md](specs/visual-language.md) (the hex codes and tokens) — this file shows the *feel* those tokens should hit.

These are external links to existing games, art, and palette tools. Click through and study the patterns; don't copy pixels. Each entry says what to take from it and what to ignore.

---

## Shop / merchant UI (most directly relevant to Phase 2 Shop UI)

### Stardew Valley — General Store
- **Reference:** [Interface In Game — Stardew Valley Store](https://interfaceingame.com/screenshots/stardew-valley-store/)
- **What to take:** Single-column scrollable list of items, each row = portrait + name + price + buy button. Coin total in a fixed corner. Warm brown wood frame around the entire dialog.
- **What to ignore:** Pixel-art texture (we're going hand-painted, not pixel). Tiny fonts (mobile needs bigger).
- **Why it's the closest reference for our witch shop:** the player-merchant relationship is one-on-one, intimate, slow-paced — exactly the vibe we want. Not a Steam-store grid.

### Stardew Valley — full UI catalog
- **Reference:** [Interface In Game — Stardew Valley](https://interfaceingame.com/games/stardew-valley/)
- **What to take:** How the inventory, journal, shipping bin, and shop all share a wood-frame aesthetic — every screen feels like the same world. We want this surface consistency across Shop / Brewing Journal / Trading Post.

### Hollow Knight — merchant UI
- **Reference:** [Hollow Knight Interface Design Analysis (champicky)](https://champicky.com/2022/03/23/hollow-knight-interface-design-analysis/) · [Interface In Game — Hollow Knight](https://interfaceingame.com/games/hollow-knight/)
- **What to take:** **Merchant character portrait at the top of the shop dialog** as decorative anchor — gives every shop a unique personality. We can do this for the Witch (silhouette in the dialog header), Substrate Dealer, Spore Merchant, etc. The handmade-ornament-as-frame approach is very on-brand for cottagecore.
- **What to ignore:** Gothic darkness — wrong mood. We want warm parchment, not stone.

---

## Trading post UI (Phase 2 later)

### Adopt Me — trade screen
- **Reference:** [Adopt Me Trade System wiki](https://adoptme.fandom.com/wiki/Trade_System)
- **What to take:** **Side-by-side offer panels** with player avatars at top, item slots below, coin offering above the accept button. The cooldown-into-green-accept-button pattern is *the* anti-scam UX; spec wants it ([remote-api.md:357](specs/remote-api.md:357) `LockTradeOffer` + `ConfirmTrade`). The "unfair trade warning" toast is also worth lifting.
- **What to ignore:** Adopt Me's purple-pink pet-shop palette — too sugary for our cottagecore mood.

### Designing a Roblox trading system (creation.dev)
- **Reference:** [Designing a Trading System for Your Roblox Game](https://www.creation.dev/blog/roblox-trading-system-design)
- **What to take:** Server-authority patterns and atomic-execution flow notes — useful when we hit the Trading Post task in Phase 2.

---

## Bee Swarm Simulator (closest gameplay analog)

### Robux Shop / Tab UIs
- **Reference:** [Robux Shop — Bee Swarm Wiki](https://bee-swarm-simulator.fandom.com/wiki/Robux_Shop) · [Bee Swarm Simulator on Roblox](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator)
- **What to take:** Tabbed shop layout (Robux Shop / Honey Shop / Egg Shop are separate), large tap targets, big icon + price + buy button structure. Onett's UI is functional rather than pretty — that's a deliberate longevity choice.
- **What to ignore:** Bee Swarm is a 2018 visual style — we're aiming for something more refined. Take the structure, leave the chrome.

---

## Cozy game UI patterns (Cozy Grove, Ooblets)

### Cozy Grove — full UI database
- **Reference:** [Game UI Database — Cozy Grove](https://www.gameuidatabase.com/gameData.php?id=1102)
- **What to take:** Hand-drawn ornaments in dialog corners. Soft round corners on every panel. Pastel palette on cream background. Note how text never sits flush against panel edges — generous padding everywhere.

### Ooblets — full UI database
- **Reference:** [Game UI Database — Ooblets](https://www.gameuidatabase.com/gameData.php?id=1722)
- **What to take:** **The closest reference for our overall visual target.** Ooblets nails the cottagecore-meets-modern-UI balance: clean type, soft sage greens, hand-drawn icons but crisp digital UI. Look at how rarity/category is communicated through small color-coded chips rather than aggressive borders.

### Game UI Database (general browse)
- **Reference:** [Game UI Database](https://www.gameuidatabase.com/) — searchable by tag (cozy / pastel / hand-drawn).

---

## World mood / concept art (for biome decoration, not UI)

### Ghibli + cottagecore wallpaper boards
- **Reference:** [Ghibli cottagecore vibes (Pinterest)](https://www.pinterest.com/colorfulshadow/ghibli-cottagecore-vibes/) · [Cozy Autumn Forest Ghibli Mushroom Wallpaper](https://www.etsy.com/listing/1771070862/cozy-autumn-forest-studio-ghibli)
- **What to take:** Color temperature for biomes. Old Growth and Misty Hollow especially — the violet-grey-green palette of a damp forest at dawn is *exactly* what `forest.mist` and the Misty Hollow tokens should evoke.

### Cottagecore + Ghibli aesthetic essay
- **Reference:** [Cottagecore Meets Ghibli — Everlasting Fabric](https://everlastingfabric.com/blogs/ever-lasting-blog/cottagecore-meets-ghibli-styling-your-home-like-a-studio-ghibli-garden-scene)
- **What to take:** Written articulation of the design philosophy — useful when describing the visual direction to a contractor or future-you.

---

## Color palette tools (sanity-check our hex picks)

### Lospec — cozy palettes
- **Reference:** [Cozy Adventure Palette](https://lospec.com/palette-list/cozy-adventure) · [Cozy palette tag](https://lospec.com/palette-list/tag/cozy)
- **What to take:** Indie-game-tested palettes. Compare against [visual-language.md](specs/visual-language.md) brand palette — if our forest greens and parchment creams sit alongside these without feeling alien, we're on track.

### Coolors — cozy palettes
- **Reference:** [Cozy palettes — Coolors](https://coolors.co/palettes/popular/cozy)
- **What to take:** Quick A/B testing for new palettes when we extend (e.g., the Mythic gradient or a new biome). Drop our hex codes into Coolors and check contrast/harmony.

---

## How to use this board

1. **Before designing a new screen:** open the closest reference in this list (e.g., Stardew shop for our shop UI), study it for 60 seconds, then close it. Don't keep it open while drafting — that leads to copying.
2. **When stuck on a color choice:** check Coolors / Lospec for nearby cozy palettes, see if any nearby hex shifts feel better.
3. **When the result feels generic-AI:** revisit Cozy Grove or Ooblets — they're the canonical "cottagecore-but-modern" benchmark. If our screen has 2× the borders / shadows / chrome of theirs, simplify.
4. **For per-biome mood:** Ghibli/cottagecore Pinterest boards are the fastest way to ground the palette. Search "Ghibli + [biome word]" — e.g., "Ghibli swamp" for Sunken Grove.

---

## What's missing / could add later

- Per-tier rarity reference (real-world examples of how Common→Mythic gradients feel right vs. tacky)
- Mobile-specific cozy game UI (Cozy Cafe, Stardew on iOS)
- Animation/motion references (cozy-game easing curves, sparkle moments)
- Typography pairings inspired by hand-painted Ghibli signage

Add when needed; don't pre-emptively bulk this out.

---

*Last touched: 2026-05-02. References are external — they may shift over time. If a link breaks, search the title; the content usually persists across moves.*
