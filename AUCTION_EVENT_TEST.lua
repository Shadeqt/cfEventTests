-- WoW API calls (Classic Era 1.15 compatible)
local _CreateFrame = CreateFrame
local _GetTime = GetTime
local _GetNumAuctionItems = GetNumAuctionItems
local _GetAuctionItemInfo = GetAuctionItemInfo
local _GetAuctionItemLink = GetAuctionItemLink
local _GetAuctionItemTimeLeft = GetAuctionItemTimeLeft
local _GetAuctionSellItemInfo = GetAuctionSellItemInfo
local _GetSelectedAuctionItem = GetSelectedAuctionItem
local _GetOwnerAuctionItems = GetOwnerAuctionItems
local _GetBidderAuctionItems = GetBidderAuctionItems
local _CanSendAuctionQuery = CanSendAuctionQuery
local _QueryAuctionItems = QueryAuctionItems
local _PlaceAuctionBid = PlaceAuctionBid
local _PutItemToAuction = PutItemToAuction
local _CancelAuction = CancelAuction
local _ClickAuctionSellItemButton = ClickAuctionSellItemButton
local _GetAuctionHouseDepositCost = GetAuctionHouseDepositCost

print("=== AUCTION HOUSE EVENT INVESTIGATION LOADED ===")
print("This module will log ALL auction house-related events")
print("Watch your chat for detailed event information")
print("==============================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All possible auction house-related events for Classic Era (1.15)
local AUCTION_EVENTS = {
	-- Core auction house events
	"AUCTION_HOUSE_SHOW",
	"AUCTION_HOUSE_CLOSED",
	"AUCTION_ITEM_LIST_UPDATE",
	"AUCTION_BIDDER_LIST_UPDATE", 
	"AUCTION_OWNED_LIST_UPDATE",
	
	-- Auction operations
	"NEW_AUCTION_UPDATE",
	"AUCTION_BID_PLACED",
	"AUCTION_MULTISELL_START",
	"AUCTION_MULTISELL_UPDATE",
	"AUCTION_MULTISELL_FAILURE",
	
	-- Chat messages
	"CHAT_MSG_SYSTEM",
	
	-- UI updates
	"UPDATE_PENDING_MAIL",
	"MAIL_INBOX_UPDATE",
	
	-- Money changes
	"PLAYER_MONEY",
	
	-- Bag updates (for item changes)
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",
	
	-- Item lock changes (for auction operations)
	"ITEM_LOCK_CHANGED",
	"ITEM_LOCKED",
	"ITEM_UNLOCKED",
	
	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(AUCTION_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Auction house state tracking
local auctionHouseOpen = false
local currentAuctionType = nil -- "list", "bidder", "auctions"
local lastQueryTime = 0
local lastQueryParams = {}

-- Track auction operations
local activeAuctionOperation = nil -- { type = "bid/sell/cancel", timestamp = time, itemName = "X" }

-- Track money before/after operations
local moneySnapshot = 0

-- UI state tracking
local auctionFrameOpen = false

-- Helper function to get auction item info
local function getAuctionItemInfo(type, index)
	if not index or not type then return "nil" end
	
	local name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = _GetAuctionItemInfo(type, index)
	
	if not name then
		return "invalid index"
	end
	
	-- Get item link
	local itemLink = _GetAuctionItemLink(type, index)
	local displayName = itemLink and itemLink:match("%[(.-)%]") or name
	
	-- Get time left
	local timeLeft = _GetAuctionItemTimeLeft(type, index)
	local timeLeftStr = ""
	if timeLeft == 1 then
		timeLeftStr = "Short"
	elseif timeLeft == 2 then
		timeLeftStr = "Medium" 
	elseif timeLeft == 3 then
		timeLeftStr = "Long"
	elseif timeLeft == 4 then
		timeLeftStr = "Very Long"
	else
		timeLeftStr = "Unknown"
	end
	
	-- Format prices
	local minBidStr = minBid and string.format("%dg %ds %dc", math.floor(minBid/10000), math.floor((minBid%10000)/100), minBid%100) or "0"
	local buyoutStr = buyoutPrice and buyoutPrice > 0 and string.format("%dg %ds %dc", math.floor(buyoutPrice/10000), math.floor((buyoutPrice%10000)/100), buyoutPrice%100) or "No buyout"
	
	return string.format("[%d] %s x%d (Min: %s, Buyout: %s, Time: %s)", index, displayName, count or 1, minBidStr, buyoutStr, timeLeftStr)
end

-- Helper function to format money
local function formatMoney(copper)
	if not copper or copper == 0 then return "0c" end
	
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local copperRem = copper % 100
	
	local parts = {}
	if gold > 0 then table.insert(parts, gold .. "g") end
	if silver > 0 then table.insert(parts, silver .. "s") end
	if copperRem > 0 or #parts == 0 then table.insert(parts, copperRem .. "c") end
	
	return table.concat(parts, " ")
end

-- Helper function to get current money
local function getCurrentMoney()
	return GetMoney and GetMoney() or 0
end

-- Register all events with error handling
local registeredEvents = {}
for _, event in ipairs(AUCTION_EVENTS) do
	local success = pcall(investigationFrame.RegisterEvent, investigationFrame, event)
	if success then
		registeredEvents[event] = true
		print("|cff00ff00Registered:|r " .. event)
	else
		print("|cffff6600Skipped (not available):|r " .. event)
	end
end

-- Event handler with detailed logging
investigationFrame:SetScript("OnEvent", function(self, event, ...)
	-- Only process events we successfully registered
	if not registeredEvents[event] then
		return
	end
	
	local arg1, arg2, arg3, arg4 = ...
	eventCounts[event] = (eventCounts[event] or 0) + 1

	local currentTime = _GetTime()
	local timeSinceLastEvent = currentTime - lastEventTime
	local timestamp = string.format("[%.2f]", currentTime)
	local countInfo = string.format("[#%d]", eventCounts[event])
	local deltaInfo = string.format("(+%.0fms)", timeSinceLastEvent * 1000)

	-- Filter out frequent events unless we're tracking auction operations
	if event == "BAG_UPDATE" then
		if not activeAuctionOperation then
			return -- Don't log bag updates outside auction context
		end
	end
	
	-- Filter CHAT_MSG_SYSTEM to auction-related messages only
	if event == "CHAT_MSG_SYSTEM" then
		local message = arg1
		if not message or not (
			message:find("auction") or 
			message:find("bid") or 
			message:find("outbid") or
			message:find("sold") or
			message:find("buyout")
		) then
			return -- Not auction-related
		end
	end

	print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "AUCTION_HOUSE_SHOW" then
		print("  |cffffaa00Auction House Opened|r")
		auctionHouseOpen = true
		moneySnapshot = getCurrentMoney()
		print("  |cffffaa00  Current Money:|r " .. formatMoney(moneySnapshot))

	elseif event == "AUCTION_HOUSE_CLOSED" then
		print("  |cffffaa00Auction House Closed|r")
		auctionHouseOpen = false
		
		-- Show money change if any
		local currentMoney = getCurrentMoney()
		if currentMoney ~= moneySnapshot then
			local change = currentMoney - moneySnapshot
			local changeStr = change > 0 and ("|cff00ff00+" .. formatMoney(change) .. "|r") or ("|cffff0000" .. formatMoney(math.abs(change)) .. "|r")
			print("  |cffffaa00  Money Change:|r " .. changeStr)
		end

	elseif event == "AUCTION_ITEM_LIST_UPDATE" then
		print("  |cffffaa00Auction Item List Updated|r")
		
		if _CanSendAuctionQuery and _CanSendAuctionQuery() then
			print("  |cffffaa00  Can send new queries|r")
		else
			print("  |cffff6600  Query cooldown active|r")
		end
		
		local numItems = _GetNumAuctionItems and _GetNumAuctionItems("list") or 0
		print("  |cffffaa00  Items Found:|r " .. numItems)
		
		-- Show first few items as sample
		if numItems > 0 then
			print("  |cffaaaaaa  Sample items:|r")
			for i = 1, math.min(5, numItems) do
				local info = getAuctionItemInfo("list", i)
				print("    |cffaaaaaa  " .. info .. "|r")
			end
			if numItems > 5 then
				print("    |cffaaaaaa  ... and " .. (numItems - 5) .. " more|r")
			end
		end

	elseif event == "AUCTION_BIDDER_LIST_UPDATE" then
		print("  |cffffaa00Bidder List Updated|r")
		
		local numItems = _GetNumAuctionItems and _GetNumAuctionItems("bidder") or 0
		print("  |cffffaa00  Your Bids:|r " .. numItems)
		
		if numItems > 0 then
			print("  |cffaaaaaa  Your bidded items:|r")
			for i = 1, numItems do
				local info = getAuctionItemInfo("bidder", i)
				print("    |cffaaaaaa  " .. info .. "|r")
			end
		end

	elseif event == "AUCTION_OWNED_LIST_UPDATE" then
		print("  |cffffaa00Owned Auctions Updated|r")
		
		local numItems = _GetNumAuctionItems and _GetNumAuctionItems("owner") or 0
		print("  |cffffaa00  Your Auctions:|r " .. numItems)
		
		if numItems > 0 then
			print("  |cffaaaaaa  Your active auctions:|r")
			for i = 1, numItems do
				local info = getAuctionItemInfo("owner", i)
				print("    |cffaaaaaa  " .. info .. "|r")
			end
		end

	elseif event == "NEW_AUCTION_UPDATE" then
		print("  |cffffaa00New Auction Update|r")
		
		-- Check sell item info
		if _GetAuctionSellItemInfo then
			local name, texture, count, quality, canUse, price = _GetAuctionSellItemInfo()
			if name then
				print("  |cffffaa00  Item to Sell:|r " .. name .. " x" .. (count or 1))
				if price and price > 0 then
					print("  |cffffaa00  Suggested Price:|r " .. formatMoney(price))
				end
			end
		end

	elseif event == "AUCTION_BID_PLACED" then
		print("  |cff00ff00Bid Placed Successfully|r")
		
		-- Track this operation
		activeAuctionOperation = {
			type = "bid",
			timestamp = currentTime
		}

	elseif event == "AUCTION_MULTISELL_START" then
		print("  |cffffaa00Multi-sell Started|r")

	elseif event == "AUCTION_MULTISELL_UPDATE" then
		print("  |cffffaa00Multi-sell Progress|r")

	elseif event == "AUCTION_MULTISELL_FAILURE" then
		print("  |cffff0000Multi-sell Failed|r")

	elseif event == "CHAT_MSG_SYSTEM" then
		local message = arg1
		print("  |cff00ff00System Message:|r " .. tostring(message))

	elseif event == "UPDATE_PENDING_MAIL" then
		print("  |cffffaa00Pending Mail Updated|r (may be auction-related)")

	elseif event == "MAIL_INBOX_UPDATE" then
		print("  |cffffaa00Mail Inbox Updated|r (may be auction-related)")

	elseif event == "PLAYER_MONEY" then
		local currentMoney = getCurrentMoney()
		local change = currentMoney - moneySnapshot
		
		if math.abs(change) > 0 then
			local changeStr = change > 0 and ("|cff00ff00+" .. formatMoney(change) .. "|r") or ("|cffff0000-" .. formatMoney(math.abs(change)) .. "|r")
			print("  |cffffaa00Money Changed:|r " .. changeStr .. " (Total: " .. formatMoney(currentMoney) .. ")")
			moneySnapshot = currentMoney
		end

	elseif event == "BAG_UPDATE" then
		local bagId = arg1
		
		if activeAuctionOperation then
			local statusStr = "(during auction operation)"
			print("  |cffffaa00Bag Updated " .. statusStr .. ":|r Bag " .. tostring(bagId))
		end

	elseif event == "BAG_UPDATE_DELAYED" then
		if activeAuctionOperation then
			print("  |cffffaa00All bag updates completed (after auction operation)|r")
			-- Clear operation tracking after a delay
			activeAuctionOperation = nil
		end

	elseif event == "ITEM_LOCK_CHANGED" then
		local bagId, slotId = arg1, arg2
		print("  |cffffaa00Item Lock Changed:|r Bag " .. tostring(bagId) .. ", Slot " .. tostring(slotId))

	elseif event == "ITEM_LOCKED" then
		local bagId, slotId = arg1, arg2
		print("  |cffffaa00Item Locked:|r Bag " .. tostring(bagId) .. ", Slot " .. tostring(slotId))

	elseif event == "ITEM_UNLOCKED" then
		local bagId, slotId = arg1, arg2
		print("  |cffffaa00Item Unlocked:|r Bag " .. tostring(bagId) .. ", Slot " .. tostring(slotId))

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Track current auction house tab
local currentAuctionTab = nil

-- Monitor AuctionFrame visibility and tab changes
local function checkAuctionFrameState()
	if AuctionFrame and AuctionFrame:IsShown() then
		if not auctionFrameOpen then
			auctionFrameOpen = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r AuctionFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
		
		-- Check for tab changes (Classic Era tab detection)
		local newTab = nil
		if AuctionFrameBrowse and AuctionFrameBrowse:IsShown() then
			newTab = "browse"
		elseif AuctionFrameBid and AuctionFrameBid:IsShown() then
			newTab = "bids"  
		elseif AuctionFrameAuctions and AuctionFrameAuctions:IsShown() then
			newTab = "auctions"
		end
		
		if newTab and newTab ~= currentAuctionTab then
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r Tab Changed → |cff00ffff" .. string.upper(newTab) .. "|r")
			currentAuctionTab = newTab
			lastEventTime = currentTime
		end
	else
		if auctionFrameOpen then
			auctionFrameOpen = false
			currentAuctionTab = nil
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r AuctionFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Add OnUpdate for continuous UI monitoring
investigationFrame:SetScript("OnUpdate", function()
	checkAuctionFrameState()
end)

-- Hook auction house functions
if _QueryAuctionItems then
	hooksecurefunc("QueryAuctionItems", function(name, minLevel, maxLevel, invTypeIndex, classIndex, subclassIndex, page, isUsable, qualityIndex, getAll)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r QueryAuctionItems")
		print("  |cffffaa00Search:|r " .. tostring(name or "All"))
		print("  |cffffaa00Level Range:|r " .. tostring(minLevel or "Any") .. "-" .. tostring(maxLevel or "Any"))
		print("  |cffffaa00Page:|r " .. tostring(page or 0))
		print("  |cffffaa00Get All:|r " .. tostring(getAll))
		
		lastQueryTime = currentTime
		lastQueryParams = {
			name = name,
			minLevel = minLevel,
			maxLevel = maxLevel,
			page = page,
			getAll = getAll
		}
		
		lastEventTime = currentTime
	end)
end

if _PlaceAuctionBid then
	hooksecurefunc("PlaceAuctionBid", function(type, index, bid)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r PlaceAuctionBid")
		
		local itemInfo = getAuctionItemInfo(type, index)
		print("  |cffffaa00Item:|r " .. itemInfo)
		print("  |cffffaa00Bid Amount:|r " .. formatMoney(bid))
		
		-- Track this operation
		activeAuctionOperation = {
			type = "bid",
			timestamp = currentTime,
			itemInfo = itemInfo,
			bidAmount = bid
		}
		
		lastEventTime = currentTime
	end)
end

if _PutItemToAuction then
	hooksecurefunc("PutItemToAuction", function(minBid, buyoutPrice, runTime)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r PutItemToAuction")
		print("  |cffffaa00Min Bid:|r " .. formatMoney(minBid))
		print("  |cffffaa00Buyout:|r " .. (buyoutPrice > 0 and formatMoney(buyoutPrice) or "None"))
		print("  |cffffaa00Duration:|r " .. tostring(runTime) .. " hours")
		
		-- Get deposit cost
		if _GetAuctionHouseDepositCost then
			local deposit = _GetAuctionHouseDepositCost(runTime)
			if deposit and deposit > 0 then
				print("  |cffffaa00Deposit:|r " .. formatMoney(deposit))
			end
		end
		
		-- Track this operation
		activeAuctionOperation = {
			type = "sell",
			timestamp = currentTime,
			minBid = minBid,
			buyoutPrice = buyoutPrice,
			runTime = runTime
		}
		
		lastEventTime = currentTime
	end)
end

if _CancelAuction then
	hooksecurefunc("CancelAuction", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r CancelAuction")
		
		local itemInfo = getAuctionItemInfo("owner", index)
		print("  |cffffaa00Item:|r " .. itemInfo)
		
		-- Track this operation
		activeAuctionOperation = {
			type = "cancel",
			timestamp = currentTime,
			itemInfo = itemInfo
		}
		
		lastEventTime = currentTime
	end)
end

if _ClickAuctionSellItemButton then
	hooksecurefunc("ClickAuctionSellItemButton", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r ClickAuctionSellItemButton")
		lastEventTime = currentTime
	end)
end

-- Hook tab switching functions if they exist
if AuctionFrameTab_OnClick then
	hooksecurefunc("AuctionFrameTab_OnClick", function(tab)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		local tabName = tab and tab:GetName() or "unknown"
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r AuctionFrameTab_OnClick → " .. tabName)
		lastEventTime = currentTime
	end)
end

-- Hook search functions
if AuctionFrameBrowse_Search then
	hooksecurefunc("AuctionFrameBrowse_Search", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r AuctionFrameBrowse_Search")
		lastEventTime = currentTime
	end)
end

-- Hook bid button
if AuctionFrameBid_OnClick then
	hooksecurefunc("AuctionFrameBid_OnClick", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r AuctionFrameBid_OnClick")
		lastEventTime = currentTime
	end)
end

-- Hook buyout button  
if AuctionFrameBuyout_OnClick then
	hooksecurefunc("AuctionFrameBuyout_OnClick", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Auction Hook]|r AuctionFrameBuyout_OnClick")
		lastEventTime = currentTime
	end)
end

-- Test functions for auction house hooks
local function testAuctionHooks()
	print("|cff00ff00=== TESTING AUCTION HOUSE HOOKS ===|r")
	
	if not (AuctionFrame and AuctionFrame:IsShown()) then
		print("|cffff0000Cannot test auction hooks - auction house not open|r")
		print("|cffff6600Visit an auctioneer first, then run /testauctionhooks|r")
		return
	end
	
	-- Test QueryAuctionItems hook
	print("|cffffaa00Testing QueryAuctionItems hook...|r")
	if _QueryAuctionItems then
		_QueryAuctionItems("", nil, nil, nil, nil, nil, 0, false, nil, false)
	else
		print("|cffff0000QueryAuctionItems function not available|r")
	end
	
	-- Test ClickAuctionSellItemButton hook
	print("|cffffaa00Testing ClickAuctionSellItemButton hook...|r")
	if _ClickAuctionSellItemButton then
		_ClickAuctionSellItemButton()
	else
		print("|cffff0000ClickAuctionSellItemButton function not available|r")
	end
	
	-- Test tab switching hooks
	if AuctionFrameTab_OnClick then
		print("|cffffaa00Testing AuctionFrameTab_OnClick hook...|r")
		-- Try to click browse tab
		if AuctionFrameTab1 then
			AuctionFrameTab_OnClick(AuctionFrameTab1)
		end
	end
	
	-- Test search hook
	if AuctionFrameBrowse_Search then
		print("|cffffaa00Testing AuctionFrameBrowse_Search hook...|r")
		AuctionFrameBrowse_Search()
	end
	
	-- Test auction operations (only if we have items/auctions)
	local numBrowseItems = _GetNumAuctionItems and _GetNumAuctionItems("list") or 0
	if numBrowseItems > 0 then
		print("|cffffaa00Testing PlaceAuctionBid hook on first item...|r")
		if _PlaceAuctionBid then
			-- Get minimum bid for first item
			local name, texture, count, quality, canUse, level, levelColHeader, minBid = _GetAuctionItemInfo("list", 1)
			if minBid then
				_PlaceAuctionBid("list", 1, minBid)
			end
		else
			print("|cffff0000PlaceAuctionBid function not available|r")
		end
	else
		print("|cffff6600Cannot test PlaceAuctionBid - no items in browse list|r")
	end
	
	local numOwnedItems = _GetNumAuctionItems and _GetNumAuctionItems("owner") or 0
	if numOwnedItems > 0 then
		print("|cffffaa00Testing CancelAuction hook on first owned auction...|r")
		if _CancelAuction then
			_CancelAuction(1)
		else
			print("|cffff0000CancelAuction function not available|r")
		end
	else
		print("|cffff6600Cannot test CancelAuction - no owned auctions|r")
	end
	
	print("|cff00ff00=== AUCTION HOUSE HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test auction house hooks
SLASH_TESTAUCTIONHOOKS1 = "/testauctionhooks"
SlashCmdList["TESTAUCTIONHOOKS"] = testAuctionHooks

print("|cff00ff00Auction House investigation ready - events will print to chat|r")
print("|cff00ff00Visit an auctioneer and perform searches, bids, and sales to test events|r")
print("|cff00ff00Use /testauctionhooks to test auction house function hooks|r")
print("|cff00ff00Classic Era (1.15) compatible version loaded|r")