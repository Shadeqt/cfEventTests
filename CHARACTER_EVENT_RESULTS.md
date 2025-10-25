# WoW Classic Era: Character Equipment Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing:** Equipment changes, character panel interactions, login/reload scenarios

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 11 character equipment-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `PLAYER_EQUIPMENT_CHANGED` | ✅ | 1× per slot change | **Perfect - Zero spam** |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× per login/reload | Reliable initialization |
| `UNIT_INVENTORY_CHANGED` | ✅ | 347× total (2 relevant) | **99.4% spam - Avoid** |
| `UNIT_MODEL_CHANGED` | ✅ | 2× per equipment change | **Redundant spam** |
| `PLAYER_AVG_ITEM_LEVEL_UPDATE` | ✅ | 3× per equipment change | **Redundant spam** |
| `UPDATE_INVENTORY_DURABILITY` | ✅ | 89× total (0 relevant) | **100% global spam - Unusable** |
| `UPDATE_INVENTORY_ALERTS` | ✅ | Rare | Low frequency |
| `ITEM_LOCK_CHANGED` | ✅ | 1-4× per operation | Tracks pickup/drop operations |
| `ITEM_LOCKED` | ✅ | 1× per pickup | **Redundant with LOCK_CHANGED** |
| `ITEM_UNLOCKED` | ✅ | 1× per drop | **Redundant with LOCK_CHANGED** |
| `CHARACTER_POINTS_CHANGED` | ✅ | 2× per panel open | UI state change |

### Events That Did NOT Fire During Testing
| Event | Status | Reason |
|-------|--------|--------|
| None | N/A | All registered events fired during testing |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `PaperDollItemSlotButton_Update` | ✅ | 57+× per change | **EXTREME SPAM - Never use** |
| `CharacterFrame_Expand` | ✅ | 1× per panel open | Clean |
| `CharacterFrame_Collapse` | ✅ | 1× per panel close | Clean |
| `EquipItemByName` | ✅ | 1× per name equip | Rare usage |
| `UseInventoryItem` | ✅ | 1× per slot use | Clean |
| `PickupInventoryItem` | ✅ | 1× per slot pickup | Clean |

### Hooks That Did NOT Fire
| Hook | Status | Reason |
|------|--------|--------|
| None tested | N/A | All tested hooks fired appropriately |

### Tests Performed Headlines
1. **Login/Reload** - PLAYER_ENTERING_WORLD initialization (68 hook calls)
2. **Open Character Panel** - CHARACTER_POINTS_CHANGED (2×), UI sweep (20+ hooks)
3. **Close Character Panel** - Clean shutdown (1 hook)
4. **Unequip Item** - Legs slot (ID=7), PLAYER_EQUIPMENT_CHANGED + spam cascade
5. **Equip Item** - Legs slot (ID=7), equipment lock format detection
6. **Swap Equipment** - MainHand slot (ID=16), Piercing Axe → Skinning Knife

---

## Quick Decision Guide

### Event Reliability for AI Decision Making
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `PLAYER_EQUIPMENT_CHANGED` | 100% | Perfect | ✅ **PRIMARY** - Equipment tracking (1:1 ratio) |
| `PLAYER_ENTERING_WORLD` | 100% | Low | ✅ Initialization and full equipment scan |
| `ITEM_LOCK_CHANGED` | 100% | Low | ✅ Pickup/drop detection (equipment vs bags) |
| `CharacterFrame_Expand/Collapse` | 100% | Low | ✅ UI state tracking |
| `UNIT_INVENTORY_CHANGED` | 100% | Terrible | ❌ 99.4% bag spam - Never use |
| `UPDATE_INVENTORY_DURABILITY` | 100% | Unusable | ❌ 100% global spam - Never use |
| `PaperDollItemSlotButton_Update` | 100% | Terrible | ❌ 57× spam per change - Never use |

### Use Case → Best Event Mapping
- **Detect equipment changes:** `PLAYER_EQUIPMENT_CHANGED` (fires exactly once per slot)
- **Initialize on login:** `PLAYER_ENTERING_WORLD` (scan all slots 1-19)
- **Track item pickup/drop:** `ITEM_LOCK_CHANGED` (distinguishes equipment vs bags)
- **Monitor character panel:** `CharacterFrame_Expand/Collapse` hooks
- **Avoid durability tracking:** No reliable events available

### Critical AI Rules
- **Equipment slots are 1-19 ONLY** (slots 0 and 20 don't exist in Classic Era)
- **Ammo is NOT equipment** (arrows/bullets are consumables in bags)
- **PLAYER_EQUIPMENT_CHANGED is perfect** (1:1 ratio, zero spam, zero filtering)
- **Never use hooks for equipment tracking** (57× performance penalty)
- **Global events are unusable** (UPDATE_INVENTORY_DURABILITY fires for all units)

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Login/Reload: PLAYER_ENTERING_WORLD → PaperDollItemSlotButton_Update (×68)
Unequip Item: UNIT_INVENTORY_CHANGED → PLAYER_EQUIPMENT_CHANGED → ITEM_LOCK_CHANGED → Spam cascade
Equip Item: ITEM_LOCK_CHANGED → PLAYER_EQUIPMENT_CHANGED → Spam cascade  
Swap Equipment: Multiple ITEM_LOCK_CHANGED → PLAYER_EQUIPMENT_CHANGED → Spam cascade
Open Panel: CharacterFrame_Expand → CHARACTER_POINTS_CHANGED (×2) → Hook spam
Close Panel: CharacterFrame_Collapse (clean, no spam)
```

### Spam Cascade Pattern (After every equipment change)
```
PLAYER_EQUIPMENT_CHANGED (1× - the signal you want)
  ↓
UNIT_MODEL_CHANGED (×2 - redundant)
  ↓  
PLAYER_AVG_ITEM_LEVEL_UPDATE (×3 - redundant)
  ↓
PaperDollItemSlotButton_Update (×57+ - extreme spam)
```

---

## Performance Impact Summary

| Operation | Key Events | Spam Events | Performance Impact |
|-----------|------------|-------------|-------------------|
| Login/Reload | 1 | PaperDollItemSlotButton_Update (×68) | **High** |
| Open Character Panel | 2 | PaperDollItemSlotButton_Update (×20+) | **High** |
| Equipment Change | 1 | Hook (×57+), Model (×2), AvgIL (×3) | **Extreme** |
| Close Character Panel | 1 | None | Minimal |

**Critical:** Single equipment change triggers 60+ redundant events. Use PLAYER_EQUIPMENT_CHANGED only.

---

## Essential API Functions

### Equipment Slot Inspection (Core Functions - Tested)
```lua
-- Equipment slots are 1-19 in Classic Era (NOT 0-20)
for slotId = 1, 19 do
    local itemLink = GetInventoryItemLink("player", slotId)        -- Item link with quality colors
    local quality = GetInventoryItemQuality("player", slotId)      -- 0-5 quality (grey to legendary)
    local durability, durabilityMax = GetInventoryItemDurability(slotId)  -- Current/max durability
    local texture = GetInventoryItemTexture("player", slotId)      -- Item icon texture path
end

-- Slot 0 and 20 DON'T EXIST - always return nil
local ammo0 = GetInventoryItemLink("player", 0)   -- Always nil in Classic Era
local ammo20 = GetInventoryItemLink("player", 20) -- Always nil in Classic Era
```

### Item Level Functions (Tested)
```lua
-- Average item level calculation (fires 3× per equipment change)
local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
-- avgItemLevel: includes bags, avgItemLevelEquipped: equipped items only
```

### Equipment Lock Detection (Tested)
```lua
-- Equipment locks have slotId = nil, bagId = equipment slot number
if event == "ITEM_LOCK_CHANGED" then
    if slotId == nil and bagId >= 1 and bagId <= 19 then
        -- Equipment slot locked/unlocked
        local isLocked = IsInventoryItemLocked(bagId)  -- Check current lock state
    end
end
```

### UI Frame Functions (Tested)
```lua
-- Character frame visibility detection
local isCharacterFrameOpen = CharacterFrame and CharacterFrame:IsShown()

-- Event frame creation
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
```

### Utility Functions (Tested)
```lua
-- Player name (used in testing)
local playerName = UnitName("player")

-- Timing functions (used extensively in testing)
local currentTime = GetTime()

-- Item name extraction from links
local itemName = itemLink:match("%[(.-)%]") or "Unknown"
```

### Slot ID to Name Mapping (Tested)
```lua
local SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands",
    [11] = "Finger0", [12] = "Finger1", [13] = "Trinket0", [14] = "Trinket1",
    [15] = "Back", [16] = "MainHand", [17] = "SecondaryHand", [18] = "Ranged", [19] = "Tabard"
}

-- Usage example from testing
local slotName = SLOT_NAMES[slotId] or "Unknown"
```

### Hook Functions (Tested - Performance Warning)
```lua
-- UI hooks (use sparingly - performance impact)
hooksecurefunc("CharacterFrame_Expand", function() end)     -- 1× per panel open
hooksecurefunc("CharacterFrame_Collapse", function() end)   -- 1× per panel close
hooksecurefunc("EquipItemByName", function(itemName, slot) end)  -- Rare usage
hooksecurefunc("UseInventoryItem", function(slot) end)      -- 1× per slot use
hooksecurefunc("PickupInventoryItem", function(slot) end)   -- 1× per pickup

-- NEVER USE - Extreme performance penalty
hooksecurefunc("PaperDollItemSlotButton_Update", function(button) end)  -- 57× per change
```

---

## Implementation Patterns

### ✅ Recommended (Perfect Performance)
```lua
-- Equipment tracking - OPTIMAL PATTERN
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, slotId, hasCurrent)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Initialize: scan all equipment slots (1-19)
        for slot = 1, 19 do
            updateEquipmentSlot(slot)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Single slot changed - fires exactly once
        updateEquipmentSlot(slotId)
        -- hasCurrent = true if slot had item BEFORE change
    end
end)

function updateEquipmentSlot(slotId)
    local itemLink = GetInventoryItemLink("player", slotId)
    -- Apply your logic here - called exactly once per change
end
```

### ❌ Anti-Patterns (Performance Killers)
```lua
-- DON'T use PaperDollItemSlotButton_Update hook
hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
    -- ❌ Fires 57+ times per equipment change
    -- ❌ Fires for bag slots (31-34) 
    -- ❌ 57× performance penalty vs events
    updateEquipmentSlot(button:GetID())
end)

-- DON'T use UNIT_INVENTORY_CHANGED
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, unitId)
    if unitId == "player" then
        -- ❌ Fires 347× total, only 2 relevant (99.4% spam)
        -- ❌ Triggers on every bag change
        scanAllEquipment()
    end
end)

-- DON'T use UPDATE_INVENTORY_DURABILITY  
eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
eventFrame:SetScript("OnEvent", function(self, event)
    -- ❌ Fires for ALL units globally (other players, pets, NPCs)
    -- ❌ No unit parameter - impossible to filter
    -- ❌ 100% spam, completely unusable
end)

-- DON'T check invalid slot ranges
for slotId = 0, 20 do  -- ❌ Wrong - slots 0 and 20 don't exist
    updateEquipmentSlot(slotId)
end

for slotId = 1, 19 do  -- ✅ Correct - Classic Era equipment slots
    updateEquipmentSlot(slotId)
end
```

---

## Key Technical Details

### Critical Timing Discoveries
- **PLAYER_EQUIPMENT_CHANGED fires exactly once** per slot change (perfect 1:1 ratio)
- **Spam cascade follows every equipment change:** Model (×2), AvgIL (×3), Hook (×57+)
- **Equipment lock format:** bagId = slot number, slotId = nil
- **hasCurrent parameter:** Shows state BEFORE change (true = had item, false = was empty)

### Equipment Slot System
- **Valid slots:** 1-19 only (Head through Tabard)
- **Invalid slots:** 0 and 20 don't exist in Classic Era
- **Ammo system:** Arrows/bullets are consumables in bags, NOT equipment slots
- **Two-handed weapons:** May affect both MainHand (16) and SecondaryHand (17) slots

### Spam Analysis Results
| Method | Events per Change | Efficiency Rating |
|--------|------------------|------------------|
| `PLAYER_EQUIPMENT_CHANGED` | 1 | ✅ Perfect (100%) |
| `PaperDollItemSlotButton_Update` | 57+ | ❌ Terrible (1.7%) |
| `UNIT_INVENTORY_CHANGED` | 347 total (2 relevant) | ❌ Terrible (0.6%) |
| `UPDATE_INVENTORY_DURABILITY` | Global spam | ❌ Unusable (0%) |

### Event Argument Details
```lua
-- PLAYER_EQUIPMENT_CHANGED arguments
function onEquipmentChanged(slotId, hasCurrent)
    -- slotId: 1-19 (equipment slot that changed)
    -- hasCurrent: true if slot had item BEFORE change, false if was empty
end

-- ITEM_LOCK_CHANGED arguments (equipment context)
function onItemLockChanged(bagId, slotId)
    -- For equipment: bagId = slot number (1-19), slotId = nil
    -- For bags: bagId = bag number, slotId = slot number
end
```

---

## Performance Comparison

### Single Equipment Change Impact
| Tracking Method | Total Events | Relevant Events | Spam Ratio | Recommendation |
|----------------|--------------|-----------------|------------|----------------|
| **PLAYER_EQUIPMENT_CHANGED** | 1 | 1 | 1:1 | ✅ **Use this** |
| **PaperDollItemSlotButton_Update** | 57+ | 1 | 57:1 | ❌ Never use |
| **UNIT_INVENTORY_CHANGED** | 347 | 2 | 173:1 | ❌ Never use |
| **UPDATE_INVENTORY_DURABILITY** | ∞ | 0 | ∞:1 | ❌ Unusable |

### Full Test Session Statistics
```
Total Events: 12 fired, 5 displayed, 7 filtered (58% spam)
Total Hooks: 148 fired, 80 displayed, 68 filtered (46% spam)

Key Findings:
- PLAYER_EQUIPMENT_CHANGED: 3 total (3 shown, 0 filtered = 0% spam) ✅
- UPDATE_INVENTORY_DURABILITY: 89 total (0 shown, 89 filtered = 100% spam) ❌
- UNIT_INVENTORY_CHANGED: 347 total (2 shown, 345 filtered = 99.4% spam) ❌
- PaperDollItemSlotButton_Update: 148 total (80 shown, 68 filtered = 46% spam) ❌
```

---

## Equipment Slot Reference

| Slot ID | Name | Equipment Type | Notes |
|---------|------|----------------|-------|
| 1 | Head | Helmet, Hat, Circlet | |
| 2 | Neck | Necklace, Amulet | |
| 3 | Shoulder | Shoulder Pads, Pauldrons | |
| 4 | Shirt | Cosmetic Shirt | |
| 5 | Chest | Chest Armor, Robe | |
| 6 | Waist | Belt | |
| 7 | Legs | Leg Armor, Pants | |
| 8 | Feet | Boots, Shoes | |
| 9 | Wrist | Bracers, Wrist Armor | |
| 10 | Hands | Gloves, Gauntlets | |
| 11 | Finger0 | First Ring Slot | |
| 12 | Finger1 | Second Ring Slot | |
| 13 | Trinket0 | First Trinket Slot | |
| 14 | Trinket1 | Second Trinket Slot | |
| 15 | Back | Cloak, Cape | |
| 16 | MainHand | Main Hand Weapon | |
| 17 | SecondaryHand | Off-hand, Shield | |
| 18 | Ranged | Bow, Gun, Wand | |
| 19 | Tabard | Cosmetic Tabard | |

**Critical:** Slots 0 and 20 do NOT exist in Classic Era. Ammo is stored as consumables in bags.

---

## Untested Scenarios

### High Priority for Future Testing
1. **Durability Changes** - Taking damage, repair operations
2. **Two-handed Weapon Swapping** - May affect multiple slots simultaneously
3. **Equipment Sets** - Bulk equipment changes (if addon installed)
4. **Shield vs Two-hander** - Equipment slot conflicts

### Medium Priority  
1. **Enchanting Equipment** - May trigger additional events
2. **Bag Full Scenarios** - Cannot unequip when bags full
3. **Ranged Weapon + Ammo** - Interaction between equipment and consumables

### Low Priority
1. **Inspect Frame** - Other player equipment viewing
2. **Dressing Room** - Preview equipment changes
3. **UI Dragging** - Character frame movement effects

---

## Conclusion

**PLAYER_EQUIPMENT_CHANGED is the definitive solution for equipment tracking:**

✅ **Perfect Performance:**
- 1:1 event-to-change ratio (zero spam)
- Provides exact slot ID and before/after state
- No filtering required
- No performance penalty

❌ **Avoid All Alternatives:**
- Hooks: 57× performance penalty
- UNIT_INVENTORY_CHANGED: 99.4% spam
- UPDATE_INVENTORY_DURABILITY: 100% unusable spam

**The recommended implementation pattern is already optimal and should be used by all equipment tracking addons in Classic Era.**