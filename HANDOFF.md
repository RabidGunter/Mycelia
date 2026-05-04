# Mycelia — Handoff

Current state of the project. The orientation doc CLAUDE.md points here first; read this for what's working, what's most recently shipped, and what to pick up next. For the *why* behind locked-in decisions, see `docs/decisions/`. For the *what* of pending implementation work, see `docs/specs/` and `docs/ROADMAP.md`.

---

## State as of last session (2026-05-03)

**Phase 2 Closed Beta in progress.** Six milestones shipped:
- 2026-05-02: Shop UI replacing Pre-Alpha witch auto-sell.
- 2026-05-03: Substrate Dealer + Spore Merchant (secondary merchants partial).
- 2026-05-03: NPC dialogue system foundation + Forest Witch tree.
- 2026-05-03: Quest system + 5-quest tutorial sequence + Gardener Coach NPC.
- 2026-05-03: Travel Coordinator + Old Hermit + Wandering Alchemist NPCs (5 of 8 launch NPCs).
- 2026-05-03: Walk-away dialogue auto-close UX.
- 2026-05-03: **Trading Post — atomic two-player trade backend + UI + audit log.**

Player Stalls + Co-op Expeditions + 15+ new species pending. Phase 1 verified complete in Studio (166 tests passing prior to Phase 2 work).

---

## State as of 2026-05-01

**Project structure**: new top-level `src/` (Luau, `.luau` extension) is now the canonical Rojo source. Wired into Roblox via `default.project.json`:

- `src/shared/` → `ReplicatedStorage.Shared` (Folder of ModuleScripts).
- `src/server/init.server.luau` → `ServerScriptService.Server` (Script entry point).
- `src/server/X.luau` → child ModuleScripts of `Server`.
- `src/server/Tests/` → child Folder of `Server` containing the test runner + specs.
- `src/client/X.client.luau` → LocalScripts under `StarterPlayerScripts.Client` (Folder).

**Pre-Alpha gameplay code** has been ported from `mycelia/src/` (the legacy folder, still present as reference) into the new `src/` layout. Path rewrites applied: every `require(ServerScriptService.X)` is now `require(ServerScriptService.Server.X)`. Shared and client paths are unchanged.

**Working end-to-end** (per Pre-Alpha pre-port — needs Studio re-verification post-port):
- Core gameplay loop: harvest → plant → sell → brew → consume potions.
- 15 mushroom species across 4 tiers; 6 brewing recipes; 3 active potion effects (speed, growth, wildYield).
- Painted terrain (mossy mountain with cave interior containing the witch+cauldron, pond west of spawn with animated koi, paths, hills).
- Brewing Journal UI showing discovered + undiscovered potions.
- 166 unit tests via TestKit (Inventory + Selling + Species + PotionEffects + Recipes + SaveSchema + Spirits + BiomeConfig specs), all passing as of 2026-05-02 verification in Studio.
- DataStore persistence with autosave + graceful degradation (place is published).
- Hand-built escape valves for every procedurally-built world piece.

**Known follow-ups from the port (verify in Studio next session)**:
- `RunTests.server.luau` lives at `ServerScriptService.Server.Tests.RunTests` — nested under the Server Script. Roblox should still auto-run nested Scripts in ServerScriptService, but verify by pressing Play and checking Output for `Tests complete: 74 passed, 0 failed`. If tests don't auto-run, convert RunTests to a ModuleScript and call it from `init.server.luau`.
- The legacy `mycelia/` subfolder still exists with the old code. Once the new `src/` is verified working in Studio, the legacy folder can be deleted (or kept as reference — your call). Nothing in the new project.json points at it.
- `mycelia/HANDOFF.md` is the legacy handoff and is now obsolete; this file (at the project root) supersedes it.

---

## How to resume work

1. Open VS Code at `C:\Users\fonte\Documents\Mycelia\` (the new project root, NOT the `mycelia/` subfolder).
2. Run `rojo serve default.project.json` from the project root (or use the Rojo VS Code extension's UI). Terminal should show `Rojo serving on port 34872`.
3. Open the Mycelia place in Studio (`File → Open from Roblox` → Mycelia).
4. **Plugins → Rojo → Connect** (default localhost:34872). Approve the HTTP prompt if shown.
5. Press Play. Output should show `Tests complete: 74 passed, 0 failed (74 total)` and the world should build with HUD + paths + cave + pond + koi.

If Studio's Toolbox panel doesn't open, see `docs/git-setup.md` and the workarounds below ("Setup gotchas"). Toolbox isn't needed for the next phase of work — only required if you want to drag in marketplace assets.

---

## Phase 1 — pick a starter task

All five Phase 1 architectural questions are resolved (see `docs/ROADMAP.md` "Open questions" — links to ADRs 001–004). Phase 1 implementation is largely mechanical execution against the specs in `docs/specs/`.

Recommended order (foundations first):

1. ~~**(L) Migrate save persistence to ProfileService.**~~ **DONE 2026-05-01** — see session log below.
2. ~~**(M) Bump save schema to v3.**~~ **DONE 2026-05-01** — see session log below.
3. ~~**(S) Add 14+ new recipes** to `Recipes.luau` to reach 20+ total.~~ **DONE 2026-05-01** — 20 recipes (6 Pre-Alpha + 14 new), 18 unique potions in catalog. See session log below.
4. ~~**(L) Implement the remaining 7 potion effects** in `PotionEffects.luau`.~~ **DONE 2026-05-01** — 10 effect kinds total (3 Pre-Alpha + 7 new). Handler-table dispatch with per-kind stacking rules. 18 active potions in `Constants.POTIONS`. cosmeticGlow + harvestYield wired into actual gameplay; luck/reveal/spiritAttract exposed via helpers but await consumer systems; weatherSummon + timeShift are spec-mandated stubs (Phase 4).
5. ~~**Forest Spirits** — attraction + claim + roster + wander AI.~~ **DONE 2026-05-01** — see session log. New PassiveBonuses module + Spirits module. Models still need to be supplied at `ReplicatedStorage.SpiritModels.<spiritId>` for visual rendering; system is functionally complete without them.
6. ~~**Biome architecture** — refactor `MapSetup` and `WildSpawn` to be biome-parameterized.~~ **DONE 2026-05-01** — see session log. WildSpawn refactored to per-biome instances. New BiomeBuilder + Travel modules. Misty Hollow data + procedural WildSpawnArea live. Client atmosphere transition + Travel NPC UI deferred to a polish/UX pass.

Full Phase 1 task list with size markers: `docs/ROADMAP.md`.

---

## Setup gotchas worth knowing about

- **Studio's Toolbox panel doesn't always appear** even when toggled in View. Workarounds: try `File → Studio Settings → search "Toolbox"`, or fully uninstall + reinstall Studio. For now, marketplace assets can be brought in via `InsertService:LoadAsset(assetId)` in code if the Toolbox UI is unavailable.
- **Rojo doesn't sync during a Play session.** After editing a `.luau`, stop Play, wait ~2s for Rojo to push, then Play again.
- **Rojo + Studio plugin must be the same protocol version.** Project pins `rojo-rbx/rojo@7.7.0-rc.1` via `aftman.toml`. Run `rojo plugin install` from the project folder once to install the matching Studio plugin.
- **Terrain repaints are sticky once `Workspace.HasHandBuiltGround=true`.** To force `TerrainBuilder.build()` to re-run after editing it, paste in the Studio command bar:
  ```
  workspace.Terrain:Clear()
  workspace:SetAttribute("HasHandBuiltGround", nil)
  ```
- **Same pattern for Witch + Cauldron Parts**: MapSetup detects existing instances by name and skips re-placement. To force re-place after moving them, delete the existing ones in Studio first.
- **DataStore is unavailable in unpublished places** — `PlayerData.lua` pcalls and degrades gracefully. To enable saves: `File → Save to Roblox` + Game Settings → Security → Enable Studio Access to API Services.
- **Place is currently published** as "Mycelia" under RabidGunter's account. DataStore reads/writes work in Studio editor.
- **Don't push code from the work machine.** The work laptop pulls / does planning; the personal machine pushes. See `docs/git-setup.md` for the asymmetric multi-machine workflow.

---

## Recent session log

### 2026-05-03 — Phase 2 Trading Post (atomic two-player trade)
- New spec [docs/specs/trading-post.md](docs/specs/trading-post.md) — locks in three architectural decisions: in-memory active sessions (DataStore for audit log only), no Trading Post zone gate yet (placeholder Part at spawn), Adopt Me lock+countdown+confirm anti-scam UX.
- New module `src/server/Trade.luau` — full state machine (Pending → Open → Locked → Completed, with Cancelled as terminal). Pure helpers `Trade.canRequest`, `Trade.validateOffer`, `Trade.applyOffer`, `Trade.hasItem` (testable). Roblox-bound: 6 remote handlers (Request, Respond, Update, Lock, Confirm, Cancel), pending-request expiry sweeper, atomic execution with snapshot-rollback, audit log writer to `MyceliaAuditLog_v1` DataStore. Player disconnects mid-trade auto-cancel via PlayerRemoving.
- New client `src/client/TradeUI.client.luau` — five UI pieces:
  1. **HUD "Trade" button** below the Quest widget at top-right.
  2. **Player picker modal** — lists online players (excluding self) with a Request button per row.
  3. **Incoming-request toast** — Accept/Decline buttons, 30s auto-decline timeout.
  4. **Trade modal** — two side-by-side panels (your offer / their offer), 6-slot grids + coin input + lock button per side. Center status bar shows live countdown during Locked state. Footer Cancel + Confirm. Confirm enables only when both Locked and ≥5s elapsed.
  5. **Item picker submodal** — opens when an empty offer slot is clicked. Lists tradable items (mushrooms from legacy inventory + tradable items from inventoryByCategory.* with `tradable ~= false`), per-row qty stepper + Add button. Filters out items already in offer.
- 10 new REMOTES wired in `Constants.REMOTES`: RequestTrade, TradeRequestReceived, RespondToTradeRequest, TradeSessionStarted, UpdateTradeOffer, TradeOfferUpdated, LockTradeOffer, ConfirmTrade, CancelTrade, TradeCompleted.
- New tests `Tests/TradeSpec.luau` — 20 tests covering hasItem (mushroom + non-mushroom + unknown + malformed), validateOffer (happy + every error code + 6-item cap + empty), applyOffer (subtract/add symmetry + inventory cleanup + bucket creation), canRequest (happy + self-trade + already-in + cooldown).
- MapSetup additions: `buildTradingPostMarker` — wood platform + signpost at (25, 0.5, 0) with SurfaceGui label "Trading Post". Pure visual — backend works from anywhere via HUD button.
- Inventory split (Phase 2 reality, same as Shop UI): mushroom species → legacy `data.inventory`; non-mushroom items → `data.inventoryByCategory[item.category]`. `Trade.applyOffer` routes per item using `Species.byId` vs `Constants.ITEMS` lookup.
- Audit log: every trade outcome (Completed / Cancelled with reason) writes to `MyceliaAuditLog_v1` DataStore at key `trade_<sessionId>`. Append-only, never overwritten. pcall'd so DataStore failures don't abort trades.

**Verification pending in Studio:**
- Press Play → `Tests complete: ~253 passed, 0 failed` (~233 prior + ~20 in TradeSpec).
- Open two clients (Test → 2 players in Studio). Click "Trade" on player A → see player picker → click "Request" next to player B's name. Player B sees an incoming-request toast top-center with Accept/Decline.
- Accept → both players get the trade modal with empty offers. Both show "Editing".
- Click an empty slot in your offer → item picker opens listing your tradable items. Pick a quantity, Add. Slot fills, status banner re-renders for both clients.
- Type a coin amount in your CoinInput, lose focus → fires UpdateTradeOffer; both panels update.
- Click "Lock my offer" → my lock indicator goes green. Other side still "Editing". Click Lock on the other client too → status banner shows "Locked. 5s until you can confirm…" with live countdown.
- During countdown, if either side modifies an offer (clicks a filled slot to remove, picks a new item, edits coins) → both lock indicators clear, status returns to "Trading with…", countdown disappears.
- After 5s of stable Lock, Confirm button enables. Both clients click Confirm → atomic execution runs → "Trade complete!" toast on both → modal closes. Item / coin counts in inventory reflect the swap.
- Try the failure paths:
  - Open trade, then sell one of the items in your offer at the witch via a separate flow → click Confirm → trade cancels with "Trade cancelled — items moved during negotiation."
  - One player closes Studio mid-trade → other player gets "Trade cancelled — player disconnected."
  - Cancel button always works; trade ends with "Trade cancelled."

**Known follow-ups / not in this pass:**
- **Trading Post zone gate** — currently trades work from anywhere. Spec calls for a physical zone with travel portals from each biome. Adding the gate is a 1-line check in `Trade.canRequest` + a hand-built zone Part with `BasePart.Touched` membership tracking.
- **Per-remote rate limits.** Spec calls out: RequestTrade 1/20s (already implemented as cooldown), UpdateTradeOffer 10/s, LockTradeOffer 2/s, ConfirmTrade 2/s. Not implemented; relies on UI throttling for now. Server-side hardening lands when a malicious actor tries to spam.
- **Inventory mutation lock during trade.** Currently other systems can still mutate inventory mid-trade; confirmation re-validation catches this with a clean cancel. A real lock that *prevents* the other system from mutating (rather than detecting after the fact) is a Phase 3 anti-griefing item.
- **Spatial Voice integration.** Spec mentions it for Trading Post; Phase 3 polish.
- **Trade chat.** "Quick chat" preset messages between trade participants ("OK", "Add more", "Final offer") — Phase 3.
- **Player-stall pattern reuse.** The atomic-execution + audit-log primitives in Trade.luau are designed to be reused by Player Stalls (next Phase 2 item). When that lands, expect Stall.luau to call into a renamed `Trade.applyExchange` shared core.
- **Real Trading Post zone art.** Current marker is a wood platform. Real zone (per spec: physical place with travel portals, ambient music, NPC manager) is a follow-up.

### 2026-05-03 — Phase 2 launch NPCs (Travel Coordinator + 2 lore NPCs)
- New dialogue action `requestBiomeTravel` — server dispatcher (in Dialogue.luau ACTION_HANDLERS) calls a new public `Travel.requestTravel(player, biomeId)` wrapper. Both the existing RequestBiomeTravel remote and the dialogue action share the same validation + side-effect path.
- New `src/shared/Dialogues.luau` entries:
  - **TravelCoordinator** — wraps the Phase 1 Travel.luau backend in a player-facing dialogue. "Take me to Misty Hollow" response is gated by a `biomeUnlocked(biomeId)` condition closure that mirrors `Travel.canTravel` (renown + coin gates). Until the gate's met, "What's beyond the glade?" surfaces a lore explanation instead.
  - **OldHermit** — lore-only flavor NPC. Two branches (lunar mushrooms + deep biomes) drop spoiler-free hints at upcoming content (Glimmerwood / Lost Cathedral / lunar mechanics).
  - **WanderingAlchemist** — lore + brewing-tip flavor NPC. "Any tips?" describes the four methods without spoiling recipes; "What does it mean when a brew fizzles?" reframes failures as compounding lessons (the design-doc framing).
- New `biomeUnlocked` + `totalRenown` helpers at the top of Dialogues.luau — pure closures that work against PlayerData on either client or server. Documented as a future consolidation point with `Travel.canTravel`.
- `src/server/MapSetup.luau`:
  - Generic `buildDialogueNpc(name, dialogueId, position, color, actionText, objectText)` helper — same pattern as `buildMerchantStall` but tagged with `dialogueId`. Three callers: Travel Coordinator, Old Hermit, Wandering Alchemist.
  - `buildTravelCoordinator()` — anchored at the reserved `npcPositions.travelCoordinator` slot (-15, 2.5, 0) just west of spawn. Slate-grey placeholder.
  - `buildOldHermit()` — at (-40, 2.5, -25), western edge of the wild spawn area. Mossy green-brown placeholder.
  - `buildWanderingAlchemist()` — at (78, 2.5, 8), near the cauldron and witch stall. Warm purple placeholder to read alongside the witch's purple stall.
- `src/server/Travel.luau` — added public `Travel.requestTravel(player, biomeId)` wrapper. Both the remote handler and the dialogue dispatcher route through it. Internal `performTravel` is unchanged.
- `src/server/Dialogue.luau` — added `requestBiomeTravel` action handler + Travel module require.
- `src/server/Tests/DialoguesSpec.luau` — added `requestBiomeTravel` to KNOWN_ACTION_KINDS + new integrity test confirming every `requestBiomeTravel` action.biomeId references a real `Constants.BIOMES` entry.

**Verification pending in Studio:**
- Press Play → tests should still print `Tests complete: ~233 passed, 0 failed` (no count change — the new dialogue trees just exercise existing test helpers).
- Walk west of spawn → "Talk to Coordinator" prompt → press E → Travel Coordinator dialogue.
  - With 0 renown: see "What's beyond the glade?" (locked-lore branch). Misty Hollow option is hidden.
  - With 100+ renown (set via command bar: `local d = require(game.ServerScriptService.Server.PlayerData).get(game.Players.LocalPlayer); d.reputation.test = { score = 100 }`): see "Take me to Misty Hollow." → click → character teleports to (2000, _, 0) and `currentBiome` attribute flips to "MistyHollow".
- Walk far west to (-40, _, -25) → "Talk to Hermit" prompt → moody two-branch lore dialogue.
- Walk near the cauldron to (78, _, 8) → "Talk to Alchemist" prompt → enthusiastic brewing-tips dialogue.
- All three NPCs have `endDialogue` paths from every node (no dead ends).

**Known follow-ups:**
- **Spirit Speaker / Expedition Coordinator / Trading Post Manager** — three remaining launch NPCs are blocked on systems that haven't shipped yet (Spirits dialogue layer, Expeditions, Trading Post). Each is ~30 min of dialogue tree work once their backing system lands.
- **Travel Coordinator UX** — currently the only way to confirm travel succeeded is the BiomeTravelCompleted remote firing (no visible client toast). A small client toast tied to that remote is a polish-pass win.
- **Real character models** — all 5 launch NPCs are colored placeholder Parts. Real rigged models drop in when assets ship.

### 2026-05-03 — Phase 2 Quest system + 5-quest tutorial + Gardener Coach
- New spec [docs/specs/quest-system.md](docs/specs/quest-system.md) defining quest data shape, objective kinds, lifecycle (accept → progress → turn-in), reward delivery, and a narrative walkthrough of what the player sees through the 5 tutorial quests.
- New module `src/shared/Quests.luau` — pure data + pure helpers. 7 supported objective kinds (`harvest_wild`, `harvest_plot`, `plant_species`, `brew_attempt`, `brew_success`, `sell_to_merchant`, `consume_potion`). Helpers: `canAccept`, `canTurnIn`, `objectivesComplete`, `objectiveMatches`, `applyEvent`. All defensive against nil/malformed data.
- **5-quest tutorial sequence** in `Quests.byId`, all given by the Gardener Coach:
  1. **First Steps** — harvest 3 wild mushrooms → 25 coins.
  2. **A Place to Grow** — plant 1 spore patch → 50 coins.
  3. **The Witch Pays** — sell 5 mushrooms to Forest Witch → 1× Compost.
  4. **The Cauldron Calls** — use the cauldron once (any brew) → 1× BrownCapSpore.
  5. **A Recipe Discovered** — brew a valid recipe → 100 coins.
  Sequential prerequisites; quest 2 unlocks after 1, etc.
- New module `src/server/Quest.luau` — server-side dispatcher. `Quest.start(harvesting)` connects to existing Harvesting BindableEvents (no edit needed there), wires AcceptQuest/TurnInQuest/AbandonQuest remotes. `Quest.onEvent(player, kind, payload)` is the direct call site for non-BindableEvent modules. `Quest.startQuest` / `turnInQuest` / `abandonQuest` are dialogue-action entry points with full validation. Reward delivery routes coins to `data.coins` and items into the right inventory bucket (mushroom species → legacy `data.inventory`; non-mushroom items → `inventoryByCategory[item.category]`, matching the Phase 2 split).
- New dialogue tree `Dialogues.GardenerCoach` — single `greeting` root node with **conditional responses**: each quest's start + turn-in response is gated by a `condition` predicate (`Quests.canAccept` / `Quests.canTurnIn`) so the same node serves "first visit", "mid-tutorial", "ready to turn in", and "graduated" without multiple roots. Always-available "Tell me about the glade." (lore) + "Goodbye." responses too.
- Dialogue dispatcher extended (`src/server/Dialogue.luau`) — added `startQuest` and `turnInQuest` action handlers. DialoguesSpec's `KNOWN_ACTION_KINDS` updated; new integrity test confirms every `startQuest`/`turnInQuest` references a real quest.
- DialogueController client (`src/client/DialogueController.client.luau`) updated: caches `PlayerDataUpdated` and filters responses by `condition(data)` at render time. Mid-conversation re-render on PlayerDataUpdated lets the "ready to turn in" response appear live the moment the player completes the last objective.
- Event hooks added (minimal touch on existing modules):
  - `Brewing.luau` — fires `brew_attempt` after every brew + `brew_success` when a real potion resolves.
  - `Planting.luau` — fires `plant_species` after a successful plant.
  - `Shop.luau` — fires `sell_to_merchant` after every successful sell, with mushroom-count payload (so quest 3 can count items, not coins).
  - Harvesting needs no edit — Quest.start connects directly to its existing `WildHarvested` / `PlotHarvested` BindableEvents.
- New client UI `src/client/QuestController.client.luau` — two pieces:
  1. **HUD pinned widget** top-right: title + first incomplete objective + `current/count` in `accent.gold`. Hidden when no active quests. Click to open journal.
  2. **Quest Journal modal** — three tabs (Active / Completed / Available). Active tab shows progress bars per objective; Completed shows a green ✓; Available lists prereq-met-but-unstarted quests. Same modal pattern as ShopUI.
- New world build: `src/server/MapSetup.luau` adds `buildGardenerCoach()` — warm tan placeholder Part at (0, 3, 8), just north of the spawn pad with `dialogueId="GardenerCoach"` and ProximityPrompt "Talk to Coach". Hand-built escape valve auto-stamps the attribute if missing.
- Constants additions: REMOTES `AcceptQuest`, `TurnInQuest`, `AbandonQuest`.
- New tests: `Tests/QuestsSpec.luau` — 16 tests covering catalog integrity (every quest's required fields, every objective.kind in OBJECTIVE_KINDS, every prereq references a real quest, tutorial chain order), `canAccept` (happy + every rejection path), `objectiveMatches` (any/specific/mismatch/sell-by-npcId), `applyEvent` (progresses matching objectives, clamps at threshold, doesn't progress completed quests), `objectivesComplete` + `canTurnIn` (active+threshold edge cases). Plus the new DialoguesSpec test "startQuest / turnInQuest references real quests" — catches typos at startup.

**Verification pending in Studio:**
- Press Play → `Tests complete: ~233 passed, 0 failed` (~217 prior + ~16 in QuestsSpec).
- On spawn: HUD top-right is empty (no active quests yet). Walk to the tan Part just north of spawn, press E → Gardener Coach greeting + 3 visible responses ("Will you train me?", "Tell me about the glade.", "I'll be on my way.").
- Click "Will you train me?" → dialogue closes, HUD widget appears: `First Steps  •  Harvest wild mushrooms 0/3`.
- Walk to the wild spawn area, harvest 3 mushrooms → widget ticks 0/3 → 1/3 → 2/3 → 3/3 → "Ready to turn in ✓" in green.
- Walk back to Coach, press E → now sees "I have the three mushrooms." response (because `Quests.canTurnIn(data, "first_steps")` is now true). Click → 25 coins added, quest moves from Active to Completed in journal, HUD widget switches to "A Place to Grow • Plant a Spore Patch 0/1".
- Continue through all 5 quests. Final reward leaves the player with ~175 coins + 1× Compost + 1× BrownCapSpore + 5 quests in the Completed tab.
- Open the Journal (no HUD button yet — click the HUD widget itself to open). Tabs: Active / Completed / Available all populate correctly.

**Known follow-ups:**
- **Dedicated Journal HUD button.** Currently the journal opens via the HUD widget click, which works but disappears when no quest is active. A pinned "📜 Journal" button next to the Brewing Journal button is a small follow-up. (Could fold both journals into one tabbed UI.)
- **`giveItem` action handler.** Spec mentions it; not wired since no quest uses it. Trivial to add when needed.
- **Reward toasts.** Right now turn-in is silent (PlayerDataUpdated propagates the coin/item delta but no celebratory toast). Add a Quest-completed toast in a polish pass.
- **Side quests / repeatable dailies.** Schema supports `repeatable=true`. Wandering Alchemist + Old Hermit + others can hand out repeatables once their NPCs ship.
- **Gardener Coach visual.** Tan Part placeholder. Real character model when assets ship.

### 2026-05-03 — Phase 2 NPC dialogue system foundation
- New spec [docs/specs/dialogue-system.md](docs/specs/dialogue-system.md) defining tree-based dialogue: client-side navigation, server-side side effects, NPC anchor `dialogueId` attribute, mutual exclusivity with `merchantId`, action-kind dispatcher.
- New module `src/shared/Dialogues.luau` — pure-data tree storage indexed by `[npcId][nodeId]`. ForestWitch tree shipped (3 nodes: greeting + lore_intro + lore_moon; 4 unique action paths including `openShop` and `endDialogue`).
- New module `src/server/Dialogue.luau` — pure helpers (`findResponse`, `canExecuteAction`) + Roblox-bound `Dialogue.start()`. Listens for ProximityPrompts on `dialogueId`-tagged Parts, fires `OpenDialogue` to the player. Listens for `DialogueAction` from clients, validates response existence + talk range, dispatches via an action handler table (`openShop`, `endDialogue` for Phase 2; `giveItem` / `startQuest` slots reserved for the Quest system).
- New client `src/client/DialogueController.client.luau` — bottom-anchored card on mobile (max 560×360). Header: circular portrait placeholder (first letter of speakerName) + speakerName (Merriweather H2). Body line in Nunito body. Scrollable response list with 44pt buttons. Local navigation for `next`-bearing responses; fires DialogueAction for `action`-bearing ones; closes immediately on `endDialogue` to avoid an unnecessary server round-trip.
- Constants additions: REMOTES `OpenDialogue` + `DialogueAction`.
- Wiring: `init.server.luau` adds `Dialogue.start()` after `Shop.start()`. `RunTests.server.luau` registers `DialoguesSpec`.
- MapSetup change: witch stall swapped from `merchantId="ForestWitch"` to `dialogueId="ForestWitch"`. Hand-built escape valve auto-strips legacy `merchantId` if present. Prompt renamed `ShopPrompt` → `DialoguePrompt`. Substrate Dealer + Spore Merchant keep `merchantId` (no dialogue) — they go straight to the shop UI.
- Shop.luau prompt handler now skips Parts with a `dialogueId` attribute (defers to Dialogue.luau). Witch's "Sell mushrooms" greeting response triggers `openShop` action which the Dialogue server fires back as `OpenShop` to the player — same Shop UI, one extra click for character flavor.
- New tests: `Tests/DialoguesSpec.luau` — 11 tests covering schema integrity (rootNodeId resolves, no dead-end nodes, every response has exactly one of next/action, every next points to a real node, every action.kind is in the dispatcher set, every openShop targets a real merchant), plus `Dialogue.findResponse` / `Dialogue.canExecuteAction` happy + sad paths.

**Verification pending in Studio:**
- Press Play → `Tests complete: ~217 passed, 0 failed` (~206 prior + ~11 in DialoguesSpec).
- Walk to witch in cave → "Talk to Witch [E]" prompt → press E → dialogue card slides up at the bottom of the screen with the witch's greeting line + 3 response buttons.
- Click "I'd like to sell mushrooms." → dialogue closes, Shop UI opens with Sell tab populated. Same as before, plus one click of character flavor.
- Click "Tell me about the forest." → navigates locally to lore_intro node (no server round-trip; instant). Click "What kind of secrets?" → lore_moon node. "I'll remember that." → back to greeting.
- Click "Just passing through." or any "Goodbye" → dialogue closes instantly (no server round-trip, endDialogue is client-only).
- Substrate Dealer / Spore Merchant: no dialogue (they don't have `dialogueId`). Press E → Shop UI opens directly. Unchanged from yesterday.

**Known follow-ups:**
- **Real NPC portraits.** Currently a colored circle with the first letter of speakerName. Real character portraits (image asset IDs) drop in when the user supplies them; just set `tree.portrait = "rbxassetid://..."` and update the controller to swap the placeholder Frame for an ImageLabel.
- **Lockout on critical lines.** Spec calls for a typewriter animation + lock-until-fully-revealed on important lines. Phase 3 polish item.
- **Remaining launch NPCs.** Old Hermit, Wandering Alchemist, Spirit Speaker, Travel Coordinator, Expedition Coordinator, Trading Post Manager, Gardener Coach. Each is ~30 min of work: Dialogues.luau entry + anchor Part with `dialogueId`. Most useful next pickup is the Travel Coordinator (turns the existing `Travel.luau` backend into a player-visible NPC interaction) and the Gardener Coach (the tutorial guide for first 5 quests).
- **Quest system actions.** `giveItem` and `startQuest` action.kind handlers are stubbed in the spec but not in the dispatcher. Land with the Quest system commit.

### 2026-05-03 — Phase 2 secondary merchants (Substrate Dealer + Spore Merchant)
- New entries in `Constants.ITEMS`: 6 substrates (`Compost`, `Straw`, `Dung`, `Hardwood`, `Peat`, `MagicalLoam`) + 3 spore samples (`BrownCapSpore`, `FairyCupSpore`, `InkpotSpore`). All stackable, tradable, droppable=false. Spore items carry a `speciesId` reference for forward-compat with future Planting consumption.
- New entries in `Constants.MERCHANTS`: `SubstrateDealer` (sells the 6 substrates, 5–500 coin range) + `SporeMerchant` (sells the 3 spores, 10–60 coin range). Both sell-only — `buyCategories = {}`. Reputation hooks plumbed via the existing shim.
- `Constants.BIOMES.StarterGlade.npcPositions` updated: added `sporeMerchant` slot, renamed `substrateMerchant` → `substrateDealer` to match the merchantId. Coordinates: dealer at (15, 2, -8), merchant at (-12, 2, -8) — both flanking the spawn pad so the tutorial walks past them.
- New world-build helpers in `MapSetup.luau`: `buildMerchantStall` (generic anchor-Part-plus-prompt) + `buildSubstrateDealer` + `buildSporeMerchant`. Wired into `MapSetup.build()` after the witch stall. Same hand-built escape valve as the witch — pre-existing Parts get the merchantId attribute auto-stamped if missing.
- Tests added to `Tests/ShopSpec.luau` — full Buy-path coverage with real Phase 2 merchant data: SubstrateDealer Compost happy path, MagicalLoam-vs-100-coins insufficient-coins rejection, dealer rejecting mushroom IDs, sell-only invariant. Plus SporeMerchant multi-item-total math. Plus two new MERCHANTS integrity tests: every `itemsForSale.category` is a real `inventoryByCategory` key, and every `itemsForSale[itemId]` has a matching `Constants.ITEMS` entry. ~10 new tests; total ShopSpec count now ~40.

**Items are INERT until cultivation depth ships (Phase 3).** Players can buy substrates and spores, see them accumulate in `inventoryByCategory.substrates` / `.spores`, but no gameplay system reads from those buckets yet. Planting still uses the legacy "spend coins, plant species directly" flow. When the substrate-driven yield formula (ADR 002) lands, planting will consume from these buckets — the schema is ready and the items are bought-and-stored correctly. This is the same forward-compat pattern as the Reputation shim.

**Verification pending in Studio:**
- Press Play → `Tests complete: ~206 passed, 0 failed` (~196 prior + ~10 in expanded ShopSpec).
- Walk near spawn → see two new wooden-crate Parts with prompts: "Talk to Dealer" + "Talk to Merchant".
- Press E on each → ShopUI opens with the Buy tab visible (since the merchant has itemsForSale). Browse listings, select quantities, confirm. Coin balance ticks down; substrate/spore counts go up in `inventoryByCategory`.
- Sell tab on these merchants → "No mushrooms to sell." (since `buyCategories = {}` rejects everything). Confirm button is a no-op.
- Inventory bucket visibility: there's no UI listing `inventoryByCategory.substrates` yet. To verify items landed, command bar:
  ```
  game:GetService("ReplicatedStorage").Remotes.GetPlayerData:InvokeServer()
  ```
  (or peek at the server PlayerData via the future debug panel.)

**Known follow-ups:**
- **Spirit Food / Cosmetic / Decoration vendors** — same pattern, ~30 min each. Each needs Constants.MERCHANTS entry + Constants.ITEMS listings + a MapSetup anchor. Only blockers: deciding the actual item content (what does Spirit Food do, which cosmetic items launch with this commit, etc.) — those are content decisions.
- **Inventory UI for non-mushroom items.** Players can't see their substrate/spore counts in-game yet. A small panel listing `inventoryByCategory` contents lands in a future polish pass.
- **NPC visual upgrade.** All three Phase 2 merchants are colored cubes. Real character models / hand-built stalls happen in a polish pass.

### 2026-05-02 — Phase 2 Shop UI (replaces Pre-Alpha witch auto-sell)
- New shared spec [docs/specs/shop-ui.md](docs/specs/shop-ui.md) defining `Constants.MERCHANTS[npcId]` schema, Buy/Sell wire flow, validation matrix, the inventory split (Sell from legacy `data.inventory`; Buy into `inventoryByCategory.*`), and the Reputation shim contract.
- New visual-language spec [docs/specs/visual-language.md](docs/specs/visual-language.md) — game-wide palette, 6 rarity-tier colors, 7 biome palettes, UI surface tokens, typography (Merriweather/Nunito/Inconsolata), motion + spacing scales. Folded into `Constants.UI` for code consumers.
- Curated visual reference board [docs/visual-references.md](docs/visual-references.md) — external links (Stardew shop, Hollow Knight merchant, Cozy Grove / Ooblets via Game UI Database, Ghibli mood boards, cozy palette tools).
- New module `src/shared/Reputation.luau` — Phase 2 shim. `Reputation.add` is log-only until the full system lands; `Reputation.get` defensively reads `data.reputation[key].score` (already in v3 schema). Travel.luau still reads `data.reputation` directly — consolidation is a future cleanup.
- New module `src/server/Shop.luau` — pure helpers (`priceFor`, `totalSellPrice`, `canSell`, `canBuy`, `validateSell`, `validateBuy`) + Roblox-bound `Shop.start()` that wires the `BuyFromMerchant` / `SellToMerchant` remotes and the `OpenShop` fan-out from `ProximityPromptService`. Merchant routing is by `merchantId` attribute on the prompt's parent Part (not by prompt name) — generic for future merchants.
- New client `src/client/ShopUI.client.luau` — shared modal with Sell / Buy tabs, per-row qty stepper, running total in `accent.gold`, "sell-all" default (every row preselected at full inventory count → one Confirm click sells everything, preserving Pre-Alpha frictionless UX). Listens for `OpenShop`, fires Sell/Buy on Confirm, handles `ShopTransactionCompleted` with toast + close.
- Constants changes:
  - **Removed** `Constants.ECONOMY.witchPriceMultiplier`. Replaced by `Constants.MERCHANTS.ForestWitch.buyMultiplier = 1.0`. Note for [decisions/004-coin-economy.md](docs/decisions/004-coin-economy.md): the inflation lever cited there as `witchPriceMultiplier` is now this field.
  - **Added** `Constants.MERCHANTS` (ForestWitch entry; secondary merchants pending) and `Constants.MERCHANT_DEFAULTS`.
  - **Added** `Constants.UI` — full token table per visual-language.md.
  - **Added** REMOTES: `OpenShop`, `BuyFromMerchant`, `SellToMerchant`, `ShopTransactionCompleted`.
  - **Removed** REMOTES: `SellInventory`, `SellCompleted`.
- MapSetup change: witch stall Part now stamps `merchantId="ForestWitch"` attribute. Prompt renamed `SellPrompt` → `ShopPrompt` (action text "Talk to Witch") since dispatch is by attribute, not prompt name. Hand-built witch stalls (escape valve) get the attribute auto-stamped if missing.
- Wiring: `init.server.luau` swaps `Selling.start()` for `Shop.start()`. `Tests/RunTests.server.luau` swaps `SellingSpec` for `ShopSpec`.
- Removed files: `src/server/Selling.luau`, `src/server/Tests/SellingSpec.luau`, `src/client/SellToast.client.luau`. Confirmation toast is now built into ShopUI.
- Spec doc cleanup: `docs/specs/remote-api.md` — `SellInventory`/`SellCompleted` marked REMOVED with pointer to the new flow; `OpenShop` documented; `BuyFromMerchant` updated to atomic-table form (matches `SellToMerchant`).
- New tests: `Tests/ShopSpec.luau` — 30 tests covering priceFor (incl. merchant-multiplier scaling), totalSellPrice (preserves the SellingSpec numeric pins exactly), canSell/canBuy, validateSell (happy path + every error code), validateBuy (happy path + insufficient coins + unknown item), and Constants.MERCHANTS integrity (every `buyCategories` entry is a real `inventoryByCategory` schema key).

**Verification pending in Studio:**
- Press Play → `Tests complete: ~196 passed, 0 failed (166 prior + ~30 in ShopSpec)`. Adjust upward when verified.
- Walk to witch stall → prompt reads "Talk to Witch [E]" → press E → ShopUI opens with Sell tab populated, every species preselected at full count, total displayed in gold. Click Confirm → sale completes, toast shows "+N coins", UI closes, coin counter updates.
- With empty inventory → ShopUI opens, body shows "No mushrooms to sell." → Confirm button is a no-op (UI doesn't fire when nothing's selected).
- Manual coin-bar test: command bar `game:GetService("ReplicatedStorage").Remotes.SellToMerchant:FireServer("ForestWitch", { BrownCap = 1 })` from a player whose stall isn't in talk range → server fires `ShopTransactionCompleted` with `success=false, code="OUT_OF_RANGE"`.
- Reputation log line: every sell prints `[Reputation] +X.XX ForestWitch for <name>` — confirms shim is wired, no save data mutated.

**Known follow-ups / not in this pass:**
- **Secondary merchants** (Substrate, Spore, Spirit Food, Cosmetic, Decoration) have config slots reserved in spec but no in-world NPC. Each is a small follow-up: Constants.MERCHANTS entry + MapSetup-tagged anchor + (for sellers) Constants.ITEMS listings.
- **Reputation system itself** still pending. Shim no-ops `Reputation.add`. When the real system lands it'll consume the existing call sites without code changes.
- **Pre-Alpha dark-themed UIs** (Journal, Brew, Potion controllers) still use their own inline color values. Migration to `Constants.UI` happens lazily as each UI gets its next polish pass — not blocking.
- **Inventory v4 reconciliation** — Sell still reads `data.inventory` (legacy) while Buy writes to `data.inventoryByCategory.*`. Documented split. Full migration deferred to v4 prep per spec.

### 2026-05-01 — Phase 1 Biome architecture refactor + Misty Hollow data
- New `Constants.BIOMES` table with full configs for `StarterGlade` (matches existing layout) and `MistyHollow` (Phase 1 second biome). Single-place world with biomes at 2000-stud spacing per ADR 001. Schema covers spatial layout, wild-spawn config, lighting/atmosphere, weather distribution, available substrates, travel cost.
- Refactored `WildSpawn.luau` to be biome-parameterized. New entry: `WildSpawn.startBiome(biomeConfig, area, harvesting)` runs an independent spawn loop per biome with the biome's own `wildSpawnTable`, `wildSpawnCap`, `wildSpawnInterval`. Each spawned mushroom gets a `biomeId` attribute so harvest events scope back to the right spawner. Old `WildSpawn.start(area, harvesting)` shim preserved for backwards-compat (routes to startBiome with StarterGlade config).
- New module `BiomeBuilder.luau`. Walks `Constants.BIOMES`, ensures every biome has a `Workspace.Biomes.<biomeId>` Folder, builds a procedural `WildSpawnArea` BasePart per biome at the configured zone center + size 400×100×400. Hand-built escape valve per spec: if the Folder exists with attribute `BuiltManually = true`, BiomeBuilder leaves it alone (just verifies the area exists). For StarterGlade specifically, BiomeBuilder reuses MapSetup's legacy `Workspace.WildSpawnArea` to avoid double-spawning.
- New module `Travel.luau`. Handles `RequestBiomeTravel` remote: validates renown threshold (sum of `data.reputation[*].score`) + travel cost, deducts coins, moves player's HumanoidRootPart to `biome.spawnPoint`, sets `player:SetAttribute("currentBiome", biomeId)`, sets `data.stats.biomesUnlocked[biomeId] = true` defensively. Also stamps initial `currentBiome = "StarterGlade"` on player join. Pure helpers `Travel.totalRenown(data)` and `Travel.canTravel(data, biomeId)` are testable.
- 3 new remotes: `RequestBiomeTravel`, `BiomeTravelCompleted`, `BiomeUnlocked`.
- `init.server.luau` updates: requires `BiomeBuilder` + `Travel`. Replaces the single `WildSpawn.start(map.wildSpawnArea, Harvesting)` call with a loop over `BiomeBuilder.buildAll()` results (one `WildSpawn.startBiome` call per biome). `Travel.start()` runs alongside other gameplay systems.
- New tests: `Tests/BiomeConfigSpec.luau` covers schema integrity (every biome has all required fields), id-key match, unique unlockOrder, every wildSpawnTable entry references known species, weatherDistribution sums to 1.0 per biome, sanity bounds on zoneRadius and travelCostCoins. Also covers `Travel.totalRenown` (nil/empty/multi-NPC sum, defensive defaults) and `Travel.canTravel` (unknown biome, StarterGlade always-ok, MistyHollow renown gate, MistyHollow cost gate, success path).

**What's not in this pass (deferred):**
- **Client-side atmosphere transition.** Spec calls for a LocalScript that polls position, detects current biome, tweens Lighting + Atmosphere settings + crossfades ambient music on transition. Awaits user-supplied audio assets and an Atmosphere instance in Lighting; can ship as a polish pass.
- **Travel NPC dialogue UI.** The remote handler works (any client can fire `RequestBiomeTravel`), but there's no in-world Travel Coordinator NPC yet. Hand-built or to be built when NPCs are tackled.
- **Reputation-driven biome unlock notifications.** Spec calls for `Reputation.add` to re-check thresholds and fire `BiomeUnlocked` toasts. Reputation system isn't implemented yet — defensive `biomesUnlocked` flagging at travel time covers the gameplay path.
- **MapSetup full per-biome refactor.** MapSetup still hardcodes Starter Glade's spawn pad / witch / cauldron / plots. Future refactor moves the StarterGlade-specific build into BiomeBuilder so MistyHollow can have parallel SpawnPads, plot regions, etc. For now: MistyHollow's WildSpawnArea exists but it's just an invisible volume — there's no pad or plots there yet.

**Verification pending in Studio:**
- Press Play → `Tests complete: ~125 passed, 0 failed` (105 prior + ~14 in BiomeConfigSpec).
- Output should print BiomeBuilder progress + show `Workspace.Biomes.MistyHollow.WildSpawnArea_MistyHollow` in the Explorer.
- Walk over to `Vector3.new(2000, 5, 0)` (MistyHollow spawn) — should see wild mushrooms spawning there with the MistyHollow palette (BrownCap/FairyCup/Mossring + Hollowstem/Dewfern/occasional Glowmoss).
- From the command bar, fire travel manually:
  ```
  game:GetService("ReplicatedStorage").Remotes.RequestBiomeTravel:FireServer("MistyHollow")
  ```
  (Expect failure with `renownGate` until the player has 100 renown — manually set via the command bar to test: edit `PlayerData.get(game.Players.LocalPlayer).reputation.test = { score = 100 }`.)

### 2026-05-01 — Phase 1 Forest Spirits + PassiveBonuses
- New module `PassiveBonuses.luau` — symmetric to PotionEffects but for *permanent* (untimed) bonuses. Per-player registry of `{ kind → magnitude }` totals. Pure helper `sumFromSpirits(data, config)` is testable; recompute pass walks the active-roster spirits and sums per-kind magnitudes from `Constants.SPIRITS.bonuses`. Future sources (gamepasses, achievements) slot into the same pass.
- New module `Spirits.luau` — full attraction + claim + equip/unequip + wander AI per the spec. Pure helpers `rosterCapForData`, `holdingsFromData`, `attractionChancePerTick` are testable. Roblox-bound: attraction loop (per-player roll every 5 min summing baseChancePerHour for held + grown species, multiplied by spiritAttract potion); spawn from `ReplicatedStorage.SpiritModels.<spiritId>:Clone()` near the player's home point with claim ProximityPrompt + 5min despawn timer; atomic claim-and-revert handler that survives concurrent claims; equip/unequip remotes that move spirits between activeRoster and inactive in `data.spirits` and recompute PassiveBonuses; Heartbeat-driven idle/walking wander state machine.
- 6 launch spirits in `Constants.SPIRITS`: Common (Mossling, Spritefly, Dewdrop) + Rare (Lanternfox, Crystalmoth, Deerlet). Forest Mother (Legendary) is data-only — Phase 4 lunar event spawn. Full attraction maps populated for the 15 species.
- New `Constants.ITEMS` table (non-mushroom inventory items). First entry: `CrystalShard` — Crystalmoth's planned daily drop. Stackable, tradable, lives in `inventoryByCategory.tools`.
- Combined-bonus reads wired into gameplay code:
  - `Harvesting.harvestWild`: yield = `floor(1 * (1 + spirit_wildYield)) + potion_wildYieldBonus`
  - `Harvesting.harvestPlot`: same pattern with `harvestYield` kind
  - `Planting.attemptPlantSpecies`: ripeAt sampled with `potion_growthMultiplier × (1 - spirit_growthSpeed)` combined factor
  - All three formulas fall through to no-op (multiplier 1.0, bonus 0) when no spirits/potions are active — backwards compatible.
- New remotes registered: `ClaimSpirit`, `SpiritClaimCompleted`, `EquipSpirit`, `UnequipSpirit`, `PassiveBonusesUpdated`.
- `init.server.luau` now starts `PassiveBonuses.start()` then `Spirits.start()` after PotionEffects.
- Tests: new `Tests/SpiritsSpec.luau` covers: rosterCap with/without gamepass + nil-data fallback, holdings extraction (inventory + plots, deduplication, Empty-state exclusion), attraction-chance math (per-hour-to-per-tick, multi-species stacking, irrelevant-holdings ignore, potion multiplier scaling), PassiveBonuses summing (single + multi spirit, kind separation, defensive against missing-allOwned and unknown-spiritType entries), Constants.SPIRITS catalog integrity (every bonus → known kind, every spirit has a rarity tier).

**Spirit Models still need to be supplied at `ReplicatedStorage.SpiritModels.<spiritId>` (one Model per spirit type, named exactly the id).** Without them, attraction rolls succeed but `Spirits.spawn` warns and skips — system is functionally complete but visually invisible. Drop in any rigged Model named `Mossling` / `Spritefly` / `Dewdrop` / `Lanternfox` / `Crystalmoth` / `Deerlet` and they appear.

**Known stubs (deferred to later content/system phases):**
- Crystalmoth's daily Crystal Shard drop — spec mentions a midnight scheduler. Code structure ready; the actual `task.delay` to next-midnight isn't wired (Phase 1 was about the foundation, not LiveOps timing). Easy follow-up.
- Lanternfox dark-plot illumination — depends on biome lighting state.
- Deerlet daily favor (instant-ripen) — depends on per-day cooldown UI.
- Forest Mother — Phase 4 lunar event.

**Verification pending in Studio:**
- Press Play → tests should now show ~22 new (`SpiritsSpec` count: rosterCap 3, holdings 6, attractionChance 6, sumFromSpirits 6, catalog integrity 3 = 24) + previous 81 = ~105 total. Adjust upward when verified.
- Dry-run attraction: no SpiritModels exist → spawn warns + skips. Loop runs without error.
- With a SpiritModels.Mossling Model present + Mossring in inventory: wait one tick (5 min — set Constants.SPIRITS.attractionTickSeconds shorter for testing), spirit appears near player, claim with E, world Model swaps to active-roster instance, PassiveBonusesUpdated remote fires with `{ wildYield = 0.05 }`.

### 2026-05-01 — Phase 1 brewing: 7 new potion effect kinds wired up
- Extended `PotionEffects.luau` with 7 new effect kinds: `harvestYield`, `luck`, `reveal`, `spiritAttract`, `cosmeticGlow`, `weatherSummon`, `timeShift`. Total: 10 effect kinds.
- Refactored to a handler-table (`EFFECT_HANDLERS`) dispatch. Each kind specifies a `stack(old, new)` rule (max-of for most, min-of for growth, replace for cosmetic/weather), plus `onApply` and `onExpire` side-effect hooks. Replaces the previous if/elseif switch in `consumeInternal`.
- Pure helpers extended: `apply` accepts an optional `params` table (for kinds whose effect data doesn't fit in scalar magnitude — cosmetic color, weather kind). New `paramsOf` helper. `snapshot` now includes params for client rendering.
- New public query helpers on the Roblox-bound layer: `harvestYieldBonus`, `luckBonus`, `revealRadius`, `spiritAttractMultiplier`, `weatherSummonKind`, `isTimeShiftActive`. Existing `growthMultiplier` and `wildYieldBonus` unchanged.
- `cosmeticGlow` actually applies — creates a placeholder ParticleEmitter on the player's HumanoidRootPart, parents survives character respawn (re-applied in CharacterAdded hook). Texture is a default for now; will be swapped when the user supplies the cosmetic particle texture asset.
- `weatherSummon` and `timeShift` are stubs per spec — Weather and Lighting.localOverride systems aren't built yet (Phase 4). Both log a warning and update the active-effect chip on the HUD; no actual world change.
- Wired `harvestYield` bonus into `Harvesting.harvestPlot` — yield is now `1 + harvestYieldBonus`. `luck` and `reveal` are exposed via helpers but no consumer reads them yet (rare-variant logic + hidden mushrooms feature land later in Phase 1+).
- Updated `Constants.POTIONS` with 12 new active entries + 3 reactivated (Inkblot/Spotted/Glowmoss). 18 active potions total. All previously-inert Pre-Alpha potions now have effects.
- Added 14 new tests to `PotionEffectsSpec` covering: params storage in apply, paramsOf helper, snapshot params inclusion, and default values + active values for all 4 new query helpers (luck, harvestYield, reveal, spiritAttract).

**Verification done 2026-05-02:**
- ✓ Studio Play output: `Tests complete: 166 passed, 0 failed (166 total)`. All 6 Phase 1 task groups ship clean (ProfileService migration, save schema v3, 14 new recipes, 7 new potion effect kinds, Forest Spirits + PassiveBonuses, Biome architecture refactor + Misty Hollow + Travel).
- One-time gotcha encountered: existing player save data in DataStore was in raw v2 format (pre-ProfileService). ProfileService:LoadProfileAsync errored with `attempt to index nil with 'ActiveSession'`. Resolved by wiping the test player's record via command bar (`DataStoreService:GetDataStore("MyceliaPlayerData_v1"):RemoveAsync("u_" .. UserId)`). Future migrations between save backends should pre-migrate raw data into the new format rather than relying on the new backend to handle it.
- Second gotcha: orphan instances from the legacy project layout (`ServerScriptService.Tests`, etc.) still embedded in the saved place file caused old test specs to run alongside new ones. Resolved by deleting the orphan duplicates from Studio's Explorer. Future restructures should include a "delete orphans" cleanup pass in the same session.
- Brew + consume Inkblot Elixir → blue chip appears for 45s with kind "reveal" + magnitude 30. (No visible effect since hidden mushrooms aren't a thing yet, but the chip + countdown should work.)
- Brew + consume Crystal Essence → cosmeticGlow particle trail appears behind player character for 600s (5min). Effect persists across character respawn.
- Brew + consume Everdew Powder → Output should print `[PotionEffects] weatherSummon stub for ... Rainy ...`.

**Known follow-ups:**
- `luck` is exposed but no consumer reads it. When the cultivation-yield formula ships (per ADR 002), it should add `PotionEffects.luckBonus(player)` into the rare-variant chance calculation.
- `reveal` similarly waits for the hidden-mushroom feature in late-Phase content.
- `spiritAttract` waits for the Spirits system.
- `weatherSummon` + `timeShift` wait for Weather + Lighting.localOverride (Phase 4).
- Cosmetic glow texture is a placeholder; user-supplied particle texture asset will replace it in a future polish pass.

### 2026-05-01 — Phase 1 brewing: 14 new recipes + 12 new potions
- Added 14 new recipes to `Recipes.luau`, hitting the Phase 1 target of 20 total. Distribution per spec: 5 Easy (commons-only), 8 Mid (uncommons or specific common combos), 5 Hard (rares + epics + multi-rare).
- Two recipes are intentional alt-paths to existing potions (DewdropTonic from 2× FairyCup, InkblotElixir from Buttoncap + Inkpot) — light combinatorial encouragement so players who don't have one ingredient set might find another.
- Added 12 new potion catalog entries to `Potions.luau` (no new potions for the alt-paths). Each has displayName + description + rarity. Naming follows the loose convention from the spec (`*Powder` from dry-grind, `*Tonic`/`*Brew`/`*Infusion` from steep/boil, `*Elixir`/`*Cordial` from ferment, `*Essence` for refined/crystalline).
- Updated Potions.luau docstring: effects ARE now defined for some potions (the 3 from Pre-Alpha + 3 from Phase 1 task 4 once that lands). Inert potions still show "No effect yet" in the UI.
- Updated `RecipesSpec` byKey count from 6 → 20. Added 5 new tests: alt-paths, 3-Mossring StonecastInfusion, 3-ingredient SpiritcallTonic, dry_grind rares, and a cross-ref test confirming every recipe output exists in `Potions.byId`.

**Inert until next task:** the 12 new potions all have catalog entries but most lack `Constants.POTIONS` effect mappings. They'll appear in inventory + Brewing Journal but show "No effect yet" when consumed. Effect implementations land in the next Phase 1 task (the 7 remaining effect kinds).

### 2026-05-01 — ProfileService migration + save schema v3
- Vendored ProfileService at `src/server/Vendor/ProfileService.luau` (downloaded from MadStudioRoblox/ProfileService master).
- Rewrote `PlayerData.luau` to use ProfileService for session locking + autosave + retries. Public API (`get`, `update`, `save`) preserved so gameplay modules don't need updates. Replaced 4 separate lifecycle calls (`onPlayerAdded`, `onPlayerRemoving`, `startAutosaveLoop`, `saveAllOnShutdown`) with a single `PlayerData.start()` — autosave + shutdown handling are now ProfileService's responsibility.
- Bumped save schema to v3. Added v3 fields per `docs/specs/save-schema-v3.md`: `inventoryByCategory` (11 categories), `spirits`, `decorations`, `plots`, `reputation`, `activeQuests`, `gamepassesOwned`, `settings`, `auditTrail`, plus new `stats` counters (`totalRareVariants`, `totalPlotFailures`, `totalDistanceWalked`, `spiritsCollected`, `biomesUnlocked`, `questsCompleted`, `recipesAttempted`, `recipesDiscovered`).
- Wrote `migrate(data)` v2→v3 step. Idempotent (safe to run on already-v3 saves). Backwards compatible: legacy `data.inventory` and `data.potions` fields preserved so existing modules (Brewing, Harvesting, Planting, Selling, PotionEffects) work unchanged. Future phase work moves consumers to `inventoryByCategory.*` and v4 can drop the legacy keys.
- Updated `init.server.luau`: replaced 4 PlayerData calls with one `PlayerData.start()` and removed the BindToClose autosave block.
- Added `Tests/SaveSchemaSpec.luau` — 21 tests covering defaultData shape, v1→v3 migration, v2→v3 migration, idempotency, malformed-input handling. Total test count target: 95 (74 + 21). Registered in `RunTests.server.luau`.

**Verification pending in Studio:**
- Run Play and confirm Output shows `Tests complete: 95 passed, 0 failed`.
- Confirm `[ProfileService]: ...` startup logs (ProfileService prints its own version info on first load).
- Existing player saves (v2) should auto-migrate on first load. Confirm a Studio Play Solo session loads cleanly + the HUD shows expected coins/inventory.

**Known follow-up:**
- Constants.SAVE.autosaveInterval is now unused (ProfileService manages its own ~30s autosave). Leave the constant for now; remove in a future cleanup pass once we're sure nothing reads it.
- `data.inventory` + `data.inventoryByCategory.mushrooms_raw` don't auto-sync after migration — they're separate tables. Existing code reads/writes `data.inventory`; new v3-aware code (Phase 2+) reads `inventoryByCategory.mushrooms_raw`. Don't write to one and expect the other to update. Sync layer or full consumer migration goes in v4 prep.

### 2026-05-01 — Pre-Alpha port to new project structure
- Ported all 36 Pre-Alpha files from `mycelia/src/` into the new top-level `src/` layout.
- Renamed `.lua` → `.luau`. Renamed `Main.server.lua` → `init.server.luau`.
- Rewrote all `require(ServerScriptService.X)` to `require(ServerScriptService.Server.X)` to match the new project.json wrapper.
- Removed the three stub files (`server/init.server.luau`, `client/init.client.luau`, `shared/Hello.luau`).
- Created this HANDOFF.md at the project root (CLAUDE.md and CONTRIBUTING.md both reference it).
- Verification pending in Studio: re-Play and confirm world builds + tests pass + no broken require paths.

### Earlier (in `mycelia/HANDOFF.md`)
The legacy handoff document captures the full Pre-Alpha build history — gameplay scaffold, brewing foundation, terrain pass, mountain + cave + pond + koi, etc. Refer to that file for the long-form history of how Pre-Alpha was built. Once the new structure is verified working in Studio, that file is archive-only.

---

## Design rules locked in (don't break)

- **Server-authoritative everything.** Clients send intents via Remotes; server validates before any state mutation.
- **Tunables in `src/shared/Constants.luau`.** Anything balance-affecting (costs, durations, multipliers, drop rates) belongs there, not in logic files.
- **Species `id` never changes once shipped.** It's the save-data key.
- **No pay-to-win.** Robux unlocks time and cosmetics, never rare items, recipes, or trading advantages.
- **Match existing module conventions.** Don't introduce new patterns (OOP frameworks, dependency injection, alternative module structures) without writing an ADR first (see `docs/CONTRIBUTING.md`).
- **Pure-function modules get tests.** Server-side remote handlers get tests. See `docs/CONTRIBUTING.md`'s Definition of Done.

---

*Last touched: 2026-05-01. Last verified working: Pre-Alpha gameplay loop in legacy `mycelia/` structure (74 tests passing). Port to new `src/` structure complete; Studio verification pending.*
