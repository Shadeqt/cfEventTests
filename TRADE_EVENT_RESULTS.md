# WoW Classic Era: Trade Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing:** Player-to-player trading, item placement, money trading, accept/cancel scenarios

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 13 trade-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `TRADE_SHOW` | ✅ | 1× per trade window open | Reliable |
| `TRADE_CLOSED` | ✅ | 2× per trade end | **Spam: Duplicate events** |
| `TRADE_PLAYER_ITEM_CHANGED` | ✅ | 1× per slot change | Fires for each slot modification |
| `TRADE_REQUEST_CANCEL` | ✅ | 1× per trade cancel | Reliable |
| `PLAYER_MONEY` | ✅ | 1× per trade end | Money change detection |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× on login/reload | Standard initialization |
| `BAG_UPDATE_DELAYED` | ✅ | 2× on login | Initialization only |

### Events That Did NOT Fire During Testing
| Event | Status | Reason |
|-------|--------|--------|
| `TRADE_UPDATE` | ❌ | May require both players active |
| `TRADE_ACCEPT_UPDATE` | ❌ | No acceptance testing performed |
| `TRADE_TARGET_ITEM_CHANGED` | ❌ | No target items placed |
| `TRADE_MONEY_CHANGED` | ❌ | No money amounts set |
| `TRADE_REQUEST` | ❌ | Testing from initiator side only |
| `BAG_UPDATE` | ❌ | Filtered out (trade context only) |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `ClickTradeButton` | ✅ | 1× per slot click | Shows slot contents accurately |

### Hooks That Did NOT Fire
| Hook | Status | Reason |
|------|--------|--------|
| `AcceptTrade` | ❌ | No trade acceptance performed |
| `CancelTrade` | ❌ | No manual cancel performed |
| `SetTradeMoney` | ❌ | No money amounts set |
| `InitiateTrade` | ❌ | Hook may not exist or fire |

### Tests Performed Headlines
1. **Login/Reload** - Event initialization patterns
2. **Trade Request** - "You have requested to trade with Sliveria"
3. **Trade Window Open** - Partner name detection, slot initialization
4. **Item Placement** - Scroll of Stamina in slots 1, 6, 7
5. **Non-Tradeable Detection** - "(NOT TRADEABLE)" flag working
6. **Item Removal** - Clicking slots to remove items
7. **Trade Cancellation** - Window closure and cleanup
8. **Multiple Trade Attempts** - Repeated testing scenarios

---

## Quick Decision Guide

### Event Reliability for AI Decision Making
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `TRADE_SHOW` | 100% | Low | ✅ Primary trade start detection |
| `TRADE_PLAYER_ITEM_CHANGED` | 100% | Low | ✅ Player slot monitoring |
| `ClickTradeButton` (hook) | 100% | Low | ✅ Slot interaction detection |
| `TRADE_REQUEST_CANCEL` | 100% | Low | ✅ Trade cancellation detection |
| `TRADE_CLOSED` | 100% | Low | ⚠️ Fires 2× (use first only) |
| `PLAYER_MONEY` | 100% | Low | ⚠️ Context-dependent (trade vs other) |

### Use Case → Best Event Mapping
- **Detect trade start:** `TRADE_SHOW` (reliable, captures partner name)
- **Monitor player items:** `TRADE_PLAYER_ITEM_CHANGED` (fires per slot change)
- **Track slot interactions:** `ClickTradeButton` hook (shows current slot contents)
- **Detect trade end:** `TRADE_CLOSED` (fires 2×, use first event only)
- **Validate tradeability:** Item info includes "(NOT TRADEABLE)" flag

### Critical AI Rules
- **Partner Detection:** Trade partner name available at TRADE_SHOW (may show "Invalid" due to timing)
- **Slot Management:** 6 slots per player (P1-P6 for player, T1-T6 for target)
- **Tradeable Validation:** Items show "(NOT TRADEABLE)" when cannot be traded
- **Duplicate Events:** TRADE_CLOSED fires twice, second event is redundant

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Trade Initiation: TRADE_SHOW → TradeFrame VISIBLE
Item Placement: TRADE_PLAYER_ITEM_CHANGED → ClickTradeButton hook
Item Removal: ClickTradeButton hook → TRADE_PLAYER_ITEM_CHANGED (EMPTY)
Trade End: TRADE_CLOSED (×2) → TradeFrame HIDDEN → PLAYER_MONEY → TRADE_REQUEST_CANCEL
```

### UI State Changes
```
Window Open: TRADE_SHOW → TradeFrame VISIBLE (0ms delay)
Window Close: TRADE_CLOSED → TradeFrame HIDDEN (7ms delay)
```

---

## Performance Impact Summary

| Operation | Total Events | Spam Events | Performance Impact |
|-----------|--------------|-------------|-------------------|
| Open Trade | 1 | None | Minimal |
| Place Item | 1 | None | Minimal |
| Remove Item | 1 | None | Minimal |
| Close Trade | 4 | TRADE_CLOSED (2×) | Low |

**Note:** Trade events are generally low-impact with minimal spam compared to other systems.

---

## Essential API Functions

### Trade Slot Inspection
```lua
-- Player's trade slots (1-6)
local name, texture, quantity, quality, enchantment, canTrade = GetTradePlayerItemInfo(slot)
local itemLink = GetTradePlayerItemLink(slot)

-- Target's trade slots (1-6)  
local name, texture, quantity, quality, enchantment, canTrade = GetTradeTargetItemInfo(slot)
local itemLink = GetTradeTargetItemLink(slot)
```

### Money Functions
```lua
local playerMoney = GetPlayerTradeMoney()  -- Money player is offering
local targetMoney = GetTargetTradeMoney()  -- Money target is offering
```

### Partner Information
```lua
local partnerName = UnitName("npc") or UnitName("target")  -- Trade partner name
```

### Trade State
```lua
-- Check if trade window is open
local isTradeOpen = TradeFrame and TradeFrame:IsShown()
```

---

## Implementation Patterns

### ✅ Recommended
```lua
-- Trade window tracking
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
eventFrame:RegisterEvent("TRADE_CLOSED")

-- Slot interaction monitoring
hooksecurefunc("ClickTradeButton", function(index)
    local name, texture, quantity, quality, enchantment, canTrade = GetTradePlayerItemInfo(index)
    if name and not canTrade then
        -- Item is not tradeable, warn user
    end
end)

-- Trade partner detection
local function onTradeShow()
    local partnerName = UnitName("npc") or UnitName("target") or "Unknown"
    -- Store partner for trade logging
end
```

### ❌ Anti-Patterns
```lua
-- DON'T process duplicate TRADE_CLOSED events
local tradeClosedCount = 0
if event == "TRADE_CLOSED" then
    tradeClosedCount = tradeClosedCount + 1
    if tradeClosedCount > 1 then
        return  -- Skip duplicate event
    end
end

-- DON'T rely on partner name timing
if event == "TRADE_SHOW" then
    local partner = UnitName("npc")
    if partner == "Invalid" then
        -- Retry partner detection later
    end
end
```

---

## Key Technical Details

### Critical Timing Discoveries
- **UI Responsiveness:** TradeFrame visibility changes within 0-7ms of events
- **Partner Name Timing:** May show "Invalid" initially due to unit data loading
- **Slot Indexing:** Player slots P1-P6, Target slots T1-T6 (6 slots each)
- **Tradeable Detection:** Real-time validation via `canTrade` flag and "(NOT TRADEABLE)" display

### Trade Slot System
- **Total Slots:** 12 (6 per player)
- **Slot States:** EMPTY, item with quality/enchantment info, NOT TRADEABLE flag
- **Item Quality:** Color-coded display (grey/white/green/blue/purple/orange)
- **Stack Support:** Quantity tracking for stackable items
- **Enchantment Support:** Enchantment level display (+enchantment)

### Money System
- **Format:** Copper/Silver/Gold breakdown
- **Display:** "5g 23s 15c" format
- **Tracking:** Separate from item slots
- **Change Detection:** TRADE_MONEY_CHANGED event (not tested)

### Accept System (Not Tested)
- **Dual Acceptance:** Both players must accept
- **Status Tracking:** TRADE_ACCEPT_UPDATE event
- **Completion:** Automatic when both accept
- **Items Transfer:** To respective inventories with BAG_UPDATE events

---

## Untested Scenarios

### High Priority for Future Testing
1. **Money Trading** - SetTradeMoney, TRADE_MONEY_CHANGED
2. **Accept/Decline** - TRADE_ACCEPT_UPDATE, AcceptTrade hook
3. **Target Items** - TRADE_TARGET_ITEM_CHANGED, TRADE_UPDATE
4. **Trade Completion** - Full trade with item/money transfer
5. **Trade Requests** - TRADE_REQUEST event from receiver perspective

### Medium Priority
1. **Enchanted Items** - Enchantment display and trading
2. **Large Stacks** - High quantity item trading
3. **Cross-Faction** - Neutral AH trading mechanics
4. **Guild Trading** - Guild member specific scenarios

### Low Priority
1. **Edge Cases** - Network lag, disconnections
2. **UI Interactions** - Keyboard shortcuts, right-click menus
3. **Addon Conflicts** - Multiple trade addons interaction