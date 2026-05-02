# Mycelia — Decision: Biome Architecture

**Status:** RESOLVED 2026-05-01
**Decision:** Single-place zones for biomes. Per-Place via TeleportService only for foraging expeditions.

---

## The question

How should biomes be implemented in Roblox terms?

**Option A — per-biome separate Places** within a Universe, traversed via `TeleportService`. (The original PDF spec.)
**Option B — single-place world** with biomes as zones, traversed by walking or local teleport.

This decision dictates the structure of `MapSetup.lua`, `WildSpawn.lua`, the Travel NPC behavior, the data layer, and how cross-biome events (lunar phases, seasonal transitions, weather) work. Locking it in now means the Phase 1 biome refactor builds the right foundation; getting it wrong = wasted work.

---

## Option A: Per-biome separate Places

Each biome (Starter Glade, Misty Hollow, Frostroot Pass, etc.) is its own Roblox Place inside the same Universe. Players use `TeleportService:Teleport` to move between them. Save data persists across the Universe via one shared DataStore.

**Pros**
- Each biome has independent terrain, lighting, atmosphere with no conflicts.
- Clients only load the current biome → smaller per-client memory.
- Server load distributes per biome; popular biomes scale independently.
- Easier to ship limited-time event biomes — just publish a new Place.
- Can iterate one biome's worldbuilding without affecting others.

**Cons**
- **Social density collapses.** Players in different biomes can't see each other. A trading-economy game lives or dies on density — this hurts retention directly.
- **Trading across biomes is impossible** without a return teleport.
- **Teleport latency: 5–15 seconds** per biome travel = a loading screen every time. Players feel it.
- **Cross-place data races.** A teleport during autosave can lose progress; mitigation requires teleport-aware save logic + idempotent ops.
- **Cross-biome events are hard.** Lunar event sweeping all 7 biomes simultaneously requires `MessagingService` + per-Place coordination.
- **Operational overhead.** Each biome is a separate publish. 7 biomes = 7 deployments per balance change.
- **Friend-finding UX is messy.** "Where's my friend?" requires querying each Place; Roblox APIs are rate-limited.

---

## Option B: Single-place zones

One giant world. Biomes are regions of the map separated by terrain (mountains, rivers, gates). Players walk between them or fast-travel via local CFrame teleport. All players in a server see each other regardless of which biome they're standing in.

**Pros**
- **All players visible to each other** → social density preserved → trading economy works.
- **Trading frictionless** between any two players in the server.
- **One Place, one publish** — every change deploys atomically.
- **Cross-biome events trivial** — server-side BindableEvents reach every zone at once.
- **No teleport latency** for biome travel.
- **Simpler data model** — single DataStore, no cross-place races.
- **Easier testing** — one `.rbxl` file.

**Cons**
- All biome assets load at once → larger client memory footprint.
- Mitigated by Roblox's `StreamingEnabled` (mature feature; culls distant geometry per-player automatically).
- Atmosphere/lighting per-biome requires region-based effects rather than global Lighting properties.
- One server has a max concurrent player count (Roblox standard ~50, can be raised). Biome 7 with 100 active players means players spill across multiple server instances and can't all see each other.
- Expanding the world map for new biomes requires layout planning.

---

## Real-world evidence

The cozy / economy-driven Roblox games whose patterns Mycelia is explicitly modeled on **all chose single-place**:

| Game | Approach | Notes |
|---|---|---|
| Bee Swarm Simulator (2018+) | Single-place | Our primary reference. All fields in one map. 7+ years strong. |
| Adopt Me (2019+) | Single-place | One giant world; trading happens anywhere players meet. |
| Theme Park Tycoon 2 (2014+) | Single-place | Every player's tycoon is in the same shared world. |
| Grow a Garden (recent hit) | Single-place | Gardens in shared world. |

Multi-place via TeleportService is used for genuinely different patterns:

| Game | Approach | Notes |
|---|---|---|
| Pet Simulator 99 | Per-Place "worlds" | But these are progression power tiers, not persistent biomes — players within a tier still see each other. |
| Murder Mystery 2 | Per-Place per map | Round-based gameplay; ephemeral, not persistent. Totally different paradigm. |

**The pattern is clear.** Every long-lived economy game uses single-place. Multi-place is for progression treadmills or ephemeral round-based games. Mycelia is neither — it's a persistent cozy world with player-driven trading. The pattern that matches is single-place.

---

## Mycelia-specific considerations

Things we know from the design doc and scripting order:

- **Player-to-player trading is THE long-term retention engine.** → favors single-place (trade density).
- **Co-op foraging expeditions** are the social hook for the algorithm. → these ARE per-Place (correct use of TeleportService — see below).
- **Lunar phases and seasonal transitions** should feel synchronized across the whole world. → favors single-place.
- **Mobile-first** with constrained client memory. → favors per-Place at first glance, but `StreamingEnabled` handles this in single-place.
- **Trading Post is "a physical place in the world (not just a menu) where players gather"** — design doc explicitly wants density at the trading post. → favors single-place.

Every consideration favors single-place except client memory, which `StreamingEnabled` solves.

---

## Recommendation: Single-place zones for biomes

Persistent biome travel happens within one Place. Use `TeleportService` **only** for ephemeral instanced content — foraging expeditions definitely; limited-time event biomes possibly.

---

## Implementation notes

Specifics for the Phase 1 biome refactor under this approach:

1. **World layout.** Lay out the 7 launch biomes as adjacent zones in one large world map. Roughly 1000-2000 stud separation between biome centers, with terrain barriers (mountains, rivers, gates) marking transitions.

2. **`StreamingEnabled`.** Set `Workspace.StreamingEnabled = true`. Tune `StreamingMinRadius` (~256) and `StreamingTargetRadius` (~1024). Distant biomes are culled per-player; memory stays bounded.

3. **Per-zone atmosphere.** Each biome has an invisible BasePart with `BiomeId` attribute. When the player's HumanoidRootPart enters the volume (Region3 check or Touched + filter), the client tweens to that biome's `Atmosphere` + `Lighting` settings. Smooth crossfades, ~1-2 seconds.

4. **Travel NPC.** A simple CFrame teleport — set `HumanoidRootPart.CFrame` to the destination biome's spawn pad. No `TeleportService`. Optional polish: brief fade-to-black overlay for visual continuity.

5. **Per-biome wild spawn areas.** Each biome has its own `WildSpawnArea` Part with attribute `BiomeId`. `WildSpawn.lua` iterates all biome configs, runs independent spawn loops per biome with biome-specific tables.

6. **Cross-biome events.** `SeasonChanged` and `LunarPhaseChanged` are server-side BindableEvents. Every biome's WildSpawn loop subscribes. Lunar event = global. Weather can be per-biome state, with the global tick affecting all biomes simultaneously.

7. **Foraging expeditions DO use `TeleportService`.** Each expedition type is a separate ReservedServer Place. Correct usage — expeditions are ephemeral, instanced, party-only. The Phase 2 spec already has this right.

8. **Hut visiting.** Two sub-options:
   - **Sub-option a: Single-place huts** — each hut is a private interior anchored somewhere in the main world map (out of bounds, accessed via teleport-to-CFrame). Cheaper memory; locked to non-friends via server-side region permissions.
   - **Sub-option b: Per-Place huts** — each player's hut is its own Place. More customization room, more operational cost.
   - **Recommend (a) initially.** Revisit if hut customization gets ambitious enough to need the isolation of (b).

---

## When the per-Place approach IS appropriate

This decision is "single-place for persistent biomes," not "never use TeleportService." Specifically:

- **Foraging expeditions: yes, per-Place** with ReservedServer. Ephemeral, instanced, party-only. Textbook case.
- **Limited-time event biomes** (e.g., a Halloween graveyard or summer beach): yes, per-Place. They're content drops, not part of the persistent world.
- **Tutorial / onboarding:** maybe, but for Mycelia the in-world Forest Witch tutorial works fine without a separate Place.

---

## Impact on Phase 1 effort estimate

The biome refactor under single-place is **slightly simpler** than under per-Place:

- No `TeleportService` coordination logic.
- No cross-place data race handling.
- No `MessagingService` for synchronizing global events.
- One `.rbxl` to test.

Phase 1 effort estimate (6-8 weeks per the roadmap) does not change. If anything, it's marginally easier.

---

## Override criteria

If you later decide to go per-Place anyway, these are the reasons that would justify it:

1. **A specific biome needs radically different physics or rendering** that can't coexist with the rest (e.g., an underwater biome with custom physics).
2. **Concurrent player count exceeds 100** at a single biome regularly, forcing multiple servers anyway.
3. **A specific biome has gameplay so different** it's effectively a separate game (e.g., a roguelike dungeon mode).

None of those apply at launch. Revisit if/when one of them becomes true.

---

## Decision

**Single-place zones for biomes. Per-Place via TeleportService only for foraging expeditions** (and possibly limited-time event biomes when those happen).

This decision drives Phase 1's biome refactor architecture. Update `MapSetup.lua` and `WildSpawn.lua` to be biome-zone-parameterized rather than biome-Place-parameterized.

Marked resolved in [../ROADMAP.md](../ROADMAP.md).
