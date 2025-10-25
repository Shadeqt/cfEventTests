-- WoW API calls
local _CreateFrame = CreateFrame
local _GetMerchantNumItems = GetMerchantNumItems
local _GetMerchantItemInfo = GetMerchantItemInfo
local _GetMerchantItemLink = GetMerchantItemLink
local _CanMerchantRepair = CanMerchantRepair
local _GetRepairAllCost = GetRepairAllCost
local _GetMoney = GetMoney
local _GetTime = GetTime
local _C_Container = C_Container
local _C_Timer = C_Timer

print("=== MERCHANT EVENT INVESTIGATION LOADED ===")
print("This module will log ALL merchant-related events")
print("Watch your chat for detailed event information")
print("===============================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- Core merchant-specific events for Classic Era
local MERCHANT_EVENTS = {
	-- Merchant lifecycle events
	"MERCHANT_SHOW",
	"MERCHANT_CLOSED",
	"MERCHANT_UPDATE",

	-- Money tracking (only when merchant is open)
	"PLAYER_MONEY",

	-- Bag events (only when merchant is open)
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",

	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(MERCHANT_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for delta timing
local lastEventTime = _GetTime()

-- Merchant state tracking
local merchantOpen = false
local merchantSnapshot = {}  -- Snapshot of merchant items when opened
local lastMoneyAmount = _GetMoney()
local merchantMoneySnapshot = nil  -- Money when merchant opened

-- Purchase tracking
local activePurchases = {}  -- Track pending purchases to monitor bag arrival
local repairCostBeforeRepair = nil

-- UI state tracking
local merchantFrameVisible = false
local currentMerchantTab = 1  -- 1 = merchant, 2 = buyback


-- Helper function to get merchant item details
local function getMerchantItemDetails(index)
	if not index then return "nil" end

	local name, texture, price, quantity, numAvailable, isUsable, extendedCost = _GetMerchantItemInfo(index)
	if not name then return "invalid index" end

	local itemLink = _GetMerchantItemLink(index)
	local itemName = itemLink and itemLink:match("%[(.-)%]") or name

	local stockInfo = ""
	if numAvailable == -1 then
		stockInfo = "unlimited"
	else
		stockInfo = numAvailable .. " available"
	end

	local priceGold = math.floor(price / 10000)
	local priceSilver = math.floor((price % 10000) / 100)
	local priceCopper = price % 100
	local priceStr = string.format("%dg %ds %dc", priceGold, priceSilver, priceCopper)

	local usableStr = isUsable and "usable" or "not usable"
	local extendedStr = extendedCost and " +extended cost" or ""

	return string.format("[%d] %s x%d (%s, %s, %s%s)", index, itemName, quantity, priceStr, stockInfo, usableStr, extendedStr)
end

-- Helper function to snapshot all merchant items
local function snapshotMerchantItems()
	local snapshot = {}
	local numItems = _GetMerchantNumItems()

	if not numItems or numItems == 0 then
		return snapshot
	end

	for i = 1, numItems do
		local name, texture, price, quantity, numAvailable, isUsable, extendedCost = _GetMerchantItemInfo(i)
		if name then
			local itemLink = _GetMerchantItemLink(i)
			snapshot[i] = {
				name = name,
				texture = texture,
				price = price,
				quantity = quantity,
				numAvailable = numAvailable,
				isUsable = isUsable,
				extendedCost = extendedCost,
				itemLink = itemLink
			}
		end
	end

	return snapshot
end

-- Helper function to format money
local function formatMoney(copper)
	if not copper then return "0g 0s 0c" end
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local copperAmount = copper % 100
	return string.format("%dg %ds %dc", gold, silver, copperAmount)
end

-- Helper function to count specific items in bags
local function countItemInBags(itemName)
	if not itemName or itemName == "" then return 0 end

	local totalCount = 0
	local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4

	-- Scan backpack (bag 0) and bags 1-4
	for bagId = 0, NUM_BAG_SLOTS do
		local numSlots = _C_Container.GetContainerNumSlots(bagId)
		if numSlots then
			for slotId = 1, numSlots do
				local containerInfo = _C_Container.GetContainerItemInfo(bagId, slotId)
				if containerInfo and containerInfo.hyperlink then
					-- Extract item name from hyperlink
					local bagItemName = containerInfo.hyperlink:match("%[(.-)%]")
					if bagItemName and bagItemName == itemName then
						totalCount = totalCount + (containerInfo.stackCount or 1)
					end
				end
			end
		end
	end

	return totalCount
end

-- Register all events with error handling
local registeredEvents = {}
for _, event in ipairs(MERCHANT_EVENTS) do
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

	print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "MERCHANT_SHOW" then
		merchantOpen = true
		print("  |cffffaa00Merchant Opened|r")

		-- Capture merchant money snapshot
		merchantMoneySnapshot = _GetMoney()
		print("  |cffffaa00  Current Money:|r " .. formatMoney(merchantMoneySnapshot))

		-- Check if merchant can repair
		local canRepair = _CanMerchantRepair()
		if canRepair then
			local repairCost, needsRepair = _GetRepairAllCost()
			print("  |cff00ff00  Merchant can REPAIR|r")
			if needsRepair then
				print("  |cffffaa00    Repair cost:|r " .. formatMoney(repairCost))
			else
				print("  |cffaaaaaa    No repairs needed|r")
			end
		else
			print("  |cffaaaaaa  Merchant cannot repair|r")
		end

		-- Note: Merchant data may be stale at this point
		print("  |cffff6600  Note: Merchant data may be STALE - wait for MERCHANT_UPDATE|r")

	elseif event == "MERCHANT_CLOSED" then
		merchantOpen = false
		print("  |cffffaa00Merchant Closed|r")

		-- Clear tracking data
		merchantSnapshot = {}
		activePurchases = {}
		repairCostBeforeRepair = nil
		merchantMoneySnapshot = nil

	elseif event == "MERCHANT_UPDATE" then
		print("  |cffffaa00Merchant Data Updated|r")

		-- Take snapshot of merchant items
		local newSnapshot = snapshotMerchantItems()
		local numItems = _GetMerchantNumItems()

		print("  |cffffaa00  Merchant has " .. (numItems or 0) .. " items for sale|r")

		-- Check if this is the initial update (data now available)
		if not next(merchantSnapshot) and next(newSnapshot) then
			print("  |cff00ff00  ✓ Merchant data now AVAILABLE (was stale before)|r")
		end

		-- Compare with previous snapshot to detect stock changes
		if next(merchantSnapshot) then
			local changesDetected = false
			for index, oldItem in pairs(merchantSnapshot) do
				local newItem = newSnapshot[index]
				if newItem and oldItem.numAvailable ~= newItem.numAvailable and oldItem.numAvailable ~= -1 then
					changesDetected = true
					print("  |cffff9900  Stock changed:|r " .. newItem.name .. " (" .. oldItem.numAvailable .. " → " .. newItem.numAvailable .. ")")
				end
			end
			if not changesDetected then
				print("  |cffaaaaaa  No stock changes detected|r")
			end
		end

		-- Show all items (only on first update to avoid spam)
		if not next(merchantSnapshot) and next(newSnapshot) then
			print("  |cffaaaaaa  Merchant inventory:|r")
			for i = 1, math.min(numItems, 10) do  -- Limit to first 10 to avoid spam
				print("    |cffaaaaaa  " .. getMerchantItemDetails(i) .. "|r")
			end
			if numItems > 10 then
				print("    |cffaaaaaa  ... and " .. (numItems - 10) .. " more items|r")
			end
		end

		-- Update snapshot
		merchantSnapshot = newSnapshot

	elseif event == "PLAYER_MONEY" then
		-- Only log if merchant is open (avoid spam from other money changes)
		if merchantOpen then
			local currentMoney = _GetMoney()
			local moneyChange = currentMoney - lastMoneyAmount
			local changeStr = ""

			if moneyChange > 0 then
				changeStr = "|cff00ff00+" .. formatMoney(moneyChange) .. "|r (gained)"
			elseif moneyChange < 0 then
				changeStr = "|cffff0000-" .. formatMoney(math.abs(moneyChange)) .. "|r (spent)"
			else
				changeStr = "no change"
			end

			print("  |cffffaa00Money Changed:|r " .. formatMoney(currentMoney) .. " (" .. changeStr .. ")")
			print("  |cff00ff00  Money change while merchant is OPEN|r")
			
			if merchantMoneySnapshot then
				local totalChange = currentMoney - merchantMoneySnapshot
				if totalChange < 0 then
					print("  |cffff6600  Total spent at this merchant:|r " .. formatMoney(math.abs(totalChange)))
				end
			end
		end

		lastMoneyAmount = _GetMoney()

	elseif event == "BAG_UPDATE" then
		-- Only log if merchant is open (avoid spam)
		if merchantOpen then
			local bagId = arg1
			print("  |cffffaa00Bag Updated:|r bagId " .. tostring(bagId))

			-- Check for any pending purchases
			if next(activePurchases) then
				for itemName, purchaseData in pairs(activePurchases) do
					local currentCount = countItemInBags(itemName)
					local timeSincePurchase = currentTime - purchaseData.timestamp

					if currentCount > purchaseData.countBefore then
						local amountReceived = currentCount - purchaseData.countBefore
						print("  |cff00ff00  ✓ Purchased item arrived in bags:|r " .. itemName .. " +" .. amountReceived)
						print("  |cff00ff00    Arrival timing: +" .. string.format("%.0fms", timeSincePurchase * 1000) .. " after BuyMerchantItem|r")
						-- Remove from tracking
						activePurchases[itemName] = nil
					end
				end
			end
		end

	elseif event == "BAG_UPDATE_DELAYED" then
		-- Only log if merchant is open (avoid spam)
		if merchantOpen then
			print("  |cffffaa00Info:|r All pending bag updates completed")

			-- Final check for any pending purchases that didn't arrive yet
			if next(activePurchases) then
				print("  |cffff6600  ⚠ Some purchased items still not visible in bags:|r")
				for itemName, _ in pairs(activePurchases) do
					print("    |cffff6600  - " .. itemName .. "|r")
				end
			end
		end

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

		-- Initialize money tracking
		lastMoneyAmount = _GetMoney()
		print("  |cffaaaaaa  Starting money:|r " .. formatMoney(lastMoneyAmount))

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Monitor MerchantFrame visibility and tab state
local function checkMerchantFrameState()
	if MerchantFrame and MerchantFrame:IsShown() then
		if not merchantFrameVisible then
			merchantFrameVisible = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant UI]|r MerchantFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end

		-- Check merchant tab state (1 = merchant, 2 = buyback)
		local newTab = 1
		if MerchantFrameTab2 and MerchantFrameTab2.GetChecked and MerchantFrameTab2:GetChecked() then
			newTab = 2
		end

		if newTab ~= currentMerchantTab then
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			local tabName = newTab == 1 and "MERCHANT" or "BUYBACK"
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant UI]|r Tab switched to |cff00ffff" .. tabName .. "|r")
			lastEventTime = currentTime
			currentMerchantTab = newTab
		end
	else
		if merchantFrameVisible then
			merchantFrameVisible = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant UI]|r MerchantFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
			currentMerchantTab = 1  -- Reset to merchant tab
		end
	end
end



-- Update UI state regularly
investigationFrame:SetScript("OnUpdate", function()
	checkMerchantFrameState()
end)

-- Hook merchant-related functions
if BuyMerchantItem then
	hooksecurefunc("BuyMerchantItem", function(index, quantity)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant Hook]|r BuyMerchantItem")
		lastEventTime = currentTime

		print("  |cffffaa00Purchasing:|r " .. getMerchantItemDetails(index))
		print("  |cffffaa00  Quantity:|r " .. tostring(quantity or 1))

		-- Track this purchase to monitor when it arrives in bags
		local name, texture, price, quantityPerStack, numAvailable, isUsable, extendedCost = _GetMerchantItemInfo(index)
		if name then
			local itemLink = _GetMerchantItemLink(index)
			local itemName = itemLink and itemLink:match("%[(.-)%]") or name

			-- Count current amount in bags BEFORE purchase
			local countBefore = countItemInBags(itemName)
			print("  |cffaaaaaa  Item count in bags BEFORE purchase:|r " .. countBefore)

			activePurchases[itemName] = {
				timestamp = currentTime,
				countBefore = countBefore,
				index = index
			}
			print("  |cff00ff00  Started monitoring BAG_UPDATE for item arrival...|r")
		end
	end)
end

if BuybackItem then
	hooksecurefunc("BuybackItem", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant Hook]|r BuybackItem")
		lastEventTime = currentTime

		print("  |cffffaa00Buyback:|r index " .. tostring(index))
	end)
end

if RepairAllItems then
	hooksecurefunc("RepairAllItems", function(guildBankRepair)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant Hook]|r RepairAllItems")
		lastEventTime = currentTime

		local useGuildFunds = guildBankRepair == 1
		print("  |cffffaa00Repairing all items:|r " .. (useGuildFunds and "using guild funds" or "using personal funds"))

		-- Capture repair cost BEFORE repair
		local repairCost, needsRepair = _GetRepairAllCost()
		if needsRepair then
			repairCostBeforeRepair = repairCost
			print("  |cffffaa00  Repair cost:|r " .. formatMoney(repairCost))
		else
			print("  |cffaaaaaa  No repairs needed|r")
		end
	end)
end

if CloseMerchant then
	hooksecurefunc("CloseMerchant", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant Hook]|r CloseMerchant")
		lastEventTime = currentTime
	end)
end

-- Merchant tab and UI update hooks
if MerchantFrame_UpdateMerchantInfo then
	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant Hook]|r MerchantFrame_UpdateMerchantInfo")
		lastEventTime = currentTime
	end)
end

if MerchantFrame_UpdateBuybackInfo then
	hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant Hook]|r MerchantFrame_UpdateBuybackInfo")
		lastEventTime = currentTime
	end)
end

-- Sell cursor hooks
if ShowMerchantSellCursor then
	hooksecurefunc("ShowMerchantSellCursor", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Merchant Hook]|r ShowMerchantSellCursor → slot: " .. tostring(index))
		lastEventTime = currentTime
	end)
end



-- Gossip interaction hooks
if SelectGossipOption then
	hooksecurefunc("SelectGossipOption", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Gossip Hook]|r SelectGossipOption → " .. tostring(index))
		lastEventTime = currentTime
	end)
end

if MerchantFrame_Update then
	hooksecurefunc("MerchantFrame_Update", function()
		-- Don't log this - fires too frequently
	end)
end

-- Test functions for merchant hooks
local function testMerchantHooks()
	print("|cff00ff00=== TESTING MERCHANT HOOKS ===|r")
	
	if not (MerchantFrame and MerchantFrame:IsShown()) then
		print("|cffff0000Cannot test merchant hooks - merchant window not open|r")
		print("|cffff6600Talk to a merchant first, then run /testmercanthooks|r")
		return
	end
	
	-- Test MerchantFrame_UpdateMerchantInfo hook
	print("|cffffaa00Testing MerchantFrame_UpdateMerchantInfo hook...|r")
	if MerchantFrame_UpdateMerchantInfo then
		MerchantFrame_UpdateMerchantInfo()
	else
		print("|cffff0000MerchantFrame_UpdateMerchantInfo function not available|r")
	end
	
	-- Test MerchantFrame_UpdateBuybackInfo hook
	print("|cffffaa00Testing MerchantFrame_UpdateBuybackInfo hook...|r")
	if MerchantFrame_UpdateBuybackInfo then
		MerchantFrame_UpdateBuybackInfo()
	else
		print("|cffff0000MerchantFrame_UpdateBuybackInfo function not available|r")
	end
	
	-- Test ShowMerchantSellCursor hook
	print("|cffffaa00Testing ShowMerchantSellCursor hook...|r")
	if ShowMerchantSellCursor then
		ShowMerchantSellCursor(1)
	else
		print("|cffff0000ShowMerchantSellCursor function not available|r")
	end
	
	-- Test RepairAllItems hook (if merchant can repair)
	if CanMerchantRepair and CanMerchantRepair() then
		print("|cffffaa00Testing RepairAllItems hook...|r")
		if RepairAllItems then
			RepairAllItems(false) -- Don't use guild bank
		else
			print("|cffff0000RepairAllItems function not available|r")
		end
	else
		print("|cffff6600Cannot test RepairAllItems - merchant cannot repair|r")
	end
	
	-- Test BuyMerchantItem hook (buy first item if available and affordable)
	local numItems = _GetMerchantNumItems and _GetMerchantNumItems() or 0
	if numItems > 0 then
		local name, texture, price, quantity, numAvailable, isUsable, extendedCost = _GetMerchantItemInfo(1)
		if name and price then
			local playerMoney = GetMoney and GetMoney() or 0
			if playerMoney >= price then
				print("|cffffaa00Testing BuyMerchantItem hook on " .. name .. "...|r")
				if BuyMerchantItem then
					BuyMerchantItem(1, 1)
				else
					print("|cffff0000BuyMerchantItem function not available|r")
				end
			else
				print("|cffff6600Cannot test BuyMerchantItem - not enough money for " .. name .. "|r")
			end
		end
	else
		print("|cffff6600Cannot test BuyMerchantItem - no items for sale|r")
	end
	
	-- Test BuybackItem hook (if there are buyback items)
	local numBuybackItems = GetNumBuybackItems and GetNumBuybackItems() or 0
	if numBuybackItems > 0 then
		print("|cffffaa00Testing BuybackItem hook on first buyback item...|r")
		if BuybackItem then
			BuybackItem(1)
		else
			print("|cffff0000BuybackItem function not available|r")
		end
	else
		print("|cffff6600Cannot test BuybackItem - no buyback items available|r")
	end
	
	-- Test CloseMerchant hook
	print("|cffffaa00Testing CloseMerchant hook...|r")
	if CloseMerchant then
		CloseMerchant()
	else
		print("|cffff0000CloseMerchant function not available|r")
	end
	
	print("|cff00ff00=== MERCHANT HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test merchant hooks
SLASH_TESTMERCANTHOOKS1 = "/testmercanthooks"
SlashCmdList["TESTMERCANTHOOKS"] = testMerchantHooks

print("|cff00ff00Merchant investigation ready - events will print to chat|r")
print("|cff00ff00Use /testmercanthooks to test merchant function hooks|r")