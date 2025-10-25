-- WoW API calls
local _CreateFrame = CreateFrame
local _GetTradePlayerItemInfo = GetTradePlayerItemInfo
local _GetTradePlayerItemLink = GetTradePlayerItemLink
local _GetTradeTargetItemInfo = GetTradeTargetItemInfo
local _GetTradeTargetItemLink = GetTradeTargetItemLink
local _GetPlayerTradeMoney = GetPlayerTradeMoney
local _GetTargetTradeMoney = GetTargetTradeMoney
local _UnitName = UnitName
local _GetTime = GetTime
local _C_Timer = C_Timer

print("=== TRADE EVENT INVESTIGATION LOADED ===")
print("This module will log ALL trade-related events")
print("Watch your chat for detailed event information")
print("Initiate trades with other players to test events")
print("===============================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All possible trade-related events for Classic Era
local TRADE_EVENTS = {
	-- Core trade lifecycle events
	"TRADE_SHOW",
	"TRADE_CLOSED",
	"TRADE_UPDATE",
	"TRADE_ACCEPT_UPDATE",
	"TRADE_PLAYER_ITEM_CHANGED",
	"TRADE_TARGET_ITEM_CHANGED",
	"TRADE_MONEY_CHANGED",
	"TRADE_REQUEST",
	"TRADE_REQUEST_CANCEL",

	-- Bag events (for tracking item movement during trade)
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",

	-- Money events (for tracking money changes during trade)
	"PLAYER_MONEY",

	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(TRADE_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Trade state tracking
local tradeWindowOpen = false
local tradePartnerName = nil
local tradeStartTime = nil
local playerAccepted = false
local targetAccepted = false

-- Trade slot snapshots
local playerTradeSnapshot = {}  -- [slotId] = {itemLink, itemName, texture, quantity, quality}
local targetTradeSnapshot = {}  -- [slotId] = {itemLink, itemName, texture, quantity, quality}
local playerMoneySnapshot = 0
local targetMoneySnapshot = 0

-- Bag update batching to reduce spam during trade
local bagUpdateBatch = {
	active = false,
	startTime = nil,
	updates = {},  -- [bagId] = count
	timer = nil
}

-- UI state tracking
local tradeFrameVisible = false

-- Register all events
for _, event in ipairs(TRADE_EVENTS) do
	investigationFrame:RegisterEvent(event)
	print("|cff00ff00Registered:|r " .. event)
end

-- Helper function to get trade slot info (player side)
local function getPlayerTradeSlotInfo(slotIndex)
	if not slotIndex then return "nil" end

	local name, texture, quantity, quality, enchantment, canTrade = _GetTradePlayerItemInfo(slotIndex)
	if not name then
		return string.format("[P%d] EMPTY", slotIndex)
	end

	local itemLink = _GetTradePlayerItemLink(slotIndex)
	local itemName = itemLink and itemLink:match("%[(.-)%]") or name

	local qualityColor = ""
	if quality == 0 then qualityColor = "|cff9d9d9d" -- Poor (grey)
	elseif quality == 1 then qualityColor = "|cffffffff" -- Common (white)
	elseif quality == 2 then qualityColor = "|cff1eff00" -- Uncommon (green)
	elseif quality == 3 then qualityColor = "|cff0070dd" -- Rare (blue)
	elseif quality == 4 then qualityColor = "|cffa335ee" -- Epic (purple)
	elseif quality == 5 then qualityColor = "|cffff8000" -- Legendary (orange)
	else qualityColor = "|cffffffff" end

	local quantityStr = quantity and quantity > 1 and (" x" .. quantity) or ""
	local tradeableStr = canTrade and "" or " (NOT TRADEABLE)"
	local enchantStr = enchantment and (" +" .. enchantment) or ""

	return string.format("[P%d] %s%s|r%s%s%s", slotIndex, qualityColor, itemName, quantityStr, enchantStr, tradeableStr)
end

-- Helper function to get trade slot info (target side)
local function getTargetTradeSlotInfo(slotIndex)
	if not slotIndex then return "nil" end

	local name, texture, quantity, quality, enchantment, canTrade = _GetTradeTargetItemInfo(slotIndex)
	if not name then
		return string.format("[T%d] EMPTY", slotIndex)
	end

	local itemLink = _GetTradeTargetItemLink(slotIndex)
	local itemName = itemLink and itemLink:match("%[(.-)%]") or name

	local qualityColor = ""
	if quality == 0 then qualityColor = "|cff9d9d9d" -- Poor (grey)
	elseif quality == 1 then qualityColor = "|cffffffff" -- Common (white)
	elseif quality == 2 then qualityColor = "|cff1eff00" -- Uncommon (green)
	elseif quality == 3 then qualityColor = "|cff0070dd" -- Rare (blue)
	elseif quality == 4 then qualityColor = "|cffa335ee" -- Epic (purple)
	elseif quality == 5 then qualityColor = "|cffff8000" -- Legendary (orange)
	else qualityColor = "|cffffffff" end

	local quantityStr = quantity and quantity > 1 and (" x" .. quantity) or ""
	local tradeableStr = canTrade and "" or " (NOT TRADEABLE)"
	local enchantStr = enchantment and (" +" .. enchantment) or ""

	return string.format("[T%d] %s%s|r%s%s%s", slotIndex, qualityColor, itemName, quantityStr, enchantStr, tradeableStr)
end

-- Helper function to snapshot player trade slots
local function snapshotPlayerTradeSlots()
	local snapshot = {}
	for i = 1, 6 do  -- Trade window has 6 slots per player
		local name, texture, quantity, quality, enchantment, canTrade = _GetTradePlayerItemInfo(i)
		if name then
			local itemLink = _GetTradePlayerItemLink(i)
			snapshot[i] = {
				name = name,
				texture = texture,
				quantity = quantity,
				quality = quality,
				enchantment = enchantment,
				canTrade = canTrade,
				itemLink = itemLink
			}
		end
	end
	return snapshot
end

-- Helper function to snapshot target trade slots
local function snapshotTargetTradeSlots()
	local snapshot = {}
	for i = 1, 6 do  -- Trade window has 6 slots per player
		local name, texture, quantity, quality, enchantment, canTrade = _GetTradeTargetItemInfo(i)
		if name then
			local itemLink = _GetTradeTargetItemLink(i)
			snapshot[i] = {
				name = name,
				texture = texture,
				quantity = quantity,
				quality = quality,
				enchantment = enchantment,
				canTrade = canTrade,
				itemLink = itemLink
			}
		end
	end
	return snapshot
end

-- Helper function to format money amount
local function formatMoney(amount)
	if not amount or amount == 0 then return "0 copper" end
	
	local gold = math.floor(amount / 10000)
	local silver = math.floor((amount % 10000) / 100)
	local copper = amount % 100
	
	local parts = {}
	if gold > 0 then table.insert(parts, gold .. "g") end
	if silver > 0 then table.insert(parts, silver .. "s") end
	if copper > 0 then table.insert(parts, copper .. "c") end
	
	return table.concat(parts, " ")
end

-- Helper function to start bag update batching
local function startBagUpdateBatch()
	if not bagUpdateBatch.active then
		bagUpdateBatch.active = true
		bagUpdateBatch.startTime = _GetTime()
		bagUpdateBatch.updates = {}
		
		-- Schedule batch summary after 500ms of no new updates
		if bagUpdateBatch.timer then
			bagUpdateBatch.timer:Cancel()
		end
	end
end

-- Helper function to add bag update to batch
local function addBagUpdateToBatch(bagId)
	startBagUpdateBatch()
	bagUpdateBatch.updates[bagId] = (bagUpdateBatch.updates[bagId] or 0) + 1
	
	-- Reset timer - we'll summarize after 500ms of no new updates
	if bagUpdateBatch.timer then
		bagUpdateBatch.timer:Cancel()
	end
	
	bagUpdateBatch.timer = _C_Timer.After(0.5, function()
		-- Check if batch is still active (might have been reset already)
		if not bagUpdateBatch.active or not bagUpdateBatch.startTime then
			return  -- Batch was already processed, ignore this timer
		end
		
		-- Summarize the batch
		local currentTime = _GetTime()
		local batchDuration = currentTime - bagUpdateBatch.startTime
		local totalUpdates = 0
		local bagSummary = {}
		
		for bagId, count in pairs(bagUpdateBatch.updates) do
			totalUpdates = totalUpdates + count
			table.insert(bagSummary, "Bag " .. bagId .. " (" .. count .. "x)")
		end
		
		local timestamp = string.format("[%.2f]", currentTime)
		local deltaInfo = string.format("(%.0fms duration)", batchDuration * 1000)
		
		print("|cffff9900" .. timestamp .. " " .. deltaInfo .. " |cff00ffff[BAG UPDATE BATCH]|r")
		print("  |cffffaa00Total Updates:|r " .. totalUpdates .. " across " .. #bagSummary .. " bags")
		print("  |cffffaa00Bags:|r " .. table.concat(bagSummary, ", "))
		
		-- Reset batch
		bagUpdateBatch.active = false
		bagUpdateBatch.startTime = nil
		bagUpdateBatch.updates = {}
		bagUpdateBatch.timer = nil
		
		lastEventTime = currentTime
	end)
end

-- Event handler with detailed logging
investigationFrame:SetScript("OnEvent", function(self, event, ...)
	local arg1, arg2, arg3, arg4 = ...
	eventCounts[event] = (eventCounts[event] or 0) + 1

	local currentTime = _GetTime()
	local timeSinceLastEvent = currentTime - lastEventTime
	local timestamp = string.format("[%.2f]", currentTime)
	local countInfo = string.format("[#%d]", eventCounts[event])
	local deltaInfo = string.format("(+%.0fms)", timeSinceLastEvent * 1000)

	-- Skip printing BAG_UPDATE events - they're handled by batching system
	if event ~= "BAG_UPDATE" then
		print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")
	end

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "TRADE_SHOW" then
		tradeWindowOpen = true
		tradeStartTime = currentTime
		playerAccepted = false
		targetAccepted = false
		
		-- Get trade partner name
		if _UnitName("npc") then
			tradePartnerName = _UnitName("npc")
		elseif _UnitName("target") then
			tradePartnerName = _UnitName("target")
		else
			tradePartnerName = "Unknown Player"
		end
		
		print("  |cff00ff00Trade Window Opened|r")
		print("  |cffffaa00  Trade Partner:|r " .. tradePartnerName)

		-- Initial snapshots
		playerTradeSnapshot = snapshotPlayerTradeSlots()
		targetTradeSnapshot = snapshotTargetTradeSlots()
		playerMoneySnapshot = _GetPlayerTradeMoney() or 0
		targetMoneySnapshot = _GetTargetTradeMoney() or 0

		print("  |cffffaa00  Initial State:|r Both sides empty")
		print("  |cffffaa00  Player Money:|r " .. formatMoney(playerMoneySnapshot))
		print("  |cffffaa00  Target Money:|r " .. formatMoney(targetMoneySnapshot))

	elseif event == "TRADE_CLOSED" then
		tradeWindowOpen = false
		print("  |cff00ff00Trade Window Closed|r")

		if tradeStartTime then
			local tradeDuration = currentTime - tradeStartTime
			print("  |cffffaa00  Trade Duration:|r " .. string.format("%.2fs", tradeDuration))
		end

		-- Clear trade state
		tradePartnerName = nil
		tradeStartTime = nil
		playerAccepted = false
		targetAccepted = false
		playerTradeSnapshot = {}
		targetTradeSnapshot = {}
		playerMoneySnapshot = 0
		targetMoneySnapshot = 0

	elseif event == "TRADE_UPDATE" then
		print("  |cff00ff00Trade Window Updated|r")

		-- Show current trade contents
		local hasPlayerItems = false
		local hasTargetItems = false

		print("  |cffffaa00  Player Items:|r")
		for i = 1, 6 do
			local slotInfo = getPlayerTradeSlotInfo(i)
			if not slotInfo:match("EMPTY") then
				hasPlayerItems = true
				print("    |cffaaaaaa  " .. slotInfo .. "|r")
			end
		end
		if not hasPlayerItems then
			print("    |cffaaaaaa  (no items)|r")
		end

		print("  |cffffaa00  Target Items:|r")
		for i = 1, 6 do
			local slotInfo = getTargetTradeSlotInfo(i)
			if not slotInfo:match("EMPTY") then
				hasTargetItems = true
				print("    |cffaaaaaa  " .. slotInfo .. "|r")
			end
		end
		if not hasTargetItems then
			print("    |cffaaaaaa  (no items)|r")
		end

		-- Show money
		local playerMoney = _GetPlayerTradeMoney() or 0
		local targetMoney = _GetTargetTradeMoney() or 0
		print("  |cffffaa00  Player Money:|r " .. formatMoney(playerMoney))
		print("  |cffffaa00  Target Money:|r " .. formatMoney(targetMoney))

	elseif event == "TRADE_ACCEPT_UPDATE" then
		local playerAcceptState, targetAcceptState = arg1, arg2
		playerAccepted = playerAcceptState == 1
		targetAccepted = targetAcceptState == 1
		
		print("  |cffffaa00Trade Accept Status:|r")
		print("  |cffffaa00  Player Accepted:|r " .. (playerAccepted and "|cff00ff00YES|r" or "|cffff0000NO|r"))
		print("  |cffffaa00  Target Accepted:|r " .. (targetAccepted and "|cff00ff00YES|r" or "|cffff0000NO|r"))

		if playerAccepted and targetAccepted then
			print("  |cff00ff00  ✓ BOTH PLAYERS ACCEPTED - Trade will complete!|r")
		end

	elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
		local slotIndex = arg1
		print("  |cffffaa00Player Item Changed:|r slot " .. tostring(slotIndex))
		print("  |cffffaa00  New contents:|r " .. getPlayerTradeSlotInfo(slotIndex))

		-- Update snapshot
		playerTradeSnapshot = snapshotPlayerTradeSlots()

	elseif event == "TRADE_TARGET_ITEM_CHANGED" then
		local slotIndex = arg1
		print("  |cffffaa00Target Item Changed:|r slot " .. tostring(slotIndex))
		print("  |cffffaa00  New contents:|r " .. getTargetTradeSlotInfo(slotIndex))

		-- Update snapshot
		targetTradeSnapshot = snapshotTargetTradeSlots()

	elseif event == "TRADE_MONEY_CHANGED" then
		print("  |cffffaa00Trade Money Changed|r")
		
		local playerMoney = _GetPlayerTradeMoney() or 0
		local targetMoney = _GetTargetTradeMoney() or 0
		
		-- Show changes from previous amounts
		if playerMoney ~= playerMoneySnapshot then
			print("  |cffffaa00  Player Money:|r " .. formatMoney(playerMoneySnapshot) .. " → " .. formatMoney(playerMoney))
			playerMoneySnapshot = playerMoney
		end
		
		if targetMoney ~= targetMoneySnapshot then
			print("  |cffffaa00  Target Money:|r " .. formatMoney(targetMoneySnapshot) .. " → " .. formatMoney(targetMoney))
			targetMoneySnapshot = targetMoney
		end

	elseif event == "TRADE_REQUEST" then
		local playerName = arg1
		print("  |cffffaa00Trade Request:|r from " .. tostring(playerName))

	elseif event == "TRADE_REQUEST_CANCEL" then
		print("  |cffffaa00Trade Request Cancelled|r")

	elseif event == "BAG_UPDATE" then
		local bagId = arg1
		
		-- Only process if we're in trade context
		if not tradeWindowOpen then
			return  -- Don't process bag updates outside trade context
		end
		
		-- Add to batch instead of logging immediately
		addBagUpdateToBatch(bagId)

	elseif event == "BAG_UPDATE_DELAYED" then
		-- Only log if we're in trade context
		if tradeWindowOpen then
			print("  |cff00ff00All bag updates completed during trade|r")
		end

	elseif event == "PLAYER_MONEY" then
		-- Only log if we're in trade context
		if tradeWindowOpen then
			print("  |cff00ff00Player Money Changed|r (during trade)")
		end

	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Monitor TradeFrame visibility
local function checkTradeFrameState()
	if TradeFrame and TradeFrame:IsShown() then
		if not tradeFrameVisible then
			tradeFrameVisible = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r TradeFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if tradeFrameVisible then
			tradeFrameVisible = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r TradeFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Add OnUpdate for continuous UI monitoring
investigationFrame:SetScript("OnUpdate", function()
	checkTradeFrameState()
end)

-- Hook trade-related functions
if AcceptTrade then
	hooksecurefunc("AcceptTrade", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Trade Hook]|r AcceptTrade")
		lastEventTime = currentTime
	end)
end

if CancelTrade then
	hooksecurefunc("CancelTrade", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Trade Hook]|r CancelTrade")
		lastEventTime = currentTime
	end)
end

if ClickTradeButton then
	hooksecurefunc("ClickTradeButton", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Trade Hook]|r ClickTradeButton")
		print("  |cffffaa00Slot:|r " .. getPlayerTradeSlotInfo(index))
		lastEventTime = currentTime
	end)
end

if SetTradeMoney then
	hooksecurefunc("SetTradeMoney", function(amount)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Trade Hook]|r SetTradeMoney")
		print("  |cffffaa00Amount:|r " .. formatMoney(amount))
		lastEventTime = currentTime
	end)
end

if InitiateTrade then
	hooksecurefunc("InitiateTrade", function(unitId)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Trade Hook]|r InitiateTrade")
		print("  |cffffaa00Target:|r " .. tostring(unitId))
		if _UnitName(unitId) then
			print("  |cffffaa00Target Name:|r " .. _UnitName(unitId))
		end
		lastEventTime = currentTime
	end)
end

-- Slash command to show current trade state
SLASH_TRADESTATE1 = "/tradestate"
SlashCmdList["TRADESTATE"] = function()
	print("|cff00ff00=== CURRENT TRADE STATE ===|r")
	
	print("|cffffaa00Trade Window Open:|r " .. tostring(tradeWindowOpen))
	
	if tradePartnerName then
		print("|cffffaa00Trade Partner:|r " .. tradePartnerName)
	else
		print("|cffffaa00Trade Partner:|r none")
	end
	
	if tradeWindowOpen then
		print("|cffffaa00Player Accepted:|r " .. tostring(playerAccepted))
		print("|cffffaa00Target Accepted:|r " .. tostring(targetAccepted))
		
		-- Show current trade contents
		print("|cffffaa00Player Items:|r")
		local hasPlayerItems = false
		for i = 1, 6 do
			local slotInfo = getPlayerTradeSlotInfo(i)
			if not slotInfo:match("EMPTY") then
				hasPlayerItems = true
				print("  |cffaaaaaa" .. slotInfo .. "|r")
			end
		end
		if not hasPlayerItems then
			print("  |cffaaaaaa(no items)|r")
		end
		
		print("|cffffaa00Target Items:|r")
		local hasTargetItems = false
		for i = 1, 6 do
			local slotInfo = getTargetTradeSlotInfo(i)
			if not slotInfo:match("EMPTY") then
				hasTargetItems = true
				print("  |cffaaaaaa" .. slotInfo .. "|r")
			end
		end
		if not hasTargetItems then
			print("  |cffaaaaaa(no items)|r")
		end
		
		-- Show money
		local playerMoney = _GetPlayerTradeMoney() or 0
		local targetMoney = _GetTargetTradeMoney() or 0
		print("|cffffaa00Player Money:|r " .. formatMoney(playerMoney))
		print("|cffffaa00Target Money:|r " .. formatMoney(targetMoney))
	end
	
	print("|cff00ff00=== END TRADE STATE ===|r")
end

-- Test functions for trade hooks
local function testTradeHooks()
	print("|cff00ff00=== TESTING TRADE HOOKS ===|r")
	
	-- Test InitiateTrade hook (if we have a target)
	if UnitExists("target") and UnitIsPlayer("target") then
		print("|cffffaa00Testing InitiateTrade hook...|r")
		if InitiateTrade then
			InitiateTrade("target")
		else
			print("|cffff0000InitiateTrade function not available|r")
		end
	else
		print("|cffff6600Cannot test InitiateTrade - no player target|r")
	end
	
	-- Test SetTradeMoney hook (if trade window is open)
	if TradeFrame and TradeFrame:IsShown() then
		print("|cffffaa00Testing SetTradeMoney hook...|r")
		if SetTradeMoney then
			SetTradeMoney(100) -- Set 1 silver
		else
			print("|cffff0000SetTradeMoney function not available|r")
		end
		
		-- Test AcceptTrade hook
		print("|cffffaa00Testing AcceptTrade hook...|r")
		if AcceptTrade then
			AcceptTrade()
		else
			print("|cffff0000AcceptTrade function not available|r")
		end
		
		-- Test CancelTrade hook
		print("|cffffaa00Testing CancelTrade hook...|r")
		if CancelTrade then
			CancelTrade()
		else
			print("|cffff0000CancelTrade function not available|r")
		end
	else
		print("|cffff6600Cannot test trade window hooks - trade window not open|r")
		print("|cffff6600Open a trade window first, then run /testtradehooks|r")
	end
	
	print("|cff00ff00=== TRADE HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test trade hooks
SLASH_TESTTRADEHOOKS1 = "/testtradehooks"
SlashCmdList["TESTTRADEHOOKS"] = testTradeHooks

print("|cff00ff00Trade investigation ready - events will print to chat|r")
print("|cff00ff00Right-click other players and select 'Trade' to test events|r")
print("|cff00ff00Use /tradestate to see current trade state|r")
print("|cff00ff00Use /testtradehooks to test trade function hooks|r")