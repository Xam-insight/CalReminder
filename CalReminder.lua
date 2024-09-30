CalReminder = LibStub("AceAddon-3.0"):NewAddon("CalReminder", "AceConsole-3.0", "AceEvent-3.0")
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
	
	if not maxDaysToCheck then
		maxDaysToCheck = 31
	elseif maxDaysToCheck < 2 then
		maxDaysToCheck = 2
	elseif maxDaysToCheck > 62 then
		maxDaysToCheck = 62
	end
end

function CalReminder:OnEnable()
	-- Called when the addon is enabled
	C_Calendar.OpenCalendar()

	self:RegisterEvent("PLAYER_STARTED_MOVING", "ReloadData") -- Not SPELLS_CHANGED we want to be sure the player is not afk.
	--self:RegisterEvent("CALENDAR_OPEN_EVENT", "CreateMassProcessButton")
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

function CalReminder_addRealm(aName, aRealm)
	if aName and not string.match(aName, "-") then
		if aRealm and aRealm ~= "" then
			aName = aName.."-"..aRealm
		else
			local realm = GetNormalizedRealmName() or UNKNOWN
			aName = aName.."-"..realm
		end
	end
	return aName
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
    else
        print("No invites for this event.")
    end

    return invitedList, tentativeList
end

function CalReminder:CreateMassProcessButton()
	CalReminder:UnregisterEvent("CALENDAR_OPEN_EVENT")
	
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
		for _, invite in ipairs(invitedList) do
			print(string.format("Invite: %s (%s) - Status: %d", CalReminder_addRealm(invite.name), invite.className, invite.inviteStatus))
			SendChatMessage("test", "WHISPER", nil, CalReminder_addRealm(invite.name))
		end

		-- Display the results for Tentative
		print(CALENDAR_STATUS_TENTATIVE..":")
		for _, invite in ipairs(tentativeList) do
			print(string.format("Invite: %s (%s) - Status: %d", CalReminder_addRealm(invite.name), invite.className, invite.inviteStatus))
			SendChatMessage("test", "WHISPER", nil, CalReminder_addRealm(invite.name))
		end
    end)
end

function CalReminder:ReloadData()
	CalReminder:UnregisterEvent("PLAYER_STARTED_MOVING")
	CalReminder:RegisterEvent("CALENDAR_ACTION_PENDING", "ReloadData")
	local curHour, curMinute = GetGameTime()
	local curDate = C_DateAndTime.GetCurrentCalendarTime()
	local calDate = C_Calendar.GetMonthInfo()
	local month, day, year = calDate.month, curDate.monthDay, calDate.year
	local curMonth, curYear = curDate.month, curDate.year
	local monthOffset = -12 * (curYear - year) + month - curMonth
	local numEvents = 0

	local monthOffsetLoopId = monthOffset
	local dayLoopId = day
	local loopId = 1
	local dayOffsetLoopId = 0
	while not firstPendingEvent and dayOffsetLoopId <= maxDaysToCheck do
		while not firstPendingEvent and dayLoopId <= 31 and dayOffsetLoopId <= maxDaysToCheck do
			numEvents = C_Calendar.GetNumDayEvents(monthOffsetLoopId, dayLoopId)
			while not firstPendingEvent and loopId <= numEvents do
				firstEvent = C_Calendar.GetDayEvent(monthOffsetLoopId, dayLoopId, loopId)
				if firstEvent then
					CalReminder:UnregisterEvent("CALENDAR_ACTION_PENDING")
					if firstEvent.calendarType == "PLAYER" or firstEvent.calendarType == "GUILD_EVENT" then
						if monthOffsetLoopId == monthOffset
							and dayLoopId == day
								and curHour >= firstEvent.startTime.hour
									and curMinute >= firstEvent.startTime.minute then 
							--too late
						else
							if firstEvent.inviteStatus == Enum.CalendarStatus.Invited
									or firstEvent.inviteStatus == Enum.CalendarStatus.Tentative then
								--need response
								if dayLoopId == day then
									firstEventIsToday = true
								elseif dayLoopId == day + 1 then
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
		monthOffsetLoopId = monthOffsetLoopId + 1
		dayLoopId = 1
	end
	
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
			print(monthOffset, day, id)
			C_Calendar.OpenEvent(0, day, id)
		end
	end
end
