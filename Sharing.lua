local L = LibStub("AceLocale-3.0"):GetLocale("CalReminder", true);

-- Number of seconds in a day (86400 seconds = 1 day)
local secondsInDay = 86400
-- Number of days to treshold data
local daysThreshold = 62

local function encodeAndSendData(data, target, messageType)
	local s = CalReminder:Serialize(dataToSend)
	local text = messageType.."#"..s
	lastCalReminderSendCommMessage = GetTime()
	CalReminder:SendCommMessage(CalReminderGlobal_CommPrefix, text, "WHISPER", target)
end

local function CalReminder_filterCalReminderData()
	local dataToSend = {}
	dataToSend["version"] = C_AddOns.GetAddOnMetadata("CalReminder", "Version")
	for event, eventData in pairs(CalReminderData.events) do
		if not eventData.obsolete then
			dataToSend[event] = {}
			for player, playerData in pairs(eventData.players) do
				local playerStatus = getCalReminderData(event, "status", player)
				if playerStatus and playerStatus == tostring(Enum.CalendarStatus.Tentative) then
					--local playerReason = getCalReminderData(event, "reason", player)
					--local playerReasonText = getCalReminderData(event, "reasonText", player)
					dataToSend[event][player] = {}
					dataToSend[event][player].reason     = eventData.players[player].reason
					dataToSend[event][player].reasonText = eventData.players[player].reasonText
					if CalReminder_countTableElements(dataToSend[event][player]) == 0 then
						dataToSend[event][player] = nil
					end
				end
			end
			if CalReminder_countTableElements(dataToSend[event]) == 0 then
				dataToSend[event] = nil
			end
		end
	end
	if CalReminder_countTableElements(dataToSend) == 0 then
		dataToSend = nil
	end
	return dataToSend
end

function CalReminder_shareDataWithInvitees(onlyCall)
	local currentTime = time()
	local playersForSharing = {}
	for eventID, data in pairs(CalReminderData.events) do
		local eventDay   = getCalReminderData(eventID, "day")
		local eventMonth = getCalReminderData(eventID, "month")
		local eventYear  = getCalReminderData(eventID, "year")
		if eventDay and eventMonth and eventYear then
			local eventTimeStamp = CalReminder_dateToTimestamp(eventDay, eventMonth, eventYear)
			
			if (currentTime - eventTimeStamp) > (daysThreshold * secondsInDay) then
				CalReminderData.events[eventID] = nil
			elseif (currentTime - eventTimeStamp) > 0 then
				CalReminderData.events[eventID].obsolete = true
			else
				for player, playerData in pairs(data.players) do
					playersForSharing[player] = true
				end
			end
		end
	end
	
	local dataToSend
	for player, data in pairs(playersForSharing) do
		local _, _, _, _, _, name, server = GetPlayerInfoByGUID(player)
		local target = CalReminder_addRealm(name, server)
		if not CalReminder_isPlayerCharacter(target) then
			if onlyCall then
				lastCalReminderSendCommMessage = GetTime()
				CalReminder:SendCommMessage(CalReminderGlobal_CommPrefix, "DataCall", "WHISPER", target)
			else
				if not dataToSend then
					dataToSend = CalReminder_filterCalReminderData()
				end
				if dataToSend then
					encodeAndSendData(dataToSend, target, "FullData")
				end
			end
		end
	end
end

function CalReminder:ReceiveData(prefix, message, distribution, sender)
	if prefix == CalReminderGlobal_CommPrefix and not CalReminder_isPlayerCharacter(sender) then
		local senderFullName = CalReminder_addRealm(sender)
		--CalReminder:Print(time().." - Received message from "..sender..".")
		local messageType, messageMessage = strsplit("#", message, 2)
		--if not isPlayerCharacter(sender) then
		if messageType == "FullData" or messageType == "FixedObloleteData" then
			local success, o = self:Deserialize(messageMessage)
			if success == false then
				CalReminder:Print(time().." - Received corrupted data from "..sender..".")
			else
				local fixedObsoleteSentValues = {}
				for eventID, eventData in pairs(o) do
					for player, playerData in pairs(eventData) do
						for data, value in pairs(playerData) do
							local actualValue, actualValueTime = getCalReminderData(eventID, data, player)
							local newValue, newValueTime = strsplit("|", value, 2)
							if newValue == "nil" then
								newValue = nil
							end
							if actualValue ~= newValue then
								if not actualValueTime or (newValueTime and newValueTime > actualValueTime) then
									setCalReminderData(eventID, data, newValue, player)
								else
									if not fixedObsoleteSentValues[eventID] then
										fixedObsoleteSentValues[eventID] = {}
									end
									if not fixedObsoleteSentValues[eventID] then
										fixedObsoleteSentValues[eventID] = {}
									end
									fixedObsoleteSentValues[eventID][player] = CalReminderData.events[eventID].players[player]
								end
							end
						end
					end
				end
				if messageType == "FullData" and CalReminder_countTableElements(fixedObsoleteSentValues) > 0 then
					encodeAndSendData(fixedObsoleteSentValues, senderFullName, "FixedObloleteData")
				end
			end
		elseif messageType == "DataCall" then
			encodeAndSendData(CalReminder_filterCalReminderData(), senderFullName, "FullData")
		end
	end
end
