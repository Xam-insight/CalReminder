-- Returns the full player name in the form "Name-Realm".
-- Uses the raw (unmodified) name to avoid color codes or realm shorthands.
function CalReminder_playerCharacter()
	-- UnitNameUnmodified("player") returns: name, realm
	local playerName, playerRealm = UnitNameUnmodified("player")

	-- SAFETY: playerName should always exist but we do not silently fail.
	-- If it is ever nil (very rare login edge case), we keep the nil to surface the abnormal state.
	return CalReminder_addRealm(playerName, playerRealm)
end


-- Returns true if the given name refers to the local player.
-- Ensures both sides are normalized to the "Name-Realm" format.
function CalReminder_isPlayerCharacter(aName)
	-- SAFETY: Do not suppress nil. If aName is nil, this returns false (correct behavior).
	return CalReminder_playerCharacter() == CalReminder_addRealm(aName)
end


-- Ensures a character name is in the form "Name-Realm".
-- If the realm is not provided, fallback to the player's normalized realm.
function CalReminder_addRealm(aName, aRealm)
	-- Keep nil explicit: if aName is nil, this should not be silently handled.
	if not aName then
		return nil
	end

	-- Only append a realm if the name does not already contain one.
	if not string.match(aName, "-") then
		local realm = aRealm

		-- If no realm provided, use the player's realm
		if not realm or realm == "" then
			realm = GetNormalizedRealmName() or UNKNOWN
		end

		aName = aName .. "-" .. realm
	end

	return aName
end

-- Converts a date into a timestamp (number of seconds since epoch)
function CalReminder_dateToTimestamp(day, month, year)
    return time({year = year, month = month, day = day, hour = 0, min = 0, sec = 0})
end

function CalReminder_getCurrentDate()
	local curDate = C_DateAndTime.GetCurrentCalendarTime()
	return curDate.monthDay, curDate.month, curDate.year
end

function CalReminder_getTimeUTCinMS()
	return tostring(time(date("!*t")))
end

function CalReminder_countTableElements(table)
	local count = 0
	if table then
		for _ in pairs(table) do
			count = count + 1
		end
	end
	return count
end
