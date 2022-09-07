local ACR = LibStub("AceConfigRegistry-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CalReminder", true)

if not CalReminderOptionsData then
	CalReminderOptionsData = {}
end

function loadCalReminderOptions()
	local alliancenpcValues = {
		["ANDUIN"               ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["ANDUIN"               ]["CreatureId"]),
		["ALLIANCE_GUILD_HERALD"] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["ALLIANCE_GUILD_HERALD"]["CreatureId"]),
		["VARIAN"               ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["VARIAN"               ]["CreatureId"]),
		["HEMET"                ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["HEMET"                ]["CreatureId"]),
		["RAVERHOLDT"           ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["RAVERHOLDT"           ]["CreatureId"]),
		["UTHER"                ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["UTHER"                ]["CreatureId"]),
		["VELEN"                ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["VELEN"                ]["CreatureId"]),
		["NOBUNDO"              ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["NOBUNDO"              ]["CreatureId"]),
		["CHEN"                 ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["CHEN"                 ]["CreatureId"]),
		["MALFURION"            ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["MALFURION"            ]["CreatureId"]),
		["ILLIDAN"              ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["ILLIDAN"              ]["CreatureId"]),
		["LICH_KING"            ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["LICH_KING"            ]["CreatureId"]),
		["SHANDRIS"             ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["SHANDRIS"             ]["CreatureId"]),
		["SHAW"                 ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["SHAW"                 ]["CreatureId"]),
	}

	local hordeNpcValues = {
		["BAINE"                ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["BAINE"                ]["CreatureId"]),
		["SYLVANAS"             ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["SYLVANAS"             ]["CreatureId"]),
		["HEMET"                ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["HEMET"                ]["CreatureId"]),
		["RAVERHOLDT"           ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["RAVERHOLDT"           ]["CreatureId"]),
		["ILLIDAN"              ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["ILLIDAN"              ]["CreatureId"]),
		["LICH_KING"            ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["LICH_KING"            ]["CreatureId"]),
		["HORDE_GUILD_HERALD"   ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["HORDE_GUILD_HERALD"   ]["CreatureId"]),
		["THRALL"               ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["THRALL"               ]["CreatureId"]),
		["GALLYWIX"             ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["GALLYWIX"             ]["CreatureId"]),
		["GAMON"                ] = EZBlizzUiPop_GetNameFromNpcID(EZBlizzUiPop_npcModels["GAMON"                ]["CreatureId"]),
	}

	local CalReminderOptions = {
		type = "group",
		name = format("%s |cffADFF2Fv%s|r", "CalReminder", GetAddOnMetadata("CalReminder", "Version")),
		args = {
			general = {
				type = "group", order = 1,
				name = GENERAL,
				inline = true,
				args = {
					alliance = {
						type = "select", order = 1,
						width = "double",
						name = string.format(L["CALREMINDER_OPTIONS_NPC"], FACTION_ALLIANCE),
						desc = string.format(L["CALREMINDER_OPTIONS_NPC_DESC"], FACTION_ALLIANCE),
						values = alliancenpcValues,
						set = function(info, val)
							CalReminderOptionsData["ALLIANCE_NPC"] = val
						end,
						get = function(info)
							return CalReminderOptionsData["ALLIANCE_NPC"] or "SHANDRIS"
						end
					},
					horde = {
						type = "select", order = 2,
						width = "double",
						name = string.format(L["CALREMINDER_OPTIONS_NPC"], FACTION_HORDE),
						desc = string.format(L["CALREMINDER_OPTIONS_NPC_DESC"], FACTION_HORDE),
						values = hordeNpcValues,
						set = function(info, val)
							CalReminderOptionsData["HORDE_NPC"] = val
						end,
						get = function(info)
							return CalReminderOptionsData["HORDE_NPC"] or "GAMON"
						end
					},
				},
			},
		},
	}

	ACR:RegisterOptionsTable("CalReminder", CalReminderOptions)
	ACD:AddToBlizOptions("CalReminder", "CalReminder")
	ACD:SetDefaultSize("CalReminder", 400, 200)
end
