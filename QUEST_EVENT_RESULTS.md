# WoW Classic Era: Quest Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing:** Quest acceptance, abandonment, progress tracking, turn-ins, quest chains

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 13 quest-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `QUEST_ACCEPTED` | ✅ | 1× per quest accept | Reliable |
| `QUEST_REMOVED` | ✅ | 1× per quest removal | Reliable |
| `QUEST_TURNED_IN` | ✅ | 1× per turn-in | **Random order with QUEST_REMOVED** |
| `QUEST_COMPLETE` | ✅ | 1× per completion | Only fires at NPC, never in field |
| `QUEST_WATCH_UPDATE` | ✅ | 1× per progress | **STALE DATA - fires before update** |
| `QUEST_LOG_UPDATE` | ✅ | 1-3× per action | **FRESH DATA - use for actual data** |
| `UNIT_QUEST_LOG_CHANGED` | ✅ | 1× per action | Reliable |
| `QUEST_DETAIL` | ✅ | 1× per dialog | Quest details shown |
| `QUEST_FINISHED` | ✅ | 1-2× per dialog | Dialog closed |
| `QUEST_PROGRESS` | ✅ | 1× per check | Incomplete quest check |
| `QUEST_GREETING` | ✅ | 1× per multi-quest NPC | Multi-quest menu |
| `BAG_UPDATE` | ✅ | 2-4× per item change | **Only reliable quest item indicator** |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× per login/reload | Initialization |

### Events That Fired Unreliably
| Event | Fired? | Reliability | Notes |
|-------|--------|-------------|-------|
| `QUEST_ITEM_UPDATE` | ⚠️ | 29% (2/7 tests) | **UNRELIABLE - Do not use** |

### Events That Did NOT Fire
| Event | Status | Reason |
|-------|--------|--------|
| `QUEST_POI_UPDATE` | ❌ | Never observed during testing |
| `QUEST_ACCEPT_CONFIRM` | ❌ | Shared/escort quests not tested |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `AcceptQuest` | ✅ | 1× per accept | **CONFIRMED** - Fires on quest acceptance |
| `DeclineQuest` | ✅ | 1× per decline | **CONFIRMED** - Fires on quest decline |
| `CompleteQuest` | ✅ | 1× per completion | **CONFIRMED** - Fires on quest completion |
| `GetQuestReward` | ❌ | Not tested | No reward choices available during testing |
| `QuestLog_Update` | ✅ | **Very frequent** | **HIGHLY ACTIVE** - Fires on almost any quest action |
| `QuestInfo_Display` | ✅ | 1× per dialog | **CONFIRMED** - Quest info display |
| `QuestFrameProgressItems_Update` | ✅ | Multiple per session | **CONFIRMED** - Progress dialog updates |

### Tests Performed Headlines
1. **Login/Reload** - QUEST_LOG_UPDATE (3×) initialization
2. **Accept Quest** - QUEST_DETAIL → QUEST_ACCEPTED flow (**"Oh Brother..." quest accepted**)
3. **Quest Dialog Interactions** - Multiple QUEST_GREETING and QUEST_FINISHED cycles
4. **Hook Testing** - Comprehensive `/testquesthooks` command validation
5. **Quest Progress Checking** - QUEST_PROGRESS events with incomplete quests
6. **Real NPC Interactions** - Actual quest giver conversations and state changes
7. **Quest Log Management** - QuestLog_Update hook firing frequently during interactions

---

## Quick Decision Guide

### Event Reliability for AI Decision Making
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `QUEST_LOG_UPDATE` | 100% | Low | ✅ **PRIMARY** - Fresh quest data (use for actual progress) |
| `QUEST_ACCEPTED` | 100% | Low | ✅ Quest acceptance detection |
| `QUEST_REMOVED` | 100% | Low | ✅ Quest removal detection |
| `BAG_UPDATE` | 100% | Medium | ✅ **ONLY reliable quest item tracking** |
| `QUEST_WATCH_UPDATE` | 100% | Low | ⚠️ **STALE DATA** - fires before update (wait for LOG_UPDATE) |
| `QUEST_TURNED_IN` | 100% | Low | ⚠️ Random order with QUEST_REMOVED |
| `QUEST_ITEM_UPDATE` | 29% | Low | ❌ **UNRELIABLE** - Never use |

### Use Case → Best Event Mapping
- **Track quest progress:** `QUEST_LOG_UPDATE` (fresh data, fires after WATCH_UPDATE)
- **Detect quest acceptance:** `QUEST_ACCEPTED` (reliable, provides quest ID)
- **Detect quest removal:** `QUEST_REMOVED` (reliable, but random order with TURNED_IN)
- **Track quest items:** `BAG_UPDATE` (only reliable method for item changes)
- **Avoid progress tracking:** Never use `QUEST_WATCH_UPDATE` alone (stale data)
- **Avoid item tracking:** Never use `QUEST_ITEM_UPDATE` (29% reliability)

### Critical AI Rules
- **QUEST_WATCH_UPDATE has STALE data** (shows old progress, wait for QUEST_LOG_UPDATE)
- **Event order is random** (QUEST_TURNED_IN and QUEST_REMOVED fire in random order)
- **QUEST_ITEM_UPDATE is broken** (29% reliability, never use)
- **BAG_UPDATE is the only reliable quest item indicator**
- **QUEST_COMPLETE only fires at NPCs** (never in the field)

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Accept Quest: QUEST_DETAIL → QUEST_FINISHED → QUEST_ACCEPTED → UNIT_QUEST_LOG_CHANGED → QUEST_LOG_UPDATE
Abandon Quest: QUEST_REMOVED → UNIT_QUEST_LOG_CHANGED → QUEST_LOG_UPDATE
Progress Update: QUEST_WATCH_UPDATE (stale) → UNIT_QUEST_LOG_CHANGED → QUEST_LOG_UPDATE (fresh)
```

### Unpredictable Sequences (Random order)
```
Turn In Quest: QUEST_COMPLETE → [RANDOM ORDER: QUEST_TURNED_IN, QUEST_REMOVED, BAG_UPDATE] → QUEST_LOG_UPDATE
Quest Chain: QUEST_GREETING → QUEST_COMPLETE → QUEST_TURNED_IN → [SAME TIMESTAMP: QUEST_ACCEPTED + QUEST_REMOVED] → BAG_UPDATE → QUEST_LOG_UPDATE
```

### Critical Timing Pattern
```
Progress Update Timeline:
1. Player loots quest item
2. QUEST_WATCH_UPDATE fires → Quest log shows "2/15" (OLD/STALE)
3. ~50-200ms delay...
4. QUEST_LOG_UPDATE fires → Quest log shows "3/15" (NEW/FRESH)
```

---

## Performance Impact Summary

| Operation | Total Events | Timing Issues | Performance Impact |
|-----------|--------------|---------------|-------------------|
| Accept Quest | 4 | None | Minimal |
| Abandon Quest | 3 | None | Minimal |
| Progress Update | 3 | QUEST_WATCH_UPDATE stale data | Medium |
| Turn In Quest | 4-6 | Random event order | Medium |
| Quest Chain | 8+ | Complex flow, timing issues | High |

**Critical:** QUEST_WATCH_UPDATE fires with stale data. Always wait for QUEST_LOG_UPDATE for accurate progress.

---

## Essential API Functions

### Quest Log Inspection
```lua
-- Quest log overview
local numEntries, numQuests = GetNumQuestLogEntries()

-- Quest details by log index
local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(index)

-- Quest objectives
local numObjectives = GetNumQuestLeaderBoards(questLogIndex)
local text, objectiveType, finished = GetQuestLogLeaderBoard(objectiveIndex, questLogIndex)

-- Quest completion check
local isComplete = IsQuestComplete(questID)
```

### Quest Progress Tracking
```lua
-- Current quest selection
local questLogIndex = GetQuestLogSelection()

-- Quest links and info
local questLink = GetQuestLink(questLogIndex)
local questDescription, questObjectives = GetQuestLogQuestText(questLogIndex)
```

### Quest Item Detection (Bag Scanning Required)
```lua
-- No reliable quest item API - must scan bags
-- Use BAG_UPDATE event and scan container items
local containerInfo = C_Container.GetContainerItemInfo(bagId, slotId)
if containerInfo and containerInfo.hyperlink then
    -- Check if item is quest-related via tooltip or item type
end
```

### Quest State Tracking
```lua
-- Quest window visibility
local isQuestFrameOpen = QuestFrame and QuestFrame:IsShown()
local isQuestLogOpen = QuestLogFrame and QuestLogFrame:IsShown()
```

---

## Implementation Patterns

### ✅ Recommended (Handles Timing Issues)
```lua
-- Quest progress tracking - OPTIMAL PATTERN
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")

-- Track pending updates to handle stale data
local pendingQuestUpdates = {}

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_WATCH_UPDATE" then
        local questId = ...
        -- Mark as pending - data is STALE at this point
        pendingQuestUpdates[questId] = GetTime()
        
    elseif event == "QUEST_LOG_UPDATE" then
        -- Data is now FRESH - process pending updates
        for questId, timestamp in pairs(pendingQuestUpdates) do
            updateQuestProgress(questId)  -- Now has accurate data
            pendingQuestUpdates[questId] = nil
        end
        
    elseif event == "QUEST_ACCEPTED" then
        local questLogIndex, questId = ...
        onQuestAccepted(questId)
        
    elseif event == "QUEST_REMOVED" then
        local questId = ...
        onQuestRemoved(questId)
    end
end)

-- Quest item tracking via BAG_UPDATE
eventFrame:RegisterEvent("BAG_UPDATE")
local function trackQuestItems()
    -- Scan bags for quest items since QUEST_ITEM_UPDATE is unreliable
    for bagId = 0, 4 do
        -- Scan container items and check for quest items
    end
end
```

### ❌ Anti-Patterns (Timing and Reliability Issues)
```lua
-- DON'T use QUEST_WATCH_UPDATE for immediate data
eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, questId)
    if event == "QUEST_WATCH_UPDATE" then
        -- ❌ BAD - Data is STALE at this point
        local progress = getQuestProgress(questId)  -- Shows OLD progress
        updateUI(progress)  -- Will show incorrect data
    end
end)

-- DON'T rely on QUEST_ITEM_UPDATE
eventFrame:RegisterEvent("QUEST_ITEM_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event)
    -- ❌ BAD - Only fires 29% of the time
    updateQuestItems()  -- Will miss most quest item changes
end)

-- DON'T assume event order for turn-ins
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_TURNED_IN" then
        -- ❌ BAD - Assuming QUEST_REMOVED comes after
        -- QUEST_REMOVED might have already fired or fire later
        processQuestCompletion()
    end
end)
```

---

## Key Technical Details

### Critical Timing Discoveries
- **QUEST_WATCH_UPDATE fires BEFORE data updates** (50-200ms delay until fresh data)
- **QUEST_LOG_UPDATE contains fresh data** (use this for actual progress)
- **Event order is random** for QUEST_TURNED_IN and QUEST_REMOVED
- **QUEST_ITEM_UPDATE reliability: 29%** (fired in only 2 of 7 turn-in tests)

### Quest Item System Issues
- **No reliable quest item events** in Classic Era
- **QUEST_ITEM_UPDATE is broken** (29% reliability, then stops firing)
- **BAG_UPDATE is the only reliable indicator** for quest item changes
- **Quest items removed at turn-in dialog** (not when objectives complete)

### Event Order Patterns (7 Turn-in Tests)
| Pattern | Frequency | Event Sequence | QUEST_ITEM_UPDATE |
|---------|-----------|----------------|-------------------|
| A | 14% (1/7) | QUEST_TURNED_IN → QUEST_REMOVED → BAG_UPDATE → QUEST_ITEM_UPDATE | ✅ Fired |
| B | 14% (1/7) | QUEST_REMOVED → BAG_UPDATE → QUEST_ITEM_UPDATE → QUEST_TURNED_IN | ✅ Fired |
| C | 72% (5/7) | Various random orders → BAG_UPDATE → No QUEST_ITEM_UPDATE | ❌ Did not fire |

### Quest Progress Data States
```lua
-- At QUEST_WATCH_UPDATE fire time
local staleProgress = getQuestProgress(questId)  -- Shows OLD count (e.g., "2/15")

-- 50-200ms later at QUEST_LOG_UPDATE fire time  
local freshProgress = getQuestProgress(questId)  -- Shows NEW count (e.g., "3/15")
```

---

## Event Arguments Reference

### Key Event Arguments
```lua
-- QUEST_ACCEPTED arguments
function onQuestAccepted(questLogIndex, questId)
    -- questLogIndex: Position in quest log (1-based)
    -- questId: Unique quest identifier
end

-- QUEST_TURNED_IN arguments
function onQuestTurnedIn(questId, xpReward, moneyReward)
    -- questId: Quest that was completed
    -- xpReward: Experience points gained
    -- moneyReward: Money reward in copper
end

-- QUEST_WATCH_UPDATE arguments
function onQuestWatchUpdate(questId)
    -- questId: Quest with updated progress
    -- WARNING: Quest data is STALE at this point
end
```

---

## Untested Scenarios

### High Priority for Future Testing
1. **Quest Starter Items** - Right-click item to start quest
2. **Shared/Escort Quests** - QUEST_ACCEPT_CONFIRM scenarios
3. **Multiple Simultaneous Objectives** - Kill + collect completing together
4. **Quest Item Usage** - Using quest items from bags to progress

### Medium Priority
1. **Loot from World Objects** - Chests/containers giving quest items
2. **Decline Quest Dialog** - Quest refusal at NPC
3. **Timed Quest Expiration** - Quest failure events
4. **Repeatable Quests** - Daily/repeatable quest patterns

### Low Priority
1. **Quest Auto-Complete** - May not exist in Classic Era
2. **Exploration Quests** - Location discovery updates
3. **Quest Progress from Spells** - Using abilities to progress quests

---

## Conclusion

**QUEST_LOG_UPDATE is the reliable event for quest data:**

✅ **Use for Quest Tracking:**
- `QUEST_LOG_UPDATE` for fresh quest progress data
- `QUEST_ACCEPTED`/`QUEST_REMOVED` for quest lifecycle
- `BAG_UPDATE` for quest item tracking (only reliable method)

❌ **Avoid These Patterns:**
- `QUEST_WATCH_UPDATE` for immediate data (stale data, 50-200ms delay)
- `QUEST_ITEM_UPDATE` for item tracking (29% reliability, broken)
- Assuming event order for turn-ins (completely random)

**The key insight: Quest events in Classic Era have significant timing and reliability issues that require careful handling with proper debouncing and fallback mechanisms.**