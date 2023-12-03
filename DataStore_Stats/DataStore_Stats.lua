--[[	*** DataStore_Stats ***
Written by : Thaoky, EU-Marécages de Zangar
July 18th, 2009
--]]
if not DataStore then return end

local addonName = "DataStore_Stats"

_G[addonName] = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local addon = _G[addonName]

local AddonDB_Defaults = {
	global = {
		Characters = {
			['*'] = {				-- ["Account.Realm.Name"] 
				lastUpdate = nil,
				Stats = {},
				WeeklyBestKeystone = {},
				WeeklyActivities = { 0, 0, 0 },			-- [1] = MythicPlus, [2] = RankedPvP, [3] = Raid
				WeeklyRunHistoryTop10 = {},
				
				Dungeons = {},
				dungeonScore = 0,					-- Mythic+ dungeon score
			}
		}
	}
}

-- *** Scanning functions ***
local function SortByLevelDesc(a, b)
	return a.level > b.level
end

local function ScanStats()
	local stats = addon.ThisCharacter.Stats
	wipe(stats)
	
	stats["HealthMax"] = UnitHealthMax("player")
	-- info on power types here : http://www.wowwiki.com/API_UnitPowerType
	stats["MaxPower"] = UnitPowerType("player") .. "|" .. UnitPowerMax("player")
	
	local t = {}

	-- *** base stats ***
	for i = 1, 4 do
		t[i] = UnitStat("player", i)
		-- stat, effectiveStat, posBuff, negBuff = UnitStat("player", statIndex);
	end
	t[5] = UnitArmor("player")
	stats["Base"] = table.concat(t, "|")	--	["Base"] = "strength | agility | stamina | intellect | spirit | armor"
	
	-- *** melee stats ***
	local minDmg, maxDmg = UnitDamage("player")
	t[1] = floor(minDmg) .."-" ..ceil(maxDmg)				-- Damage "215-337"
	t[2] = UnitAttackSpeed("player")
	t[3] = UnitAttackPower("player")
	t[4] = GetCombatRating(CR_HIT_MELEE)
	t[5] = GetCritChance()
	t[6] = GetExpertise()
	stats["Melee"] = table.concat(t, "|")	--	["Melee"] = "Damage | Speed | Power | Hit rating | Crit chance | Expertise"
	
	-- *** ranged stats ***
	local speed
	speed, minDmg, maxDmg = UnitRangedDamage("player")
	t[1] = floor(minDmg) .."-" ..ceil(maxDmg)
	t[2] = speed
	t[3] = UnitRangedAttackPower("player")
	t[4] = GetCombatRating(CR_HIT_RANGED)
	t[5] = GetRangedCritChance()
	t[6] = nil
	stats["Ranged"] = table.concat(t, "|")	--	["Ranged"] = "Damage | Speed | Power | Hit rating | Crit chance"
	
	-- *** spell stats ***
	t[1] = GetSpellBonusDamage(2)			-- 2, since 1 = physical damage
	t[2] = GetSpellBonusHealing()
	t[3] = GetCombatRating(CR_HIT_SPELL)
	t[4] = GetSpellCritChance(2)
	t[5] = GetCombatRating(CR_HASTE_SPELL)
	t[6] = floor(GetManaRegen() * 5.0)
	stats["Spell"] = table.concat(t, "|")	--	["Spell"] = "+Damage | +Healing | Hit | Crit chance | Haste | Mana Regen"
		
	-- *** defenses stats ***
	t[1] = UnitArmor("player")
	-- t[2] = UnitDefense("player")	deprecated in 8.0
	t[2] = 0
	t[3] = GetDodgeChance()
	t[4] = GetParryChance()
	t[5] = GetBlockChance()
	t[6] = GetCombatRating(COMBAT_RATING_RESILIENCE_PLAYER_DAMAGE_TAKEN)
	stats["Defense"] = table.concat(t, "|")	--	["Defense"] = "Armor | Defense | Dodge | Parry | Block | Resilience"

	-- *** PVP Stats ***
	t[1], t[2] = GetPVPLifetimeStats()
	t[3] = nil
	t[4] = nil
	t[5] = nil
	t[6] = nil
	stats["PVP"] = table.concat(t, "|")	--	["PVP"] = "honorable kills | dishonorable kills"
	
	-- *** Arena Teams ***
	--[[
	for i = 1, MAX_ARENA_TEAMS do
		local teamName, teamSize = GetArenaTeam(i)
		if teamName then
			stats["Arena"..teamSize] = table.concat({ GetArenaTeam(i) }, "|")
			-- more info here : http://www.wowwiki.com/API_GetArenaTeam
		end
	end
	--]]
	
	addon.ThisCharacter.lastUpdate = time()
end

local function ScanMythicPlusBestForMapInfo()
	local char = addon.ThisCharacter

	wipe(char.WeeklyBestKeystone)
	
	-- Get the dungeons
	local maps = C_ChallengeMode.GetMapTable()
	if not maps then return end

	local bestTime = 999999
	local bestLevel = 0
	local bestMapID
	
	-- Loop through maps
	for i = 1, #maps do
		local mapID = maps[i]
		local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
		
		-- clear previously saved info
		if char.Dungeons[mapID] then
			local dungeonInfo = char.Dungeons[mapID]
			
			dungeonInfo.weeklyBestLevel = nil
			dungeonInfo.weeklyBestTimeInSeconds = nil
			dungeonInfo.seasonBestLevel = nil
			dungeonInfo.seasonBestTimeInSeconds = nil
			dungeonInfo.seasonBestOvertimeLevel = nil
			dungeonInfo.seasonBestOvertimeTimeInSeconds = nil			
		end
		
		-- Weekly Best
		local durationSec, level = C_MythicPlus.GetWeeklyBestForMap(mapID)
		
		if level then
			-- save this map's info
			char.Dungeons[mapID] = char.Dungeons[mapID] or {}
			local dungeonInfo = char.Dungeons[mapID]
			
			dungeonInfo.weeklyBestLevel = level
			dungeonInfo.weeklyBestTimeInSeconds = durationSec
			
			-- Is it the best ?
			if (level > bestLevel) or ((level == bestLevel) and (durationSec < bestTime)) then
				bestTime = durationSec
				bestLevel = level
				bestMapID = mapID
			end
		end

		-- Season Best
		local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
		if intimeInfo and intimeInfo.level then
			char.Dungeons[mapID] = char.Dungeons[mapID] or {}
			local dungeonInfo = char.Dungeons[mapID]
		
			dungeonInfo.seasonBestLevel = intimeInfo.level
			dungeonInfo.seasonBestTimeInSeconds = intimeInfo.durationSec
		end
		
		if overtimeInfo and overtimeInfo.level then
			char.Dungeons[mapID] = char.Dungeons[mapID] or {}
			local dungeonInfo = char.Dungeons[mapID]

			dungeonInfo.seasonBestOvertimeLevel = overtimeInfo.level
			dungeonInfo.seasonBestOvertimeTimeInSeconds = overtimeInfo.durationSec			
		end
	end
	
	-- Save the best map info
	if bestMapID then
		local name = C_ChallengeMode.GetMapUIInfo(bestMapID)
		local keyInfo = char.WeeklyBestKeystone
		
		keyInfo.name = name
		keyInfo.level = bestLevel
		keyInfo.timeInSeconds = bestTime
	end

	char.lastUpdate = time()
	
	char.dungeonScore = C_ChallengeMode.GetOverallDungeonScore()
end

local function ScanRewardType(rewardType)
	local char = addon.ThisCharacter
	--wipe(char.WeeklyActivities)
	
	-- https://wowpedia.fandom.com/wiki/API_C_WeeklyRewards.GetActivities
	local activities = C_WeeklyRewards.GetActivities(rewardType)
	
	for _, activity in pairs(activities) do
		
		-- Ex: for M+, index 1 = 0/1,  index 2 = 0/4, index 3 = 0/8 .. we only care about index 3
		if activity.index == 3 then
			char.WeeklyActivities[activity.type] = activity.progress
		end
	end
end

local function ScanRunHistory()
	local includePreviousWeeks = false
	local includeIncompleteRuns = true
	
	local runs = C_MythicPlus.GetRunHistory(includePreviousWeeks, includeIncompleteRuns)
	if not runs or #runs == 0 then return end		-- no runs ? exit
	
	local char = addon.ThisCharacter
	local top10 = {}
	
	-- clear the run history from previous scans
	for mapID, mapInfo in pairs(char.Dungeons) do
		if mapInfo.weeklyRunHistory then
			wipe(mapInfo.weeklyRunHistory)
		end
	end

	-- loop through runs
	for i, runInfo in pairs(runs) do
		local mapID = runInfo.mapChallengeModeID
		char.Dungeons[mapID] = char.Dungeons[mapID] or {}
		local dungeonInfo = char.Dungeons[mapID]

		-- Make room for the run history
		dungeonInfo.weeklyRunHistory = dungeonInfo.weeklyRunHistory or {}		-- Create if it does not exist yet
		table.insert(dungeonInfo.weeklyRunHistory, { level = runInfo.level, completed = runInfo.completed })
		
		-- Track the top10 completed dungeons
		if runInfo.completed then
			table.insert(top10, { mapID = mapID, level = runInfo.level })
		end
	end

	-- sort the levels of each map
	for mapID, mapInfo in pairs(char.Dungeons) do
		if mapInfo.weeklyRunHistory then
			table.sort(mapInfo.weeklyRunHistory, SortByLevelDesc)
		end
	end
	
	-- Sort the top 10 runs by level, descending
	table.sort(top10, SortByLevelDesc)
	
	-- if we have more than 10 in the list, trim the surplus
	if #top10 > 10 then
		for i = #top10, 11, -1 do
			table.remove(top10)		-- remove last
		end
	end
	
	char.WeeklyRunHistoryTop10 = top10
end

-- *** Event Handlers ***
local function OnPlayerAlive()
	ScanStats()
	
	-- This call will trigger the "CHALLENGE_MODE_MAPS_UPDATE" event
	-- It is necessary to ensure that the proper best times are read, because when logging on a character, it could still
	-- show the best times of the previous alt until the event is triggered. So clearly, on alt can read another alt's data.
	-- To avoid this, trigger the event from here (not before PLAYER_ALIVE, it's too soon)
	C_MythicPlus.RequestMapInfo()
	
	ScanRunHistory()
end

local function OnWeeklyRewardsUpdate()
	ScanMythicPlusBestForMapInfo()
end

local function OnChallengeModeMapsUpdate()
	ScanMythicPlusBestForMapInfo()
end

local function OnWeeklyRewardsFrameOpened(event, interactionType)
	if interactionType == Enum.PlayerInteractionType.WeeklyRewards then
		ScanRewardType(Enum.WeeklyRewardChestThresholdType.Raid)
		ScanRewardType(Enum.WeeklyRewardChestThresholdType.MythicPlus)
		ScanRewardType(Enum.WeeklyRewardChestThresholdType.RankedPvP)
	end
end

local function OnLoginCheckRewards(event, isLogin, isReload)
	if isLogin or isReload then
		ScanRewardType(Enum.WeeklyRewardChestThresholdType.Raid)
		ScanRewardType(Enum.WeeklyRewardChestThresholdType.MythicPlus)
		ScanRewardType(Enum.WeeklyRewardChestThresholdType.RankedPvP)
	end
end

-- ** Mixins **
local function _GetStats(character, statType)
	local data = character.Stats[statType]
	if not data then return end
	
	return strsplit("|", data)
	
	-- if there's a need to automate the tonumber of each var, do this ( improve it), since most of the time, these data will be used for display purposes, strings are acceptable
	-- local var1, var2, var3, var4, var5, var6 = strsplit("|", data)
	-- return tonumber(var1), tonumber(var2), tonumber(var3), tonumber(var4), tonumber(var5), tonumber(var6)
end

local function _GetWeeklyBestKeystoneName(character)
	return character.WeeklyBestKeystone.name or ""
end

local function _GetWeeklyBestKeystoneLevel(character)
	return character.WeeklyBestKeystone.level or 0
end

local function _GetWeeklyBestKeystoneTime(character)
	return character.WeeklyBestKeystone.timeInSeconds or 0
end

local function _GetDungeonScore(character)
	return character.dungeonScore
end

local function _GetWeeklyMythicPlusReward(character)
	return character.WeeklyActivities[1]
end

local function _GetWeeklyRankedPvPReward(character)
	return character.WeeklyActivities[2]
end

local function _GetWeeklyRaidReward(character)
	return character.WeeklyActivities[3]
end

local function _GetDungeonStats(character)
	return character.Dungeons
end

local function _GetWeeklyRunHistory(character, mapID)
	local info = character.Dungeons[mapID]
	
	if info then
		return info.weeklyRunHistory
	end
end

local function _GetWeeklyTop10Runs(character)
	return character.WeeklyRunHistoryTop10
end

local function _GetWeeklyBestByDungeon(character, mapID)
	local info = character.Dungeons[mapID]
	
	if info then
		return info.weeklyBestLevel
	end
end

local PublicMethods = {
	GetStats = _GetStats,
	GetWeeklyBestKeystoneName = _GetWeeklyBestKeystoneName,
	GetWeeklyBestKeystoneLevel = _GetWeeklyBestKeystoneLevel,
	GetWeeklyBestKeystoneTime = _GetWeeklyBestKeystoneTime,
	GetDungeonScore = _GetDungeonScore,
	GetWeeklyMythicPlusReward = _GetWeeklyMythicPlusReward,
	GetWeeklyRankedPvPReward = _GetWeeklyRankedPvPReward,
	GetWeeklyRaidReward = _GetWeeklyRaidReward,
	GetDungeonStats = _GetDungeonStats,
	GetWeeklyRunHistory = _GetWeeklyRunHistory,
	GetWeeklyTop10Runs = _GetWeeklyTop10Runs,
	GetWeeklyBestByDungeon = _GetWeeklyBestByDungeon,
}

function addon:OnInitialize()
	addon.db = LibStub("AceDB-3.0"):New(addonName .. "DB", AddonDB_Defaults)

	DataStore:RegisterModule(addonName, addon, PublicMethods)
	DataStore:SetCharacterBasedMethod("GetStats")
	DataStore:SetCharacterBasedMethod("GetWeeklyBestKeystoneName")
	DataStore:SetCharacterBasedMethod("GetWeeklyBestKeystoneLevel")
	DataStore:SetCharacterBasedMethod("GetWeeklyBestKeystoneTime")
	DataStore:SetCharacterBasedMethod("GetDungeonScore")
	DataStore:SetCharacterBasedMethod("GetWeeklyMythicPlusReward")
	DataStore:SetCharacterBasedMethod("GetWeeklyRankedPvPReward")
	DataStore:SetCharacterBasedMethod("GetWeeklyRaidReward")
	DataStore:SetCharacterBasedMethod("GetDungeonStats")
	DataStore:SetCharacterBasedMethod("GetWeeklyRunHistory")
	DataStore:SetCharacterBasedMethod("GetWeeklyTop10Runs")
	DataStore:SetCharacterBasedMethod("GetWeeklyBestByDungeon")
end

function addon:OnEnable()
	addon:RegisterEvent("PLAYER_ALIVE", OnPlayerAlive)
	addon:RegisterEvent("UNIT_INVENTORY_CHANGED", ScanStats)
	addon:RegisterEvent("WEEKLY_REWARDS_UPDATE", OnWeeklyRewardsUpdate)
	addon:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", OnChallengeModeMapsUpdate)
	
	addon:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", OnWeeklyRewardsFrameOpened)
	addon:RegisterEvent("PLAYER_ENTERING_WORLD", OnLoginCheckRewards)
end

function addon:OnDisable()
	addon:UnregisterEvent("PLAYER_ALIVE")
	addon:UnregisterEvent("UNIT_INVENTORY_CHANGED")
	addon:UnregisterEvent("WEEKLY_REWARDS_UPDATE")
	addon:UnregisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
	addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
end
