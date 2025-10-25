# WoW Classic Era: Merchant Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing:** Merchant purchases, sales, buyback operations, tab switching, rapid purchase stress testing

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 8 merchant-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `MERCHANT_SHOW` | ✅ | 1× per window open | **STALE DATA - wait for MERCHANT_UPDATE** |
| `MERCHANT_UPDATE` | ✅ | 1× per transaction | **FRESH DATA - fires after purchases** |
| `MERCHANT_CLOSED` | ✅ | 1× per window close | Clean single event |
| `PLAYER_MONEY` | ✅ | 1× per transaction | Precise copper tracking |
| `BAG_UPDATE` | ✅ | 2-33× per transaction | **EXTREME SPAM during rapid purchases** |
| `BAG_UPDATE_DELAYED` | ✅ | 1× per transaction | Signals completion |
| `UPDATE_INVENTORY_DURABILITY` | ✅ | 1× on login | Initialization only |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× per login/reload | Standard initialization |

### Events That Did NOT Fire During Testing
| Event | Status | Reason |
|-------|--------|--------|
| `GOSSIP_SHOW` | ❌ | Gossip interactions not tested |
| `GOSSIP_CLOSED` | ❌ | Gossip interactions not tested |
| `PLAYER_TARGET_CHANGED` | ❌ | Target changes not monitored |
| `MODIFIER_STATE_CHANGED` | ❌ | Shift-click comparisons not tested |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `BuyMerchantItem` | ✅ | 1× per purchase | Fires before MERCHANT_UPDATE |
| `BuybackItem` | ✅ | 1× per buyback | +260ms delay to money change |
| `MerchantFrame_UpdateMerchantInfo` | ✅ | 1× per merchant tab | **Tab switching detection** |
| `MerchantFrame_UpdateBuybackInfo` | ✅ | 1× per buyback tab | **Tab switching detection** |
| `ShowMerchantSellCursor` | ✅ | 1× per sell drag | Sell cursor activation |

### Hooks That Did NOT Fire
| Hook | Status | Reason |
|------|--------|--------|
| `RepairAllItems` | ❌ | No repair merchant tested |
| `CloseMerchant` | ❌ | Hook did not trigger during testing |

### Tests Performed Headlines
1. **Login/Reload** - Money initialization, bag updates
2. **Open Merchant** - MERCHANT_SHOW with stale data detection
3. **Single Purchase** - Rough Arrow x200 (+55ms item arrival)
4. **Rapid Purchase Spam** - 7× purchases (33 BAG_UPDATE events!)
5. **Selling Items** - Drag-and-drop to merchant
6. **Buyback Operations** - Complete buyback flow
7. **Tab Switching** - Merchant ↔ Buyback detection

---

## Quick Decision Guide

### Event Reliability for AI Decision Making
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `MERCHANT_UPDATE` | 100% | Low | ✅ **PRIMARY** - Fresh merchant data (fires after transactions) |
| `PLAYER_MONEY` | 100% | Low | ✅ Money tracking (precise copper amounts) |
| `BuyMerchantItem` hook | 100% | Low | ✅ Purchase detection (fires before UPDATE) |
| `BuybackItem` hook | 100% | Low | ✅ Buyback detection |
| `MERCHANT_SHOW` | 100% | Low | ⚠️ **STALE DATA** - wait for MERCHANT_UPDATE |
| `BAG_UPDATE` | 100% | Terrible | ❌ **33× spam during rapid purchases** |

### Use Case → Best Event Mapping
- **Track merchant transactions:** `MERCHANT_UPDATE` (fresh data, fires after purchases)
- **Detect purchases:** `BuyMerchantItem` hook (fires immediately)
- **Monitor money changes:** `PLAYER_MONEY` (precise copper tracking)
- **Detect tab switching:** `MerchantFrame_UpdateMerchantInfo/BuybackInfo` hooks
- **Avoid bag tracking:** Never use raw `BAG_UPDATE` (extreme spam)
- **Avoid initial data:** Never use `MERCHANT_SHOW` for item data (stale)

### Critical AI Rules
- **MERCHANT_SHOW has STALE data** (item count may be 0, wait for UPDATE)
- **MERCHANT_UPDATE fires AFTER transactions** (reactive, not predictive)
- **BAG_UPDATE creates extreme spam** (33× events during rapid purchases)
- **Money tracking is precise** (exact copper amounts per transaction)
- **No sell hooks exist** (drag-and-drop selling has no hook detection)

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Open Merchant: MERCHANT_SHOW (stale) → MERCHANT_UPDATE (fresh data available)
Single Purchase: BuyMerchantItem hook → BAG_UPDATE (+55ms) → PLAYER_MONEY → MERCHANT_UPDATE (+67ms)
Sell Item: PLAYER_MONEY → BAG_UPDATE → MERCHANT_UPDATE (simultaneous)
Buyback: BuybackItem hook → PLAYER_MONEY (+260ms) → BAG_UPDATE → MERCHANT_UPDATE
Close Merchant: MERCHANT_CLOSED (clean single event)
```

### Tab Switching (Hook-based Detection)
```
Switch to Merchant Tab: MerchantFrame_UpdateMerchantInfo hook (no events)
Switch to Buyback Tab: MerchantFrame_UpdateBuybackInfo hook (no events)
```

### Rapid Purchase Chaos (Unpredictable)
```
Rapid Purchases: BuyMerchantItem hooks (overlapping 60-90ms intervals) → BAG_UPDATE EXPLOSION (33× events) → PLAYER_MONEY (batched) → Item arrival (+435ms delayed)
```

---

## Performance Impact Summary

| Operation | Total Events | Spam Events | Performance Impact |
|-----------|--------------|-------------|-------------------|
| Single Purchase | 6 | BAG_UPDATE (×2) | Low |
| Rapid Purchases (7×) | 40+ | BAG_UPDATE (×33) | **EXTREME** |
| Sell Item | 5 | BAG_UPDATE (×2) | Low |
| Buyback | 5 | BAG_UPDATE (×2) | Low |
| Tab Switching | 0 | None (hooks only) | Minimal |

**Critical:** BAG_UPDATE spam multiplier during rapid purchases: **16.5× increase** (2 events → 33 events).

---

## Essential API Functions

### Merchant Window Inspection
```lua
-- Merchant info
local numItems = GetMerchantNumItems()
local canRepair = CanMerchantRepair()
local repairCost = GetRepairAllCost()

-- Merchant item details
local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
local itemLink = GetMerchantItemLink(index)

-- Money tracking
local currentMoney = GetMoney()  -- In copper
```

### Merchant Transactions
```lua
-- Purchase items
BuyMerchantItem(index, quantity)

-- Buyback items
BuybackItem(index)

-- Repair (untested)
RepairAllItems(guildBankRepair)  -- guildBankRepair: boolean
```

### Merchant State Detection
```lua
-- Merchant frame visibility
local isMerchantOpen = MerchantFrame and MerchantFrame:IsShown()

-- Current tab detection (via hooks)
-- MerchantFrame_UpdateMerchantInfo = merchant tab active
-- MerchantFrame_UpdateBuybackInfo = buyback tab active
```

### Money Formatting
```lua
-- Convert copper to readable format
local function formatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperAmount = copper % 100
    return string.format("%dg %ds %dc", gold, silver, copperAmount)
end
```

---

## Implementation Patterns

### ✅ Recommended (Handles Stale Data and Spam)
```lua
-- Merchant tracking - OPTIMAL PATTERN
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("MERCHANT_UPDATE")  -- Use UPDATE, not SHOW
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("MERCHANT_CLOSED")

-- Track merchant state
local merchantOpen = false
local lastMoneyAmount = GetMoney()

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "MERCHANT_SHOW" then
        merchantOpen = true
        lastMoneyAmount = GetMoney()
        -- DON'T process merchant data here - it's STALE
        
    elseif event == "MERCHANT_UPDATE" then
        -- NOW process merchant data - it's FRESH
        if merchantOpen then
            updateMerchantData()
        end
        
    elseif event == "PLAYER_MONEY" then
        if merchantOpen then
            local currentMoney = GetMoney()
            local moneyChange = currentMoney - lastMoneyAmount
            trackMoneyChange(moneyChange)
            lastMoneyAmount = currentMoney
        end
        
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        completeMerchantSession()
    end
end)

-- Hook purchase actions
hooksecurefunc("BuyMerchantItem", function(index, quantity)
    local name, texture, price = GetMerchantItemInfo(index)
    trackPurchase(index, name, price, quantity or 1)
end)

hooksecurefunc("BuybackItem", function(index)
    trackBuyback(index)
end)

-- Tab switching detection
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
    onMerchantTabActive()
end)

hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
    onBuybackTabActive()
end)
```

### ✅ BAG_UPDATE Spam Protection
```lua
-- Implement aggressive filtering for BAG_UPDATE during merchant sessions
local bagUpdateFilter = {
    merchantOpen = false,
    lastUpdate = 0,
    updateCount = 0,
    SPAM_THRESHOLD = 5,  -- More than 5 updates = spam
    TIME_WINDOW = 1.0    -- Within 1 second
}

eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, bagId)
    if event == "BAG_UPDATE" and bagUpdateFilter.merchantOpen then
        local currentTime = GetTime()
        
        -- Reset counter if outside time window
        if currentTime - bagUpdateFilter.lastUpdate > bagUpdateFilter.TIME_WINDOW then
            bagUpdateFilter.updateCount = 0
        end
        
        bagUpdateFilter.updateCount = bagUpdateFilter.updateCount + 1
        bagUpdateFilter.lastUpdate = currentTime
        
        -- Filter spam
        if bagUpdateFilter.updateCount > bagUpdateFilter.SPAM_THRESHOLD then
            return  -- Ignore spam updates
        end
        
        -- Process legitimate bag update
        processBagUpdate(bagId)
    end
end)
```

### ❌ Anti-Patterns (Performance Killers)
```lua
-- DON'T use MERCHANT_SHOW for item data
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        -- ❌ BAD - Data is STALE at this point
        local numItems = GetMerchantNumItems()  -- May return 0
        updateMerchantDisplay(numItems)  -- Will show incorrect data
    end
end)

-- DON'T process every BAG_UPDATE during merchant sessions
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, bagId)
    if event == "BAG_UPDATE" then
        -- ❌ BAD - Can fire 33× during rapid purchases
        -- ❌ No spam filtering = severe performance impact
        updateInventoryDisplay()  -- Called 33× in 1 second
    end
end)

-- DON'T assume sell hooks exist
local function trackSelling()
    -- ❌ BAD - No hooks fire for drag-and-drop selling
    -- Must rely on PLAYER_MONEY + MERCHANT_UPDATE instead
end
```

---

## Key Technical Details

### Critical Timing Discoveries
- **MERCHANT_SHOW fires with stale data** (item count may be 0)
- **MERCHANT_UPDATE fires AFTER transactions** (+67ms delay from purchase)
- **Item arrival timing varies:** Single purchase +55ms, rapid purchases +435ms
- **Money changes are immediate:** PLAYER_MONEY fires with BAG_UPDATE
- **Buyback has consistent delay:** +260ms from hook to money change

### BAG_UPDATE Spam Analysis
| Purchase Type | BAG_UPDATE Events | Spam Multiplier | Performance Impact |
|---------------|------------------|-----------------|-------------------|
| Single Purchase | 2× | 1× baseline | Low |
| Rapid Purchases (7×) | 33× | **16.5× increase** | **EXTREME** |
| Sell Item | 2× | 1× baseline | Low |
| Buyback | 2× | 1× baseline | Low |

### Merchant Data Reliability
```lua
-- At MERCHANT_SHOW fire time
local numItems = GetMerchantNumItems()  -- May return 0 (STALE)

-- At MERCHANT_UPDATE fire time (after transactions)
local numItems = GetMerchantNumItems()  -- Accurate count (FRESH)
```

### Tab Switching Detection
- **No events fire** for tab switching
- **Hooks are the only detection method:**
  - `MerchantFrame_UpdateMerchantInfo` = merchant tab active
  - `MerchantFrame_UpdateBuybackInfo` = buyback tab active

### Money Tracking Precision
```lua
-- Observed money changes during testing
Single Purchase: -9 copper (exact)
Rapid Purchases: -63 copper total (9+27+18+9 = perfect tracking)
Sell Item: +615 copper (exact)
Buyback: -1278 copper (exact)
```

---

## Rapid Purchase Stress Test Results

### Purchase Overlap Pattern
```
BuyMerchantItem #1 → +0ms (baseline)
BuyMerchantItem #2 → +66ms (overlapping)
BuyMerchantItem #3 → +61ms (overlapping)
BuyMerchantItem #4 → +54ms (overlapping)
BuyMerchantItem #5 → +91ms (overlapping)
BuyMerchantItem #6 → +61ms (overlapping)
BuyMerchantItem #7 → +60ms (overlapping)
```

### BAG_UPDATE Explosion
- **33 BAG_UPDATE events** in ~1 second
- **All bags affected:** 0, -2, 1, 4
- **Item stacking works:** 6×200 arrows = 1200 total
- **Delayed arrival:** +435ms vs +55ms single purchase

### Performance Implications
- **16.5× BAG_UPDATE spam increase**
- **Addons MUST implement spam filtering**
- **Single rapid-clicking user can generate 33+ events per second**

---

## Untested Scenarios

### High Priority for Future Testing
1. **Repair Operations** - RepairAllItems hook, repair cost tracking
2. **Guild Bank Repairs** - Alternative repair funding
3. **Extended Cost Items** - Items requiring tokens/reputation
4. **Insufficient Funds** - Purchase failure scenarios
5. **Gossip Interactions** - GOSSIP_SHOW/CLOSED events

### Medium Priority
1. **Multiple Merchant Sessions** - Rapid merchant switching
2. **Shift-Click Comparisons** - MODIFIER_STATE_CHANGED events
3. **Target Changes** - PLAYER_TARGET_CHANGED during merchant sessions
4. **Full Bag Scenarios** - Purchase behavior when inventory full
5. **Network Lag Effects** - Event timing under poor connection

### Low Priority
1. **Addon Conflicts** - Interaction with other merchant addons
2. **Different Merchant Types** - Specialty vendors, faction vendors
3. **Auction House Integration** - If considered merchant-related
4. **Mail System** - If considered merchant-related

---

## Conclusion

**Merchant event tracking in Classic Era is reliable but requires careful handling:**

✅ **Reliable Core Events:**
- MERCHANT_UPDATE provides fresh data (use instead of MERCHANT_SHOW)
- PLAYER_MONEY tracking is precise (exact copper amounts)
- Purchase/buyback hooks fire reliably
- Tab switching detection works via UI hooks

⚠️ **Critical Performance Issues:**
- **BAG_UPDATE spam during rapid purchases** (16.5× increase, 33 events/second)
- **MERCHANT_SHOW has stale data** (wait for MERCHANT_UPDATE)
- **No sell hooks exist** (must use money/update events)

✅ **Recommended Implementation:**
- Use MERCHANT_UPDATE for fresh merchant data
- Implement aggressive BAG_UPDATE spam filtering
- Track money changes with PLAYER_MONEY
- Use hooks for purchase/buyback detection
- Handle tab switching with UI hooks

**The key insight: Merchant events are reliable for tracking transactions, but require spam protection and proper timing to handle rapid user interactions effectively.**