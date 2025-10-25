-- WoW API calls (Classic Era 1.15 compatible)
local _CreateFrame = CreateFrame
local _GetTime = GetTime
local _GetNumTradeSkills = GetNumTradeSkills
local _GetTradeSkillInfo = GetTradeSkillInfo
local _GetTradeSkillLine = GetTradeSkillLine
local _GetTradeSkillRecipeLink = GetTradeSkillRecipeLink
local _GetTradeSkillCooldown = GetTradeSkillCooldown
local _GetTradeSkillReagentInfo = GetTradeSkillReagentInfo
local _GetTradeSkillReagentItemLink = GetTradeSkillReagentItemLink
local _GetNumCrafts = GetNumCrafts
local _GetCraftInfo = GetCraftInfo
local _GetCraftName = GetCraftName
local _GetCraftReagentInfo = GetCraftReagentInfo
local _GetCraftReagentItemLink = GetCraftReagentItemLink
local _GetCraftCooldown = GetCraftCooldown
local _UnitCastingInfo = UnitCastingInfo
local _UnitChannelInfo = UnitChannelInfo

-- Classic Era uses different container API
local _GetContainerNumSlots = GetContainerNumSlots
local _GetContainerItemInfo = GetContainerItemInfo
local _GetContainerItemLink = GetContainerItemLink

print("=== PROFESSION EVENT INVESTIGATION LOADED ===")
print("This module will log ALL profession-related events")
print("Watch your chat for detailed event information")
print("==============================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All possible profession-related events for Classic Era (1.15)
local PROFESSION_EVENTS = {
	-- Trade skill events (Alchemy, Blacksmithing, Cooking, Engineering, First Aid, Fishing, Leatherworking, Mining, Skinning, Tailoring)
	"TRADE_SKILL_SHOW",
	"TRADE_SKILL_CLOSE",
	"TRADE_SKILL_UPDATE",
	"UPDATE_TRADESKILL_RECAST",

	-- Craft events (Enchanting and similar)
	"CRAFT_SHOW",
	"CRAFT_CLOSE",
	"CRAFT_UPDATE",

	-- Enchanting-specific events (Classic Era confirmed)
	"BIND_ENCHANT",
	"REPLACE_ENCHANT",
	"TRADE_REPLACE_ENCHANT",

	-- Profession trainer events
	"TRAINER_SHOW",
	"TRAINER_CLOSED", 
	"TRAINER_UPDATE",

	-- Profession skill updates and messages
	"CHAT_MSG_SKILL",

	-- Spell casting events (for tracking actual crafting)
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_CHANNEL_UPDATE",

	-- Skill line updates
	"SKILL_LINES_CHANGED",
	"UPDATE_PENDING_MAIL",

	-- Bag events (for tracking reagent consumption)
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",

	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(PROFESSION_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Profession state tracking
local currentTradeSkill = {
	name = nil,
	rank = nil,
	maxRank = nil,
	numSkills = 0,
	selectedIndex = nil,
}

local currentCraft = {
	name = nil,
	rank = nil,
	maxRank = nil,
	numCrafts = 0,
	selectedIndex = nil,
}

-- Track recent crafting attempts
local activeCraftingSpell = nil  -- { spellName = "X", timestamp = time, completed = false }

-- Track reagent snapshots before/after crafting
local reagentSnapshot = {}  -- [itemId] = count

-- UI state tracking
local tradeSkillFrameOpen = false
local craftFrameOpen = false
local trainerFrameOpen = false

-- Trainer state tracking
local currentTrainer = {
	name = nil,
	numServices = 0,
	selectedIndex = nil,
}

-- Helper function to get tradeskill info
local function getTradeSkillInfo(index)
	if not index then return "nil" end

	local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps = _GetTradeSkillInfo(index)

	if not skillName then
		return "invalid index"
	end

	-- Handle headers
	if skillType == "header" then
		local expandedStr = isExpanded and "expanded" or "collapsed"
		return string.format("HEADER: %s (%s)", skillName, expandedStr)
	end

	-- Get difficulty color
	local difficultyColor = "grey"
	if skillType == "trivial" then
		difficultyColor = "|cff808080grey|r"
	elseif skillType == "easy" then
		difficultyColor = "|cff40bf40green|r"
	elseif skillType == "medium" then
		difficultyColor = "|cffffff00yellow|r"
	elseif skillType == "optimal" then
		difficultyColor = "|cffff8040orange|r"
	elseif skillType == "difficult" then
		difficultyColor = "|cffff4040red|r"
	end

	-- Get recipe link
	local recipeLink = _GetTradeSkillRecipeLink(index)
	local recipeName = recipeLink and recipeLink:match("%[(.-)%]") or skillName

	-- Get cooldown
	local cooldown = _GetTradeSkillCooldown(index)
	local cooldownStr = ""
	if cooldown then
		cooldownStr = string.format(", CD: %.0fs", cooldown)
	end

	return string.format("[%d] %s (%s, x%d%s)", index, recipeName, difficultyColor, numAvailable, cooldownStr)
end

-- Helper function to get craft info
local function getCraftInfo(index)
	if not index then return "nil" end

	local craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = _GetCraftInfo(index)

	if not craftName then
		return "invalid index"
	end

	-- Handle headers
	if craftType == "header" then
		local expandedStr = isExpanded and "expanded" or "collapsed"
		return string.format("HEADER: %s (%s)", craftName, expandedStr)
	end

	-- Get difficulty color
	local difficultyColor = "grey"
	if craftType == "trivial" then
		difficultyColor = "|cff808080grey|r"
	elseif craftType == "easy" then
		difficultyColor = "|cff40bf40green|r"
	elseif craftType == "medium" then
		difficultyColor = "|cffffff00yellow|r"
	elseif craftType == "optimal" then
		difficultyColor = "|cffff8040orange|r"
	elseif craftType == "difficult" then
		difficultyColor = "|cffff4040red|r"
	end

	-- Get cooldown
	local cooldown = _GetCraftCooldown(index)
	local cooldownStr = ""
	if cooldown then
		cooldownStr = string.format(", CD: %.0fs", cooldown)
	end

	return string.format("[%d] %s (%s, x%d%s)", index, craftName, difficultyColor, numAvailable, cooldownStr)
end

-- Helper function to get reagent info for tradeskill
local function getTradeSkillReagents(index)
	local reagents = {}
	local i = 1

	while true do
		local reagentName, reagentTexture, reagentCount, playerReagentCount = _GetTradeSkillReagentInfo(index, i)
		if not reagentName then break end

		local reagentLink = _GetTradeSkillReagentItemLink(index, i)
		local hasEnough = playerReagentCount >= reagentCount
		local colorCode = hasEnough and "|cff00ff00" or "|cffff0000"

		table.insert(reagents, {
			name = reagentName,
			link = reagentLink,
			required = reagentCount,
			available = playerReagentCount,
			hasEnough = hasEnough,
			displayStr = string.format("%s%s: %d/%d|r", colorCode, reagentName, playerReagentCount, reagentCount)
		})

		i = i + 1
	end

	return reagents
end

-- Helper function to get reagent info for craft
local function getCraftReagents(index)
	local reagents = {}
	local i = 1

	while true do
		local reagentName, reagentTexture, reagentCount, playerReagentCount = _GetCraftReagentInfo(index, i)
		if not reagentName then break end

		local reagentLink = _GetCraftReagentItemLink(index, i)
		local hasEnough = playerReagentCount >= reagentCount
		local colorCode = hasEnough and "|cff00ff00" or "|cffff0000"

		table.insert(reagents, {
			name = reagentName,
			link = reagentLink,
			required = reagentCount,
			available = playerReagentCount,
			hasEnough = hasEnough,
			displayStr = string.format("%s%s: %d/%d|r", colorCode, reagentName, playerReagentCount, reagentCount)
		})

		i = i + 1
	end

	return reagents
end

-- Helper function to snapshot reagent counts (Classic Era compatible)
local function snapshotReagents()
	local snapshot = {}
	local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4

	-- Scan all bags using Classic Era API
	for bagId = 0, NUM_BAG_SLOTS do
		local numSlots = _GetContainerNumSlots(bagId)
		if numSlots and numSlots > 0 then
			for slotId = 1, numSlots do
				local itemLink = _GetContainerItemLink(bagId, slotId)
				if itemLink then
					local _, stackCount = _GetContainerItemInfo(bagId, slotId)
					local itemId = tonumber(itemLink:match("item:(%d+)"))
					if itemId and stackCount then
						snapshot[itemId] = (snapshot[itemId] or 0) + stackCount
					end
				end
			end
		end
	end

	return snapshot
end

-- Helper function to compare reagent snapshots
local function compareReagentSnapshots(oldSnapshot, newSnapshot)
	if not oldSnapshot or not newSnapshot then return nil end

	local changes = {}

	-- Check for removed/decreased items
	for itemId, oldCount in pairs(oldSnapshot) do
		local newCount = newSnapshot[itemId] or 0
		if newCount < oldCount then
			table.insert(changes, {
				itemId = itemId,
				oldCount = oldCount,
				newCount = newCount,
				change = newCount - oldCount
			})
		end
	end

	-- Check for added/increased items (crafting produces items)
	for itemId, newCount in pairs(newSnapshot) do
		local oldCount = oldSnapshot[itemId] or 0
		if newCount > oldCount then
			table.insert(changes, {
				itemId = itemId,
				oldCount = oldCount,
				newCount = newCount,
				change = newCount - oldCount
			})
		end
	end

	return changes
end

-- Register all events with error handling
local registeredEvents = {}
for _, event in ipairs(PROFESSION_EVENTS) do
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

	-- Filter out non-player spellcast events
	if event:match("^UNIT_SPELLCAST_") then
		if arg1 ~= "player" then
			return  -- Don't log non-player spellcasts
		end
	end

	-- Filter out BAG_UPDATE events unless we're tracking crafting
	if event == "BAG_UPDATE" then
		if not activeCraftingSpell then
			return  -- Don't log bag updates outside crafting context
		end
		-- Allow BAG_UPDATE for 5 seconds after crafting completes (to catch reagent/item changes)
		if activeCraftingSpell.completed then
			local timeSinceCompletion = currentTime - activeCraftingSpell.completedTime
			if timeSinceCompletion > 5.0 then
				return  -- Too long after craft, ignore
			end
		end
	end

	-- BAG_UPDATE_DELAYED always shows when tracking crafting (signals completion)
	if event == "BAG_UPDATE_DELAYED" then
		if not activeCraftingSpell then
			return  -- Don't log outside crafting context
		end
	end

	print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "TRADE_SKILL_SHOW" then
		local skillName, currentLevel, maxLevel = _GetTradeSkillLine()
		print("  |cffffaa00Trade Skill Opened:|r " .. (skillName or "Unknown"))
		print("  |cffffaa00  Skill Level:|r " .. (currentLevel or 0) .. "/" .. (maxLevel or 0))

		-- Update state
		currentTradeSkill.name = skillName
		currentTradeSkill.rank = currentLevel
		currentTradeSkill.maxRank = maxLevel
		currentTradeSkill.numSkills = _GetNumTradeSkills()

		print("  |cffffaa00  Available Recipes:|r " .. currentTradeSkill.numSkills)

		-- Show first 5 recipes as a sample
		if currentTradeSkill.numSkills > 0 then
			print("  |cffaaaaaa  Sample recipes:|r")
			for i = 1, math.min(5, currentTradeSkill.numSkills) do
				local info = getTradeSkillInfo(i)
				if not info:match("HEADER") then
					print("    |cffaaaaaa  " .. info .. "|r")
				end
			end
			if currentTradeSkill.numSkills > 5 then
				print("    |cffaaaaaa  ... and " .. (currentTradeSkill.numSkills - 5) .. " more|r")
			end
		end

	elseif event == "TRADE_SKILL_CLOSE" then
		print("  |cffffaa00Trade Skill Closed:|r " .. (currentTradeSkill.name or "Unknown"))

		-- Clear state
		currentTradeSkill.name = nil
		currentTradeSkill.rank = nil
		currentTradeSkill.maxRank = nil
		currentTradeSkill.numSkills = 0
		currentTradeSkill.selectedIndex = nil

	elseif event == "TRADE_SKILL_UPDATE" then
		local skillName, currentLevel, maxLevel = _GetTradeSkillLine()
		print("  |cffffaa00Trade Skill Updated:|r " .. (skillName or "Unknown"))

		-- Check if skill level changed
		if currentTradeSkill.rank and currentLevel and currentLevel > currentTradeSkill.rank then
			print("  |cff00ff00  SKILL UP!|r " .. currentTradeSkill.rank .. " → " .. currentLevel)
		end

		-- Update state
		currentTradeSkill.name = skillName
		currentTradeSkill.rank = currentLevel
		currentTradeSkill.maxRank = maxLevel
		local oldNumSkills = currentTradeSkill.numSkills
		currentTradeSkill.numSkills = _GetNumTradeSkills()

		-- Check if recipe list changed
		if oldNumSkills ~= currentTradeSkill.numSkills then
			print("  |cffffaa00  Recipe count changed:|r " .. oldNumSkills .. " → " .. currentTradeSkill.numSkills)
		end

	elseif event == "UPDATE_TRADESKILL_RECAST" then
		print("  |cffffaa00Trade Skill Recast Update:|r Cooldown information updated")

	elseif event == "CRAFT_SHOW" then
		local craftName, currentLevel, maxLevel = _GetCraftName()
		print("  |cffffaa00Craft Window Opened:|r " .. (craftName or "Unknown"))
		print("  |cffffaa00  Craft Level:|r " .. (currentLevel or 0) .. "/" .. (maxLevel or 0))

		-- Update state
		currentCraft.name = craftName
		currentCraft.rank = currentLevel
		currentCraft.maxRank = maxLevel
		currentCraft.numCrafts = _GetNumCrafts()

		print("  |cffffaa00  Available Crafts:|r " .. currentCraft.numCrafts)

		-- Show all crafts (Enchanting typically has fewer than other professions)
		if currentCraft.numCrafts > 0 then
			print("  |cffaaaaaa  Available crafts:|r")
			for i = 1, currentCraft.numCrafts do
				local info = getCraftInfo(i)
				if not info:match("HEADER") then
					print("    |cffaaaaaa  " .. info .. "|r")
				end
			end
		end

	elseif event == "CRAFT_CLOSE" then
		print("  |cffffaa00Craft Window Closed:|r " .. (currentCraft.name or "Unknown"))

		-- Clear state
		currentCraft.name = nil
		currentCraft.rank = nil
		currentCraft.maxRank = nil
		currentCraft.numCrafts = 0
		currentCraft.selectedIndex = nil

	elseif event == "CRAFT_UPDATE" then
		local craftName, currentLevel, maxLevel = _GetCraftName()
		print("  |cffffaa00Craft Updated:|r " .. (craftName or "Unknown"))

		-- Check if craft level changed
		if currentCraft.rank and currentLevel and currentLevel > currentCraft.rank then
			print("  |cff00ff00  SKILL UP!|r " .. currentCraft.rank .. " → " .. currentLevel)
		end

		-- Update state
		currentCraft.name = craftName
		currentCraft.rank = currentLevel
		currentCraft.maxRank = maxLevel
		local oldNumCrafts = currentCraft.numCrafts
		currentCraft.numCrafts = _GetNumCrafts()

		-- Check if craft list changed
		if oldNumCrafts ~= currentCraft.numCrafts then
			print("  |cffffaa00  Craft count changed:|r " .. oldNumCrafts .. " → " .. currentCraft.numCrafts)
		end

	elseif event == "BIND_ENCHANT" then
		print("  |cffffaa00Bind Enchant:|r Enchanting an unbound item")
		print("  |cffff6600  ⚠ This will bind the item!|r")

	elseif event == "REPLACE_ENCHANT" then
		print("  |cffffaa00Replace Enchant:|r Replacing existing enchantment")
		print("  |cffff6600  ⚠ Previous enchantment will be lost!|r")

	elseif event == "TRADE_REPLACE_ENCHANT" then
		print("  |cffffaa00Trade Replace Enchant:|r Enchanting item in trade window")

	elseif event == "UNIT_SPELLCAST_START" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3
		local spellName, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible = _UnitCastingInfo(unitTarget)

		if spellName then
			print("  |cff00ff00Spell Cast Started:|r " .. spellName)
			print("  |cffffaa00  Is Trade Skill:|r " .. tostring(isTradeSkill))
			print("  |cffffaa00  Cast Time:|r " .. string.format("%.1fs", (endTime - startTime) / 1000))

			-- Track this crafting attempt
			if isTradeSkill then
				activeCraftingSpell = {
					spellName = spellName,
					timestamp = currentTime,
					completed = false,
					startTime = startTime,
					endTime = endTime
				}

				-- Snapshot reagents before crafting
				reagentSnapshot = snapshotReagents()
				print("  |cffaaaaaa  Snapshotted reagents before crafting|r")
			end
		end

	elseif event == "UNIT_SPELLCAST_STOP" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3

		print("  |cff00ff00Spell Cast Completed:|r")

		-- Check if this was a tracked crafting spell
		if activeCraftingSpell and not activeCraftingSpell.completed then
			local craftDuration = currentTime - activeCraftingSpell.timestamp
			print("  |cff00ff00  ✓ Crafting completed:|r " .. activeCraftingSpell.spellName)
			print("  |cff00ff00    Duration:|r " .. string.format("%.2fs", craftDuration))

			activeCraftingSpell.completed = true
			activeCraftingSpell.completedTime = currentTime
		end

	elseif event == "UNIT_SPELLCAST_FAILED" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3

		print("  |cffff0000Spell Cast Failed:|r")

		if activeCraftingSpell and not activeCraftingSpell.completed then
			print("  |cffff0000  ✗ Crafting failed:|r " .. activeCraftingSpell.spellName)
			activeCraftingSpell.completed = true
			activeCraftingSpell.completedTime = currentTime
		end

	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3

		print("  |cffff0000Spell Cast Interrupted:|r")

		if activeCraftingSpell and not activeCraftingSpell.completed then
			print("  |cffff0000  ✗ Crafting interrupted:|r " .. activeCraftingSpell.spellName)
			activeCraftingSpell.completed = true
			activeCraftingSpell.completedTime = currentTime
		end

	elseif event == "UNIT_SPELLCAST_DELAYED" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3

		print("  |cffff6600Spell Cast Delayed:|r")

	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3
		local spellName, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible, spellID = _UnitChannelInfo(unitTarget)

		if spellName then
			print("  |cff00ff00Channeling Started:|r " .. spellName)
			print("  |cffffaa00  Duration:|r " .. string.format("%.1fs", (endTime - startTime) / 1000))
		end

	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3

		print("  |cff00ff00Channeling Stopped:|r")

	elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		local unitTarget, castGUID, spellID = arg1, arg2, arg3

		print("  |cffffaa00Channeling Updated:|r")

	elseif event == "SKILL_LINES_CHANGED" then
		print("  |cffffaa00Skill Lines Changed:|r Profession skills updated")

	elseif event == "UPDATE_PENDING_MAIL" then
		print("  |cffffaa00Pending Mail:|r Mail notification (may be profession-related)")

	elseif event == "BAG_UPDATE" then
		local bagId = arg1

		-- Show details during casting OR after completion (within time window)
		if activeCraftingSpell then
			local statusStr = activeCraftingSpell.completed and "(after crafting)" or "(during crafting)"
			print("  |cffffaa00Bag Updated " .. statusStr .. ":|r Bag " .. tostring(bagId))

			-- Compare with reagent snapshot
			local newSnapshot = snapshotReagents()
			local changes = compareReagentSnapshots(reagentSnapshot, newSnapshot)

			if changes and #changes > 0 then
				print("  |cffffaa00  Item changes detected:|r")
				for _, change in ipairs(changes) do
					local changeStr = ""
					if change.change > 0 then
						changeStr = "|cff00ff00+" .. change.change .. "|r (created/gained)"
					else
						changeStr = "|cffff0000" .. change.change .. "|r (consumed)"
					end
					print("    |cffaaaaaa  ItemID " .. change.itemId .. ":|r " .. change.oldCount .. " → " .. change.newCount .. " (" .. changeStr .. ")")
				end
			end
		end

	elseif event == "BAG_UPDATE_DELAYED" then
		-- Only log if we're tracking crafting
		if activeCraftingSpell and activeCraftingSpell.completed then
			print("  |cffffaa00All bag updates completed (after crafting)|r")

			-- Final reagent comparison
			local newSnapshot = snapshotReagents()
			local changes = compareReagentSnapshots(reagentSnapshot, newSnapshot)

			if changes and #changes > 0 then
				print("  |cff00ff00  Final item changes:|r")
				for _, change in ipairs(changes) do
					local changeStr = ""
					if change.change > 0 then
						changeStr = "|cff00ff00+" .. change.change .. "|r (created/gained)"
					else
						changeStr = "|cffff0000" .. change.change .. "|r (consumed)"
					end
					print("    |cffaaaaaa  ItemID " .. change.itemId .. ":|r " .. change.oldCount .. " → " .. change.newCount .. " (" .. changeStr .. ")")
				end
			end

			-- Clear crafting tracking
			activeCraftingSpell = nil
		end

	elseif event == "TRAINER_SHOW" then
		print("  |cffffaa00Trainer Window Opened|r")
		
		-- Get trainer info if available (Classic Era compatible)
		if GetNumTrainerServices then
			local success, numServices = pcall(GetNumTrainerServices)
			if success and numServices then
				currentTrainer.numServices = numServices
				print("  |cffffaa00  Available Services:|r " .. currentTrainer.numServices)
				
				-- Show first few services as sample
				if currentTrainer.numServices > 0 then
					print("  |cffaaaaaa  Sample services:|r")
					for i = 1, math.min(5, currentTrainer.numServices) do
						if GetTrainerServiceInfo then
							local success2, serviceName, serviceSubText, serviceType, isExpanded = pcall(GetTrainerServiceInfo, i)
							if success2 and serviceName then
								local typeStr = serviceType or "unknown"
								print("    |cffaaaaaa  [" .. i .. "] " .. serviceName .. " (" .. typeStr .. ")|r")
							end
						end
					end
					if currentTrainer.numServices > 5 then
						print("    |cffaaaaaa  ... and " .. (currentTrainer.numServices - 5) .. " more|r")
					end
				end
			end
		end

	elseif event == "TRAINER_CLOSED" then
		print("  |cffffaa00Trainer Window Closed|r")
		
		-- Clear trainer state
		currentTrainer.name = nil
		currentTrainer.numServices = 0
		currentTrainer.selectedIndex = nil

	elseif event == "TRAINER_UPDATE" then
		print("  |cffffaa00Trainer Updated|r")
		
		if GetNumTrainerServices then
			local success, numServices = pcall(GetNumTrainerServices)
			if success and numServices then
				local oldNumServices = currentTrainer.numServices
				currentTrainer.numServices = numServices
				
				if oldNumServices ~= currentTrainer.numServices then
					print("  |cffffaa00  Service count changed:|r " .. oldNumServices .. " → " .. currentTrainer.numServices)
				end
			end
		end

	elseif event == "CHAT_MSG_SKILL" then
		local message = arg1
		print("  |cff00ff00Skill Message:|r " .. tostring(message))



	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		print("  |cffffaa00Initial Login:|r " .. tostring(isInitialLogin))
		print("  |cffffaa00Reloading UI:|r " .. tostring(isReloadingUi))

	else
		-- Generic logging for any other events
		print("  |cffffaa00Args:|r " .. tostring(arg1) .. ", " .. tostring(arg2) .. ", " .. tostring(arg3) .. ", " .. tostring(arg4))
	end
end)

-- Monitor TradeSkillFrame visibility
local function checkTradeSkillFrameState()
	if TradeSkillFrame and TradeSkillFrame:IsShown() then
		if not tradeSkillFrameOpen then
			tradeSkillFrameOpen = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r TradeSkillFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if tradeSkillFrameOpen then
			tradeSkillFrameOpen = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r TradeSkillFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Monitor CraftFrame visibility
local function checkCraftFrameState()
	if CraftFrame and CraftFrame:IsShown() then
		if not craftFrameOpen then
			craftFrameOpen = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r CraftFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if craftFrameOpen then
			craftFrameOpen = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r CraftFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Monitor ClassTrainerFrame visibility
local function checkTrainerFrameState()
	if ClassTrainerFrame and ClassTrainerFrame:IsShown() then
		if not trainerFrameOpen then
			trainerFrameOpen = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r ClassTrainerFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
	else
		if trainerFrameOpen then
			trainerFrameOpen = false
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r ClassTrainerFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Add OnUpdate for continuous UI monitoring
investigationFrame:SetScript("OnUpdate", function()
	checkTradeSkillFrameState()
	checkCraftFrameState()
	checkTrainerFrameState()
end)

-- Hook profession-related functions
if CastTradeSkill then
	hooksecurefunc("CastTradeSkill", function(index, repeat_count)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r CastTradeSkill")
		print("  |cffffaa00Recipe:|r " .. getTradeSkillInfo(index))
		print("  |cffffaa00Repeat Count:|r " .. tostring(repeat_count or 1))

		-- Show reagent requirements
		local reagents = getTradeSkillReagents(index)
		if #reagents > 0 then
			print("  |cffffaa00  Reagents:|r")
			for _, reagent in ipairs(reagents) do
				print("    |cffaaaaaa  " .. reagent.displayStr .. "|r")
			end
		end

		lastEventTime = currentTime
	end)
end

if DoCraft then
	hooksecurefunc("DoCraft", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r DoCraft")
		print("  |cffffaa00Craft:|r " .. getCraftInfo(index))

		-- Show reagent requirements
		local reagents = getCraftReagents(index)
		if #reagents > 0 then
			print("  |cffffaa00  Reagents:|r")
			for _, reagent in ipairs(reagents) do
				print("    |cffaaaaaa  " .. reagent.displayStr .. "|r")
			end
		end

		lastEventTime = currentTime
	end)
end

if CloseTradeSkill then
	hooksecurefunc("CloseTradeSkill", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r CloseTradeSkill")
		lastEventTime = currentTime
	end)
end

if CloseCraft then
	hooksecurefunc("CloseCraft", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r CloseCraft")
		lastEventTime = currentTime
	end)
end

if ExpandTradeSkillSubClass then
	hooksecurefunc("ExpandTradeSkillSubClass", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r ExpandTradeSkillSubClass → index: " .. tostring(index))
		lastEventTime = currentTime
	end)
end

if CollapseTradeSkillSubClass then
	hooksecurefunc("CollapseTradeSkillSubClass", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r CollapseTradeSkillSubClass → index: " .. tostring(index))
		lastEventTime = currentTime
	end)
end

if ExpandCraftSubClass then
	hooksecurefunc("ExpandCraftSubClass", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r ExpandCraftSubClass → index: " .. tostring(index))
		lastEventTime = currentTime
	end)
end

if CollapseCraftSubClass then
	hooksecurefunc("CollapseCraftSubClass", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Profession Hook]|r CollapseCraftSubClass → index: " .. tostring(index))
		lastEventTime = currentTime
	end)
end

if SelectTradeSkill then
	hooksecurefunc("SelectTradeSkill", function(index)
		-- Don't log this - fires constantly on mouse-over
		currentTradeSkill.selectedIndex = index
	end)
end

if SelectCraft then
	hooksecurefunc("SelectCraft", function(index)
		-- Don't log this - fires constantly on mouse-over
		currentCraft.selectedIndex = index
	end)
end

-- Profession trainer function hooks (Classic Era compatible)
if BuyTrainerService then
	local success = pcall(hooksecurefunc, "BuyTrainerService", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Trainer Hook]|r BuyTrainerService")
		
		if GetTrainerServiceInfo then
			local success2, serviceName, serviceSubText, serviceType, isExpanded = pcall(GetTrainerServiceInfo, index)
			if success2 and serviceName then
				print("  |cffffaa00Service:|r " .. serviceName .. " (type: " .. tostring(serviceType) .. ")")
			end
		end
		
		if GetTrainerServiceCost then
			local success3, cost = pcall(GetTrainerServiceCost, index)
			if success3 and cost and cost > 0 then
				print("  |cffffaa00Cost:|r " .. cost .. " copper")
			end
		end
		
		lastEventTime = currentTime
	end)
	if not success then
		print("|cffff6600Warning: Could not hook BuyTrainerService (not available in Classic Era)|r")
	end
end

if CloseTrainer then
	local success = pcall(hooksecurefunc, "CloseTrainer", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Trainer Hook]|r CloseTrainer")
		lastEventTime = currentTime
	end)
	if not success then
		print("|cffff6600Warning: Could not hook CloseTrainer (not available in Classic Era)|r")
	end
end

-- Only hook functions that exist in Classic Era
if SelectTradeSkill then
	pcall(hooksecurefunc, "SelectTradeSkill", function(index)
		-- Don't log this - fires constantly on mouse-over
		currentTradeSkill.selectedIndex = index
	end)
end

if SelectCraft then
	pcall(hooksecurefunc, "SelectCraft", function(index)
		-- Don't log this - fires constantly on mouse-over
		currentCraft.selectedIndex = index
	end)
end

-- Test functions for profession hooks
local function testProfessionHooks()
	print("|cff00ff00=== TESTING PROFESSION HOOKS ===|r")
	
	-- Test TradeSkill hooks (if TradeSkill window is open)
	if TradeSkillFrame and TradeSkillFrame:IsShown() then
		print("|cffffaa00Testing TradeSkill hooks...|r")
		
		-- Test ExpandTradeSkillSubClass hook
		print("|cffffaa00Testing ExpandTradeSkillSubClass hook...|r")
		if ExpandTradeSkillSubClass then
			ExpandTradeSkillSubClass(1)
		else
			print("|cffff0000ExpandTradeSkillSubClass function not available|r")
		end
		
		-- Test CollapseTradeSkillSubClass hook
		print("|cffffaa00Testing CollapseTradeSkillSubClass hook...|r")
		if CollapseTradeSkillSubClass then
			CollapseTradeSkillSubClass(1)
		else
			print("|cffff0000CollapseTradeSkillSubClass function not available|r")
		end
		
		-- Test SelectTradeSkill hook
		print("|cffffaa00Testing SelectTradeSkill hook...|r")
		if SelectTradeSkill then
			SelectTradeSkill(1)
		else
			print("|cffff0000SelectTradeSkill function not available|r")
		end
		
		-- Test CastTradeSkill hook (if we have a recipe selected)
		local numTradeSkills = _GetNumTradeSkills and _GetNumTradeSkills() or 0
		if numTradeSkills > 0 then
			print("|cffffaa00Testing CastTradeSkill hook on first recipe...|r")
			if CastTradeSkill then
				CastTradeSkill(1, 1)
			else
				print("|cffff0000CastTradeSkill function not available|r")
			end
		else
			print("|cffff6600Cannot test CastTradeSkill - no recipes available|r")
		end
		
		-- Test CloseTradeSkill hook
		print("|cffffaa00Testing CloseTradeSkill hook...|r")
		if CloseTradeSkill then
			CloseTradeSkill()
		else
			print("|cffff0000CloseTradeSkill function not available|r")
		end
		
	-- Test Craft hooks (if Craft window is open)
	elseif CraftFrame and CraftFrame:IsShown() then
		print("|cffffaa00Testing Craft hooks...|r")
		
		-- Test ExpandCraftSubClass hook
		print("|cffffaa00Testing ExpandCraftSubClass hook...|r")
		if ExpandCraftSubClass then
			ExpandCraftSubClass(1)
		else
			print("|cffff0000ExpandCraftSubClass function not available|r")
		end
		
		-- Test CollapseCraftSubClass hook
		print("|cffffaa00Testing CollapseCraftSubClass hook...|r")
		if CollapseCraftSubClass then
			CollapseCraftSubClass(1)
		else
			print("|cffff0000CollapseCraftSubClass function not available|r")
		end
		
		-- Test SelectCraft hook
		print("|cffffaa00Testing SelectCraft hook...|r")
		if SelectCraft then
			SelectCraft(1)
		else
			print("|cffff0000SelectCraft function not available|r")
		end
		
		-- Test DoCraft hook (if we have a recipe selected)
		local numCrafts = _GetNumCrafts and _GetNumCrafts() or 0
		if numCrafts > 0 then
			print("|cffffaa00Testing DoCraft hook on first recipe...|r")
			if DoCraft then
				DoCraft(1)
			else
				print("|cffff0000DoCraft function not available|r")
			end
		else
			print("|cffff6600Cannot test DoCraft - no recipes available|r")
		end
		
		-- Test CloseCraft hook
		print("|cffffaa00Testing CloseCraft hook...|r")
		if CloseCraft then
			CloseCraft()
		else
			print("|cffff0000CloseCraft function not available|r")
		end
		
	else
		print("|cffff6600Cannot test profession hooks - no profession window open|r")
		print("|cffff6600Open a TradeSkill or Craft window first, then run /testprofessionhooks|r")
	end
	
	-- Test trainer hooks (if trainer window is open)
	if ClassTrainerFrame and ClassTrainerFrame:IsShown() then
		print("|cffffaa00Testing trainer hooks...|r")
		
		-- Test BuyTrainerService hook (if there are services available)
		local numServices = GetNumTrainerServices and GetNumTrainerServices() or 0
		if numServices > 0 then
			print("|cffffaa00Testing BuyTrainerService hook on first service...|r")
			if BuyTrainerService then
				-- Only buy if it's available and we can afford it
				local serviceName, serviceSubText, serviceType, isExpanded, serviceDisabled = GetTrainerServiceInfo(1)
				if serviceName and not serviceDisabled and serviceType == "available" then
					BuyTrainerService(1)
				else
					print("|cffff6600Skipping BuyTrainerService - service not available or disabled|r")
				end
			else
				print("|cffff0000BuyTrainerService function not available|r")
			end
		else
			print("|cffff6600Cannot test BuyTrainerService - no trainer services available|r")
		end
		
		-- Test CloseTrainer hook
		print("|cffffaa00Testing CloseTrainer hook...|r")
		if CloseTrainer then
			CloseTrainer()
		else
			print("|cffff0000CloseTrainer function not available|r")
		end
	else
		print("|cffff6600Cannot test trainer hooks - no trainer window open|r")
	end
	
	print("|cff00ff00=== PROFESSION HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test profession hooks
SLASH_TESTPROFESSIONHOOKS1 = "/testprofessionhooks"
SlashCmdList["TESTPROFESSIONHOOKS"] = testProfessionHooks

print("|cff00ff00Profession investigation ready - events will print to chat|r")
print("|cff00ff00Open any profession window, trainer, and perform crafting to test events|r")
print("|cff00ff00Use /testprofessionhooks to test profession function hooks|r")
print("|cff00ff00Classic Era (1.15) compatible version loaded|r")
