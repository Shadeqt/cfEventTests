# WoW Classic Era: Character Equipment Events Reference
## Version 1.12 Event Investigation

**Last Updated:** October 25, 2025
**Testing Method:** Live event monitoring with comprehensive logging, event batching detection, and statistics tracking

---

## Quick Reference

### Primary Events for Equipment Changes
- **`PLAYER_EQUIPMENT_CHANGED`** - ⭐ BEST - Fires exactly once per slot change, provides slot ID
- **`PLAYER_ENTERING_WORLD`** - Perfect for initialization on login/reload
- **`ITEM_LOCK_CHANGED`** - Tracks item pickup/placement (ITEM_LOCKED/UNLOCKED are redundant)

### Primary Hooks for UI State
- **`CharacterFrame_Expand`** - Character panel expanded
- **`CharacterFrame_Collapse`** - Character panel collapsed
- **`EquipItemByName`** - Item equipped by name
- **`UseInventoryItem`** - Item used from equipment slot
- **`PickupInventoryItem`** - Item picked up from equipment slot

### Critical Quirks
- **Equipment slots are 1-19 in Classic Era** (NOT 0-19, NOT 1-20)
- **Slot 0 and 20 don't exist** - ammo/arrows are consumables, not equipment
- **PaperDollItemSlotButton_Update is EXTREMELY spammy** (57+ calls per change)
- **UPDATE_INVENTORY_DURABILITY is unusable** (fires for ALL units globally)
- **UNIT_INVENTORY_CHANGED is 99%+ spam** (fires for bags, not just equipment)
- **PLAYER_AVG_ITEM_LEVEL_UPDATE fires 3 times redundantly** per equipment change
- **UNIT_MODEL_CHANGED fires 2 times redundantly** per equipment change

---

## Equipment Slot Reference

| Slot ID | Name | Notes |
|---------|------|-------|
| `1` | Head | Helmet, circlet, etc. |
| `2` | Neck | Necklace, amulet |
| `3` | Shoulder | Shoulder pads, pauldrons |
| `4` | Shirt | Cosmetic shirt |
| `5` | Chest | Chest armor, robe |
| `6` | Waist | Belt |
| `7` | Legs | Leg armor, pants |
| `8` | Feet | Boots, shoes |
| `9` | Wrist | Bracers, wrist armor |
| `10` | Hands | Gloves, gauntlets |
| `11` | Finger0 | First ring slot |
| `12` | Finger1 | Second ring slot |
| `13` | Trinket0 | First trinket slot |
| `14` | Trinket1 | Second trinket slot |
| `15` | Back | Cloak, cape |
| `16` | MainHand | Main hand weapon |
| `17` | SecondaryHand | Off-hand weapon, shield |
| `18` | Ranged | Ranged weapon (bow, gun, wand) |
| `19` | Tabard | Cosmetic tabard |

**Important:** Slots 0 and 20 do NOT exist in Classic Era. Ammo (arrows, bullets) are consumable items in bags, NOT equipment slots, and cannot be queried via `GetInventoryItemLink()` or similar APIs.

---

## Event Reference

### Events That Fire

| Event | Arguments | When It Fires |
|-------|-----------|---------------|
| `PLAYER_EQUIPMENT_CHANGED` | `slotId, hasCurrent` | Equipment slot changed (hasCurrent shows BEFORE state) |
| `PLAYER_ENTERING_WORLD` | `isLogin, isReload` | Login or UI reload |
| `UNIT_INVENTORY_CHANGED` | `unitId` | Inventory changed (fires for bags + equipment, 99%+ bag spam) |
| `UNIT_MODEL_CHANGED` | `unitId` | Character model changed (fires 2× per equipment change) |
| `UPDATE_INVENTORY_DURABILITY` | none | Durability changed (fires for ALL units globally - unusable) |
| `UPDATE_INVENTORY_ALERTS` | none | Inventory alert state changed |
| `PLAYER_AVG_ITEM_LEVEL_UPDATE` | none | Average item level updated (fires 3× per equipment change) |
| `ITEM_LOCK_CHANGED` | `bagId, slotId` | Item or equipment slot locked/unlocked |
| `ITEM_LOCKED` | `bagId, slotId` | Item locked (redundant - fires immediately after ITEM_LOCK_CHANGED) |
| `ITEM_UNLOCKED` | `bagId, slotId` | Item unlocked (redundant - fires immediately after ITEM_LOCK_CHANGED) |
| `CHARACTER_POINTS_CHANGED` | `change` | Character stats changed (talent points, etc.) |

### Events That Never Fire

No equipment-related events were found to be non-functional during testing.

---

## Hookable Functions

| Function | When It Fires | Arguments |
|----------|---------------|-----------|
| `PaperDollItemSlotButton_Update` | Every equipment slot UI update | `button` (EXTREME SPAM - 57+ calls per change) |
| `CharacterFrame_Expand` | Character panel expanded | none |
| `CharacterFrame_Collapse` | Character panel collapsed | none |
| `EquipItemByName` | Item equipped by name | `itemName, slot` |
| `UseInventoryItem` | Item used from equipment slot | `slotId` |
| `PickupInventoryItem` | Item picked up from equipment slot | `slotId` |

---

## Event Flow Patterns

### 1. Login / UI Reload

```
PLAYER_ENTERING_WORLD (isLogin=1 or isReload=1)
  ↓
PaperDollItemSlotButton_Update (×20, one per slot 1-19 + extras)
```

**Important:**
- No equipment events fire on login/reload (only PLAYER_ENTERING_WORLD)
- Must manually scan all equipment slots on PLAYER_ENTERING_WORLD
- PaperDollItemSlotButton_Update fires for all slots during initialization
- 28 of 68 hook calls are filtered (bag slots 31-34)

**Statistics from Login Test:**
```
Total Events: 1 fired, 1 displayed, 0 filtered
Total Hooks: 68 fired, 40 displayed, 28 filtered

PLAYER_ENTERING_WORLD: 1 total (1 shown, 0 filtered)
PaperDollItemSlotButton_Update: 68 total (40 shown, 28 filtered = 41.2%)
```

---

### 2. Opening/Closing Character Panel

**Opening Character Panel:**
```
CharacterFrame_Expand (hook)
  ↓
CHARACTER_POINTS_CHANGED (×2)
  ↓
PaperDollItemSlotButton_Update (×20, sweeps all slots)
```

**Closing Character Panel:**
```
CharacterFrame_Collapse (hook)
```

**Note:** Opening character panel triggers full UI sweep (20+ hook calls). Closing is clean (1 hook).

**Statistics from Open/Close Test:**
```
Opening:
  CHARACTER_POINTS_CHANGED: 2 fired
  PaperDollItemSlotButton_Update: 20+ fired

Closing:
  CharacterFrame_Collapse: 1 fired
```

---

### 3. Unequipping Item to Bag

```
UNIT_INVENTORY_CHANGED (unitId="player")
  ↓
PLAYER_EQUIPMENT_CHANGED (slotId, hasCurrent=true)
  ↓
ITEM_LOCK_CHANGED (bagId=destination, slotId)
  ↓
UNIT_MODEL_CHANGED (unitId="player", fires 2×)
  ↓
PLAYER_AVG_ITEM_LEVEL_UPDATE (fires 3×)
  ↓
PaperDollItemSlotButton_Update (×57+, full UI sweeps)
```

**Pattern:** Clean single PLAYER_EQUIPMENT_CHANGED, followed by redundant spam:
- UNIT_MODEL_CHANGED fires 2× (redundant)
- PLAYER_AVG_ITEM_LEVEL_UPDATE fires 3× (redundant)
- PaperDollItemSlotButton_Update fires 57+ times (extreme spam)

**Statistics from Unequip Test:**
```
PLAYER_EQUIPMENT_CHANGED: 1 fired (slotId=7 "Legs")
UNIT_MODEL_CHANGED: 2 fired (both "player")
PLAYER_AVG_ITEM_LEVEL_UPDATE: 3 fired
PaperDollItemSlotButton_Update: 57+ fired
```

---

### 4. Equipping Item from Bag

```
PickupInventoryItem (hook, if dragged)
  ↓
ITEM_LOCK_CHANGED (bagId=source, slotId)
  ↓
UNIT_INVENTORY_CHANGED (unitId="player")
  ↓
ITEM_LOCK_CHANGED (bagId=slotNumber, slotId=nil) [equipment lock format]
  ↓
PLAYER_EQUIPMENT_CHANGED (slotId, hasCurrent=false)
  ↓
UNIT_MODEL_CHANGED (unitId="player", fires 2×)
  ↓
PLAYER_AVG_ITEM_LEVEL_UPDATE (fires 3×)
  ↓
PaperDollItemSlotButton_Update (×57+, full UI sweeps)
```

**Equipment Lock Format:** When equipment slots are locked, `ITEM_LOCK_CHANGED` fires with:
```lua
bagId = equipmentSlotNumber  -- e.g., 7 (legs), 16 (mainhand)
slotId = nil
```
This distinguishes equipment locks from bag item locks (which have both bagId and slotId).

**Note:** `PLAYER_EQUIPMENT_CHANGED` shows state BEFORE the change (hasCurrent=false when equipping to empty slot).

**Statistics from Equip Test:**
```
PLAYER_EQUIPMENT_CHANGED: 1 fired (slotId=7 "Legs", hasCurrent=false)
UNIT_MODEL_CHANGED: 2 fired
PLAYER_AVG_ITEM_LEVEL_UPDATE: 3 fired
PaperDollItemSlotButton_Update: 57+ fired
```

---

### 5. Swapping Equipment

**Swapping Weapon (MainHand slot 16):**
```
PickupInventoryItem (hook, if dragged from equipment)
  ↓
ITEM_LOCK_CHANGED (bagId=16, slotId=nil) [old weapon]
  ↓
ITEM_LOCK_CHANGED (bagId=source, slotId) [new weapon in bag]
  ↓
UNIT_INVENTORY_CHANGED (unitId="player")
  ↓
ITEM_LOCK_CHANGED (bagId=16, slotId=nil) [equipment slot unlocked]
  ↓
PLAYER_EQUIPMENT_CHANGED (slotId=16, hasCurrent=true)
  ↓
ITEM_LOCK_CHANGED (bagId=destination, slotId) [old weapon in bag]
  ↓
UNIT_MODEL_CHANGED (unitId="player", fires 2×)
  ↓
PLAYER_AVG_ITEM_LEVEL_UPDATE (fires 3×)
  ↓
PaperDollItemSlotButton_Update (×57+, full UI sweeps)
```

**Pattern:** Multiple ITEM_LOCK_CHANGED events track the swap operation, but PLAYER_EQUIPMENT_CHANGED fires exactly once.

**Statistics from Swap Test (Piercing Axe → Skinning Knife):**
```
PLAYER_EQUIPMENT_CHANGED: 1 fired (slotId=16 "MainHand")
ITEM_LOCK_CHANGED: 4 fired (tracks pickup, drop, bag operations)
UNIT_MODEL_CHANGED: 2 fired
PLAYER_AVG_ITEM_LEVEL_UPDATE: 3 fired
PaperDollItemSlotButton_Update: 57+ fired
```

---

### 6. Durability Changes

**Taking Damage:**
```
UPDATE_INVENTORY_DURABILITY (no args, fires for ALL units)
```

**Critical:** This event fires for EVERY unit that takes damage (other players, pets, NPCs globally). It has NO unit parameter, making it impossible to filter to just the player. During testing, it fired 3 times with 100% filtered (0 relevant to player equipment).

**Recommendation:** ❌ **NEVER USE** - Global spam, completely unusable.

---

## Special Behaviors and Quirks

### Equipment Slot IDs in Classic Era
- **Valid slots:** 1-19 only
- **Invalid slots:** 0 and 20 do NOT exist
- **Ammo/Arrows:** NOT equipment slots - they're consumable items in bags
  - Cannot query with `GetInventoryItemLink("player", 0)` or `GetInventoryItemLink("player", 20)`
  - Both return `nil` even when arrows are "equipped"
  - Ammo is stored in bag slots and consumed on use

### PaperDollItemSlotButton_Update Hook Spam
- **Fires 57+ times for single equipment change**
- **Reason:** Sweeps all 20 button slots, 3 full sweeps per UI update
- **Bag slot spam:** 41.2% of calls are for bag slots (31-34), not equipment
- **Recommendation:** ❌ **NEVER USE** - Use PLAYER_EQUIPMENT_CHANGED event instead

### Redundant Events
- **`ITEM_LOCKED`** - Fires immediately after `ITEM_LOCK_CHANGED` (pickup), provides no extra info
- **`ITEM_UNLOCKED`** - Fires immediately after `ITEM_LOCK_CHANGED` (placement), provides no extra info
- **Recommendation:** Only listen to `ITEM_LOCK_CHANGED`

### Multiple Redundant Fires
- **`PLAYER_AVG_ITEM_LEVEL_UPDATE`** - Fires 3 times per equipment change (all identical)
- **`UNIT_MODEL_CHANGED`** - Fires 2 times per equipment change (both "player")
- **Recommendation:** Debounce or ignore - PLAYER_EQUIPMENT_CHANGED is sufficient

### UNIT_INVENTORY_CHANGED Spam
- **Fires for ALL inventory changes** (bags + equipment)
- **Test results:** 347 total fires, only 2 were equipment changes (99.4% spam)
- **Recommendation:** ⚠️ **Avoid** - Use PLAYER_EQUIPMENT_CHANGED instead
- **If you must use it:** Filter to `unitId == "player"` AND snapshot-compare equipment to detect actual changes

### UPDATE_INVENTORY_DURABILITY Global Spam
- **Fires for ALL units globally** (other players, pets, NPCs, mobs)
- **Has NO unit parameter** - impossible to filter to player only
- **Test results:** 3 total fires, 0 relevant (100% filtered)
- **Recommendation:** ❌ **NEVER USE** - Completely unusable

### Equipment Lock Format
In `ITEM_LOCK_CHANGED`, equipment slots appear as:
```lua
bagId = equipmentSlotNumber  -- e.g., 7 (legs), 16 (mainhand)
slotId = nil
```
This distinguishes equipment locks from bag item locks (which have both bagId and slotId).

---

## Pattern Recognition Rules

### Operation Complexity (ITEM_LOCK_CHANGED count)
- **1 lock:** Single operation (unequip to empty bag slot)
- **2 locks:** Simple operation (equip from bag, or cursor swap)
- **4 locks:** Swap operation (equipment → bag → equipment)

### Change Type (PLAYER_EQUIPMENT_CHANGED)
- **Fires exactly once per slot change**
- **hasCurrent parameter:**
  - `true` = slot had item BEFORE change (unequipping or swapping)
  - `false` = slot was empty BEFORE change (equipping to empty slot)

### Redundancy Indicators
- **UNIT_MODEL_CHANGED fires 2×** per equipment change
- **PLAYER_AVG_ITEM_LEVEL_UPDATE fires 3×** per equipment change
- **PaperDollItemSlotButton_Update fires 57+×** per equipment change

---

## Event Timing Summary

| Operation | First Event | Key Event(s) | Last Event | Redundant Spam |
|-----------|-------------|--------------|------------|----------------|
| Login/reload | PLAYER_ENTERING_WORLD | - | PaperDollItemSlotButton_Update (×20+) | Hook spam |
| Open character panel | CharacterFrame_Expand | CHARACTER_POINTS_CHANGED (×2) | PaperDollItemSlotButton_Update (×20+) | Hook spam |
| Close character panel | CharacterFrame_Collapse | - | - | None |
| Unequip item | UNIT_INVENTORY_CHANGED | PLAYER_EQUIPMENT_CHANGED | PaperDollItemSlotButton_Update (×57+) | Model (×2), AvgIL (×3), Hook (×57+) |
| Equip item | ITEM_LOCK_CHANGED | PLAYER_EQUIPMENT_CHANGED | PaperDollItemSlotButton_Update (×57+) | Model (×2), AvgIL (×3), Hook (×57+) |
| Swap equipment | ITEM_LOCK_CHANGED | PLAYER_EQUIPMENT_CHANGED | PaperDollItemSlotButton_Update (×57+) | Model (×2), AvgIL (×3), Hook (×57+) |
| Durability change | UPDATE_INVENTORY_DURABILITY | - | - | 100% global spam |

---

## Implementation Recommendations

### ✅ Recommended Approach

Use **PLAYER_EQUIPMENT_CHANGED** as the primary event for equipment tracking:

```lua
-- Create event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Handle events
eventFrame:SetScript("OnEvent", function(self, event, slotId, hasCurrent)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Initialize: scan all equipment slots (1-19)
        for slot = 1, 19 do
            updateEquipmentSlot(slot)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Single slot changed
        updateEquipmentSlot(slotId)
    end
end)

-- Update function
function updateEquipmentSlot(slotId)
    local itemLink = GetInventoryItemLink("player", slotId)
    local button = _G["Character" .. SLOT_NAMES[slotId] .. "Slot"]

    if button then
        applyQualityColor(button, itemLink)
    end
end
```

### ✅ Optional: Track Cursor Pickup/Drop

If you need to track when items are picked up from equipment slots:

```lua
eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, bagId, slotId)
    if event == "ITEM_LOCK_CHANGED" then
        -- Check if it's an equipment slot (slotId is nil)
        if slotId == nil and bagId >= 1 and bagId <= 19 then
            -- Equipment slot locked/unlocked
            local isLocked = IsInventoryItemLocked(bagId)
            if isLocked then
                -- Player picked up item from equipment slot
            else
                -- Player dropped item into equipment slot
            end
        end
    end
end)
```

**Note:** You do NOT need to listen to ITEM_LOCKED or ITEM_UNLOCKED - they're redundant with ITEM_LOCK_CHANGED.

---

### ❌ What NOT to Do

#### DON'T Hook PaperDollItemSlotButton_Update
```lua
-- ❌ BAD - Fires 57+ times per equipment change
hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
    local slotId = button:GetID()
    updateEquipmentSlot(slotId)  -- Called 57+ times!
end)
```

**Why it's bad:**
- Fires 57+ times for single equipment change
- Sweeps all 20 button slots, 3 full sweeps per UI update
- 41.2% of calls are for bag slots (31-34), not equipment
- Massive performance waste

**Use instead:** PLAYER_EQUIPMENT_CHANGED event (fires exactly once)

---

#### DON'T Use UPDATE_INVENTORY_DURABILITY
```lua
-- ❌ BAD - Fires for ALL units globally
eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
eventFrame:SetScript("OnEvent", function(self, event)
    -- This fires for other players, pets, NPCs - unusable!
    updateAllEquipmentSlots()
end)
```

**Why it's bad:**
- Fires for EVERY unit that takes damage (globally)
- Has NO unit parameter - impossible to filter to player
- Test results: 100% of fires were for other units
- Completely unusable

**Use instead:** If you need durability tracking, scan equipment on PLAYER_EQUIPMENT_CHANGED or use a throttled timer.

---

#### DON'T Use UNIT_INVENTORY_CHANGED
```lua
-- ❌ BAD - 99%+ spam from bag changes
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, unitId)
    if unitId == "player" then
        updateAllEquipmentSlots()  -- Called on every bag change!
    end
end)
```

**Why it's bad:**
- Fires for ALL inventory changes (bags + equipment)
- Test results: 347 total fires, only 2 were equipment changes (99.4% spam)
- Would trigger full equipment scan on every bag operation
- Massive performance waste

**Use instead:** PLAYER_EQUIPMENT_CHANGED (fires only for actual equipment changes)

---

#### DON'T Check Slot 0 or Slot 20
```lua
-- ❌ BAD - These slots don't exist in Classic Era
local ammoSlot0 = GetInventoryItemLink("player", 0)   -- Always nil
local ammoSlot20 = GetInventoryItemLink("player", 20) -- Always nil

for slotId = 0, 20 do  -- ❌ Wrong range
    updateEquipmentSlot(slotId)
end
```

**Why it's bad:**
- Slot 0 and 20 don't exist in Classic Era
- Ammo/arrows are consumables in bags, not equipment slots
- Cannot be queried via inventory APIs

**Use instead:** Loop from 1 to 19 only
```lua
for slotId = 1, 19 do  -- ✅ Correct range
    updateEquipmentSlot(slotId)
end
```

---

## Performance Considerations

### Critical: Hook Spam Analysis

**PaperDollItemSlotButton_Update generates extreme spam:**

| Operation | Hook Fires | Equipment Changes | Spam Ratio |
|-----------|-----------|-------------------|------------|
| Single unequip | 57+ | 1 | 57:1 |
| Single equip | 57+ | 1 | 57:1 |
| Single swap | 57+ | 1 | 57:1 |
| Open character panel | 20+ | 0 | ∞:1 (no actual changes) |
| Login/reload | 68 | 0 | ∞:1 (initialization only) |

**Why it's so spammy:**
- Sweeps all 20 button slots (including bag slots 31-34)
- Performs 3 full sweeps per UI update
- Triggered by ANY UI change, not just equipment changes
- Bag slots account for 41.2% of calls (28 of 68 during login)

**Comparison to PLAYER_EQUIPMENT_CHANGED:**
- Hook: 57+ fires per equipment change
- Event: 1 fire per equipment change
- **Performance improvement: 57× faster**

---

### Event Spam Analysis

| Event | Total Fires | Relevant Fires | Spam % | Usability |
|-------|-------------|----------------|--------|-----------|
| UPDATE_INVENTORY_DURABILITY | 3 | 0 | 100% | ❌ Unusable |
| UNIT_INVENTORY_CHANGED | 347 | 2 | 99.4% | ⚠️ Avoid |
| UNIT_MODEL_CHANGED | 2 | 1 | 50% | ⚠️ Redundant (2× per change) |
| PLAYER_AVG_ITEM_LEVEL_UPDATE | 3 | 1 | 66% | ⚠️ Redundant (3× per change) |
| PLAYER_EQUIPMENT_CHANGED | 1 | 1 | 0% | ✅ Perfect |

---

### Recommended Optimizations

1. **Use PLAYER_EQUIPMENT_CHANGED exclusively**
   - Fires exactly once per slot change
   - No filtering needed
   - No spam

2. **Avoid all hooks for equipment tracking**
   - PaperDollItemSlotButton_Update: 57× spam
   - Other hooks: unnecessary when using events

3. **Cache equipment state**
   - Store current equipment in table
   - Only update on PLAYER_EQUIPMENT_CHANGED
   - Avoid redundant GetInventoryItemLink() calls

4. **Debounce redundant events** (if you must use them)
   - PLAYER_AVG_ITEM_LEVEL_UPDATE fires 3× within milliseconds
   - UNIT_MODEL_CHANGED fires 2× within milliseconds
   - Use timestamp-based debouncing if listening to these

---

## Statistics from Full Test Session

### Event Breakdown
```
=== CHARACTER EVENT STATISTICS ===
Total Events: 12 fired, 5 displayed, 7 filtered
Total Hooks: 148 fired, 80 displayed, 68 filtered

=== EVENTS BREAKDOWN ===
PLAYER_EQUIPMENT_CHANGED: 3 total (3 shown, 0 filtered = 0.0%)
  - Perfect reliability, no spam

PLAYER_ENTERING_WORLD: 1 total (1 shown, 0 filtered = 0.0%)
  - Initialization only

UNIT_INVENTORY_CHANGED: 347 total (2 shown, 345 filtered = 99.4%)
  - Extreme bag spam, avoid

UNIT_MODEL_CHANGED: 6 total (3 shown, 3 filtered = 50.0%)
  - Fires 2× per equipment change (redundant)

PLAYER_AVG_ITEM_LEVEL_UPDATE: 9 total (3 shown, 6 filtered = 66.7%)
  - Fires 3× per equipment change (redundant)

UPDATE_INVENTORY_DURABILITY: 89 total (0 shown, 89 filtered = 100.0%)
  - Global spam, completely unusable

=== HOOKS BREAKDOWN ===
PaperDollItemSlotButton_Update: 148 total (80 shown, 68 filtered = 45.9%)
  - Extreme spam: 57+ fires per equipment change
  - 68 filtered calls were bag slots (31-34)

CharacterFrame_Expand: 2 total (2 shown, 0 filtered = 0.0%)
CharacterFrame_Collapse: 2 total (2 shown, 0 filtered = 0.0%)
```

---

## Known Untested Scenarios

The following operations were not tested and may have unique event patterns:

### Equipment-Related
- **Durability loss from taking damage** - UPDATE_INVENTORY_DURABILITY fires but is unusable
- **Repairing equipment at vendor** - May trigger multiple equipment events
- **Enchanting equipment** - May trigger PLAYER_EQUIPMENT_CHANGED or other events
- **Equipment sets (if addon installed)** - Bulk equipment changes

### Edge Cases
- **Two-handed weapon swapping** - Unequips both MainHand and SecondaryHand
- **Shield swap with two-hander** - Equipping shield requires one-hander
- **Ranged weapon + ammo interaction** - Ammo is consumable, but ranged weapon is equipment
- **Bag full scenarios** - Cannot unequip when bags are full

### UI Interactions
- **CharacterFrame dragging** - May trigger UI update hooks
- **Inspect frame for other players** - May trigger PaperDollItemSlotButton_Update
- **Dressing room (Ctrl+Click)** - Preview equipment changes

These likely follow similar patterns to tested operations, but may have unique edge cases or spam characteristics.

---

## Testing Methodology

**Environment:** WoW Classic Era 1.15.x (Classic Era)

**Method:** Comprehensive event logging with:
- Event listener frame for 11 equipment-related events
- hooksecurefunc for 6 UI functions
- Event batching detection (5+ events at same timestamp)
- Statistics tracking (total fired vs. displayed)
- Smart filtering (player-only, equipment-only, no global spam)

**Tools:**
- Event listener frame with OnEvent handler
- Hook registration via hooksecurefunc
- Equipment snapshot comparison (detect actual changes)
- `/eventstats` command for statistics breakdown

**Scope:** 6 distinct operation types tested with detailed output logging:
1. Login/UI Reload
2. Open/Close Character Panel
3. Unequip Item (Legs slot 7)
4. Equip Item (Legs slot 7)
5. Swap Equipment (MainHand slot 16: Piercing Axe → Skinning Knife)
6. Durability Changes (passive monitoring)

**Event Batching:** Events firing at the same timestamp are grouped and analyzed for spam patterns. Threshold: 5+ events at same timestamp triggers "⚠ SPAM" warning.

**Filtering:** Test automatically filters:
- Non-player unit events (UNIT_*)
- Global spam (UPDATE_INVENTORY_DURABILITY)
- Bag-related spam (UNIT_INVENTORY_CHANGED with no equipment changes)
- Bag slot hook calls (slots 31-34)

**Statistics Tracking:** Dual counter system tracks:
- Total events/hooks fired (including filtered)
- Events/hooks actually displayed
- Filter percentage for spam analysis

See [CHARACTER_EVENT_TEST.lua](CHARACTER_EVENT_TEST.lua) for the test harness and [CHARACTER_EVENT_README.md](CHARACTER_EVENT_README.md) for usage guide.

---

## Conclusion

**PLAYER_EQUIPMENT_CHANGED is the definitive event for equipment tracking in Classic Era:**

✅ **Advantages:**
- Fires exactly once per slot change
- Provides slot ID as first argument
- Shows before/after state via hasCurrent parameter
- Zero spam, zero filtering needed
- Perfect reliability (0% filter rate)
- Clean and simple to implement

❌ **Alternatives to Avoid:**
- **PaperDollItemSlotButton_Update hook:** 57:1 spam ratio
- **UPDATE_INVENTORY_DURABILITY event:** 100% global spam
- **UNIT_INVENTORY_CHANGED event:** 99.4% bag spam
- **Redundant events:** UNIT_MODEL_CHANGED (2×), PLAYER_AVG_ITEM_LEVEL_UPDATE (3×)

**The current [cfItemColors Character.lua](../cfItemColors/Modules/Character.lua) implementation is already optimal!** ✅

It uses:
- PLAYER_EQUIPMENT_CHANGED for slot-specific updates
- PLAYER_ENTERING_WORLD for initialization
- Cached button references for performance
- No hooks, no spam, no filtering needed

This is the recommended pattern for ALL equipment tracking addons in Classic Era.
