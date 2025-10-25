# WoW Classic Era: Merchant Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing Method:** Live event monitoring with comprehensive logging and merchant interaction testing

---

## Quick Reference

### Primary Events for Merchant Tracking
- **`MERCHANT_SHOW`** - Merchant window opened (fires with stale data)
- **`MERCHANT_UPDATE`** - Merchant data loaded/changed (fires AFTER purchases with fresh data)
- **`MERCHANT_CLOSED`** - Merchant window closed
- **`PLAYER_MONEY`** - Money changes (purchases, sales, repairs)
- **`BAG_UPDATE`** - Item changes in bags (fires +290ms after purchase)
- **`BAG_UPDATE_DELAYED`** - All bag updates completed

### Primary Hooks for Actions
- **`BuyMerchantItem(index, quantity)`** - Purchasing items from merchant
- **`BuybackItem(index)`** - Buying back previously sold items
- **`RepairAllItems(guildBankRepair)`** - Repairing equipment
- **`CloseMerchant()`** - Merchant window closing
- **`SelectGossipOption(index)`** - Selecting gossip options to access merchant

### Critical Quirks
- **MERCHANT_SHOW fires with STALE data** - Item count may be 0, wait for MERCHANT_UPDATE
- **MERCHANT_UPDATE fires AFTER purchases** - Reactive updates, not predictive
- **BAG_UPDATE spam (4× events)** - Fires for bags 0, -2, 0, -2 (backpack + keyring duplicated)
- **Money tracking is precise** - Exact copper amounts tracked per transaction
- **No tab switching events** - Switching between merchant/buyback tabs generates no events
- **Buyback timing** - BuybackItem hook → +187ms → PLAYER_MONEY → BAG_UPDATE

---

## Event Reference

### ✅ Events That Fire (Confirmed)

| Event | Arguments | When It Fires | Timing Notes |
|-------|-----------|---------------|--------------|
| `MERCHANT_SHOW` | none | Merchant window opened | Fires with stale data, wait for UPDATE |
| `MERCHANT_UPDATE` | none | Merchant data loaded/changed | Fires +164ms AFTER BuyMerchantItem hook |
| `MERCHANT_CLOSED` | none | Merchant window closed | Single clean event |
| `PLAYER_MONEY` | none | Money amount changed | Fires simultaneously with BAG_UPDATE |
| `BAG_UPDATE` | bagId | Bag contents changed | Fires +290ms after purchase, 4× spam pattern |
| `BAG_UPDATE_DELAYED` | none | All bag updates completed | Signals end of transaction |
| `UPDATE_INVENTORY_DURABILITY` | none | Equipment durability changed | Fires on login, not yet tested with repairs |
| `PLAYER_ENTERING_WORLD` | isLogin, isReload | Login or UI reload | Standard initialization event |

### 🔲 Events Not Yet Tested

| Event | Expected Use | Status |
|-------|--------------|--------|
| `GOSSIP_SHOW` | NPC gossip window opened | Registered, not yet tested |
| `GOSSIP_CLOSED` | Gossip window closed | Registered, not yet tested |
| `PLAYER_TARGET_CHANGED` | Target changed to/from merchant NPC | Registered, not yet tested |

| `MODIFIER_STATE_CHANGED` | Shift-click for item comparisons | Registered, not yet tested |

### ❌ Events That Don't Exist in Classic Era 1.15

| Event | Expected Use | Status |
|-------|--------------|--------|
| `MERCHANT_FILTER_ITEM_UPDATE` | Merchant item filtering | Not available in Classic Era |
| `BUYBACK_ITEM_UPDATE` | Buyback tab updates | Not available in Classic Era |
| `MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL` | Trade confirmation timer | Not available in Classic Era |

### ✅ Tab Switching Solution Found

- **MerchantFrame_UpdateMerchantInfo** - Fires when switching TO merchant tab
- **MerchantFrame_UpdateBuybackInfo** - Fires when switching TO buyback tab


### ❌ Events That Don't Exist in Classic Era 1.15

- `MERCHANT_FILTER_ITEM_UPDATE` - Merchant filtering not available
- `BUYBACK_ITEM_UPDATE` - No specific buyback events  
- `MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL` - Trade timers not implemented

---

## Hookable Functions

| Function | When It Fires | Arguments | Notes |
|----------|---------------|-----------|-------|
| `BuyMerchantItem` | Player purchases item | `index, quantity` | Fires immediately, before MERCHANT_UPDATE |
| `BuybackItem` | Player buys back sold item | `index` | Fires immediately, +260ms before money change |
| `RepairAllItems` | Player repairs equipment | `guildBankRepair` | Not yet tested |
| `CloseMerchant` | Merchant window closing | none | Not yet tested |
| `MerchantFrame_UpdateMerchantInfo` | Merchant tab active/refreshed | none | **✅ CONFIRMED: Tab switching detection** |
| `MerchantFrame_UpdateBuybackInfo` | Buyback tab active/refreshed | none | **✅ CONFIRMED: Tab switching detection** |
| `ShowMerchantSellCursor` | Sell cursor activated | `index` | When dragging item to sell |

---

## Event Flows

### 1. Login / UI Reload

```
UPDATE_INVENTORY_DURABILITY (#1) → +0ms
  ↓
BAG_UPDATE (×6) → +0ms (bags 1,2,3,4,5,6)
  ↓
PLAYER_ENTERING_WORLD → isLogin: false, isReload: true
  - Starting money: 6g 96s 63c
  ↓
BAG_UPDATE_DELAYED (#1) → +616ms
```

**Notes:**
- Multiple BAG_UPDATE events fire on login for all bag slots
- Money amount initialized and tracked from login

---

### 2. Opening Merchant Window

```
MERCHANT_SHOW → +0ms (baseline)
  - Merchant Opened
  - Current Money: 6g 96s 63c
  - Merchant cannot repair ← Detected automatically
  - Note: Merchant data may be STALE - wait for MERCHANT_UPDATE
  ↓
MerchantFrame → VISIBLE (UI State) → +0ms (simultaneous)
```

**Key Findings:**
- **MERCHANT_SHOW fires with stale data** - Item count may be 0
- **Repair capability detected** - CanMerchantRepair() works immediately
- **Money snapshot taken** - Current money tracked for session totals
- **UI state tracked** - Frame visibility monitored

---

### 3A. Single Purchase (Normal Flow)

```
BuyMerchantItem Hook → +0ms (baseline)
  - Purchasing: [3] Rough Arrow x200 (0g 0s 9c, unlimited, usable +extended cost)
  - Quantity: 1
  - Item count in bags BEFORE purchase: 0
  - Started monitoring BAG_UPDATE for item arrival...
  ↓
BAG_UPDATE (#18) → +55ms - Bag 4
  - ✓ Purchased item arrived in bags: Rough Arrow +200
  - Arrival timing: +55ms after BuyMerchantItem
  ↓
PLAYER_MONEY (#5) → +0ms (simultaneous)
  - Money Changed: 6g 96s 25c (-0g 0s 9c (spent))
  - Money change while merchant is OPEN
  - Total spent at this merchant: 0g 0s 9c
  ↓
BAG_UPDATE (#19) → +0ms - Bag 4 (duplicate)
  ↓
BAG_UPDATE_DELAYED (#8) → +0ms
  ↓
MERCHANT_UPDATE (#8) → +67ms
  - Merchant Data Updated
  - No stock changes detected
  ↓
MerchantFrame_UpdateMerchantInfo Hook → +0ms
  ↓
"You receive item: [Rough Arrow]x200." → Chat message
```

**Key Findings:**
- **Fast item arrival** - +55ms vs previous +290ms timing
- **Money/bag updates simultaneous** - PLAYER_MONEY + BAG_UPDATE at same time
- **MERCHANT_UPDATE delayed** - Fires +67ms after money change
- **UI update after transaction** - MerchantFrame hook fires last
- **Chat message delayed** - Appears after all events complete

---

### 3B. Rapid Purchase Spam (Stress Test)

```
BuyMerchantItem Hook (#1) → +0ms (baseline)
  ↓
BuyMerchantItem Hook (#2) → +66ms (OVERLAPPING!)
  ↓
BuyMerchantItem Hook (#3) → +61ms (OVERLAPPING!)
  ↓
BuyMerchantItem Hook (#4) → +54ms (OVERLAPPING!)
  ↓
BuyMerchantItem Hook (#5) → +91ms (OVERLAPPING!)
  ↓
BuyMerchantItem Hook (#6) → +61ms (OVERLAPPING!)
  ↓
BuyMerchantItem Hook (#7) → +60ms (OVERLAPPING!)
  ↓
[MASSIVE BAG_UPDATE EXPLOSION]
BAG_UPDATE (×33 events) → Bags 0, -2, 1, 4 (all bags affected)
  ↓
PLAYER_MONEY (batched) → Final total: -0g 0s 63c
  ↓
BAG_UPDATE_DELAYED → +0ms
  - ✓ Purchased item arrived in bags: Rough Arrow +1200 (6×200 stacked)
  - Arrival timing: +435ms after first BuyMerchantItem
```

**Critical Findings:**
- **Purchase overlap** - New purchases start before previous complete (~60-90ms intervals)
- **BAG_UPDATE explosion** - 33 events in ~1 second (vs 2 for single purchase)
- **Item stacking works** - 6×200 arrows = 1200 total, properly combined
- **Money tracking perfect** - Precise copper tracking despite chaos (9+27+18+9 = 63c)
- **Delayed item arrival** - +435ms during spam vs +55ms single purchase
- **All bags affected** - Bags 0, -2, 1, 4 fire BAG_UPDATE during rapid purchases

---

### 4. Selling Items to Merchant (Complete Flow)

```
"Selling item to merchant" → Player drags item to merchant
  ↓
PLAYER_MONEY (#2) → +0ms (baseline)
  - Money Changed: 7g 15s 27c (+0g 6s 15c (gained))
  - Money change while merchant is OPEN
  ↓
BAG_UPDATE (#9) → +0ms - Bag 0
BAG_UPDATE (#10) → +0ms - Bag -2
  ↓
MERCHANT_UPDATE (#2) → +0ms (simultaneous)
  - Merchant Data Updated
  - Merchant has 8 items for sale
  - No stock changes detected
  ↓
BAG_UPDATE_DELAYED (#3) → +0ms
  ↓
MerchantFrame_UpdateMerchantInfo Hook → +0ms
```

**Key Findings:**
- **No sell hook detected** - No hook fires when selling items (drag-and-drop)
- **Money change fires first** - PLAYER_MONEY leads the event sequence
- **MerchantFrame_UpdateMerchantInfo fires after sell** - UI updates after transaction
- **BAG_UPDATE spam pattern** - 2 events per sell (bags 0, -2)
- **Merchant updates reactively** - MERCHANT_UPDATE fires after sell completes

---

### 5. Buyback Operations (Complete Flow)

```
[Player switches to buyback tab]
  ↓
MerchantFrame_UpdateBuybackInfo Hook → +0ms
  ↓
[Player clicks buyback item]
  ↓
BuybackItem Hook → +0ms (baseline)
  - Buyback: index 1
  ↓
PLAYER_MONEY (#3) → +260ms
  - Money Changed: 7g 2s 49c (-0g 12s 78c (spent))
  - Money change while merchant is OPEN
  ↓
BAG_UPDATE (#11) → +0ms - Bag 0
BAG_UPDATE (#12) → +0ms - Bag -2
  ↓
MERCHANT_UPDATE (#3) → +0ms (simultaneous)
  - No stock changes detected
  ↓
BAG_UPDATE_DELAYED (#4) → +0ms
  ↓
MerchantFrame_UpdateBuybackInfo Hook → +0ms
```

**Key Findings:**
- **Complete buyback flow tracked** - Tab switch + purchase + UI update
- **BuybackItem hook works perfectly** - Fires immediately when buying back
- **Consistent timing pattern** - Hook → +260ms → PLAYER_MONEY → BAG_UPDATE
- **UI updates after transaction** - MerchantFrame_UpdateBuybackInfo fires at end
- **BAG_UPDATE spam pattern** - 2 events per transaction (bags 0, -2)

---

### 6. Tab Switching Detection (SUCCESS!)

```
[Player clicks to buyback tab]
  ↓
MerchantFrame_UpdateBuybackInfo Hook → +0ms
  ↓
[Player clicks back to merchant tab]
  ↓
MerchantFrame_UpdateMerchantInfo Hook → +0ms
```

**Critical Finding:**
- **✅ Tab switching detection WORKS!** - Hooks fire reliably for tab changes
- **MerchantFrame_UpdateBuybackInfo** fires when switching TO buyback tab
- **MerchantFrame_UpdateMerchantInfo** fires when switching TO merchant tab
- **No events needed** - Hooks provide complete tab switching coverage

---

## Pattern Recognition Rules

### Event Order Patterns
- **Single Purchase:** BuyMerchantItem Hook → +55ms → BAG_UPDATE → PLAYER_MONEY → +67ms → MERCHANT_UPDATE
- **Rapid Purchases:** BuyMerchantItem Hook (×7, overlapping) → BAG_UPDATE explosion (×33) → PLAYER_MONEY (batched)
- **Sell:** PLAYER_MONEY → BAG_UPDATE → MERCHANT_UPDATE (simultaneous)
- **Buyback:** BuybackItem Hook → +260ms → PLAYER_MONEY → BAG_UPDATE

### Timing Patterns
- **Single purchase timing:** Hook → +55ms → money/bag → +67ms → UI update
- **Rapid purchase timing:** Hooks every ~60-90ms, final resolution +435ms
- **Hook to money change:** 55ms single, batched during spam
- **BAG_UPDATE spam:** 2 events single, 33+ events during rapid purchases

### Purchase Complexity Detection
- **Single purchase:** 2 BAG_UPDATE events (bags affected: target bag + keyring)
- **Rapid purchases:** 33+ BAG_UPDATE events (bags affected: 0, -2, 1, 4 - all bags)
- **Overlapping detection:** New BuyMerchantItem hooks fire before previous complete
- **Item stacking:** Multiple purchases combine (6×200 = 1200 total)

### Money Tracking Accuracy
- **Bulletproof precision** - Exact copper tracking even during 33-event spam
- **Session totals work** - Running total accurate during rapid purchases (63c total)
- **Batched updates** - PLAYER_MONEY fires in batches during spam, final total correct

---

## Performance Considerations

### Critical: Event Spam Analysis

**BAG_UPDATE spam scales with purchase frequency:**
- **Single purchase:** 2 events (target bag + keyring)
- **Rapid purchases:** 33+ events in 1 second (all bags: 0, -2, 1, 4)
- **Spam multiplier:** 16.5× increase during rapid actions
- **All events contain same global data** - Bag scanning is global, not per-bag

**Purchase overlap creates chaos:**
- **BuyMerchantItem hooks overlap** - New purchases start before previous complete
- **Event timing becomes unpredictable** - +55ms single vs +435ms during spam
- **MERCHANT_UPDATE fires repeatedly** - Every ~80ms during rapid purchases

**Money tracking remains bulletproof:**
- **Precise during spam** - 63 copper tracked exactly across 7 rapid purchases
- **Batched updates work** - PLAYER_MONEY consolidates multiple transactions
- **Session totals accurate** - Running calculations survive event chaos

### Essential Optimizations

1. **Aggressive BAG_UPDATE debouncing:**
   ```lua
   local lastBagUpdateTime = 0
   local bagUpdateCount = 0
   
   if event == "BAG_UPDATE" then
       local currentTime = GetTime()
       if currentTime - lastBagUpdateTime < 0.5 then  -- 500ms window
           bagUpdateCount = bagUpdateCount + 1
           if bagUpdateCount > 5 then
               return  -- Skip excessive spam
           end
       else
           bagUpdateCount = 1  -- Reset counter
       end
       lastBagUpdateTime = currentTime
   end
   ```

2. **Purchase overlap detection:**
   ```lua
   local activePurchases = 0
   
   -- In BuyMerchantItem hook:
   activePurchases = activePurchases + 1
   if activePurchases > 1 then
       -- Handle overlapping purchase
       return  -- Skip processing until batch completes
   end
   
   -- In BAG_UPDATE_DELAYED:
   activePurchases = 0  -- Reset when batch completes
   ```

3. **Batch completion detection:**
   - Use BAG_UPDATE_DELAYED as batch completion signal
   - Process final state only, ignore intermediate updates
   - Wait for MerchantFrame_UpdateMerchantInfo for UI stability

### Performance Impact Analysis

| Scenario | BAG_UPDATE Events | Processing Load | Recommendation |
|----------|------------------|-----------------|----------------|
| Single purchase | 2 events | Low | Process normally |
| Rapid purchases | 33+ events | **Extreme** | **Aggressive filtering required** |
| Sell operations | 2 events | Low | Process normally |
| Tab switching | 0 events | None | Use hooks only |

**Critical Recommendation:** Addons MUST implement BAG_UPDATE spam filtering or risk severe performance degradation during rapid merchant interactions.

---

## Event Timing Summary

| Operation | First Event | Key Event(s) | Last Event | Spam Events |
|-----------|-------------|--------------|------------|-------------|
| Open merchant | MERCHANT_SHOW | MERCHANT_UPDATE | UI VISIBLE | MerchantFrame_UpdateMerchantInfo (×3) |
| Single purchase | BuyMerchantItem | PLAYER_MONEY | BAG_UPDATE_DELAYED | BAG_UPDATE (×2) |
| Rapid purchases | BuyMerchantItem (×7) | PLAYER_MONEY (batched) | BAG_UPDATE_DELAYED | **BAG_UPDATE (×33)** |
| Sell item | PLAYER_MONEY | MERCHANT_UPDATE | BAG_UPDATE_DELAYED | BAG_UPDATE (×2) |
| Buyback item | BuybackItem | PLAYER_MONEY | BAG_UPDATE_DELAYED | BAG_UPDATE (×2) |
| Switch to buyback | MerchantFrame_UpdateBuybackInfo | None | None | None |
| Switch to merchant | MerchantFrame_UpdateMerchantInfo | None | None | None |
| Close merchant | MERCHANT_CLOSED | UI HIDDEN | None | None |

---

## Special Behaviors and Quirks

### Stale Data Pattern
- **MERCHANT_SHOW fires first** with potentially stale data (item count may be 0)
- **MERCHANT_UPDATE fires later** with accurate, fresh data
- **Similar to profession pattern** - SHOW before UPDATE, but UPDATE has real data

### Money Tracking Excellence
- **Precise copper tracking** - All amounts exact to 1 copper
- **Session totals** - Running calculation of net spending at current merchant
- **Gain/loss detection** - Clear indication of money gained vs spent

### BAG_UPDATE Spam Pattern
- **4 events per purchase** - Bags 0, -2, 0, -2 (backpack + keyring duplicated)
- **2 events per sell** - Same pattern but fewer duplicates
- **Keyring always included** - Bag -2 fires even when keyring unchanged

### Tab Switching Gap
- **No events for tab changes** - Major limitation in event system
- **UI monitoring required** - Must use OnUpdate to detect tab state
- **Potential hook solutions** - MerchantFrame update functions may help

---

## Merchant Type Detection

### Repair Capability
```lua
local canRepair = CanMerchantRepair()
if canRepair then
    local repairCost, needsRepair = GetRepairAllCost()
    -- Handle repair merchant
end
```

### Item Analysis
```lua
-- Analyze merchant inventory
local categories = { weapons = 0, armor = 0, consumables = 0, recipes = 0 }
for i = 1, GetMerchantNumItems() do
    local itemLink = GetMerchantItemLink(i)
    if itemLink then
        local _, _, _, _, _, class = GetItemInfo(itemLink)
        categories[class] = (categories[class] or 0) + 1
    end
end
```

---

## API Functions for Querying Merchant Data

### Merchant Info
```lua
-- Get merchant item count
local numItems = GetMerchantNumItems()

-- Get item details
local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
local itemLink = GetMerchantItemLink(index)

-- Check repair capability
local canRepair = CanMerchantRepair()
local repairCost, needsRepair = GetRepairAllCost()

-- Money tracking
local currentMoney = GetMoney()
```

### Extended Cost Items
- Items showing `+extended cost` require additional currencies/tokens
- `extendedCost` parameter in GetMerchantItemInfo indicates this
- May require reputation, tokens, or other items beyond gold

---

## Implementation Recommendations

### ✅ Recommended Approach

Use **MERCHANT_UPDATE** as primary event for data processing:

```lua
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:RegisterEvent("PLAYER_MONEY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "MERCHANT_SHOW" then
        -- Merchant opened - data may be stale
        initializeMerchantSession()
    elseif event == "MERCHANT_UPDATE" then
        -- Fresh data available - process merchant inventory
        updateMerchantDisplay()
    elseif event == "PLAYER_MONEY" then
        -- Money changed - update spending totals
        updateMoneyTracking()
    end
end)
```

### ✅ Hook Purchase Tracking

```lua
-- Track purchases with detailed information
if BuyMerchantItem then
    hooksecurefunc("BuyMerchantItem", function(index, quantity)
        local name, texture, price = GetMerchantItemInfo(index)
        local totalCost = price * (quantity or 1)
        
        -- Log or track purchase
        print("Purchasing: " .. name .. " x" .. (quantity or 1) .. " for " .. totalCost .. " copper")
    end)
end
```

### ⚠️ Handle BAG_UPDATE Spam

```lua
-- Debounce BAG_UPDATE events during merchant sessions
local lastBagUpdateTime = 0
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" and merchantOpen then
        local currentTime = GetTime()
        if currentTime - lastBagUpdateTime < 0.1 then
            return  -- Skip duplicate BAG_UPDATE
        end
        lastBagUpdateTime = currentTime
        
        -- Process bag update
        handlePurchaseArrival()
    end
end)
```

### ✅ Monitor Tab State

```lua
-- Since no events fire for tab switching, use OnUpdate
local currentTab = 1
local function checkMerchantTabState()
    if MerchantFrame and MerchantFrame:IsShown() then
        local newTab = MerchantFrameTab2:GetChecked() and 2 or 1
        if newTab ~= currentTab then
            currentTab = newTab
            onTabChanged(newTab)  -- Custom handler
        end
    end
end

-- Add to OnUpdate monitoring
```

### ✅ Best Practices

1. **Wait for MERCHANT_UPDATE** - Don't process data at MERCHANT_SHOW (stale)
2. **Track money precisely** - Use session snapshots for spending analysis
3. **Debounce BAG_UPDATE** - Handle 4× spam pattern during purchases
4. **Monitor tab state manually** - No events fire for merchant/buyback switching
5. **Hook purchase actions** - BuyMerchantItem and BuybackItem provide immediate feedback
6. **Handle extended cost items** - Check extendedCost flag for special requirements

### ❌ What NOT to Do

#### DON'T Process Stale Data
```lua
-- ❌ BAD - MERCHANT_SHOW has stale data
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        local numItems = GetMerchantNumItems()  -- May be 0!
        -- Data not loaded yet
    end
end)
```

**Use instead:** Wait for MERCHANT_UPDATE for accurate data

#### DON'T Ignore BAG_UPDATE Spam
```lua
-- ❌ BAD - Processing every BAG_UPDATE
if event == "BAG_UPDATE" then
    updateInventoryDisplay()  -- Fires 4× per purchase!
end
```

**Use instead:** Debounce BAG_UPDATE or wait for BAG_UPDATE_DELAYED

---

## Rapid Purchase Stress Test Analysis

### Event Spam Scaling Discovered

**Single Purchase Pattern:**
- BuyMerchantItem Hook → +55ms → BAG_UPDATE (×2) → PLAYER_MONEY → MERCHANT_UPDATE
- **Clean and predictable** - 2 BAG_UPDATE events, precise timing

**Rapid Purchase Pattern (7 purchases in ~1 second):**
- BuyMerchantItem Hook (×7, overlapping every ~60-90ms)
- BAG_UPDATE explosion (×33 events across all bags: 0, -2, 1, 4)
- PLAYER_MONEY (batched) → Final accurate total
- Item arrival delayed (+435ms vs +55ms single)

### Critical Performance Implications

**BAG_UPDATE Spam Multiplier: 16.5×**
- Single purchase: 2 events
- Rapid purchases: 33 events
- **All bags affected** - Not just target bag, entire inventory scanned

**Purchase Overlap Chaos:**
- New purchases start before previous complete
- Event timing becomes unpredictable
- MERCHANT_UPDATE fires repeatedly (~80ms intervals)

**Money Tracking Remains Bulletproof:**
- Perfect copper precision during 33-event chaos
- Session totals accurate (63c across 7 purchases)
- Batched PLAYER_MONEY events work correctly

### Addon Development Warnings

**CRITICAL:** Addons processing BAG_UPDATE during merchant sessions MUST implement aggressive spam filtering or risk severe performance degradation. A single rapid-clicking user can generate 33+ events per second.

**Recommended Filtering:**
```lua
-- Debounce BAG_UPDATE during merchant sessions
local bagUpdateCount = 0
local lastBagTime = 0

if event == "BAG_UPDATE" and merchantOpen then
    local currentTime = GetTime()
    if currentTime - lastBagTime < 0.5 then
        bagUpdateCount = bagUpdateCount + 1
        if bagUpdateCount > 5 then
            return  -- Skip excessive spam
        end
    else
        bagUpdateCount = 1
    end
    lastBagTime = currentTime
end
```

---

## Untested Scenarios

### High Priority
- [ ] **Repair merchant flow** - RepairAllItems hook, durability events, repair costs
- [ ] **Limited stock items** - Stock depletion, MERCHANT_UPDATE with stock changes
- [ ] **Extended cost items** - Items requiring tokens/reputation, purchase failure handling
- [ ] **Multiple quantity purchases** - Shift-click quantity dialog, batch purchase timing
- [ ] **Gossip integration** - NPCs requiring gossip before merchant access

### Medium Priority
- [ ] **Insufficient funds** - Purchase failure behavior, error handling
- [ ] **Bag full purchases** - Purchase failure when inventory full
- [ ] **Cross-merchant sessions** - Switching between different merchants
- [ ] **Sell cursor operations** - ShowMerchantSellCursor/ResetCursor hook timing
- [ ] **Item comparison** - Shift-click item comparisons, tooltip events

### Low Priority
- [ ] **Network lag effects** - Event timing under poor connection
- [ ] **Addon conflicts** - Interaction with other merchant addons
- [ ] **Different merchant types** - Weapon vendors, reagent vendors, specialty merchants
- [ ] **Guild bank repairs** - Alternative repair methods

---

## Testing Methodology

**Environment:** WoW Classic Era 1.15.x

**Method:** Comprehensive event logging with:
- Event listener frame for 16 merchant-related events
- hooksecurefunc for 9 merchant functions
- UI frame visibility monitoring (MerchantFrame, GossipFrame)
- Tab state monitoring via OnUpdate
- Money tracking with session totals
- Item arrival timing analysis

**Tools:**
- Event listener frame with OnEvent handler
- Hook registration via hooksecurefunc
- OnUpdate monitoring for UI state
- Timestamp tracking with millisecond precision
- Money change calculation and session tracking

**Scope:** 6 distinct operation types tested:
1. Login/UI Reload
2. Opening Merchant Window
3. Purchasing Items (single quantity)
4. Selling Items to Merchant
5. Buyback Operations
6. Tab Switching Detection

**Key Findings:**
- All core merchant events fire reliably
- MERCHANT_UPDATE provides accurate data (MERCHANT_SHOW may be stale)
- BAG_UPDATE spam pattern identified (4× per purchase)
- Money tracking is precise to the copper
- Tab switching has no events (UI monitoring required)
- Purchase timing: Hook → +164ms → UPDATE → +290ms → BAG_UPDATE

See `MERCHANT_EVENT_TEST.lua` for the test harness used to generate this data.

---

## Conclusion

**Merchant event tracking in Classic Era 1.15 is comprehensive and reliable:**

✅ **Complete Coverage:**
- Purchase tracking: BuyMerchantItem hook with detailed item analysis
- Money tracking: Precise copper-level transaction monitoring
- Inventory updates: BAG_UPDATE timing and item arrival detection
- Session tracking: Running totals of spending per merchant visit

✅ **Key Insights:**
- MERCHANT_UPDATE fires AFTER purchases (reactive, not predictive)
- BAG_UPDATE spam pattern requires debouncing (4× per purchase)
- Money tracking is extremely accurate (precise to 1 copper)
- Tab switching requires UI monitoring (no events fire)

✅ **Recommended Implementation:**
- Use MERCHANT_UPDATE as primary data source (not MERCHANT_SHOW)
- Hook BuyMerchantItem and BuybackItem for immediate purchase feedback
- Debounce BAG_UPDATE events during merchant sessions
- Monitor tab state via OnUpdate (no events available)
- Track money changes for spending analysis

⚠️ **Known Limitations:**
- No events for merchant/buyback tab switching
- MERCHANT_SHOW fires with potentially stale data
- BAG_UPDATE spam requires careful handling

The merchant system in Classic Era provides excellent event coverage for most operations, with only tab switching requiring manual UI monitoring. Purchase and money tracking are particularly robust and precise.