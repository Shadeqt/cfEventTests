# WoW Classic Era: Bag and Bank Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 26, 2025
**Testing:** Bag operations, bank interactions, item movements, container state tracking, ultra-minimal optimization

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 15 bag and bank-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `BAG_UPDATE` | ✅ | 1-12× per operation | Reliable but with spam (use BAG_UPDATE_DELAYED instead) |
| `BAG_UPDATE_DELAYED` | ✅ | 1-2× per operation | **Optimal - covers ALL operations** |
| `PLAYERBANKSLOTS_CHANGED` | ✅ | 1× per bank slot | **Required for bank container (ID:-1)** |
| `ITEM_LOCK_CHANGED` | ✅ | 2-4× per move | Redundant - overwritten by BAG_UPDATE_DELAYED |
| `ITEM_PUSH` | ✅ | 1× per new item | **Uses internal bagId mapping: 31-34 → UI bags 1-4** |
| `BAG_NEW_ITEMS_UPDATED` | ✅ | 1× per ITEM_PUSH | Always follows ITEM_PUSH |
| `BAG_CONTAINER_UPDATE` | ✅ | 1× on login | Container-wide refresh |
| `UNIT_INVENTORY_CHANGED` | ✅ | 1× per operation | Redundant - BAG_UPDATE_DELAYED covers deletions |
| `BANKFRAME_OPENED` | ✅ | 1× per bank open | Bank window opened |
| `BANKFRAME_CLOSED` | ✅ | 1× per bank close | Bank window closed |
| `BAG_UPDATE_COOLDOWN` | ✅ | 1× per consumable | Item consumption |
| `ITEM_LOCKED` | ✅ | 1× per pickup | **Redundant with LOCK_CHANGED** |
| `ITEM_UNLOCKED` | ✅ | 1× per placement | **Redundant with LOCK_CHANGED** |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× per login/reload | Initialization |

### Events That Did NOT Fire During Testing
| Event | Status | Reason |
|-------|--------|--------|
| `BAG_OPEN` | ❌ | **Non-functional in Classic Era** |
| `BAG_CLOSED` | ❌ | **Non-functional in Classic Era** |
| `BAG_SLOT_FLAGS_UPDATED` | ❌ | Never triggered during testing |
| `PLAYERBANKBAGSLOTS_CHANGED` | ❌ | Never triggered during testing |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `ToggleBag` | ✅ | 1× per bag toggle | **Essential - User operations + system backpack** |
| `ToggleBackpack` | ✅ | 1× per backpack toggle | **Redundant** - Always fires with ToggleBag(0) |
| `OpenBag` | ✅ | 1× per bag open | **Essential - System operations bags 1-4** |
| `CloseBag` | ✅ | 1× per bag close | **Optional** - Only needed if tracking closes |
| `OpenAllBags` | ✅ | 1× per system open | **Redundant** - Fires after individual OpenBag calls |
| `CloseAllBags` | ✅ | 1× per system close | **Optional** - Only needed if tracking closes |

### Hook Coverage Analysis (NEW - October 2025)
| **User Action** | **ToggleBag** | **ToggleBackpack** | **OpenBag** | **OpenAllBags** | **CloseBag** |
|-----------------|---------------|-------------------|-------------|-----------------|--------------|
| **Click backpack icon** | ✅ (bagId=0) | ✅ | ❌ | ❌ | ❌ |
| **Click bag 1-4 icon** | ✅ (bagId=1-4) | ❌ | ❌ | ❌ | ❌ |
| **Press B key (open all)** | ✅ (bagId=0) | ✅ | ✅ (bagId=1-4) | ✅ | ❌ |
| **Press B key (close all)** | ❌ | ❌ | ❌ | ❌ | ✅ (bagId=1-4) |
| **Talk to vendor** | ✅ (bagId=0) | ✅ | ✅ (bagId=1-4) | ✅ | ❌ |
| **Walk away from vendor** | ❌ | ❌ | ❌ | ❌ | ✅ (bagId=1-4) |

### Optimal Hook Strategy (NEW - October 2025)
**For bag opening detection (most common use case), only 2 hooks are needed:**

```lua
-- Hook 1: Handles ALL backpack + user individual bags
hooksecurefunc("ToggleBag", function(bagId)
    if IsBagOpen(bagId) then
        processBagOpen(bagId)
    end
end)

-- Hook 2: Handles system operations for bags 1-4
hooksecurefunc("OpenBag", function(bagId)
    if bagId >= 1 and bagId <= NUM_BAG_SLOTS and IsBagOpen(bagId) then
        processBagOpen(bagId)
    end
end)
```

**Eliminated hooks (redundant for opening detection):**
- ❌ `ToggleBackpack` - Always fires with ToggleBag(0), adds no value
- ❌ `OpenAllBags` - Always fires after individual OpenBag calls, adds no value
- ❌ `CloseBag/CloseAllBags` - Only needed if tracking bag closes

### Tests Performed Headlines
1. **Login/Reload** - Bag initialization (backpack special case)
2. **Bag Open/Close** - Hook-based detection (no events)
3. **Item Movements** - Cross-bag, same-bag, bank operations
4. **Bank Interactions** - Container vs bag differences
5. **Item Consumption** - BAG_UPDATE_COOLDOWN patterns
6. **New Item Detection** - ITEM_PUSH vs moves/buybacks
7. **Merchant Purchases** - Real transaction with Small Quiver (1s cost)
8. **Mail Item Retrieval** - Auction house mail with Bolt of Linen Cloth
9. **Auction Creation** - Item removal for Linen Cloth auction
10. **Cross-System Integration** - Perfect coordination with merchant, mail, auction systems
11. **Hook Coverage Analysis** - Comprehensive testing of all 6 bag hooks (NEW - October 2025)
12. **Individual Bag Operations** - Click testing for each bag 0-4 (NEW - October 2025)
13. **System Operations** - Vendor, bank, mailbox hook behavior (NEW - October 2025)
14. **Hook Optimization** - Minimal 2-hook solution validation (NEW - October 2025)

---

## Quick Decision Guide

### Event Reliability for AI Decision Making (UPDATED - October 2025)
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `BAG_UPDATE_DELAYED` | 100% | ✅ **OPTIMAL** | ✅ **ULTRA-MINIMAL** - ALL bag operations |
| `PLAYERBANKSLOTS_CHANGED` | 100% | Low | ✅ **Required** - Bank container (ID:-1) changes |
| `BANKFRAME_OPENED/CLOSED` | 100% | Low | ✅ Bank window state |
| `BAG_UPDATE` | 100% | Medium | ❌ **Redundant** - Use BAG_UPDATE_DELAYED instead |
| `ITEM_PUSH` | 100% | Low | ❌ **Redundant** - BAG_UPDATE_DELAYED covers new items |
| `ITEM_LOCK_CHANGED` | 100% | Low | ❌ **Redundant** - Slot updates overwritten by bag updates |
| `UNIT_INVENTORY_CHANGED` | 100% | Medium | ❌ **Redundant** - BAG_UPDATE_DELAYED covers deletions |

### Ultra-Minimal Use Case Mapping (NEW - October 2025)
- **Track ALL bag operations:** `BAG_UPDATE_DELAYED` (moves, splits, deletions, new items)
- **Detect bag opens:** `ToggleBag` + `OpenBag` hooks (complete coverage)
- **Monitor bank container:** `PLAYERBANKSLOTS_CHANGED` (ID:-1 only)
- **Login initialization:** `PLAYER_ENTERING_WORLD`
- **❌ Everything else is redundant complexity**

### Hook Efficiency Rankings (NEW - October 2025)
| Hook | Efficiency | Coverage | Recommendation |
|------|------------|----------|----------------|
| `ToggleBag` | ✅ Perfect | User ops + system backpack | ✅ **Essential** |
| `OpenBag` | ✅ Perfect | System ops bags 1-4 | ✅ **Essential** |
| `ToggleBackpack` | ❌ Redundant | Always with ToggleBag(0) | ❌ Skip |
| `OpenAllBags` | ❌ Redundant | After individual OpenBag | ❌ Skip |
| `CloseBag` | ⚠️ Optional | Close operations only | ⚠️ If needed |
- **Monitor bank window:** `BANKFRAME_OPENED/CLOSED`

### Critical AI Rules (UPDATED - October 2025)
- **Use ONLY BAG_UPDATE_DELAYED for bag operations** (covers everything, no redundancy)
- **BAG_UPDATE_DELAYED(bagId=nil) means stack operation** (update all open bags)
- **BAG_UPDATE_DELAYED(bagId=specific) means single bag operation** (update only that bag)
- **BAG_OPEN/BAG_CLOSED events don't work** (use hooks for bag state)
- **Bank container (ID:-1) uses different event** (PLAYERBANKSLOTS_CHANGED)
- **Slot-level optimizations are redundant** (bag-level events overwrite them anyway)
- **Simplicity beats complexity** (2 events work better than 4+ events)

### Hook Optimization Rules (NEW - October 2025)
- **ToggleBag covers user operations + system backpack** (essential)
- **OpenBag covers system operations for bags 1-4** (essential)
- **ToggleBackpack is always redundant** with ToggleBag(0) (skip)
- **OpenAllBags is always redundant** with individual OpenBag calls (skip)
- **Close hooks only needed if tracking bag closes** (usually skip)

---

## Container ID Reference

| Container ID | Type | Slots | Event | Notes |
|--------------|------|-------|-------|-------|
| `-2` | Keyring | Varies | `BAG_UPDATE` | Classic Era only |
| `-1` | Bank Container | 24 | `PLAYERBANKSLOTS_CHANGED` | **Different event!** |
| `0` | Backpack | 16-20 | `BAG_UPDATE` | **No login BAG_UPDATE** |
| `1-4` | Bags | Varies | `BAG_UPDATE` | Regular bags |
| `5-10` | Bank Bags | Varies | `BAG_UPDATE` | Like regular bags |

### ITEM_PUSH Internal Bag ID Mapping
**Critical Discovery:** `ITEM_PUSH` uses WoW's internal bag numbering system, not UI bag IDs:

| ITEM_PUSH bagId | UI Bag ID | Bag Type | Mapping Required |
|-----------------|-----------|----------|------------------|
| `0` | `0` | Backpack | Direct mapping |
| `31` | `1` | Bag 1 | **Subtract 30** |
| `32` | `2` | Bag 2 | **Subtract 30** |
| `33` | `3` | Bag 3 | **Subtract 30** |
| `34` | `4` | Bag 4 | **Subtract 30** |

**Implementation Pattern:**
```lua
if event == "ITEM_PUSH" then
    local internalBagId, iconFileID = ...
    local uiBagId = nil
    
    if internalBagId == 0 then
        uiBagId = 0  -- Backpack
    elseif internalBagId >= 31 and internalBagId <= 34 then
        uiBagId = internalBagId - 30  -- Bags 1-4: 31→1, 32→2, 33→3, 34→4
    end
    
    if uiBagId and IsBagOpen(uiBagId) then
        processBagContent(uiBagId)
    end
end
```

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Login: BAG_UPDATE (bags 1-4, 5-10) → BAG_CONTAINER_UPDATE → PLAYER_ENTERING_WORLD → BAG_UPDATE_DELAYED
Item Move: ITEM_LOCK_CHANGED (pickup) → ITEM_LOCK_CHANGED (placement) → BAG_UPDATE → BAG_UPDATE_DELAYED
Stack Split: ITEM_LOCK_CHANGED (pickup) → ITEM_LOCK_CHANGED (placement) → BAG_UPDATE_DELAYED(bagId=nil)
New Item: ITEM_PUSH → BAG_NEW_ITEMS_UPDATED → BAG_UPDATE → BAG_UPDATE_DELAYED
Bank Operation: PLAYERBANKSLOTS_CHANGED → BAG_UPDATE (spam) → BAG_UPDATE_DELAYED
Merchant Purchase: PLAYER_MONEY → ITEM_PUSH → CHAT_MSG_LOOT → BAG_UPDATE (+430ms) → BAG_UPDATE_DELAYED
Mail Retrieval: ITEM_PUSH → CHAT_MSG_LOOT → MAIL_INBOX_UPDATE → BAG_UPDATE (+734ms) → BAG_UPDATE_DELAYED (async)
Auction Creation: ITEM_LOCK_CHANGED → ITEM_UNLOCKED → BAG_UPDATE → BAG_UPDATE_DELAYED
```

**Key Insight:** In all sequences, `BAG_UPDATE_DELAYED` is the final event that processes complete state. Earlier events (`ITEM_LOCK_CHANGED`, `ITEM_PUSH`) provide redundant intermediate updates that get overwritten.

### Event Detail Analysis
**ITEM_LOCK_CHANGED Precision:**
- Provides exact `bagId` and `slotId` for pickup/placement operations
- Fires twice per item swap: pickup from source, placement to destination
- Stack splits: Only tracks source slot (pickup + placement), destination slot unknown
- **Limitation:** Cannot detect destination slot in stack operations

**ITEM_PUSH Bag ID Mapping:**
- Uses internal WoW bag numbering (31-34 for UI bags 1-4)
- Requires mapping: `uiBagId = internalBagId - 30` for bags 1-4
- Only fires for genuinely NEW items (not moves or buybacks)
- **Limitation:** Complex mapping required, redundant with BAG_UPDATE_DELAYED

### Bag Open/Close (Hook-based Only)
```
Individual Bag: ToggleBag(bagId) [+ ToggleBackpack() if bag 0]
System Open: OpenAllBags() → OpenBag() for each bag
System Close: CloseAllBags() → CloseBag() for each bag
```

### Bank Operation Spam Pattern
```
Single Bank Slot Change: PLAYERBANKSLOTS_CHANGED → BAG_UPDATE (backpack, duplicate) → BAG_UPDATE (keyring, duplicate) → BAG_UPDATE_DELAYED
```

---

## Performance Impact Summary

| Operation | Total Events | Useful Events | Redundant Events | Optimal Strategy |
|-----------|--------------|---------------|------------------|------------------|
| Regular Bag Operations | 3-5 | 1 (BAG_UPDATE_DELAYED) | 2-4 (ITEM_LOCK_CHANGED, etc.) | Use only BAG_UPDATE_DELAYED |
| Same-Bag Splits | 9 | 1 (BAG_UPDATE_DELAYED) | 8 (BAG_UPDATE ×3, ITEM_LOCK_CHANGED ×2, etc.) | Use only BAG_UPDATE_DELAYED |
| Bank Operations | 12+ | 1-4 (PLAYERBANKSLOTS_CHANGED, BAG_UPDATE_DELAYED) | 8+ (duplicate BAG_UPDATE) | Use PLAYERBANKSLOTS_CHANGED + BAG_UPDATE_DELAYED |
| Cross-Bag Moves | 6-8 | 2 (BAG_UPDATE_DELAYED ×2) | 4-6 (ITEM_LOCK_CHANGED, BAG_UPDATE) | Use only BAG_UPDATE_DELAYED |

**Critical Discovery:** Most events in each sequence are redundant. `BAG_UPDATE_DELAYED` alone provides complete coverage for all bag operations.

**Critical:** Bank operations generate **66-71% spam** (duplicate BAG_UPDATE events on unchanged bags).

**Key Discovery:** Slot-level optimizations (`ITEM_LOCK_CHANGED`, `ITEM_PUSH`) are redundant when `BAG_UPDATE_DELAYED` processes entire bags anyway. Stack operations always fire `BAG_UPDATE_DELAYED(bagId=nil)` requiring all-bag updates regardless of slot-level precision attempts.

---

## Essential API Functions

### Bag Content Inspection
```lua
-- Container info
local numSlots = C_Container.GetContainerNumSlots(bagId)
local containerInfo = C_Container.GetContainerItemInfo(bagId, slotId)

-- Classic Era fallbacks
local numSlots = GetContainerNumSlots(bagId)  -- May not exist
local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bagId, slotId)
```

### Bag State Detection (Critical - No Events Available)
```lua
-- Method 1: Query current state
local isOpen = IsBagOpen(bagId)

-- Method 2: UI frame visibility
local containerFrame = _G["ContainerFrame" .. (bagId + 1)]
local isVisible = containerFrame and containerFrame:IsShown()

-- Method 3: Hook-based tracking (recommended)
local bagStates = {}  -- [bagId] = true/false
hooksecurefunc("ToggleBag", function(bagId)
    bagStates[bagId] = not bagStates[bagId]
end)
```

### Bank Detection
```lua
-- Bank window state
local isBankOpen = BankFrame and BankFrame:IsShown()

-- Bank container vs bank bags
-- Bank container (ID:-1): Uses PLAYERBANKSLOTS_CHANGED
-- Bank bags (ID:5-10): Use BAG_UPDATE like regular bags
```

### Item Movement Detection
```lua
-- New items only (excludes moves/buybacks)
if event == "ITEM_PUSH" then
    local bagId, iconFileID = ...
    -- This is a genuinely NEW item
end

-- All bag changes (includes moves)
if event == "BAG_UPDATE" then
    local bagId = ...
    -- Content changed (may be duplicate event)
end
```

---

## Implementation Patterns

### ✅ Recommended - Minimal Hook Approach (NEW - October 2025)
```lua
-- OPTIMAL: 2-Hook Solution for Bag Opening Detection
-- Covers 100% of scenarios with minimal overhead

-- Hook 1: User operations + system backpack
hooksecurefunc("ToggleBag", function(bagId)
    if IsBagOpen(bagId) then
        processBagOpen(bagId)  -- Only when opening
    end
end)

-- Hook 2: System operations for bags 1-4
if OpenBag then
    hooksecurefunc("OpenBag", function(bagId)
        if bagId >= 1 and bagId <= NUM_BAG_SLOTS and IsBagOpen(bagId) then
            processBagOpen(bagId)  -- Only when opening
        end
    end)
end

-- Result: Complete coverage, zero redundancy, optimal performance
```

### ✅ OPTIMAL - Ultra-Minimal Event Approach
```lua
-- ULTIMATE: 2-Event Solution for ALL Bag Operations
-- Discovered through redundancy analysis - slot-level optimizations are unnecessary

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event, bagId)
    if event == "BAG_UPDATE_DELAYED" then
        if bagId and bagId >= 0 and bagId <= NUM_BAG_SLOTS and IsBagOpen(bagId) then
            -- Specific bag operation - update only that bag
            processBagContent(bagId)
        elseif bagId == nil then
            -- Stack operation or deletion - update all open bags
            for checkBagId = 0, NUM_BAG_SLOTS do
                if IsBagOpen(checkBagId) then
                    processBagContent(checkBagId)
                end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Login initialization
        for bagId = 0, NUM_BAG_SLOTS do
            if IsBagOpen(bagId) then
                processBagContent(bagId)
            end
        end
    end
end)

-- Result: Complete coverage, zero redundancy, maximum simplicity
-- Covers: moves, splits, deletions, new items, login - everything
```

### ✅ Legacy - Full Event Tracking (High Overhead)
```lua
-- BAG_UPDATE with spam filtering - Original approach
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("ITEM_PUSH")

-- Duplicate filtering system
local bagContents = {}  -- [bagId] = { [slotId] = itemData }

local function getBagSnapshot(bagId)
    local snapshot = {}
    local numSlots = C_Container.GetContainerNumSlots(bagId)
    if numSlots then
        for slotId = 1, numSlots do
            local containerInfo = C_Container.GetContainerItemInfo(bagId, slotId)
            if containerInfo then
                snapshot[slotId] = {
                    itemID = containerInfo.itemID,
                    stackCount = containerInfo.stackCount,
                    itemLink = containerInfo.hyperlink
                }
            end
        end
    end
    return snapshot
end

local function hasContentChanged(bagId, newSnapshot)
    local oldSnapshot = bagContents[bagId]
    if not oldSnapshot then return true end
    
    -- Compare snapshots
    for slotId, newData in pairs(newSnapshot) do
        local oldData = oldSnapshot[slotId]
        if not oldData or 
           oldData.itemID ~= newData.itemID or 
           oldData.stackCount ~= newData.stackCount then
            return true
        end
    end
    
    for slotId, oldData in pairs(oldSnapshot) do
        if not newSnapshot[slotId] then
            return true
        end
    end
    
    return false
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" then
        local bagId = ...
        
        -- Take snapshot and compare
        local newSnapshot = getBagSnapshot(bagId)
        if hasContentChanged(bagId, newSnapshot) then
            -- Content actually changed
            bagContents[bagId] = newSnapshot
            onBagContentChanged(bagId)
        else
            -- Duplicate event - ignore
        end
        
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        local slotId = ...
        -- Bank container (ID:-1) changed
        onBankSlotChanged(slotId)
        
    elseif event == "ITEM_PUSH" then
        local bagId, iconFileID = ...
        -- NEW item (not move/buyback)
        onNewItemReceived(bagId, iconFileID)
        
    elseif event == "BAG_UPDATE_DELAYED" then
        -- All bag operations completed
        onBagOperationsComplete()
    end
end)

-- Bag state tracking (hooks required - no events)
local bagStates = {}
hooksecurefunc("ToggleBag", function(bagId)
    bagStates[bagId] = not bagStates[bagId]
    updateBagColors(bagId, bagStates[bagId])
end)

hooksecurefunc("OpenAllBags", function()
    for i = 0, NUM_BAG_SLOTS do
        bagStates[i] = true
        updateBagColors(i, true)
    end
end)

hooksecurefunc("CloseAllBags", function()
    for i = 0, NUM_BAG_SLOTS do
        bagStates[i] = false
        updateBagColors(i, false)
    end
end)

-- Handle backpack special case on login
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Backpack doesn't fire BAG_UPDATE on login - scan manually
        local backpackSnapshot = getBagSnapshot(0)
        bagContents[0] = backpackSnapshot
        onBagContentChanged(0)
    end
end)
```

### ❌ Anti-Patterns (Performance Killers and Broken Patterns)
```lua
-- DON'T use BAG_OPEN/BAG_CLOSED events
eventFrame:RegisterEvent("BAG_OPEN")
eventFrame:RegisterEvent("BAG_CLOSED")
eventFrame:SetScript("OnEvent", function(self, event, bagId)
    -- ❌ BAD - These events never fire in Classic Era
    -- ❌ Completely non-functional
    updateBagState(bagId)
end)

-- DON'T process BAG_UPDATE without duplicate filtering
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, bagId)
    -- ❌ BAD - Bank operations fire 66-71% duplicate events
    -- ❌ Same content, multiple events = wasted processing
    updateBagDisplay(bagId)  -- Called multiple times with identical data
end)

-- DON'T assume backpack fires BAG_UPDATE on login
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    -- ❌ BAD - Backpack (bag 0) doesn't fire BAG_UPDATE on login
    -- ❌ Will miss backpack contents on initialization
    -- Must manually scan bag 0 on login
end)

-- DON'T use same event for bank container and bank bags
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, bagId)
    if bagId == -1 then
        -- ❌ BAD - Bank container uses PLAYERBANKSLOTS_CHANGED, not BAG_UPDATE
        -- ❌ This will never fire for bank container
        updateBankContainer()
    end
end)
```

---

## Key Technical Details

### Critical Discoveries
- **BAG_OPEN/BAG_CLOSED events are non-functional** (register but never fire)
- **Backpack special case:** No BAG_UPDATE on login (manual scan required)
- **Bank container uses different event:** PLAYERBANKSLOTS_CHANGED (not BAG_UPDATE)
- **Bank operations create 66-71% spam** (duplicate BAG_UPDATE on unchanged bags)
- **Content comparison is mandatory** (identical events fire repeatedly)

### Bag State Tracking Solutions
| Method | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| `IsBagOpen()` API | Simple, accurate | Polling required | ✅ Good for validation |
| ContainerFrame visibility | Direct UI state | Frame-dependent | ✅ Good for UI addons |
| Hook-based tracking | Real-time updates | Must handle all cases | ✅ **Best for real-time** |

### Bank System Complexity
```lua
-- Bank has two different systems:
-- 1. Bank container (ID:-1): 24 slots, PLAYERBANKSLOTS_CHANGED event
-- 2. Bank bags (ID:5-10): Variable slots, BAG_UPDATE events (like regular bags)

-- Bank window state is separate from container state
local isBankWindowOpen = BankFrame and BankFrame:IsShown()
local isBankContainerAccessible = -- No direct API, infer from window state
```

### Event Spam Analysis
| Operation Type | BAG_UPDATE Events | Useful Events | Spam Percentage |
|----------------|------------------|---------------|-----------------|
| Regular bag operations | 1-3 | 1-3 | 0% |
| Same-bag splits | 3 | 1 | 67% |
| Bank operations | 3-12 | 1-4 | 66-71% |
| Cross-bag moves | 2-4 | 2-4 | 0-50% |

### Login Behavior Special Cases
```lua
-- On login/reload:
// ✅ Bags 1-4: Fire BAG_UPDATE if equipped
// ✅ Bank bags 5-10: Fire BAG_UPDATE if they exist  
// ❌ Backpack (bag 0): Does NOT fire BAG_UPDATE
// ✅ All: BAG_CONTAINER_UPDATE → PLAYER_ENTERING_WORLD → BAG_UPDATE_DELAYED

-- Must handle backpack manually:
if event == "PLAYER_ENTERING_WORLD" then
    scanBackpackContents()  -- Required for bag 0
end
```

---

## Untested Scenarios

### High Priority for Future Testing
1. **Guild Bank Interactions** - Different container system entirely
2. **Mail System Integration** - Mailbox bag interactions
3. **Auction House** - Bag interactions during bidding/selling
4. **Trade Window** - Bag state during player trading
5. **Vendor Buyback** - Bag behavior with buyback operations

### Medium Priority
1. **Bag Swapping** - Equipping/unequipping bag containers
2. **Full Bag Scenarios** - Behavior when bags are completely full
3. **Corrupted Items** - How events handle damaged/corrupted items
4. **Soulbound Items** - Special handling for bind-on-pickup items
5. **Quest Items** - Quest item specific bag behaviors

### Low Priority
1. **Network Lag Effects** - Event timing under poor connection
2. **Addon Conflicts** - Multiple bag addons interaction
3. **UI Scale Changes** - ContainerFrame behavior with UI scaling
4. **Different Bag Types** - Special bags (herb, enchanting, etc.)

---

## Conclusion

**Bag and bank event tracking in Classic Era requires careful handling:**

✅ **Reliable Core Events:**
- BAG_UPDATE for content changes (with mandatory duplicate filtering)
- PLAYERBANKSLOTS_CHANGED for bank container (ID:-1)
- ITEM_PUSH for genuine new items (excludes moves)
- BAG_UPDATE_DELAYED for operation completion

❌ **Broken/Missing Events:**
- **BAG_OPEN/BAG_CLOSED don't work** (use hooks instead)
- **Backpack doesn't fire BAG_UPDATE on login** (manual scan required)

⚠️ **Critical Performance Issues:**
- **Bank operations generate 66-71% spam** (duplicate BAG_UPDATE events)
- **Content comparison is mandatory** (identical events fire repeatedly)
- **Same-bag operations fire 3× identical events**

✅ **Recommended Implementation:**
- Use BAG_UPDATE with content comparison for duplicate filtering
- Use hooks for bag open/close state (no events available)
- Handle backpack special case on login
- Use PLAYERBANKSLOTS_CHANGED for bank container
- Implement aggressive spam filtering for bank operations

**The key insight: Bag events are reliable for content tracking but require sophisticated duplicate filtering and hook-based state management due to Classic Era's event system limitations.**

---

## Hook Optimization Summary (NEW - October 2025)

**After comprehensive hook investigation, the optimal approach for bag opening detection:**

✅ **Minimal 2-Hook Solution (67% reduction):**
- `ToggleBag` - Handles user operations + system backpack
- `OpenBag` - Handles system operations for bags 1-4
- **Result:** Complete coverage, zero redundancy, optimal performance

❌ **Eliminated Redundant Hooks:**
- `ToggleBackpack` - Always fires with ToggleBag(0), adds no value
- `OpenAllBags` - Always fires after individual OpenBag calls, adds no value
- `CloseBag/CloseAllBags` - Only needed if tracking bag closes (rare use case)

🎯 **Performance Impact:**
- **6 hooks → 2 hooks** (67% code reduction)
- **Zero duplicate processing** (each bag processed exactly once)
- **Complete scenario coverage** (user clicks, system operations, all bag types)

**Updated recommendation: Use the minimal 2-hook approach for bag opening detection, achieving the same functionality with significantly less complexity and overhead.**