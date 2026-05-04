# Quest System — Spec

Pure-data quest definitions + server-side state tracking + Quest Journal UI + HUD pinned widget. Phase 2 ships the foundation plus the **5-quest tutorial sequence** with the Gardener Coach NPC.

Pairs with [dialogue-system.md](dialogue-system.md): NPCs accept/turn-in via dialogue actions (`startQuest`, `turnInQuest`).

---

## Architecture summary

- **Pure-data quest definitions** in `src/shared/Quests.luau`. Each entry: id, title, description, givenBy NPC, objectives, rewards, prerequisites, repeatable flag.
- **Server-side state** in `data.activeQuests[questId] = { acceptedAt, progress = {[i] = count} }` and `data.stats.questsCompleted[questId] = true`. Both already exist in v3 schema.
- **Event-driven progress.** Gameplay modules (Harvesting, Planting, Brewing, Shop, PotionEffects) call `Quests.onEvent(player, eventName, payload)`. The Quest module updates objective progress for every active quest whose objective matches.
- **Dialogue-driven lifecycle.** Quests start and turn in through dialogue actions (`startQuest(id)` / `turnInQuest(id)`). No HUD-attached "Accept/Abandon" buttons in Phase 2 — keeps the social loop NPC-anchored.
- **Pure-helper coverage.** Server module exposes pure helpers (`isActive`, `isComplete`, `objectivesComplete`, `canAccept`, `canTurnIn`) so dialogue conditions and tests use the same source of truth.

---

## Data shape

### Quest definition

```lua
Quests.first_steps = {
    id           = "first_steps",
    title        = "First Steps",
    description  = "Brand-new gatherers spot wild mushrooms by their gentle glow. Pick three.",
    givenBy      = "GardenerCoach",
    objectives = {
        { kind = "harvest_wild", target = "any", count = 3, label = "Harvest wild mushrooms" },
    },
    rewards = {
        coins = 25,
        items = {},          -- { [itemId] = qty }, optional
    },
    prerequisites = {},      -- list of questId strings
    repeatable    = false,
}
```

### Objective fields
| Field | Type | Notes |
|---|---|---|
| `kind` | string | One of the supported event kinds (see below). |
| `target` | string | Either an itemId/speciesId, or `"any"` for wildcard. |
| `count` | number | Threshold to mark this objective complete. |
| `label` | string | Player-facing text for the journal/HUD. |

### Supported event kinds (Phase 2)
| Kind | Fires from | Payload |
|---|---|---|
| `harvest_wild` | Harvesting.WildHarvested BindableEvent | `{ speciesId, count }` |
| `harvest_plot` | Harvesting.PlotHarvested BindableEvent | `{ speciesId, count }` |
| `plant_species` | Planting.attemptPlantSpecies (success path) | `{ speciesId }` |
| `brew_attempt` | Brewing.start (any brew, success or fail) | `{}` |
| `brew_success` | Brewing.start (success only) | `{ potionId, isNewDiscovery }` |
| `sell_to_merchant` | Shop.handleSell (success only) | `{ npcId, items }` |
| `consume_potion` | PotionEffects.consume (server) | `{ potionId }` |

Adding a new kind: extend `Quests.OBJECTIVE_KINDS` in the data module + add the event firing site to whichever gameplay module owns the moment.

---

## Wire flow

### Accepting a quest
1. Player walks to NPC, opens dialogue.
2. Dialogue tree shows a response with `action = { kind = "startQuest", questId = "<id>" }`. Response only appears if `Quests.canAccept(data, questId)` is true (client-side `condition` filter).
3. Player clicks → client fires `DialogueAction`. Server's dialogue dispatcher routes to the new `startQuest` handler.
4. Server validates: questId exists, prerequisites met, not already active, not already completed (unless `repeatable=true`). Adds entry to `data.activeQuests`.
5. PlayerDataUpdated fires → client re-renders Quest Journal + HUD widget.

### Tracking progress
6. Player does something — harvests a mushroom. Harvesting fires `WildHarvested` BindableEvent.
7. Quest module is connected to those BindableEvents at startup. Walks every active quest, increments objectives whose kind matches and target matches (or is wildcard).
8. Updated progress lives in `data.activeQuests[questId].progress`. PlayerDataUpdated propagates.

### Turning in
9. Once all objectives hit their counts, `Quests.canTurnIn(data, questId)` returns true.
10. Dialogue's "Done with <X>." response (gated by `condition` checking canTurnIn) becomes visible.
11. Player clicks → DialogueAction → server's `turnInQuest` handler validates, then in one PlayerData.update:
    - Removes from `activeQuests`.
    - Sets `stats.questsCompleted[questId] = true`.
    - Awards rewards (coins, items into the right inventory bucket).
12. PlayerDataUpdated fires → journal moves quest to Completed tab, HUD widget switches to next active quest.

### Abandoning (optional, not used by tutorial but supported)
- `AbandonQuest(questId)` remote drops the quest from `activeQuests`. Quests with `repeatable=false` and the same id can still be re-accepted later — abandoning isn't a permanent lock-out for now.

---

## Tutorial 5-quest sequence

All given by **Gardener Coach** NPC (new — anchored at spawn). Each is a prerequisite of the next.

| # | id | Objective | Reward | Why |
|---|---|---|---|---|
| 1 | `first_steps` | Harvest 3 wild mushrooms | 25 coins | Teaches the harvest loop. |
| 2 | `a_place_to_grow` | Plant 1 Spore Patch (any species) | 50 coins | Teaches planting. |
| 3 | `the_witch_pays` | Sell 5 mushrooms to Forest Witch | 1× Compost | Sends them to the witch (introduces dialogue + Shop UI). |
| 4 | `the_cauldron_calls` | Drop ingredients in the cauldron once (any brew, success or fizzle) | 1× BrownCapSpore | Teaches the brewing action without spoiling recipes. |
| 5 | `a_recipe_discovered` | Discover your first valid recipe (a real potion appears) | 100 coins | The discovery moment. Graduates the player from tutorial. |

**Why this shape:** tracks the design's five-minute core loop verbatim (walk → harvest → plant → sell → brew → discover). Each step rewards modestly so the player has 175 coins + 1 Compost + 1 BrownCapSpore at tutorial end — enough to plant a couple of patches and try a deliberate brew.

---

## What the player sees — narrative walkthrough

### Spawn
Drop into the misty Starter Glade. A new pinned widget at top-right reads:
```
First Steps
  • Harvest wild mushrooms 0/3
```
A few yards away, a tan-cloaked NPC (Gardener Coach) stands near the spawn pad with a "Talk to Coach [E]" prompt.

### Talking to the Coach (first time)
Press E → dialogue card slides up:
> **Gardener Coach**
> "First time in the glade? The mushrooms here practically wave at you. Pick a few, and we'll talk about the rest."
>
> [Will you train me?]    [Just looking around.]    [Goodbye.]

Click "Will you train me?" → server starts `first_steps` → dialogue closes → HUD widget shows the active objective.

### Doing the first quest
Walk into the wild spawn area. Tap any glowing mushroom (BrownCap, FairyCup, Mossring, etc.). HUD widget updates: `0/3 → 1/3 → 2/3 → 3/3`. The objective text turns green when complete.

### Returning to the Coach
Press E → dialogue:
> **Gardener Coach**
> "Three mushrooms. Not bad for an afternoon. The land takes notice."
>
> [I have the three mushrooms.]    [Just chatting.]    [Goodbye.]

Click "I have the three mushrooms." → server turns in → 25 coins added → quest moves from Active to Completed in the Journal → HUD widget switches to:
```
A Place to Grow
  • Plant a spore patch 0/1
```

### Through quests 2–5
Same pattern — go do the thing, come back, hand it in. Each turn-in line reads a little wiser: the Coach speaks like he's seen all five-minute beginners come through this exact arc. The fifth quest finishes with:

> **Gardener Coach**
> "You discovered a recipe — that's not a small thing. From here, the forest is yours. Most of the land doesn't speak to those who haven't brewed once."
>
> [Thank you.]    [Goodbye.]

After turn-in, the HUD widget clears (no active quests). The Journal shows all 5 in the Completed tab. The player has ~175 coins, 1× Compost, 1× BrownCapSpore — enough to keep going on their own.

---

## Quest Journal UI

Three tabs (Nunito Bold, `forest.mid` underline on active):

- **Active** — currently-accepted quests. Each row: title (Merriweather), description (Nunito body, muted), objectives list with progress bars + counts in `accent.gold`, "Tracked" indicator on the one currently shown in the HUD.
- **Completed** — questsCompleted entries. Same row shape minus progress (replaced with a subtle ✓ in `state.success`). Sorted by completion order if we ever store that timestamp; otherwise alphabetical.
- **Available** — quests whose prerequisites are met but the player hasn't accepted. Shows the giver's name. Phase 2 doesn't actively populate this tab (the tutorial is sequential and dialogue-driven), but the tab exists so future side quests fit naturally.

Open via a "Journal" button in the HUD next to the Brewing Journal button. Same modal pattern as ShopUI / Brewing Journal.

## HUD pinned widget

Top-right corner. Compact card:
- Quest title (Merriweather H2, 16pt — small).
- First incomplete objective: label + `current/count` in `accent.gold`. (Multi-objective quests cycle through their objectives via the Journal — HUD only shows one at a time to keep cognitive load low.)
- Click to open the Journal.

If no active quest: widget hidden.

---

## Tests (`Tests/QuestsSpec.luau`)

Pure helpers covered:
- `Quests.byId` integrity — every quest has required fields, every objective.kind is in OBJECTIVE_KINDS, every prerequisite id exists.
- `Quest.canAccept(data, questId)` — happy path, missing prereqs, already active, already completed (non-repeatable).
- `Quest.canTurnIn(data, questId)` — incomplete objectives, complete objectives, not active, etc.
- `Quest.objectiveMatches(objective, eventKind, payload)` — kind match, target match, wildcard target, mismatch.
- `Quest.applyEvent(data, eventKind, payload)` — increments progress on matching active objectives, doesn't double-count, clamps at the count threshold.
- 5-quest sequence integrity — each prerequisite chains to the previous, no broken links.

Roblox-bound side (remote handlers + dialogue dispatch + reward delivery) — Studio integration testing, not unit tests.

---

## Dialogue action handlers (extend `Dialogue.luau`)

| `kind` | Server validation | Effect |
|---|---|---|
| `startQuest` | `Quest.canAccept(data, questId)` is true | Insert into `data.activeQuests`. |
| `turnInQuest` | `Quest.canTurnIn(data, questId)` is true | Apply rewards, mark complete, remove from active. |

Update [dialogue-system.md](dialogue-system.md) "Action shapes" table to mark these as Phase 2 shipped (was: future).

---

## Future-proofing

Adding a new quest:
1. Append entry to `Quests.byId`.
2. Add `startQuest` / `turnInQuest` responses to the giver's dialogue tree (with appropriate `condition` predicates).
3. If a new objective kind is needed, extend `Quests.OBJECTIVE_KINDS` + add the event firing site.
4. Run `QuestsSpec` — schema integrity catches typos.

Side quests (non-sequential, repeatable, optional dailies) work today via the same data shape — just set `repeatable=true` and put them on the Wandering Alchemist or Old Hermit instead of the Gardener Coach.

---

*Last touched: 2026-05-03. Status: foundation + tutorial sequence shipping in this commit.*
