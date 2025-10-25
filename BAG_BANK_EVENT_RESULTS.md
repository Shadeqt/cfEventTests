# WoW Classic Era: Bag and Bank Events Reference
## Version 1.12 Event Investigation

**Last Updated:** October 25, 2025
**Testing Method:** Live event monitoring with comprehensive logging

---

## Quick Reference

### Primary Events for Bag Changes
- **`BAG_UPDATE`** - Most reliable event for tracking bag content changes
- **`BAG_UPDATE_DELAYED`** - Signals all pending updates are complete
- **`PLAYERBANKSLOTS_CHANGED`** - Required for bank container (ID: -1) changes
- **`ITEM_LOCK_CHANGED`** - Tracks item pickup/placement (ITEM_LOCKED/UNLOCKED are redundant)

### Primary Hooks for UI State
- **`ToggleBag(bagId)`** - Individual bag open/close
- **`OpenAllBags(forceUpdate)`** - System-initiated bag opening (vendor, bank, mailbox)
- **`CloseAllBags()`** - System-initiated bag closing

### Critical Quirks
- Backpack (bag 0) does NOT fire `BAG_UPDATE` on login
- Backpack closes silently via "B" key (no hook fires)
- Cross-bag splits are async (2 `BAG_UPDATE_DELAYED` cycles)
- Buying new items delays ~400ms (item visible in 2nd update cycle)
- Bank container uses `PLAYERBANKSLOTS_CHANGED`, bank bags use `BAG_UPDATE`

---

## Container ID Reference

| Container ID | Type | Slots | Notes |
|--------------|------|-------|-------|
| `-2` | Keyring | Varies | Classic Era only (removed in later expansions) |
| `-1` | Bank Container | 24 | Uses `PLAYERBANKSLOTS_CHANGED` event (not `BAG_UPDATE`). No UI frame. |
| `0` | Backpack | 16-20 | Always present, special behaviors. Maps to ContainerFrame1. |
| `1-4` | Bags | Varies | Regular bag slots. Map to ContainerFrame2-5. |
| `5-10` | Bank bags | Varies | 6 total bank bag slots, use `BAG_UPDATE` like regular bags. Note: `OpenBag` is called for 5-13 but only 5-10 are valid. |

---

## Event Reference

### Events That Fire

| Event | Arguments | When It Fires |
|-------|-----------|---------------|
| `BAG_UPDATE` | `bagId` | Bag contents changed (not for bank container ID:-1) |
| `BAG_UPDATE_DELAYED` | none | All pending bag updates completed |
| `BAG_UPDATE_COOLDOWN` | `bagId` (nil) | Consuming items (potions, food) |
| `ITEM_LOCK_CHANGED` | `bagId, slotId` | Item or equipment slot locked/unlocked |
| `ITEM_LOCKED` | `bagId, slotId` | Item locked (redundant - fires immediately after ITEM_LOCK_CHANGED) |
| `ITEM_UNLOCKED` | `bagId, slotId` | Item unlocked (redundant - fires immediately after ITEM_LOCK_CHANGED) |
| `ITEM_PUSH` | `bagId, iconFileID` | NEW item entering bags (not moves/buybacks) |
| `BAG_NEW_ITEMS_UPDATED` | none | New item flags updated (always follows ITEM_PUSH) |
| `BAG_CONTAINER_UPDATE` | none | Container-wide refresh (login, bank operations) |
| `UNIT_INVENTORY_CHANGED` | `unitId` | Stack operations, deletion, equipment changes |
| `PLAYER_EQUIPMENT_CHANGED` | `slot, hasCurrent` | Equipment slot changed (hasCurrent shows BEFORE state) |
| `PLAYER_ENTERING_WORLD` | `isLogin, isReload` | Login or UI reload |
| `BANKFRAME_OPENED` | none | Bank window opened |
| `BANKFRAME_CLOSED` | none | Bank window closed |
| `PLAYERBANKSLOTS_CHANGED` | `slotId` | Bank container (ID:-1) slot changed |

### Events That Never Fire

- `BAG_OPEN` - Registered but never triggered
- `BAG_CLOSED` - Registered but never triggered
- `BAG_SLOT_FLAGS_UPDATED` - Registered but never triggered
- `PLAYERBANKBAGSLOTS_CHANGED` - Registered but never triggered

---

## Hookable Functions

| Function | When It Fires | Arguments |
|----------|---------------|-----------|
| `ToggleBag` | Individual bag toggle (clicking bag icon) | `bagId` |
| `ToggleBackpack` | Backpack toggle (always fires with ToggleBag(0)) | none |
| `OpenBag` | Open specific bag (B key, system UI) | `bagId, forceUpdate` |
| `CloseBag` | Close specific bag (B key, system UI) | `bagId` |
| `OpenAllBags` | Open all bags (vendor, mailbox, bank) | `forceUpdate` |
| `CloseAllBags` | Close all bags (system-initiated) | none |

---

## Tracking Bag Open/Close State

**Critical Finding:** The `BAG_OPEN` and `BAG_CLOSED` events are **non-functional in Classic Era** (they register but never fire). To track bag open/close state, you must use alternative methods.

### Method 1: Query Current State with `IsBagOpen()`

```lua
local isOpen = IsBagOpen(bagId)
```

This API returns the current open/closed state of a bag at the time of the call.

### Method 2: Monitor ContainerFrame Visibility

Each bag has a corresponding UI frame that can be checked for visibility:

```lua
-- ContainerFrame mapping:
-- ContainerFrame1 = bag 0 (backpack)
-- ContainerFrame2 = bag 1
-- ContainerFrame3 = bag 2
-- ContainerFrame4 = bag 3
-- ContainerFrame5 = bag 4

local containerFrame = _G["ContainerFrame" .. (bagId + 1)]
local isVisible = containerFrame and containerFrame:IsShown()
```

### Method 3: Hook-Based State Tracking

Since no events fire, hooks are the ONLY way to detect state changes in real-time:

```lua
local bagStates = {}  -- [bagId] = true/false

hooksecurefunc("ToggleBag", function(bagId)
    bagStates[bagId] = not bagStates[bagId]
    -- Update colors here
end)

hooksecurefunc("OpenBag", function(bagId)
    bagStates[bagId] = true
    -- Update colors here
end)

hooksecurefunc("CloseBag", function(bagId)
    bagStates[bagId] = false
    -- Update colors here
end)

hooksecurefunc("OpenAllBags", function()
    for i = 0, NUM_BAG_SLOTS do
        bagStates[i] = true
    end
    -- Update colors here
end)

hooksecurefunc("CloseAllBags", function()
    for i = 0, NUM_BAG_SLOTS do
        bagStates[i] = false
    end
    -- Update colors here
end)
```

### Recommended Approach

**Hybrid: Hooks + Periodic Validation**

1. Use hooks to detect state changes immediately (primary method)
2. Periodically verify state with `IsBagOpen()` or `ContainerFrame:IsShown()` as a safety net
3. Update colors immediately when hooks fire
4. Use a short throttle/debounce to avoid excessive updates

### Special Cases

- **Bank Container (ID:-1):** Has no UI frame. Use `BANKFRAME_OPENED/CLOSED` events instead.
- **BankFrame:** The bank UI window (`BankFrame:IsShown()`) is separate from the bank container state
- **Backpack "B" Key Close:** Closes without firing any hook - requires periodic polling to detect

---

## Event Flow Patterns

### 1. Login / UI Reload

```
BAG_UPDATE (bags 1-4, bank bags 5-10) → BAG_CONTAINER_UPDATE → PLAYER_ENTERING_WORLD → BAG_UPDATE_DELAYED
```

**Important:**
- **Bags 1-4 DO fire** `BAG_UPDATE` on login/reload (if they have bag containers equipped)
- **Bank bags 5-10 DO fire** `BAG_UPDATE` on login/reload (if they exist)
- **Backpack (bag 0) does NOT fire** `BAG_UPDATE` on login/reload (special case)

This means you must manually scan bag 0 contents on PLAYER_ENTERING_WORLD, but bags 1-4 will send BAG_UPDATE events automatically.

---

### 2. Opening/Closing Bags

**No events fire** - only hooks are triggered.

#### Opening Bags

**Individual Bag Click (clicking bag icon):**
```
Bags 1-4: ToggleBag(bagId) → UI VISIBLE
Bag 0:    ToggleBag(0) + ToggleBackpack() → UI VISIBLE
```
Simple toggle behavior - just one or two hook calls.

**"B" Key Press (open all):**
```
OpenBag(1) → OpenBag(2) → OpenBag(3) → OpenBag(4) →
ToggleBag(0) + ToggleBackpack() → All bags VISIBLE
```

**System-Initiated (vendor, bank, mailbox):**
```
OpenBag(1) → OpenBag(2) → OpenBag(3) → OpenBag(4) →
OpenAllBags() → ToggleBag(0) + ToggleBackpack() → All bags VISIBLE
```

#### Closing Bags

**Individual Bag Click (clicking bag icon):**
```
Bags 1-4: ToggleBag(bagId) → UI HIDDEN
Bag 0:    ToggleBackpack() → UI HIDDEN
```
Note: Backpack close via click only fires `ToggleBackpack()`, NOT `ToggleBag(0)`.

**"B" Key Press (close all):**
```
CloseBag(1) → CloseBag(2) → CloseBag(3) → CloseBag(4) →
Backpack closes SILENTLY (no hook fires!)
```
**Critical:** Backpack closes without any hook when using "B" key. This requires periodic polling to detect.

**System-Initiated:**
```
CloseAllBags() → All bags HIDDEN
```

---

### 3. Moving Items Between Bags

```
ITEM_LOCK_CHANGED (source) → BAG_UPDATE (source) →
ITEM_LOCK_CHANGED (destination) → BAG_UPDATE (destination) →
BAG_UPDATE_DELAYED
```

**Pattern:** 2 locks, 2 updates, 1 delayed signal (synchronous).

---

### 4. Swapping Items

```
ITEM_LOCK_CHANGED (item1) → ITEM_LOCK_CHANGED (item2) →
ITEM_LOCK_CHANGED (new location 1) + BAG_UPDATE →
ITEM_LOCK_CHANGED (new location 2) + BAG_UPDATE →
BAG_UPDATE_DELAYED
```

**Pattern:** 4 locks, 2 updates, 1 delayed signal (synchronous).

---

### 5. Stack Operations

#### Split Stack (Same Bag)
```
ITEM_LOCK_CHANGED (×2) → BAG_UPDATE (×3) + UNIT_INVENTORY_CHANGED (×2) → BAG_UPDATE_DELAYED
```
**Warning:** Fires 3 `BAG_UPDATE` events with identical contents.

#### Split Stack (Cross-Bag)
```
ITEM_LOCK_CHANGED → BAG_UPDATE (destination, empty) →
ITEM_LOCK_CHANGED → BAG_UPDATE (source) + UNIT_INVENTORY_CHANGED → BAG_UPDATE_DELAYED →
BAG_UPDATE (destination, NOW shows item) + UNIT_INVENTORY_CHANGED → BAG_UPDATE_DELAYED
```
**Warning:** Asynchronous! Two separate `BAG_UPDATE_DELAYED` cycles. Destination visible ~400ms later.

#### Merge Stacks
```
ITEM_LOCK_CHANGED (×2-3) → UNIT_INVENTORY_CHANGED → BAG_UPDATE (×2) → BAG_UPDATE_DELAYED
```
**Note:** Merges are synchronous (both same-bag and cross-bag).

---

### 6. Deleting Items

```
ITEM_LOCK_CHANGED (×3, same slot) → UNIT_INVENTORY_CHANGED → BAG_UPDATE → BAG_UPDATE_DELAYED
```

**Unique Pattern:** Triple `ITEM_LOCK_CHANGED` on the same slot distinguishes deletion from other operations.

---

### 7. Equipment Changes

#### Equipping from Bag
```
ITEM_LOCK_CHANGED (bag) → UNIT_INVENTORY_CHANGED →
ITEM_LOCK_CHANGED (equipment: bagId=slotNumber, slotId=nil) →
PLAYER_EQUIPMENT_CHANGED → BAG_UPDATE → BAG_UPDATE_DELAYED
```

#### Unequipping to Bag
```
UNIT_INVENTORY_CHANGED → PLAYER_EQUIPMENT_CHANGED →
ITEM_LOCK_CHANGED (bag) → BAG_UPDATE → BAG_UPDATE_DELAYED
```

**Equipment Lock Format:** `bagId = equipmentSlotNumber, slotId = nil` (distinguishes from bag slots).

**Note:** `PLAYER_EQUIPMENT_CHANGED` shows state BEFORE the change (hasCurrent=true when removing).

---

### 8. Vendor Operations

#### Selling
```
OpenAllBags (hook) → ITEM_LOCK_CHANGED → BAG_UPDATE (×2, includes keyring) → BAG_UPDATE_DELAYED
```

#### Buying New Item
```
OpenAllBags (hook) → ITEM_PUSH → BAG_NEW_ITEMS_UPDATED →
BAG_UPDATE (×2, item count changes but NOT visible yet) → BAG_UPDATE_DELAYED →
BAG_UPDATE (×2, item NOW visible) + UNIT_INVENTORY_CHANGED → BAG_UPDATE_DELAYED
```
**Warning:** Two `BAG_UPDATE_DELAYED` cycles. Item visible ~400ms later in 2nd cycle.

#### Buyback
```
ITEM_LOCK_CHANGED + ITEM_UNLOCKED → BAG_UPDATE (×2, includes keyring) → BAG_UPDATE_DELAYED
```
**Note:** No `ITEM_PUSH` - buyback is NOT considered a "new" item.

**Keyring Behavior:** Keyring (ID:-2) always fires `BAG_UPDATE` during vendor operations even if contents unchanged.

---

### 9. Consuming Items

```
BAG_UPDATE_COOLDOWN (bagId=nil) → BAG_UPDATE → BAG_UPDATE_DELAYED
```

**Note:** No `ITEM_LOCK_CHANGED` events. `BAG_UPDATE_COOLDOWN` is specific to consumables.

---

### 10. Bank Operations

#### Opening/Closing Bank Window

**Opening Bank:**
```
ToggleBag(0) + ToggleBackpack + OpenBag(1-4) + OpenAllBags(forceUpdate) →
BANKFRAME_OPENED →
All bags become VISIBLE
```

**Opening Bank Bags (clicking "Bag" button at bank):**
```
CloseBag(1-4) → ToggleBag(0) + ToggleBackpack →
OpenBag(1-4) + OpenBag(5-13)
```
**Note:** `OpenBag` is called for bagId 5-13 (9 calls), though only bags 5-10 may have slots. The extra calls (11-13) may be speculative or for future compatibility.

**Closing Bank:**
```
CloseBag(1-4) + CloseAllBags + CloseBag(5-10) → BANKFRAME_CLOSED
```

**No `BAG_UPDATE` events** - only hooks and `BANKFRAME_OPENED/CLOSED`.

#### Moving Items: Bank Container → Bag

**Complete Event Sequence (all 6 events):**
```
ITEM_LOCK_CHANGED (bank container, slot X) + ITEM_LOCKED →
PLAYERBANKSLOTS_CHANGED (slot X) →
BAG_UPDATE (backpack, no changes - DUPLICATE) →
BAG_UPDATE (keyring, no changes - DUPLICATE) →
BAG_CONTAINER_UPDATE →
ITEM_LOCK_CHANGED (destination bag, slot Y) + ITEM_UNLOCKED →
BAG_UPDATE (destination bag, shows new item) →
BAG_UPDATE_DELAYED
```

**Performance Note:** Only 2 events contain useful data (PLAYERBANKSLOTS_CHANGED + final BAG_UPDATE). The other 4 are noise.

#### Swapping Items: Bank Container ↔ Bag

**Complete Event Sequence (12+ events for simple swap):**
```
ITEM_LOCK_CHANGED (bank, slot X) + ITEM_LOCKED →
ITEM_LOCK_CHANGED (bag, slot Y) + ITEM_LOCKED →
ITEM_LOCK_CHANGED (bank, slot X) + ITEM_UNLOCKED →
PLAYERBANKSLOTS_CHANGED (slot X) →
BAG_UPDATE (backpack, no changes - DUPLICATE) →
BAG_UPDATE (keyring, no changes - DUPLICATE) →
BAG_CONTAINER_UPDATE →
ITEM_LOCK_CHANGED (bag, slot Y) + ITEM_UNLOCKED →
BAG_UPDATE (bag, shows swapped item) →
BAG_UPDATE_DELAYED
```

**Performance Warning:** 12+ events generated, but only 4 contain useful data (2 ITEM_LOCK_CHANGED, 1 PLAYERBANKSLOTS_CHANGED, 1 BAG_UPDATE with actual changes). The remaining ~8 events are duplicates/noise.

#### Swapping Items: Within Bank Container

**Complete Event Sequence (14+ events for swap within bank):**
```
ITEM_LOCK_CHANGED (bank, slot X) + ITEM_LOCKED →
ITEM_LOCK_CHANGED (bank, slot Y) + ITEM_LOCKED →
ITEM_LOCK_CHANGED (bank, slot X) + ITEM_UNLOCKED →
PLAYERBANKSLOTS_CHANGED (slot X) →
BAG_UPDATE (backpack, no changes - DUPLICATE) →
BAG_UPDATE (keyring, no changes - DUPLICATE) →
BAG_CONTAINER_UPDATE →
ITEM_LOCK_CHANGED (bank, slot Y) + ITEM_UNLOCKED →
PLAYERBANKSLOTS_CHANGED (slot Y) →
BAG_UPDATE (backpack, no changes - DUPLICATE) →
BAG_UPDATE (keyring, no changes - DUPLICATE) →
BAG_CONTAINER_UPDATE →
BAG_UPDATE_DELAYED
```

**Critical Performance Note:** Each bank slot update triggers 4 events (PLAYERBANKSLOTS_CHANGED + 3 duplicates). A simple swap = 2 slots = 8 events of noise + 4 useful events.

#### Moving Items: Bank Bags

Bank bags (ID: 5-10) use `BAG_UPDATE` exactly like regular bags (1-4). No special handling or duplicate events.

**Pattern for moving between bank bags:**
```
ITEM_LOCK_CHANGED (source bank bag) →
BAG_UPDATE (source bank bag) →
ITEM_LOCK_CHANGED (destination bank bag) →
BAG_UPDATE (destination bank bag) →
BAG_UPDATE_DELAYED
```

Clean, simple pattern - identical to regular bag operations.

#### Cross-Container Operation Summary

Any operation involving bank **container** (ID:-1) triggers:
- `PLAYERBANKSLOTS_CHANGED` (for each bank slot affected)
- `BAG_UPDATE` (backpack) - **DUPLICATE, no changes**
- `BAG_UPDATE` (keyring) - **DUPLICATE, no changes**
- `BAG_CONTAINER_UPDATE` (for each bank slot affected)

These duplicate events fire **EVERY TIME** a bank container slot changes, even if backpack and keyring are completely unchanged.

---

## Pattern Recognition Rules

### Operation Complexity (ITEM_LOCK_CHANGED count)
- **2 locks:** Simple operation (move, split)
- **3 locks:** Merge or deletion
- **4 locks:** Swap operation

### Change Type (UNIT_INVENTORY_CHANGED count)
- **0 times:** Pure location change (move, swap)
- **1 time:** Item destroyed or equipment interaction
- **2 times:** Stack count changed (split, merge)

### Timing (BAG_UPDATE_DELAYED count)
- **1 time:** Synchronous operation (most operations)
- **2 times:** Asynchronous operation (cross-bag split, buying new items)

### New Items (ITEM_PUSH)
- Fires for truly NEW items entering inventory (loot, purchases, quest rewards)
- Does NOT fire for moves, swaps, or buybacks
- Fires BEFORE item is visible in bag contents
- Always followed immediately by `BAG_NEW_ITEMS_UPDATED`

---

## Special Behaviors and Quirks

### Backpack (Bag 0)
- **Login:** Does NOT fire `BAG_UPDATE` (unlike bags 1-4)
- **Opening:** Fires both `ToggleBag(0)` and `ToggleBackpack()`
- **Closing via click:** Only `ToggleBackpack()` fires (no `ToggleBag(0)`)
- **Closing via "B" key:** Closes **silently** without any hookable function call

### Bank Container vs Bank Bags
- **Bank container (ID:-1):**
  - Uses `PLAYERBANKSLOTS_CHANGED` event (NOT `BAG_UPDATE`)
  - Has no UI frame (no ContainerFrame to check visibility)
  - Always in "CLOSED" state from `IsBagOpen()` perspective
  - Use `BankFrame:IsShown()` to check if bank window is open
  - Generates massive event spam (see Performance Considerations)
- **Bank bags (ID:5-10):**
  - Use `BAG_UPDATE` event (identical to regular bags 1-4)
  - Clean event patterns, no duplicate spam
  - `OpenBag` is called for 5-13 but only 5-10 are valid
- **Detection:** Listen to both `BAG_UPDATE` and `PLAYERBANKSLOTS_CHANGED` to handle all bank operations

### Keyring (ID:-2)
- Classic Era only (removed in later expansions)
- Always fires `BAG_UPDATE` during vendor operations, even if contents unchanged
- Suggests WoW checks all containers during vendor transactions

### Redundant Events
- **`ITEM_LOCKED`** - Fires immediately after `ITEM_LOCK_CHANGED` (pickup), provides no extra info
- **`ITEM_UNLOCKED`** - Fires immediately after `ITEM_LOCK_CHANGED` (placement), provides no extra info
- **Recommendation:** Only listen to `ITEM_LOCK_CHANGED`

### Asynchronous Operations
- **Cross-bag splits:** Destination bag updates ~400ms after source (2 `BAG_UPDATE_DELAYED` cycles)
- **Buying new items:** Item visible ~400ms after first update (2 `BAG_UPDATE_DELAYED` cycles)
- **Cross-bag merges:** Synchronous (unlike splits)

### Duplicate Updates
- **Same-bag splits:** Fire 3 `BAG_UPDATE` events with identical contents (300% spam)
- **Bank container operations:** Fire duplicate `BAG_UPDATE` on backpack AND keyring on EVERY bank slot change, even when completely unchanged (see Performance section for details - 66-71% event spam)
- **Vendor operations:** Keyring fires `BAG_UPDATE` on every transaction even if unchanged
- **Critical Recommendation:** MUST implement content comparison to filter duplicate events. Do NOT process BAG_UPDATE blindly. Bank operations alone generate 2:1 noise-to-signal ratio.

### Equipment Lock Format
In `ITEM_LOCK_CHANGED`, equipment slots appear as:
```lua
bagId = equipmentSlotNumber  -- e.g., 8 (feet), 11 (finger)
slotId = nil
```
This distinguishes equipment locks from bag item locks (which have both bagId and slotId).

---

## Event Timing Summary

| Operation | First Event | Key Event(s) | Last Event |
|-----------|-------------|--------------|------------|
| Open/close bags | Hook | - | Hook |
| Move item | ITEM_LOCK_CHANGED | - | BAG_UPDATE_DELAYED |
| Swap items | ITEM_LOCK_CHANGED | - | BAG_UPDATE_DELAYED |
| Split stack | ITEM_LOCK_CHANGED | UNIT_INVENTORY_CHANGED | BAG_UPDATE_DELAYED (×1 or ×2) |
| Merge stack | ITEM_LOCK_CHANGED | UNIT_INVENTORY_CHANGED | BAG_UPDATE_DELAYED |
| Delete item | ITEM_LOCK_CHANGED (×3) | UNIT_INVENTORY_CHANGED | BAG_UPDATE_DELAYED |
| Equip/unequip | ITEM_LOCK_CHANGED or UNIT_INVENTORY_CHANGED | PLAYER_EQUIPMENT_CHANGED | BAG_UPDATE_DELAYED |
| Sell/buyback | ITEM_LOCK_CHANGED | - | BAG_UPDATE_DELAYED |
| Buy new item | ITEM_PUSH | BAG_NEW_ITEMS_UPDATED | BAG_UPDATE_DELAYED (×2) |
| Consume item | BAG_UPDATE_COOLDOWN | - | BAG_UPDATE_DELAYED |
| Bank operations | ITEM_LOCK_CHANGED | PLAYERBANKSLOTS_CHANGED + BAG_CONTAINER_UPDATE | BAG_UPDATE_DELAYED |

---

## Implementation Recommendations

### Essential Events
1. **`BAG_UPDATE`** - Primary event for tracking bag content changes
2. **`PLAYERBANKSLOTS_CHANGED`** - Required for bank container (ID:-1)
3. **`BAG_UPDATE_DELAYED`** - Signal that all updates are complete
4. **`BANKFRAME_OPENED/CLOSED`** - Track bank availability

### Optional Events (For Advanced Features)
- **`ITEM_LOCK_CHANGED`** - Early warning before BAG_UPDATE (ignore ITEM_LOCKED/UNLOCKED)
- **`ITEM_PUSH`** - Detect new items entering bags (loot, purchases)
- **`PLAYER_EQUIPMENT_CHANGED`** - Track equipment changes affecting bags

### Avoid Listening To
- **`ITEM_LOCKED/ITEM_UNLOCKED`** - Redundant with ITEM_LOCK_CHANGED
- **`BAG_CONTAINER_UPDATE`** - Too rare/broad (BAG_UPDATE more precise)
- **`BAG_UPDATE_COOLDOWN`** - Too specific (BAG_UPDATE catches these)

### Performance Considerations

#### Critical: Bank Operation Event Spam

**WARNING:** Bank container operations generate an extreme 2:1 noise-to-signal ratio.

- **Simple bank move:** 6 events total (2 useful, 4 noise = 66% waste)
- **Bank swap:** 12+ events total (4 useful, 8+ noise = 66% waste)
- **Bank internal swap:** 14+ events total (4 useful, 10+ noise = 71% waste)

**Root Cause:** EVERY `PLAYERBANKSLOTS_CHANGED` triggers:
1. The actual bank slot change (useful)
2. `BAG_UPDATE` on backpack - **ALWAYS duplicate, ALWAYS unchanged**
3. `BAG_UPDATE` on keyring - **ALWAYS duplicate, ALWAYS unchanged**
4. `BAG_CONTAINER_UPDATE` (broad signal, low value)

**Required Optimization:** Must check for actual item changes before processing. Do NOT blindly react to every BAG_UPDATE when bank is open.

#### Essential Optimizations

1. **Debounce same-bag splits:** Can fire 3 identical BAG_UPDATE events
2. **Handle async operations:** Cross-bag splits and purchases have ~400ms delays
3. **Filter bank operation noise:**
   - Compare bag contents before/after BAG_UPDATE
   - Ignore BAG_UPDATE if items haven't changed
   - Bank operations = 66-71% duplicate events
4. **Filter vendor keyring noise:** Keyring fires BAG_UPDATE on every vendor transaction even if unchanged
5. **Wait for BAG_UPDATE_DELAYED:** Signals completion of batch operations
6. **Use content comparison:** Many operations fire duplicate BAG_UPDATE events with identical contents

#### Recommended Pattern

```lua
local bagSnapshots = {}  -- [bagId] = snapshot of contents

function OnBagUpdate(bagId)
    local oldSnapshot = bagSnapshots[bagId]
    local newSnapshot = SnapshotBag(bagId)

    -- Only process if contents actually changed
    if ContentsChanged(oldSnapshot, newSnapshot) then
        -- Update colors here
        bagSnapshots[bagId] = newSnapshot
    else
        -- Skip processing - duplicate event
    end
end
```

This pattern eliminates wasted processing on:
- Same-bag split duplicates (3 events → 1 processed)
- Bank operation backpack/keyring duplicates (always filtered)
- Vendor keyring duplicates (filtered when unchanged)

---

## Known Untested Scenarios

The following operations were not tested and may have unique event patterns:

- Looting from corpses/containers
- Quest reward selection
- Mail attachment retrieval
- Crafting/profession item creation
- Auto-loot stacking behavior

These likely follow similar patterns to tested operations (e.g., looting probably behaves like vendor purchases with `ITEM_PUSH`).

---

## Testing Methodology

**Environment:** WoW Classic Era 1.15.x (Classic Era)
**Method:** Comprehensive event logging with hooked functions and UI state monitoring
**Tools:** Event listener frame + hooksecurefunc for all bag/bank operations + OnUpdate for ContainerFrame visibility tracking
**Scope:** 35+ distinct operation types tested with detailed output logging including:
- Regular bag operations (open, close, move, swap, split, merge, delete)
- Bank container operations (all combinations of moves and swaps)
- Bank bag operations (moves between bank bags)
- Cross-container operations (bag ↔ bank, bank ↔ bank bags)
- UI state changes (bag open/close detection via ContainerFrame visibility)
- Event spam analysis (duplicate event identification and quantification)

See `BAG_BANK_EVENT_TEST.lua` for the test harness used to generate this data.
