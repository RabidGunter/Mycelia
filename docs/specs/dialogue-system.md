# NPC Dialogue System — Spec

Tree-based dialogue for every NPC interaction in Mycelia. Replaces the direct-prompt-opens-shop flow for narrative-bearing NPCs (Forest Witch first; Old Hermit, Travel Coordinator, Quest Coach, etc. follow). Lightweight stall merchants (Substrate Dealer, Spore Merchant) keep their direct-shop pattern.

This is a Phase 2 foundation system. Quest system + Trading Post Manager + Expedition Coordinator all consume this — the API surface needs to stay stable from this commit forward.

---

## Architecture summary

- **Pure-data dialogue trees** in `src/shared/Dialogues.luau`, indexed by `[npcId][nodeId]`. Pure data: testable, replicable to client without serialization.
- **Client-side navigation.** Client receives `OpenDialogue({npcId, startNodeId})`, walks the local tree, renders the current node, handles response selection. No round-trip per click.
- **Server-side side effects.** When a response carries an `action`, the client fires `DialogueAction(npcId, nodeId, actionId)` to the server. Server validates (player still in talk range, action exists in that node, action result is allowed) and applies the side effect (open shop, give quest, give item, etc.).
- **Mutual exclusivity at the anchor.** An NPC anchor Part has *either* `dialogueId` OR `merchantId` (or both — see "merchant + dialogue" below). `Shop.luau`'s prompt handler defers to dialogue if `dialogueId` is present; `Dialogue.luau`'s prompt handler defers to shop if `dialogueId` is absent.

---

## Data shape

### Dialogue tree

```lua
Dialogues.ForestWitch = {
    rootNodeId = "greeting",                     -- where dialogue starts
    portrait   = "rbxassetid://0",               -- placeholder; user supplies
    speakerName = "Forest Witch",                -- shown above the line
    nodes = {
        greeting = {
            text = "Welcome, gatherer. What brings you to my stall today?",
            responses = {
                { id = "sell",   text = "I'd like to sell mushrooms.", action = { kind = "openShop", npcId = "ForestWitch" } },
                { id = "lore",   text = "Tell me about the forest.",    next = "lore_intro" },
                { id = "leave",  text = "Just passing through.",        action = { kind = "endDialogue" } },
            },
        },
        lore_intro = {
            text = "The forest is older than memory. Many secrets sleep beneath the moss.",
            responses = {
                { id = "back",   text = "Tell me more.",                next = "lore_deeper" },
                { id = "leave",  text = "I should go.",                 action = { kind = "endDialogue" } },
            },
        },
        ...
    },
}
```

### Node fields
| Field | Type | Required | Notes |
|---|---|---|---|
| `text` | string | yes | The line spoken by this NPC. Always English in Phase 2. |
| `responses` | `{Response}` | yes | At least one. Players need a way out of every node. |
| `condition` | `(data) -> boolean` | no | If false, this node is skipped (parent's response auto-routes to fallback). For future quest-gated dialogue. |

### Response fields
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Unique within the node. |
| `text` | string | yes | The button text shown to the player. |
| `next` | string | one of next/action | Target nodeId for client to navigate to. |
| `action` | Action | one of next/action | Side-effect descriptor. Triggers server validation + ends client navigation (most actions close the dialogue). |

### Action shapes (Phase 2)

| `kind` | Args | Effect |
|---|---|---|
| `openShop` | `{ npcId: string }` | Server fires `OpenShop` remote to player; client closes dialogue + opens Shop UI. |
| `endDialogue` | none | Client closes dialogue UI. No server-side effect. (Optionally we could log "talked to NPC X" for daily-greeting tracking.) |
| `giveItem` (future) | `{ itemId: string, quantity: number }` | Server adds item to player inventory (validated against quest gates). Lands when first quest reward needs it. |
| `startQuest` (future) | `{ questId: string }` | Server registers quest in `data.activeQuests`. Lands with the Quest system. |

Future actions (one-time-giveable rewards, biome unlocks, sound triggers, etc.) extend the dispatch table in `Dialogue.luau`.

---

## Wire flow

### Player initiates
1. Walks within ProximityPrompt range of an anchor Part with attribute `dialogueId="<npcId>"`.
2. Presses prompt key. `ProximityPromptService.PromptTriggered` fires server-side.
3. Server's `Dialogue.start()` reads the `dialogueId` attribute, looks up `Dialogues[npcId]`, fires `OpenDialogue({npcId, startNodeId = tree.rootNodeId})` to the player.

### Client navigates
4. `DialogueController.client.luau` receives `OpenDialogue`. Looks up `Dialogues[npcId]`, renders the start node's text + response buttons.
5. Player clicks a response.
   - If `next`: client renders that node. No server traffic.
   - If `action`: client fires `DialogueAction(npcId, nodeId, responseId)` to server.

### Server validates + applies action
6. Server checks: NPC anchor exists, player within `Constants.MERCHANT_DEFAULTS.talkRange` of it, response is a real response on that node, action is in the dispatch table.
7. Server applies the side effect. For `openShop`: fires `OpenShop` to the player. For `endDialogue`: no-op.

### Client wraps up
8. For `openShop`: client closes dialogue UI. Then receives `OpenShop` and opens Shop UI.
9. For `endDialogue`: client closes dialogue UI immediately on local click (no server confirmation needed).

---

## UI surface

Per [visual-language.md](visual-language.md):
- **Bottom-anchored card** on mobile (60% of screen height max), centered card on desktop. Doesn't fill the screen — preserves world visibility.
- **Header:** speaker portrait (left, 64×64 circle) + `speakerName` (Merriweather H2). For Phase 2, portrait is a colored circle with NPC initials — real assets land in polish pass.
- **Body:** node `text`. Nunito body, line-height 1.4, generous padding. **No typewriter animation in Phase 2** — text appears instantly. Lockout-on-critical-lines is a Phase 3 polish item.
- **Responses:** list of buttons stacked vertically. Each is `parchment.recessed` background with `text.primary` text. 44pt min tap target. Up to 4 responses per node before the list scrolls.
- **No "Continue" button** — every line has explicit responses. Even "OK" / "I see" leads somewhere.

### Walk-away auto-close

Client runs a throttled (4Hz) Heartbeat check while dialogue is open: if the player's HumanoidRootPart drifts more than `MERCHANT_DEFAULTS.talkRange + 4` studs from the NPC anchor, the dialogue closes. Same behavior on character death/respawn (HRP missing → close). Server still re-validates talk range when any side-effect action fires, so this is purely UX — a player can't game the auto-close to fire actions from out of range.

---

## Tests (`Tests/DialoguesSpec.luau`)

Pure-function coverage:
- Every `npcId` in `Dialogues` has a `rootNodeId` that exists in its `nodes`.
- Every response's `next` references a node that exists.
- Every response has exactly one of `next` or `action` (not both, not neither).
- Every action's `kind` is in the known set: `openShop`, `endDialogue` (Phase 2). Test fails when a future action shows up un-wired.
- Every node has at least one response (no dead ends).

Server dispatcher coverage (`Tests/DialogueServerSpec.luau`, optional — could fold into DialoguesSpec):
- `Dialogue.canExecuteAction` (pure helper) returns true for valid (npcId, nodeId, responseId) tuples; false for fabricated ones. Anti-cheat invariant.

Roblox-bound bits (UI rendering, prompt routing) get Studio integration testing, not unit tests.

---

## Migration from Shop UI direct-prompt

The Forest Witch currently has `merchantId="ForestWitch"` and the prompt opens shop directly. With dialogue:
- Witch anchor swaps `merchantId` for `dialogueId="ForestWitch"`. Shop.luau prompt handler now skips it.
- Dialogue tree for ForestWitch has a "Sell mushrooms" response with `action = { kind = "openShop", npcId = "ForestWitch" }`.
- One extra click for the player on the happy path: prompt → greeting → "Sell mushrooms" → shop. The greeting is short enough to feel like character flavor, not friction.

Substrate Dealer + Spore Merchant keep `merchantId` (no dialogue). They get dialogue trees in a future commit when a designer wants to flavor them.

---

## Future-proofing

Adding a new NPC dialogue tree requires:
1. New `Dialogues.luau` entry.
2. NPC anchor Part with `dialogueId="<npcId>"` attribute (MapSetup or hand-built).
3. Run tests — DialoguesSpec catches malformed trees automatically.

Adding a new action `kind`:
1. Extend `Dialogue.luau`'s action dispatch table.
2. Update DialoguesSpec known-kinds list.
3. Trees can immediately reference the new action.

Localization is deliberately out of scope for Phase 2. If/when needed: `node.text` becomes a translation key, server fires translations alongside the `OpenDialogue` payload. Schema is forward-compatible.

---

*Last touched: 2026-05-03. Status: foundation shipping in this commit; tutorial quest tree depends on this.*
