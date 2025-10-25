# WoW Classic Era: Auction House Events Reference
## Version 1.15 Event Investigation

**Last Updated:** October 25, 2025
**Testing:** Search operations, bidding, buyouts, selling items, auction cancellation, filtered searches

---

## Test Summary

### Events Registered for Testing
**Total Events Monitored:** 20 auction house-related events

### Events That Fired During Testing
| Event | Fired? | Frequency | Notes |
|-------|--------|-----------|-------|
| `AUCTION_HOUSE_SHOW` | ✅ | 1× per AH open | Reliable |
| `AUCTION_HOUSE_CLOSED` | ✅ | 1× per AH close | Reliable |
| `AUCTION_ITEM_LIST_UPDATE` | ✅ | 1-8× per search | **Spam: Multiple identical events** |
| `AUCTION_BIDDER_LIST_UPDATE` | ✅ | 1× per bid operation | Updates your bids list |
| `AUCTION_OWNED_LIST_UPDATE` | ✅ | 1× per sell/cancel | Updates your auctions list |
| `NEW_AUCTION_UPDATE` | ✅ | 2× per sell operation | Item placement + creation |
| `AUCTION_MULTISELL_START` | ✅ | Registered | Not triggered in testing |
| `AUCTION_MULTISELL_UPDATE` | ✅ | Registered | Not triggered in testing |
| `AUCTION_MULTISELL_FAILURE` | ✅ | Registered | Not triggered in testing |
| `CHAT_MSG_SYSTEM` | ✅ | 1× per buyout | "You won an auction" messages |
| `UPDATE_PENDING_MAIL` | ✅ | 2× per auction result | Mail notifications |
| `PLAYER_MONEY` | ✅ | 1× per transaction | Money changes from bids/buyouts |
| `BAG_UPDATE` | ✅ | Multiple per operation | Item movement tracking |
| `BAG_UPDATE_DELAYED` | ✅ | 1× per operation | Signals completion |
| `ITEM_LOCK_CHANGED` | ✅ | 2× per sell operation | Lock/unlock during posting |
| `ITEM_LOCKED` | ✅ | 1× per sell operation | Item locked for auction |
| `ITEM_UNLOCKED` | ✅ | 1× per sell operation | Item unlocked after posting |
| `PLAYER_ENTERING_WORLD` | ✅ | 1× on login/reload | Standard initialization |

### Events That Did NOT Fire
| Event | Status | Reason |
|-------|--------|--------|
| `AUCTION_BID_PLACED` | ❌ | Event not available in Classic Era |
| `MAIL_INBOX_UPDATE` | ❌ | Registered but didn't fire during testing |

### Hooks That Fired During Testing
| Hook | Fired? | Frequency | Notes |
|------|--------|-----------|-------|
| `QueryAuctionItems` | ✅ | 1× per search | Shows search parameters |
| `PlaceAuctionBid` | ✅ | 1× per bid/buyout | Shows item and bid amount |
| `PutItemToAuction` | ✅ | 1× per sell | Shows prices and duration |
| `CancelAuction` | ✅ | 1× per cancel | Shows cancelled item |
| `ClickAuctionSellItemButton` | ✅ | 1× per item placement | Item selection for selling |

### Hooks That Did NOT Fire
| Hook | Status | Reason |
|------|--------|--------|
| `AuctionFrameTab_OnClick` | ❌ | Function not available in Classic Era |
| `AuctionFrameBrowse_Search` | ❌ | Function not available in Classic Era |
| `AuctionFrameBid_OnClick` | ❌ | Function not available in Classic Era |
| `AuctionFrameBuyout_OnClick` | ❌ | Function not available in Classic Era |

### Tests Performed Headlines
1. **Open Auction House** - Initial state, money tracking, tab detection
2. **Search All Items** - Empty search, 50 results, spam pattern detection
3. **Search with Text Filter** - "linen cloth" search, filtered results
4. **Search with Level Filter** - Level 15-49 range, empty results vs full results
5. **Place Regular Bid** - Minimum bid on Bolt of Linen Cloth
6. **Buyout Item** - Instant purchase with system message
7. **Sell Item** - List Linen Cloth for auction with item locking
8. **Cancel Auction** - Remove own auction, mail notification
9. **Tab Switching** - Browse/Bids/Auctions UI state tracking
10. **Close Auction House** - Money change summary

---

## Quick Decision Guide

### Event Reliability for AI Decision Making
| Event | Reliability | Performance | Best Use Case |
|-------|-------------|-------------|---------------|
| `AUCTION_HOUSE_SHOW` | 100% | Low | ✅ AH opening detection |
| `AUCTION_HOUSE_CLOSED` | 100% | Low | ✅ AH closing detection |
| `QueryAuctionItems` (hook) | 100% | Low | ✅ Search operation tracking |
| `PlaceAuctionBid` (hook) | 100% | Low | ✅ Bid/buyout detection |
| `CHAT_MSG_SYSTEM` | 100% | Low | ✅ Buyout success confirmation |
| `PLAYER_MONEY` | 100% | Low | ✅ Transaction amount tracking |
| `UPDATE_PENDING_MAIL` | 100% | Low | ✅ Auction result notifications |
| `AUCTION_BIDDER_LIST_UPDATE` | 100% | Low | ✅ Your bids tracking |
| `AUCTION_OWNED_LIST_UPDATE` | 100% | Low | ✅ Your auctions tracking |
| `AUCTION_ITEM_LIST_UPDATE` | 100% | High | ❌ Fires 1-8× per search (spam, debounce required) |
| `BAG_UPDATE` | 100% | High | ❌ Multiple events per operation (use BAG_UPDATE_DELAYED) |

### Use Case → Best Event Mapping
- **Detect AH opening/closing:** `AUCTION_HOUSE_SHOW` / `AUCTION_HOUSE_CLOSED`
- **Track search operations:** `QueryAuctionItems` hook (shows parameters)
- **Detect bid/buyout operations:** `PlaceAuctionBid` hook + `PLAYER_MONEY`
- **Confirm buyout success:** `CHAT_MSG_SYSTEM` ("You won an auction")
- **Track your bids:** `AUCTION_BIDDER_LIST_UPDATE`
- **Track your auctions:** `AUCTION_OWNED_LIST_UPDATE`
- **Detect auction mail:** `UPDATE_PENDING_MAIL` (fires 2×)

### Critical AI Rules
- **Search Spam:** AUCTION_ITEM_LIST_UPDATE fires 1-8× per search with identical data
- **Tab Switching:** No events fired - use UI state monitoring (AuctionFrameBrowse/Bid/Auctions visibility)
- **Money Timing:** PLAYER_MONEY fires 117-244ms after bid operations
- **Mail Notifications:** UPDATE_PENDING_MAIL fires 2× for auction results

---

## Event Sequence Patterns

### Predictable Sequences (Safe to rely on order)
```
Open AH: AUCTION_HOUSE_SHOW → AUCTION_BIDDER_LIST_UPDATE → AUCTION_OWNED_LIST_UPDATE
Search: QueryAuctionItems hook → AUCTION_ITEM_LIST_UPDATE (×1-8 spam)
Regular Bid: PlaceAuctionBid hook → AUCTION_ITEM_LIST_UPDATE → AUCTION_BIDDER_LIST_UPDATE → PLAYER_MONEY
Buyout: PlaceAuctionBid hook → CHAT_MSG_SYSTEM → AUCTION_ITEM_LIST_UPDATE → UPDATE_PENDING_MAIL (×2) → AUCTION_BIDDER_LIST_UPDATE → PLAYER_MONEY
Sell Item: ITEM_LOCK_CHANGED → NEW_AUCTION_UPDATE → ClickAuctionSellItemButton → ITEM_UNLOCK → NEW_AUCTION_UPDATE → AUCTION_OWNED_LIST_UPDATE
Cancel Auction: CancelAuction hook → UPDATE_PENDING_MAIL → AUCTION_OWNED_LIST_UPDATE → UPDATE_PENDING_MAIL
```

### Variable Timing (Wait for completion)
```
Search Results: AUCTION_ITEM_LIST_UPDATE fires 1-8× with 0-336ms gaps
Mail Notifications: UPDATE_PENDING_MAIL fires 2× with 117-143ms gaps
```

---

## Performance Impact Summary

| Operation | Total Events | Spam Events | Performance Impact |
|-----------|--------------|-------------|-------------------|
| Open AH | 3 | None | Minimal |
| Search (no results) | 1 | None | Low |
| Search (with results) | 1-8 | AUCTION_ITEM_LIST_UPDATE (×1-8) | **High** |
| Regular Bid | 4 | None | Low |
| Buyout | 7 | UPDATE_PENDING_MAIL (×2) | Medium |
| Sell Item | 8 | ITEM_LOCK_CHANGED (×2) | Medium |
| Cancel Auction | 3 | UPDATE_PENDING_MAIL (×2) | Low |

**Critical:** AUCTION_ITEM_LIST_UPDATE fires 1-8× per search with identical data. Use debouncing or process only the first event.

---

## Essential API Functions

### Auction House Core
```lua
-- Auction house state
local canQuery = CanSendAuctionQuery()

-- Search operations
QueryAuctionItems(name, minLevel, maxLevel, invTypeIndex, classIndex, subclassIndex, page, isUsable, qualityIndex, getAll)

-- Get search results
local numItems = GetNumAuctionItems("list") -- "list", "bidder", "owner"
local name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index)
local itemLink = GetAuctionItemLink("list", index)
local timeLeft = GetAuctionItemTimeLeft("list", index) -- 1=Short, 2=Medium, 3=Long, 4=Very Long

-- Bidding operations
PlaceAuctionBid("list", index, bidAmount)

-- Selling operations  
local name, texture, count, quality, canUse, price = GetAuctionSellItemInfo()
local deposit = GetAuctionHouseDepositCost(runTime)
PutItemToAuction(minBid, buyoutPrice, runTime)
ClickAuctionSellItemButton()

-- Auction management
CancelAuction(index)
local numBids = GetNumAuctionItems("bidder")
local numOwned = GetNumAuctionItems("owner")
```

### Money and Item Tracking
```lua
-- Money tracking
local currentMoney = GetMoney()

-- Item locking (during auction operations)
-- ITEM_LOCK_CHANGED, ITEM_LOCKED, ITEM_UNLOCKED events track item state
```

---

## Implementation Patterns

### ✅ Recommended
```lua
-- Auction house tracking
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

-- Search operation tracking
hooksecurefunc("QueryAuctionItems", function(name, minLevel, maxLevel, invTypeIndex, classIndex, subclassIndex, page, isUsable, qualityIndex, getAll)
    -- Track search parameters
end)

-- Debounce search results spam
local lastSearchUpdate = 0
local function onAuctionItemListUpdate()
    local now = GetTime()
    if now - lastSearchUpdate < 0.5 then
        return -- Skip spam events
    end
    lastSearchUpdate = now
    -- Process search results
end

-- Bid/buyout tracking
hooksecurefunc("PlaceAuctionBid", function(type, index, bid)
    local itemInfo = GetAuctionItemInfo(type, index)
    -- Track bid operation
end)

-- Money change tracking
eventFrame:RegisterEvent("PLAYER_MONEY")
local function onPlayerMoney()
    local currentMoney = GetMoney()
    -- Track money changes from auctions
end
```

### ❌ Anti-Patterns
```lua
-- DON'T process every AUCTION_ITEM_LIST_UPDATE
eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE") -- ❌ Fires 1-8× per search
local function onAuctionItemListUpdate()
    ProcessAllAuctionItems() -- ❌ Called multiple times with same data
end

-- DON'T rely on AUCTION_BID_PLACED event
eventFrame:RegisterEvent("AUCTION_BID_PLACED") -- ❌ Not available in Classic Era
```

---

## Key Technical Details

### Critical Timing Discoveries
- **Search Spam:** AUCTION_ITEM_LIST_UPDATE fires 1-8× per search (varies by server load)
- **Tab Switching:** No events fired - purely UI-driven (monitor frame visibility)
- **Buyout vs Bid:** Buyouts trigger CHAT_MSG_SYSTEM, regular bids don't
- **Mail Timing:** UPDATE_PENDING_MAIL fires 2× with 117-143ms gaps
- **Money Delay:** PLAYER_MONEY fires 117-244ms after bid operations

### System Architecture
- **Search System:** QueryAuctionItems → AUCTION_ITEM_LIST_UPDATE spam → results available
- **Bidding System:** PlaceAuctionBid → money/list updates → mail notifications
- **Selling System:** Item locking → NEW_AUCTION_UPDATE → list updates
- **UI System:** Tab switching via frame visibility (no events)