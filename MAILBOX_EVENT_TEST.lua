-- WoW API calls (Classic Era 1.15 compatible)
local _CreateFrame = CreateFrame
local _GetTime = GetTime
local _GetInboxNumItems = GetInboxNumItems
local _GetInboxHeaderInfo = GetInboxHeaderInfo
local _GetInboxText = GetInboxText
local _GetInboxItem = GetInboxItem
local _GetInboxItemLink = GetInboxItemLink
local _GetInboxInvoiceInfo = GetInboxInvoiceInfo
local _GetSendMailPrice = GetSendMailPrice
local _GetSendMailItem = GetSendMailItem
local _GetSendMailMoney = GetSendMailMoney
local _GetNumPackages = GetNumPackages
local _GetPackageInfo = GetPackageInfo
local _TakeInboxItem = TakeInboxItem
local _TakeInboxMoney = TakeInboxMoney
local _TakeInboxTextItem = TakeInboxTextItem
local _DeleteInboxItem = DeleteInboxItem
local _SendMail = SendMail
local _DropItemOnUnit = DropItemOnUnit
local _PickupInventoryItem = PickupInventoryItem
local _ClearSendMail = ClearSendMail
local _CloseMail = CloseMail
local _CheckInbox = CheckInbox
local _InboxItemCanDelete = InboxItemCanDelete
local _GetSelectedDisplayChannel = GetSelectedDisplayChannel

print("=== MAILBOX EVENT INVESTIGATION LOADED ===")
print("This module will log ALL mailbox-related events")
print("Watch your chat for detailed event information")
print("===========================================")

-- Event tracking frame
local investigationFrame = _CreateFrame("Frame")

-- All mailbox-related events for Classic Era (1.15)
local MAILBOX_EVENTS = {
	-- Core mailbox events
	"MAIL_SHOW",
	"MAIL_CLOSED",
	"MAIL_INBOX_UPDATE",
	"MAIL_SEND_INFO_UPDATE",
	"MAIL_SEND_SUCCESS",
	"MAIL_FAILED",
	
	-- Mail content events
	"UPDATE_PENDING_MAIL",
	"MAIL_LOCK_SEND_ITEMS",
	"MAIL_UNLOCK_SEND_ITEMS",
	
	-- Chat messages (filtered to mail-related only)
	"CHAT_MSG_SYSTEM",
	
	-- Money changes (during mail operations)
	"PLAYER_MONEY",
	
	-- Bag updates (for item changes during mail operations)
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",
	
	-- Item lock changes (for mail operations)
	"ITEM_LOCK_CHANGED",
	"ITEM_LOCKED",
	"ITEM_UNLOCKED",
	
	-- Player entering world (for initialization)
	"PLAYER_ENTERING_WORLD",
}

-- Event counter
local eventCounts = {}
for _, event in ipairs(MAILBOX_EVENTS) do
	eventCounts[event] = 0
end

-- Track last event timestamp for timing delta analysis
local lastEventTime = _GetTime()

-- Mailbox state tracking
local mailboxOpen = false
local currentMailTab = nil -- "inbox", "send"
local lastInboxCheck = 0

-- Track mail operations
local activeMailOperation = nil -- { type = "send/take/delete", timestamp = time, details = {} }

-- Track money before/after operations
local moneySnapshot = 0

-- UI state tracking
local mailFrameOpen = false

-- Helper function to get inbox item info
local function getInboxItemInfo(index)
	if not index then return "nil" end
	
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = _GetInboxHeaderInfo(index)
	
	if not sender then
		return "invalid index"
	end
	
	-- Format money amounts
	local moneyStr = money and money > 0 and formatMoney(money) or "0"
	local codStr = CODAmount and CODAmount > 0 and formatMoney(CODAmount) or "0"
	
	-- Get item info if present
	local itemInfo = ""
	if hasItem then
		local name, itemTexture, count, quality, canUse = _GetInboxItem(index, 1)
		if name then
			local itemLink = _GetInboxItemLink(index, 1)
			local displayName = itemLink and itemLink:match("%[(.-)%]") or name
			itemInfo = string.format(" [Item: %s x%d]", displayName, count or 1)
		end
	end
	
	-- Status indicators
	local statusFlags = {}
	if wasRead then table.insert(statusFlags, "Read") end
	if wasReturned then table.insert(statusFlags, "Returned") end
	if isGM then table.insert(statusFlags, "GM") end
	if CODAmount and CODAmount > 0 then table.insert(statusFlags, "COD") end
	
	local statusStr = #statusFlags > 0 and (" [" .. table.concat(statusFlags, ", ") .. "]") or ""
	
	return string.format("[%d] From: %s | Subject: %s | Money: %s | COD: %s | Days: %d%s%s", 
		index, sender, subject or "(no subject)", moneyStr, codStr, daysLeft or 0, itemInfo, statusStr)
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

-- Helper function to get send mail info
local function getSendMailInfo()
	local info = {}
	
	-- Get recipient
	if SendMailNameEditBox and SendMailNameEditBox:GetText() then
		info.recipient = SendMailNameEditBox:GetText()
	end
	
	-- Get subject
	if SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() then
		info.subject = SendMailSubjectEditBox:GetText()
	end
	
	-- Get money being sent
	local money = _GetSendMailMoney and _GetSendMailMoney() or 0
	if money > 0 then
		info.money = formatMoney(money)
	end
	
	-- Get mail cost
	local cost = _GetSendMailPrice and _GetSendMailPrice() or 0
	if cost > 0 then
		info.cost = formatMoney(cost)
	end
	
	-- Check for items
	local items = {}
	for i = 1, ATTACHMENTS_MAX_SEND or 12 do
		local name, itemTexture, count, quality, canUse = _GetSendMailItem(i)
		if name then
			table.insert(items, string.format("%s x%d", name, count or 1))
		end
	end
	if #items > 0 then
		info.items = table.concat(items, ", ")
	end
	
	return info
end

-- Register all events with error handling
local registeredEvents = {}
for _, event in ipairs(MAILBOX_EVENTS) do
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

	-- Filter out frequent events unless we're tracking mail operations
	if event == "BAG_UPDATE" then
		if not activeMailOperation then
			return -- Don't log bag updates outside mail context
		end
	end
	
	-- Filter CHAT_MSG_SYSTEM to mail-related messages only
	if event == "CHAT_MSG_SYSTEM" then
		local message = arg1
		if not message or not (
			message:find("mail") or 
			message:find("Mail") or
			message:find("postmaster") or
			message:find("Postmaster") or
			message:find("sent") or
			message:find("received") or
			message:find("return") or
			message:find("delete")
		) then
			return -- Not mail-related
		end
	end
	


	print("|cffff9900" .. timestamp .. " " .. countInfo .. " " .. deltaInfo .. " |cff00ffff" .. event .. "|r")

	lastEventTime = currentTime

	-- Event-specific detailed logging
	if event == "MAIL_SHOW" then
		print("  |cffffaa00Mailbox Opened|r")
		mailboxOpen = true
		moneySnapshot = getCurrentMoney()
		print("  |cffffaa00  Current Money:|r " .. formatMoney(moneySnapshot))

	elseif event == "MAIL_CLOSED" then
		print("  |cffffaa00Mailbox Closed|r")
		mailboxOpen = false
		
		-- Show money change if any
		local currentMoney = getCurrentMoney()
		if currentMoney ~= moneySnapshot then
			local change = currentMoney - moneySnapshot
			local changeStr = change > 0 and ("|cff00ff00+" .. formatMoney(change) .. "|r") or ("|cffff0000" .. formatMoney(math.abs(change)) .. "|r")
			print("  |cffffaa00  Money Change:|r " .. changeStr)
		end

	elseif event == "MAIL_INBOX_UPDATE" then
		print("  |cffffaa00Inbox Updated|r")
		
		local numItems = _GetInboxNumItems and _GetInboxNumItems() or 0
		print("  |cffffaa00  Mail Count:|r " .. numItems)
		
		-- Show first few mails as sample
		if numItems > 0 then
			print("  |cffaaaaaa  Sample mails:|r")
			for i = 1, math.min(5, numItems) do
				local info = getInboxItemInfo(i)
				print("    |cffaaaaaa  " .. info .. "|r")
			end
			if numItems > 5 then
				print("    |cffaaaaaa  ... and " .. (numItems - 5) .. " more|r")
			end
		end

	elseif event == "MAIL_SEND_INFO_UPDATE" then
		print("  |cffffaa00Send Mail Info Updated|r")
		
		local sendInfo = getSendMailInfo()
		if sendInfo.recipient then
			print("  |cffffaa00  Recipient:|r " .. sendInfo.recipient)
		end
		if sendInfo.subject then
			print("  |cffffaa00  Subject:|r " .. sendInfo.subject)
		end
		if sendInfo.money then
			print("  |cffffaa00  Money Attached:|r " .. sendInfo.money)
		end
		if sendInfo.cost then
			print("  |cffffaa00  Postage Cost:|r " .. sendInfo.cost)
		end
		if sendInfo.items then
			print("  |cffffaa00  Items Attached:|r " .. sendInfo.items)
		end

	elseif event == "MAIL_SEND_SUCCESS" then
		print("  |cff00ff00Mail Sent Successfully|r")
		
		-- Track this operation
		activeMailOperation = {
			type = "send",
			timestamp = currentTime
		}

	elseif event == "MAIL_FAILED" then
		print("  |cffff0000Mail Send Failed|r")
		local reason = arg1
		if reason then
			print("  |cffff0000  Reason:|r " .. tostring(reason))
		end

	elseif event == "UPDATE_PENDING_MAIL" then
		print("  |cffffaa00Pending Mail Notification Updated|r")
		
		-- Check if we have new mail
		if HasNewMail and HasNewMail() then
			print("  |cff00ff00  You have new mail!|r")
		end

	elseif event == "MAIL_LOCK_SEND_ITEMS" then
		print("  |cffffaa00Send Items Locked|r")

	elseif event == "MAIL_UNLOCK_SEND_ITEMS" then
		print("  |cffffaa00Send Items Unlocked|r")

	elseif event == "CHAT_MSG_SYSTEM" then
		local message = arg1
		print("  |cff00ff00System Message:|r " .. tostring(message))

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
		
		if activeMailOperation then
			local statusStr = "(during mail operation)"
			print("  |cffffaa00Bag Updated " .. statusStr .. ":|r Bag " .. tostring(bagId))
		end

	elseif event == "BAG_UPDATE_DELAYED" then
		if activeMailOperation then
			print("  |cffffaa00All bag updates completed (after mail operation)|r")
			-- Clear operation tracking after a delay
			activeMailOperation = nil
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

-- Track current mail tab
local currentMailTab = nil

-- Monitor MailFrame visibility and tab changes
local function checkMailFrameState()
	if MailFrame and MailFrame:IsShown() then
		if not mailFrameOpen then
			mailFrameOpen = true
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r MailFrame → |cff00ff00VISIBLE|r")
			lastEventTime = currentTime
		end
		
		-- Check for tab changes (Classic Era tab detection)
		local newTab = nil
		if InboxFrame and InboxFrame:IsShown() then
			newTab = "inbox"
		elseif SendMailFrame and SendMailFrame:IsShown() then
			newTab = "send"
		end
		
		if newTab and newTab ~= currentMailTab then
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r Tab Changed → |cff00ffff" .. string.upper(newTab) .. "|r")
			currentMailTab = newTab
			lastEventTime = currentTime
		end
	else
		if mailFrameOpen then
			mailFrameOpen = false
			currentMailTab = nil
			local currentTime = _GetTime()
			local delta = currentTime - lastEventTime
			print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [UI State]|r MailFrame → |cffff0000HIDDEN|r")
			lastEventTime = currentTime
		end
	end
end

-- Add OnUpdate for continuous UI monitoring
investigationFrame:SetScript("OnUpdate", function()
	checkMailFrameState()
end)

-- Hook mailbox functions
if _SendMail then
	hooksecurefunc("SendMail", function(recipient, subject, body)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r SendMail")
		print("  |cffffaa00To:|r " .. tostring(recipient))
		print("  |cffffaa00Subject:|r " .. tostring(subject))
		
		local sendInfo = getSendMailInfo()
		if sendInfo.money then
			print("  |cffffaa00Money:|r " .. sendInfo.money)
		end
		if sendInfo.cost then
			print("  |cffffaa00Cost:|r " .. sendInfo.cost)
		end
		if sendInfo.items then
			print("  |cffffaa00Items:|r " .. sendInfo.items)
		end
		
		-- Track this operation
		activeMailOperation = {
			type = "send",
			timestamp = currentTime,
			recipient = recipient,
			subject = subject
		}
		
		lastEventTime = currentTime
	end)
end

if _TakeInboxItem then
	hooksecurefunc("TakeInboxItem", function(index, itemIndex)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r TakeInboxItem")
		
		local mailInfo = getInboxItemInfo(index)
		print("  |cffffaa00Mail:|r " .. mailInfo)
		print("  |cffffaa00Item Index:|r " .. tostring(itemIndex))
		
		-- Track this operation
		activeMailOperation = {
			type = "take_item",
			timestamp = currentTime,
			mailIndex = index,
			itemIndex = itemIndex
		}
		
		lastEventTime = currentTime
	end)
end

if _TakeInboxMoney then
	hooksecurefunc("TakeInboxMoney", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r TakeInboxMoney")
		
		local mailInfo = getInboxItemInfo(index)
		print("  |cffffaa00Mail:|r " .. mailInfo)
		
		-- Track this operation
		activeMailOperation = {
			type = "take_money",
			timestamp = currentTime,
			mailIndex = index
		}
		
		lastEventTime = currentTime
	end)
end

if _TakeInboxTextItem then
	hooksecurefunc("TakeInboxTextItem", function(index, itemIndex)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r TakeInboxTextItem")
		
		local mailInfo = getInboxItemInfo(index)
		print("  |cffffaa00Mail:|r " .. mailInfo)
		print("  |cffffaa00Item Index:|r " .. tostring(itemIndex))
		
		-- Track this operation
		activeMailOperation = {
			type = "take_text_item",
			timestamp = currentTime,
			mailIndex = index,
			itemIndex = itemIndex
		}
		
		lastEventTime = currentTime
	end)
end

if _DeleteInboxItem then
	hooksecurefunc("DeleteInboxItem", function(index)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r DeleteInboxItem")
		
		local mailInfo = getInboxItemInfo(index)
		print("  |cffffaa00Mail:|r " .. mailInfo)
		
		-- Track this operation
		activeMailOperation = {
			type = "delete",
			timestamp = currentTime,
			mailIndex = index
		}
		
		lastEventTime = currentTime
	end)
end

if _CheckInbox then
	hooksecurefunc("CheckInbox", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r CheckInbox")
		
		lastInboxCheck = currentTime
		lastEventTime = currentTime
	end)
end

if _ClearSendMail then
	hooksecurefunc("ClearSendMail", function()
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r ClearSendMail")
		lastEventTime = currentTime
	end)
end

-- Hook tab switching functions if they exist
if MailFrameTab_OnClick then
	hooksecurefunc("MailFrameTab_OnClick", function(tab)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		local tabName = tab and tab:GetName() or "unknown"
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r MailFrameTab_OnClick → " .. tabName)
		lastEventTime = currentTime
	end)
end

-- Hook attachment functions
if ClickSendMailItemButton then
	hooksecurefunc("ClickSendMailItemButton", function(itemIndex, clearItem)
		local currentTime = _GetTime()
		local delta = currentTime - lastEventTime
		print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r ClickSendMailItemButton")
		print("  |cffffaa00Item Index:|r " .. tostring(itemIndex))
		print("  |cffffaa00Clear Item:|r " .. tostring(clearItem))
		lastEventTime = currentTime
	end)
end

-- Hook money input functions
if MoneyInputFrame_SetCopper then
	hooksecurefunc("MoneyInputFrame_SetCopper", function(frame, copper)
		-- Only log if this is actually a mail-related money frame
		-- Use pcall to safely check parent without errors
		if frame then
			local success, parent = pcall(function() return frame:GetParent() end)
			if success and parent == SendMailFrame then
				local currentTime = _GetTime()
				local delta = currentTime - lastEventTime
				print("|cffff9900[" .. string.format("%.2f", currentTime) .. "] (+" .. string.format("%.0fms", delta * 1000) .. ") [Mail Hook]|r MoneyInputFrame_SetCopper")
				print("  |cffffaa00Amount:|r " .. formatMoney(copper or 0))
				lastEventTime = currentTime
			end
		end
	end)
end

-- Test functions for mailbox hooks
local function testMailboxHooks()
	print("|cff00ff00=== TESTING MAILBOX HOOKS ===|r")
	
	if not (MailFrame and MailFrame:IsShown()) then
		print("|cffff0000Cannot test mailbox hooks - mailbox not open|r")
		print("|cffff6600Visit a mailbox first, then run /testmailboxhooks|r")
		return
	end
	
	-- Test CheckInbox hook
	print("|cffffaa00Testing CheckInbox hook...|r")
	if _CheckInbox then
		_CheckInbox()
	else
		print("|cffff0000CheckInbox function not available|r")
	end
	
	-- Test ClearSendMail hook
	print("|cffffaa00Testing ClearSendMail hook...|r")
	if _ClearSendMail then
		_ClearSendMail()
	else
		print("|cffff0000ClearSendMail function not available|r")
	end
	
	-- Test ClickSendMailItemButton hook
	print("|cffffaa00Testing ClickSendMailItemButton hook...|r")
	if ClickSendMailItemButton then
		ClickSendMailItemButton(1, false)
	else
		print("|cffff0000ClickSendMailItemButton function not available|r")
	end
	
	-- Test tab switching hook
	if MailFrameTab_OnClick then
		print("|cffffaa00Testing MailFrameTab_OnClick hook...|r")
		-- Try to click send tab
		if MailFrameTab2 then
			MailFrameTab_OnClick(MailFrameTab2)
		end
		-- Switch back to inbox tab
		if MailFrameTab1 then
			MailFrameTab_OnClick(MailFrameTab1)
		end
	end
	
	-- Test inbox operations (only if we have mail)
	local numItems = _GetInboxNumItems and _GetInboxNumItems() or 0
	if numItems > 0 then
		print("|cffffaa00Testing inbox hooks on first mail...|r")
		
		-- Check if first mail has money
		local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = _GetInboxHeaderInfo(1)
		
		if money and money > 0 then
			print("|cffffaa00Testing TakeInboxMoney hook...|r")
			if _TakeInboxMoney then
				_TakeInboxMoney(1)
			else
				print("|cffff0000TakeInboxMoney function not available|r")
			end
		end
		
		if hasItem then
			print("|cffffaa00Testing TakeInboxItem hook...|r")
			if _TakeInboxItem then
				_TakeInboxItem(1, 1)
			else
				print("|cffff0000TakeInboxItem function not available|r")
			end
		end
		
		-- Test delete (be careful with this one)
		print("|cffffaa00Testing DeleteInboxItem hook (WARNING: will delete mail)...|r")
		if _DeleteInboxItem then
			-- Only delete if it's a test mail or empty mail
			if subject and (subject:lower():find("test") or subject == "") then
				_DeleteInboxItem(1)
			else
				print("|cffff6600Skipping delete - mail doesn't appear to be a test mail|r")
			end
		else
			print("|cffff0000DeleteInboxItem function not available|r")
		end
	else
		print("|cffff6600Cannot test inbox hooks - no mail in inbox|r")
	end
	
	-- Test SendMail hook (send a test mail to yourself)
	print("|cffffaa00Testing SendMail hook (sending test mail to self)...|r")
	if _SendMail then
		local playerName = UnitName("player")
		if playerName then
			_SendMail(playerName, "Hook Test", "This is a test mail from the mailbox hook test.")
		end
	else
		print("|cffff0000SendMail function not available|r")
	end
	
	print("|cff00ff00=== MAILBOX HOOK TESTS COMPLETE ===|r")
end

-- Slash command to test mailbox hooks
SLASH_TESTMAILBOXHOOKS1 = "/testmailboxhooks"
SlashCmdList["TESTMAILBOXHOOKS"] = testMailboxHooks

print("|cff00ff00Mailbox investigation ready - events will print to chat|r")
print("|cff00ff00Visit a mailbox and send/receive mail to test events|r")
print("|cff00ff00Use /testmailboxhooks to test mailbox function hooks|r")
print("|cff00ff00Classic Era (1.15) compatible version loaded|r")