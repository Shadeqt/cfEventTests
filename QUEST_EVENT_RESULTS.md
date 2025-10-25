# Quest Event Investigation Results
## Classic Era (1.12)

**Date:** October 25, 2025
**Purpose:** Document which quest events fire and when in WoW Classic Era
**Method:** Live testing with event listeners, hooks, and UI frame monitors

---

## Events Available in Classic Era

### ✅ Events That Fire (Confirmed)

| Event | Args | Description |
|-------|------|-------------|
| `QUEST_ACCEPTED` | questLogIndex, questId | Quest added to quest log |
| `QUEST_REMOVED` | questId | Quest removed from log |
| `QUEST_TURNED_IN` | questId, xpReward, moneyReward | Quest completion confirmed |
| `QUEST_COMPLETE` | (none) | Quest objectives finished (fires at NPC only, never in field) |
| `QUEST_PROGRESS` | (none) | Quest progress dialog shown |
| `QUEST_WATCH_UPDATE` | questId | Quest objective progress updated |
| `QUEST_DETAIL` | ??? | Quest details displayed |
| `QUEST_FINISHED` | (none) | Quest dialog closed |
| `QUEST_LOG_UPDATE` | (none) | Generic quest log change |
| `UNIT_QUEST_LOG_CHANGED` | unitId | Quest log changed for unit |
| `QUEST_GREETING` | (none) | Multi-quest NPC greeting menu (confirmed) |
| `BAG_UPDATE` | bagId | Bag contents changed |
| `PLAYER_ENTERING_WORLD` | isLogin, isReload | World entry/reload |

### ⚠️ Events That Fire Unreliably

| Event | Args | Description |
|-------|------|-------------|
| `QUEST_ITEM_UPDATE` | (none) | Quest item changed - UNRELIABLE: Fired in 2 of 7 turn-in tests, then never again. Do not rely on this event. |

### ❌ Events That Don't Fire (Not Triggered)

- `QUEST_POI_UPDATE` - Never observed during testing
- `QUEST_ACCEPT_CONFIRM` - Shared/escort quest prompt (scenario not tested)

### 🎣 UI Hooks (hooksecurefunc)

| Hook | When It Fires |
|------|---------------|
| `QuestLog_Update` | Quest log UI updates |
| `QuestInfo_Display` | Quest info shown at NPC |
| `QuestFrameProgressItems_Update` | Quest progress dialog shown |
| `AcceptQuest` | Player accepts quest from NPC |
| `AbandonQuest` | Player abandons quest |
| `CompleteQuest` | Player clicks to complete quest at NPC |
| `GetQuestReward` | Player selects reward choice (if applicable) |

---

## Event Flows

### 1. Login / UI Reload

```
PLAYER_ENTERING_WORLD → isLogin, isReload
  ↓
QUEST_LOG_UPDATE (×3)
```

---

### 2. Quest Log UI Interactions

**Opening/closing quest log:** No events fire (hooks only)

**Selecting different quests:** No events fire (hooks only)

---

### 3. Abandon Quest

```
QUEST_REMOVED → questId
  ↓
UNIT_QUEST_LOG_CHANGED → player
  ↓
QUEST_LOG_UPDATE
```

---

### 4. Accept Quest from NPC

```
QUEST_DETAIL → questStartItemID
  ↓
QUEST_FINISHED
  ↓
QUEST_ACCEPTED → questLogIndex, questId
  ↓
UNIT_QUEST_LOG_CHANGED → player
  ↓
QUEST_LOG_UPDATE
```

**Note:** `QUEST_FINISHED` fires while dialog is still open, before `QUEST_ACCEPTED`

---

### 5. Check Quest Progress (Incomplete)

```
QUEST_PROGRESS
  ↓
QUEST_FINISHED (×2)
```

---

### 6. Turn In Quest (Complete)

**6a. No Reward Choice:**

```
QUEST_COMPLETE
  ↓
QUEST_TURNED_IN → questId, xpReward, moneyReward
  ↓
QUEST_FINISHED
  ↓
QUEST_REMOVED → questId
  ↓
UNIT_QUEST_LOG_CHANGED → player
  ↓
QUEST_LOG_UPDATE
```

**6b. With Reward Choice:**

```
QUEST_COMPLETE
  ↓
QUEST_TURNED_IN → questId, xpReward, moneyReward
  ↓
QUEST_FINISHED
  ↓
QUEST_DETAIL (next quest)
  ↓
QUEST_LOG_UPDATE
  ↓
QUEST_REMOVED → questId
  ↓
UNIT_QUEST_LOG_CHANGED → player
  ↓
QUEST_LOG_UPDATE
```

**Note:** When NPC has another quest, it displays automatically before `QUEST_REMOVED`

**6c. Quest Chain at Multi-Quest NPC:**

```
QUEST_GREETING
  ↓
QUEST_PROGRESS
  ↓
QUEST_FINISHED (×2)
  ↓
QUEST_COMPLETE
  ↓
QUEST_TURNED_IN → questId, xpReward, moneyReward
  ↓
QUEST_FINISHED (×2)
  ↓
QUEST_DETAIL (new quest)
  ↓
QUEST_ACCEPTED (new quest)
  ↓ (same timestamp)
QUEST_REMOVED (old quest)
  ↓ (same timestamp)
BAG_UPDATE (×4)
  ↓
QUEST_LOG_UPDATE
```

**Note:** Quest chain completion triggers `QUEST_GREETING` first. New quest acceptance and old quest removal occur at same timestamp with quest items removed via `BAG_UPDATE`

---

### 7. Quest Progress Updates (Loot Items / Kill Mobs)

```
QUEST_WATCH_UPDATE → questId
  ↓
UNIT_QUEST_LOG_CHANGED → player
  ↓
QUEST_LOG_UPDATE
```

**Note:** `QUEST_WATCH_UPDATE` fires with **stale data** - see "Key Observations" section for critical timing details.

---

### 8. Quest Item Removal During Turn-In

**🚨 CRITICAL: Event order is HIGHLY INCONSISTENT**

| Pattern | Event Sequence | QUEST_ITEM_UPDATE Fired? |
|---------|----------------|--------------------------|
| A | `QUEST_TURNED_IN` → `QUEST_REMOVED` → `BAG_UPDATE` → `QUEST_ITEM_UPDATE` | ✅ Yes (~6ms after BAG_UPDATE) |
| B | `QUEST_REMOVED` → `BAG_UPDATE` → `QUEST_ITEM_UPDATE` → `QUEST_TURNED_IN` | ✅ Yes (~6ms after BAG_UPDATE) |
| C | `QUEST_COMPLETE` → `QUEST_REMOVED` → `BAG_UPDATE(×2)` → `QUEST_TURNED_IN` → `BAG_UPDATE(×4)` | ❌ No |
| D | `QUEST_COMPLETE` → `QUEST_TURNED_IN` → `QUEST_LOG_UPDATE` → `QUEST_REMOVED` → `BAG_UPDATE(×2)` | ❌ No |
| E | `QUEST_COMPLETE` → `QUEST_TURNED_IN` → `QUEST_ACCEPTED` → `QUEST_REMOVED` → `BAG_UPDATE(×4)` | ❌ No |

**Key Findings (7 turn-ins tested):**
- `QUEST_TURNED_IN` and `QUEST_REMOVED` fire in **completely random order**
- `QUEST_ITEM_UPDATE` is **UNRELIABLE** (fired in only 2 of 7 tests = 29% reliability)
- `BAG_UPDATE` is the **ONLY consistent indicator** for quest item removal
- Items removed at turn-in dialog, NOT when objectives complete

---

### 9. Quest Item Bag Operations

**Split Stack:**
```
QUEST_LOG_UPDATE (×2)
```

**Delete Item:**
```
UNIT_QUEST_LOG_CHANGED → player
  ↓
QUEST_LOG_UPDATE
```

**Note:** Neither operation fires `QUEST_WATCH_UPDATE` - only `QUEST_LOG_UPDATE` events

---

## Key Observations

### ⚠️ CRITICAL: Quest Data Update Timing

**`QUEST_WATCH_UPDATE` fires BEFORE quest data updates:**

- ❌ **At event fire:** Quest log data is **STALE** (shows OLD progress count)
- ✅ **After ~50-200ms:** Quest data is updated (by the time `QUEST_LOG_UPDATE` fires)

**Example Timeline:**
```
1. You loot the 3rd quest item
2. QUEST_WATCH_UPDATE fires → Quest log still shows "2/15" (OLD)
3. ~100ms passes...
4. QUEST_LOG_UPDATE fires → Quest log now shows "3/15" (NEW)
```

---

### Event Timing Summary

| Action | Key Events (in order) |
|--------|----------------|
| **Accept Quest** | `QUEST_DETAIL` → `QUEST_FINISHED` → `QUEST_ACCEPTED` → `UNIT_QUEST_LOG_CHANGED` → `QUEST_LOG_UPDATE` |
| **Abandon Quest** | `QUEST_REMOVED` → `UNIT_QUEST_LOG_CHANGED` → `QUEST_LOG_UPDATE` |
| **Loot/Kill Quest Objective** | `QUEST_WATCH_UPDATE` (stale) → `UNIT_QUEST_LOG_CHANGED` → `QUEST_LOG_UPDATE` (updated) |
| **Turn In Quest** | `QUEST_COMPLETE` → **Unordered:** `QUEST_TURNED_IN`, `QUEST_REMOVED`, `BAG_UPDATE` → `QUEST_LOG_UPDATE` |
| **Quest Chain Turn-In** | `QUEST_GREETING` → `QUEST_COMPLETE` → `QUEST_TURNED_IN` → `QUEST_ACCEPTED` (new) + `QUEST_REMOVED` (old) → `BAG_UPDATE` → `QUEST_LOG_UPDATE` |
| **Split/Delete Quest Item** | `UNIT_QUEST_LOG_CHANGED` → `QUEST_LOG_UPDATE` |

---

## Untested Scenarios

### High Priority

These scenarios are essential for understanding quest item state changes:

1. **Complete multiple objectives simultaneously** - Quest with "Kill 10 mobs AND collect 2 items" where 10th kill drops the 2nd item

### Medium Priority

Common quest scenarios:

2. **Loot quest item from world object/container** - Clickable chest, crate, or world object that gives quest items (not mob loot)
3. **Accept quest from item (quest starter item)** - Right-click item in bags to start quest (e.g., "A Sealed Letter")
4. **Decline quest at NPC dialog** - View quest details but click "Decline" instead of "Accept"

### Lower Priority

Edge cases and rare scenarios:

5. **Shared/escort quest prompts** - Acceptance flow for shared/escort quests
6. **Quest item used from inventory** - Using quest item from bags to progress quest (plant banner, activate item)
7. **Repeatable/daily quests** - Event patterns for repeatable quest acceptance
8. **Timed quest expiration/failure** - Events when timed quest expires
9. **Quest progress from exploration** - Discovering location that updates quest objectives
10. **Quest auto-complete** - Quest completes without returning to NPC (may not exist in Classic Era)

---

## Summary

### Event Categories

**Quest Lifecycle (quest added/removed from log):**
- `QUEST_ACCEPTED` - Quest added to log
- `QUEST_REMOVED` - Quest removed from log
- `PLAYER_ENTERING_WORLD` - Login/reload

**Quest Progress (quest remains in log):**
- `QUEST_WATCH_UPDATE` - Objective progress updated
- `QUEST_COMPLETE` - All objectives finished
- `QUEST_TURNED_IN` - Quest completed (but not removed yet)

**Quest UI (display only, no data changes):**
- `QUEST_DETAIL` - Viewing quest details
- `QUEST_PROGRESS` - Checking incomplete quest
- `QUEST_FINISHED` - Dialog closed

**Generic Changes:**
- `QUEST_LOG_UPDATE` - Any quest-related change (fires 1-3× per action)
- `UNIT_QUEST_LOG_CHANGED` - Quest log changed (fires 1× per action)

### Events Not Triggered or Scenario Not Tested

- `QUEST_POI_UPDATE` - Quest marker updates (never observed)
- `QUEST_ACCEPT_CONFIRM` - Shared/escort quest (scenario not tested)

**Note on `QUEST_ITEM_UPDATE`:** This event is **UNRELIABLE** in Classic Era 1.12. Across 7 quest turn-ins tested (collection and delivery quests), it fired in only 2 tests (~29%), then never again. When it did fire, it occurred ~6ms after `BAG_UPDATE`. Does NOT fire when looting quest items - `QUEST_WATCH_UPDATE` handles that instead. **Do not build addon logic around this event** - use `BAG_UPDATE` as the reliable indicator for quest item changes.
