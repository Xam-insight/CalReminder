local L = LibStub("AceLocale-3.0"):GetLocale("CalReminder", true);

-- Number of seconds in a day (86400 seconds = 1 day)
local secondsInDay = 86400
-- Number of days to treshold data
local daysThreshold = 62

local function encodeAndSendData(data, target, messageType)
	local dataToSend = {}
	dataToSend.events = data.events
	dataToSend["version"] = C_AddOns.GetAddOnMetadata("CalReminder", "Version")
	local s = CalReminder:Serialize(data)
	local text = messageType.."#"..s
	lastCalReminderSendCommMessage = GetTime()
	CalReminder:SendCommMessage(CalReminderGlobal_CommPrefix, text, "WHISPER", target)
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
			else
				for player, playerData in pairs(data.players) do
					playersForSharing[player] = true
				end
			end
		end
	end
	
	for player, data in pairs(playersForSharing) do
		local _, _, _, _, _, name, server = GetPlayerInfoByGUID(player)
		local target = CalReminder_addRealm(name, server)
		if not CalReminder_isPlayerCharacter(target) then
			if onlyCall then
				lastCalReminderSendCommMessage = GetTime()
				CalReminder:SendCommMessage(CalReminderGlobal_CommPrefix, "DataCall", "WHISPER", target)
			else
				encodeAndSendData(CalReminderData, target, "FullData")
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
				fixedObsoleteSentValues.events = {}
				for eventID, eventData in pairs(o.events) do
					for player, playerData in pairs(eventData.players) do
						for data, value in pairs(playerData) do
							if name == "Farfouille" then print("******", eventID, name, data, value) end
							local actualValue, actualValueTime = getCalReminderData(eventID, data, player)
							local newValue, newValueTime = strsplit("|", value, 2)
							if newValue == "nil" then
								newValue = nil
							end
							if actualValue ~= newValue then
								if not actualValueTime or (newValueTime and newValueTime > actualValueTime) then
									setCalReminderData(eventID, data, newValue, player)
								else
									if not fixedObsoleteSentValues.events[eventID] then
										fixedObsoleteSentValues.events[eventID] = {}
									end
									if not fixedObsoleteSentValues.events[eventID].players then
										fixedObsoleteSentValues.events[eventID].players = {}
									end
									fixedObsoleteSentValues.events[eventID].players[player] = CalReminderData.events[eventID].players[player]
								end
							end
						end
					end
				end
				if messageType == "FullData" and CalReminder_countTableElements(fixedObsoleteSentValues.events) > 0 then
					encodeAndSendData(fixedObsoleteSentValues, senderFullName, "FixedObloleteData")
				end
			end
		elseif messageType == "DataCall" then
			encodeAndSendData(CalReminderData, senderFullName, "FullData")
		end
	end
end
