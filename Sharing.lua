local L = LibStub("AceLocale-3.0"):GetLocale("CalReminder", true);

-- Number of seconds in a day (86400 seconds = 1 day)
local secondsInDay = 86400
-- Number of days to treshold data
local daysThreshold = 62

local function encodeAndSendData(data, target, messageType)
	data["version"] = C_AddOns.GetAddOnMetadata("CalReminder", "Version")
	local s = CalReminder:Serialize(data)
	local text = messageType.."#"..s
	lastCalReminderSendCommMessage = GetTime()
	CalReminder:SendCommMessage(CalReminderGlobal_CommPrefix, text, "WHISPER", target)
end

function CalReminder_shareDataWithInvitees()
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
		_, _, _, _, _, name, server = GetPlayerInfoByGUID(player)
		encodeAndSendData(CalReminderData, CalReminder_addRealm(name, server), "FullData")
	end
end

function CalReminder:ReceiveData(prefix, message, distribution, sender)
	if prefix == CalReminderGlobal_CommPrefix then
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
							local actualValue, actualValueTime = getCalReminderData(eventID, data, player)
							local newValue, newValueTime = strsplit("|", value, 2)
							if not actualValueTime or (newValueTime and newValueTime > actualValueTime) then
								print("NEW")
								setCalReminderData(eventID, data, newValue, player)
							elseif actualValue ~= newValue and actualValueTime ~= newValueTime then
								print("OBSOLETE", data, actualValue, newValue, actualValueTime, newValueTime)
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
				if messageType == "FullData" and CalReminder_countTableElements(fixedObsoleteSentValues.events) > 0 then
					encodeAndSendData(fixedObsoleteSentValues, senderFullName, "FixedObloleteData")
				end
			end
		end
	end
end
