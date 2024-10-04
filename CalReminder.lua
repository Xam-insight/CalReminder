CalReminder = LibStub("AceAddon-3.0"):NewAddon("CalReminder", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CalReminder", true)
local ACD = LibStub("AceConfigDialog-3.0")

CalReminderGlobal_CommPrefix = "CalReminder"

firstPendingEvent = false
firstEvent = nil
firstEventMonthOffset = nil
firstEventDay = nil
firstEventId = nil
firstEventDate = nil
firstEventIsTomorrow = false
firstEventIsToday = false

function CalReminder:OnInitialize()
	-- Called when the addon is loaded
	self:RegisterComm(CalReminderGlobal_CommPrefix, "ReceiveData")
	
	if not maxDaysToCheck then
		maxDaysToCheck = 31
	elseif maxDaysToCheck < 2 then
		maxDaysToCheck = 2
	elseif maxDaysToCheck > 62 then
		maxDaysToCheck = 62
	end
	
	if not CalReminderData then
		CalReminderData = {}
	end
	if not CalReminderData.events then
		CalReminderData.events = {}
	end
	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", self.ChatFilter)
end

local playerNotFoundMsg = string.gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "%%s", "(.-)")
function CalReminder:ChatFilter(event, msg, author, ...)
	if string.match(msg, playerNotFoundMsg) then
		local actualTime = GetTime()
		if lastCalReminderSendCommMessage and actualTime <= lastCalReminderSendCommMessage + 5 then
			return true
		end
	end
	return false, msg, author, ...
end

function CalReminder:OnEnable()
	-- Called when the addon is enabled
	C_Calendar.OpenCalendar()

	self:RegisterEvent("PLAYER_STARTED_MOVING", "ReloadData") -- Not SPELLS_CHANGED we want to be sure the player is not afk.
	self:RegisterEvent("ADDON_LOADED", "CreateCalReminderButtons")
	self:RegisterEvent("CALENDAR_OPEN_EVENT", "SaveEventData")
	self:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST", "SaveEventData")
	
    --self:RegisterEvent("CALENDAR_ACTION_PENDING", "ReloadData")

	self:RegisterChatCommand("crm", "CalReminderChatCommand")
	self:Print(L["CALREMINDER_WELCOME"])
end

function CalReminder:CalReminderChatCommand()
	CalReminder_OpenOptions()
end

function CalReminder_OpenOptions()
	if not CalReminderOptionsLoaded then
		loadCalReminderOptions()
	end
	ACD:Open("CalReminder")
end

-- Function to retrieve the current event's unique ID
local function CalReminder_getCurrentEventId()
	local currentEventInfo = C_Calendar.GetEventIndex()
	local eventInfo = currentEventInfo and C_Calendar.GetDayEvent(currentEventInfo.offsetMonths, currentEventInfo.monthDay, currentEventInfo.eventIndex)
	return eventInfo and eventInfo.eventID  -- Retrieve the event's unique ID
end

function getCalReminderData(eventID, data, player)
	if not data then
		return nil
	end
	if not eventID then
		eventID = CalReminder_getCurrentEventId()
		if not eventID then
			return nil
		end
	end
	local value = CalReminderData and CalReminderData.events and CalReminderData.events[eventID]
		and ( (player and CalReminderData.events[eventID].players and CalReminderData.events[eventID].players[player] and CalReminderData.events[eventID].players[player][data])
			or (CalReminderData.events[eventID].infos and CalReminderData.events[eventID].infos[data]) )
	if value ~= nil then
		value, dataTime = strsplit("|", tostring(value), 2)
		if dataTime and dataTime == "" then
			dataTime = nil
		end
		if value == "nil" then
			value = nil
		end
	end
	return value, dataTime
end

local function setCalReminderData(eventID, data, aValue, player)
	local value, dataTime = strsplit("|", tostring(aValue), 2)
	if not data then
		return
	end
	if not eventID then
		eventID = CalReminder_getCurrentEventId()
		if not eventID then
			return
		end
	end
	if not CalReminderData.events[eventID] then
		CalReminderData.events[eventID] = {}
	end
	if not CalReminderData.events[eventID].players then
		CalReminderData.events[eventID].players = {}
	end
	if not CalReminderData.events[eventID].infos then
		CalReminderData.events[eventID].infos = {}
	end
	if player and not CalReminderData.events[eventID].players[player] then
		CalReminderData.events[eventID].players[player] = {}
	end
	if not dataTime or dataTime == "" then
		dataTime = tostring(CalReminder_getTimeUTCinMS())
	end
	if player then
		CalReminderData.events[eventID].players[player][data] = value.."|"..dataTime
	else
		CalReminderData.events[eventID].infos[data] = value.."|"..dataTime
	end
end

local function GetEventInvites()
    -- Lists for filtered invites by status
    local invitedList = {}
    local tentativeList = {}

    -- Total number of invites for the current event
    local numInvites = C_Calendar.GetNumInvites()

    -- Check if there are any invites
    if numInvites > 0 then
        for i = 1, numInvites do
            -- Retrieve the invite details
            local inviteInfo = C_Calendar.EventGetInvite(i)
            
            if inviteInfo then
                local inviteStatus = inviteInfo.inviteStatus

                -- Check if the status is "Invited" or "Tentative" and add to respective list
                if inviteStatus == Enum.CalendarStatus.Invited then
                    table.insert(invitedList, inviteInfo)
                elseif inviteStatus == Enum.CalendarStatus.Tentative then
                    table.insert(tentativeList, inviteInfo)
                end
            end
        end
    end

    return invitedList, tentativeList
end

-- Create a table of options with predefined text for the dropdown menu
local reasonsDropdownOptions = {
    L["CALREMINDER_TENTATIVE_REASON1"],
    L["CALREMINDER_TENTATIVE_REASON2"],
    L["CALREMINDER_TENTATIVE_REASON3"],
    L["CALREMINDER_TENTATIVE_REASON4"],
    L["CALREMINDER_TENTATIVE_REASON5"],
    L["CALREMINDER_TENTATIVE_REASON6"]
}

-- Function to create and show the popup with dropdown and text input
local function ShowReasonPopup(eventID, player)
    -- Create the popup dialog
    StaticPopupDialogs["TENTATIVE_REASON"] = {
        text = "Please select a reason and provide additional details:",
        button1 = SUBMIT,
        hasEditBox = true, -- Enable the text input box
        timeout = 0, -- Don't auto-close the popup
        whileDead = true, -- Allow popup even when the player is dead
        hideOnEscape = true, -- Hide when escape is pressed
        OnAccept = function(self)
			-- Get the reason from the text box
			local reasonText = self.editBox:GetText()
			local reasonID = getCalReminderData(eventID, "reason", player)
			reasonID = tonumber(reasonID)
			local reason = reasonID and reasonsDropdownOptions[reasonID]
			if reasonText == reason then
				reasonText = nil
			end
			setCalReminderData(eventID, "reasonText", reasonText, player)
			setCalReminderData("CalReminder_defaultValues", reasonID, reasonText, "lastReasonText")
			CalReminder_shareDataWithInvitees()
        end,
        EditBoxOnTextChanged = function(self)
            -- Enable or disable the "Submit" button based on text input
            local reason = self:GetText()

            -- Only enable the "Submit" button if there is text in the edit box
            if reason and reason ~= "" then
                self:GetParent().button1:Enable()  -- Enable the "Submit" button
            else
                self:GetParent().button1:Disable() -- Disable the "Submit" button
            end
        end,
        OnShow = function(self)
            -- Initially disable the "Submit" button until there is input
            self.button1:Disable()

            -- Resize the editBox to make it larger
            self.editBox:SetWidth(200)  -- Adjust width of the editBox

			-- Set default selected value and fill editBox with default text
			local currentEventInfo = C_Calendar.GetEventIndex()
			local eventID
			if currentEventInfo then
				local eventInfo = C_Calendar.GetDayEvent(currentEventInfo.offsetMonths, currentEventInfo.monthDay, currentEventInfo.eventIndex)
				eventID = eventInfo and eventInfo.eventID  -- Retrieve the event's unique ID
			end
			local reasonID = getCalReminderData(eventID, "reason", player)
			reasonID = tonumber(reasonID)
			local reason = reasonID and reasonsDropdownOptions[reasonID]
			local reasonText = getCalReminderData(eventID, "reasonText", player)
			local lastReasonText = getCalReminderData("CalReminder_defaultValues", reasonID, "lastReasonText")
			self.editBox:SetText(reasonText or lastReasonText or reason or "")
			self.editBox:SetFocus()
			self.editBox:HighlightText()
        end,
    }

    -- Show the popup dialog
    StaticPopup_Show("TENTATIVE_REASON")
end

-- Function to show the dropdown when the button is clicked
local function ShowTentativeDropdown(player)
    -- Create the dropdown frame
    local dropdown = CreateFrame("Frame", "TentativeDropdownMenu", UIParent, "UIDropDownMenuTemplate")
    -- Initialize the dropdown
    UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        for optionValue, optionText in ipairs(reasonsDropdownOptions) do
            local info = UIDropDownMenu_CreateInfo()
			info.notCheckable = 1
            info.text = optionText
            info.value = optionValue
            info.func = function()
				CalendarViewEventTentativeButton_OnClick(self)
				local eventID = CalReminder_getCurrentEventId() -- Retrieve the event's unique ID
				if eventID then
					local targetPlayer = player
					setCalReminderData(eventID, "reason", optionValue, targetPlayer)
					ShowReasonPopup(eventID, targetPlayer)
				end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    
    -- Show the dropdown near the button
    ToggleDropDownMenu(1, nil, dropdown, "CalendarViewEventTentativeButton", 0, 0)
end

function CalReminder:SaveEventData()
	local actualEventIndex = C_Calendar.GetEventIndex()
	if actualEventIndex then
		local actualEventInfo = actualEventIndex and C_Calendar.GetDayEvent(actualEventIndex.offsetMonths, actualEventIndex.monthDay, actualEventIndex.eventIndex)
		if actualEventInfo then
			if actualEventInfo.calendarType == "PLAYER" or actualEventInfo.calendarType == "GUILD_EVENT" then
				setCalReminderData(actualEventInfo.eventID, "month", actualEventInfo.startTime and actualEventInfo.startTime.month)
				setCalReminderData(actualEventInfo.eventID, "day",   actualEventInfo.startTime and actualEventInfo.startTime.monthDay)
				setCalReminderData(actualEventInfo.eventID, "year",  actualEventInfo.startTime and actualEventInfo.startTime.year)

				if actualEventInfo.modStatus == "CREATOR" or actualEventInfo.modStatus == "MODERATOR" then
					CalReminder_shareDataWithInvitees(true)
				end

				-- Retrieves the event's invitees
				local numInvites = C_Calendar.GetNumInvites()

				for i = 1, numInvites do
					local inviteInfo = C_Calendar.EventGetInvite(i)
					if inviteInfo then
						setCalReminderData(actualEventInfo.eventID, "modStatus", inviteInfo.modStatus, inviteInfo.guid)
						setCalReminderData(actualEventInfo.eventID, "status", inviteInfo.inviteStatus, inviteInfo.guid)
					end
				end
			end
		end
	end
end

function CalReminder:CreateCalReminderButtons(event, addOnName)
	if addOnName == "Blizzard_Calendar" then
		CalReminder:UnregisterEvent("ADDON_LOADED")
		
		-- Hook the function that shows tootip on invite list buttons
		hooksecurefunc("CalendarEventInviteListButton_OnEnter", function(self)
			if ( self.inviteIndex ) then
				local inviteInfo = C_Calendar.EventGetInvite(self.inviteIndex)
				if inviteInfo and inviteInfo.inviteStatus == Enum.CalendarStatus.Tentative then
					local currentEventId = CalReminder_getCurrentEventId()
					local reason = getCalReminderData(currentEventId, "reason", inviteInfo.guid)
					reason = tonumber(reason)
					reason = (reason and reasonsDropdownOptions[reason]) or ""
					local reasonText = getCalReminderData(currentEventId, "reasonText", inviteInfo.guid)
					if reasonText == reason then
						reasonText = ""
					end
					if reason or reasonText then
						local responseTime = C_Calendar.EventGetInviteResponseTime(self.inviteIndex)
						if not responseTime or responseTime.weekday == 0 then
							GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
							GameTooltip:AddLine(LFG_LIST_DETAILS)
						end
						GameTooltip:AddLine(L["CALREMINDER_TENTATIVE_REASON"]..reason, ORANGE_FONT_COLOR.r, ORANGE_FONT_COLOR.g, ORANGE_FONT_COLOR.b)
						GameTooltip:AddLine(reasonText, ORANGE_FONT_COLOR.r, ORANGE_FONT_COLOR.g, ORANGE_FONT_COLOR.b)
						GameTooltip:Show()
					end
				end
			end
		end)
		
		-- Hook the function that updates calendar invite status
		hooksecurefunc(C_Calendar, "EventSetInviteStatus", function(inviteIndex, statusOption)
			-- Check if the status is set to Tentative
			if statusOption == Enum.CalendarStatus.Tentative then
				-- Show the popup to ask for the reason
				local inviteInfo = C_Calendar.EventGetInvite(inviteIndex)
				if inviteInfo then
					ShowReasonPopup(CalReminder_getCurrentEventId(), inviteInfo.guid)
				end
			end
		end)
		
		Menu.ModifyMenu("MENU_CALENDAR_CREATE_INVITE", function(ownerRegion, rootDescription, contextData)
			-- Append a new section to the end of the menu.
			local inviteIndex = ownerRegion and ownerRegion.inviteIndex
			local inviteInfo = C_Calendar.EventGetInvite(inviteIndex)
			if not inviteInfo or inviteInfo.modStatus ~= "CREATOR" then
				rootDescription:QueueDivider()
			end
			rootDescription:CreateTitle("CalReminder")
			local submenu = rootDescription:CreateButton(ORANGE_FONT_COLOR:GenerateHexColorMarkup()..CALENDAR_STATUS_TENTATIVE.."|r")
			local targetPlayer = inviteInfo.guid
			for optionValue, optionText in ipairs(reasonsDropdownOptions) do
				local texture = "" -- 130750
				if tostring(optionValue) == getCalReminderData(inviteInfo and inviteInfo.eventID, "reason", targetPlayer) then
					texture = 130751
				end
				submenu:CreateButton("|T"..texture..":16:16:0:0|t "..ORANGE_FONT_COLOR:GenerateHexColorMarkup()..optionText.."|r", function()
					C_Calendar.EventSetInviteStatus(inviteIndex, Enum.CalendarStatus.Tentative)
					
					if inviteInfo then
						setCalReminderData(inviteInfo.eventID, "reason", optionValue, targetPlayer)
						ShowReasonPopup(inviteInfo.eventID, targetPlayer)
					end
				end)
			end
		end)

		-- Hook into the button's OnClick event
		CalendarViewEventTentativeButton:SetScript("OnClick", function(self)
			ShowTentativeDropdown()  -- Show the dropdown when the button is clicked
		end)
		
		local myButton = CreateFrame("Button", "CR_MassProcessButton", CalendarCreateEventFrame, "UIPanelButtonTemplate")
		myButton:SetSize(120, 22)  -- Taille du bouton
		myButton:SetText(BATTLEGROUND_HOLIDAY)  -- Texte du bouton
		myButton:SetPoint("TOPLEFT", CalendarCreateEventDescriptionContainer.ScrollingEditBox, "BOTTOMLEFT", -3, -4)  -- Position du bouton

		-- Fonctionnalité du bouton (ce que fait ton bouton quand on clique dessus)
		myButton:SetScript("OnClick", function(self)
			-- Example usage: retrieve the two lists for Invited and Tentative statuses
			local invitedList, tentativeList = GetEventInvites()

			-- Display the results for Invited
			print(CALENDAR_STATUS_INVITED..":")
			for _, inviteInfo in ipairs(invitedList) do
				print(string.format("Invite: %s (%s) - Status: %d", inviteInfo.guid, inviteInfo.className, inviteInfo.inviteStatus))
				SendChatMessage("test", "WHISPER", nil, CalReminder_addRealm(invite.name))
			end

			-- Display the results for Tentative
			print(CALENDAR_STATUS_TENTATIVE..":")
			for _, inviteInfo in ipairs(tentativeList) do
				print(string.format("Invite: %s (%s) - Status: %d", inviteInfo.guid, inviteInfo.className, inviteInfo.inviteStatus))
				SendChatMessage("test", "WHISPER", nil, CalReminder_addRealm(invite.name))
			end
		end)
	end
end

function CalReminder_browseEvents()
	local curHour, curMinute = GetGameTime()
	local curDay, curMonth, curYear = CalReminder_getCurrentDate()
	local calDate = C_Calendar.GetMonthInfo()
	local calMonth, calYear = calDate.month, calDate.year
	local monthOffset = 12 * (curYear - calYear) + curMonth - calMonth
		
	local actualEventInfo = C_Calendar.GetEventIndex()
	C_Calendar.SetMonth(monthOffset)
	
	local monthOffsetLoopId = 0
	local dayLoopId = curDay
	local loopId = 1
	local dayOffsetLoopId = 0
	firstPendingEvent = false
	while not firstPendingEvent and dayOffsetLoopId <= maxDaysToCheck do
		while not firstPendingEvent and dayLoopId <= 31 and dayOffsetLoopId <= maxDaysToCheck do
			local numEvents = C_Calendar.GetNumDayEvents(0, dayLoopId)
			while not firstPendingEvent and loopId <= numEvents do
				local event = C_Calendar.GetDayEvent(0, dayLoopId, loopId)
				if event then
					CalReminder:UnregisterEvent("CALENDAR_ACTION_PENDING")
					if event.calendarType == "PLAYER" or event.calendarType == "GUILD_EVENT" then
						if monthOffsetLoopId == 0
							and dayLoopId == curDay
								and curHour >= event.startTime.hour
									and curMinute >= event.startTime.minute then 
							--too late
						else
							if not firstPendingEvent 
									and (event.inviteStatus == Enum.CalendarStatus.Invited
										or event.inviteStatus == Enum.CalendarStatus.Tentative) then
								--need response
								firstEvent = event
								if dayLoopId == curDay then
									firstEventIsToday = true
								elseif dayLoopId == curDay + 1 then
									firstEventIsTomorrow = true
								end
								firstEventMonthOffset = monthOffsetLoopId
								firstEventDay = dayLoopId
								firstEventId = loopId
								firstPendingEvent = true
							end
						end
					end
				end
				loopId = loopId + 1
			end
			dayLoopId = dayLoopId + 1
			dayOffsetLoopId = dayOffsetLoopId + 1
			loopId = 1
		end
		C_Calendar.SetMonth(1)
		monthOffsetLoopId = monthOffsetLoopId + 1
		dayLoopId = 1
	end
	
	C_Calendar.SetMonth(- monthOffset - monthOffsetLoopId)
	if actualEventInfo then
		C_Calendar.OpenEvent(0, actualEventInfo.monthDay, actualEventInfo.eventIndex)
	else
		C_Calendar.CloseEvent()
	end
end

function CalReminder:ReloadData()
	CalReminder:UnregisterEvent("PLAYER_STARTED_MOVING")
	CalReminder:RegisterEvent("CALENDAR_ACTION_PENDING", "ReloadData")

	CalReminder_browseEvents()
	CalReminder_shareDataWithInvitees()
	
	if firstPendingEvent and firstEvent then
		englishFaction, localizedFaction = UnitFactionGroup("player")
		local chief = CalReminderOptionsData["HORDE_NPC"] or "GAMON"
		if englishFaction == "Alliance" then
			chief = CalReminderOptionsData["ALLIANCE_NPC"] or "SHANDRIS"
		end
		local frame = nil
		if firstEventIsToday then
			if not CalReminderOptionsData["SoundsDisabled"] then
				EZBlizzUiPop_PlaySound(12867)
			end
			frame = EZBlizzUiPop_npcDialog(chief, string.format(L["CALREMINDER_DDAY_REMINDER"], UnitName("player"), L["SPACE_BEFORE_DOT"], firstEvent.title), "CalReminderFrameTemplate")
		elseif firstEventIsTomorrow then
			if not CalReminderOptionsData["SoundsDisabled"] then
				EZBlizzUiPop_PlaySound(12867)
			end
			frame = EZBlizzUiPop_npcDialog(chief, string.format(L["CALREMINDER_LDAY_REMINDER"], UnitName("player"), L["SPACE_BEFORE_DOT"], firstEvent.title), "CalReminderFrameTemplate")
		end
		if not frame then
			local isGuildEvent = GetGuildInfo("player") ~= nil and firstEvent.calendarType == "GUILD_EVENT"
			EZBlizzUiPop_ToastFakeAchievement(CalReminder, not CalReminderOptionsData["SoundsDisabled"], 4, nil, firstEvent.title, nil, 237538, isGuildEvent, L["CALREMINDER_ACHIV_REMINDER"], true, function()  CalReminderShowCalendar(firstEventMonthOffset, firstEventDay, firstEventId)  end)
		end
	end
end

function CalReminderShowCalendar(monthOffset, day, id)
	if ( not C_AddOns.IsAddOnLoaded("Blizzard_Calendar") ) then
		UIParentLoadAddOn("Blizzard_Calendar")
	end
	if ( Calendar_Toggle ) then
		Calendar_Toggle()
		ShowUIPanel(CalendarFrame)
	end
	
	if monthOffset and day and id then
		C_Calendar.SetMonth(monthOffset)
		
		local dayOffset = 0

		for button = 1, 7 do
			local dayButton = _G["CalendarDayButton"..button]
			if dayButton and dayButton.monthOffset == 0 then
				dayOffset = button - 1
				break
			end
		end
		
		CalendarDayButton_Click(_G["CalendarDayButton"..day + dayOffset])
		if _G["CalendarDayButton"..day + dayOffset.."EventButton"..id] then
			CalendarDayEventButton_Click(_G["CalendarDayButton"..day + dayOffset.."EventButton"..id], true)
		else
			C_Calendar.OpenEvent(0, day, id)
		end
	end
end
