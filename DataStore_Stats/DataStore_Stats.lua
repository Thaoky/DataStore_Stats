--[[	*** DataStore_Stats ***
Written by : Thaoky, EU-Marécages de Zangar
July 18th, 2009
--]]
if not DataStore then return end

local addonName, addon = ...
local thisCharacter

local TableConcat, TableInsert, TableSort, format, floor, ceil = table.concat, table.insert, table.sort, format, floor, ceil
local UnitHealthMax, UnitPowerType, UnitPowerMax, GetPVPLifetimeStats = UnitHealthMax, UnitPowerType, UnitPowerMax, GetPVPLifetimeStats
local UnitStat, UnitArmor, UnitDamage, UnitAttackSpeed, UnitAttackPower = UnitStat, UnitArmor, UnitDamage, UnitAttackSpeed, UnitAttackPower
local GetCombatRating, GetCritChance, GetExpertise, GetSpellBonusDamage, GetSpellBonusHealing, GetSpellCritChance, GetManaRegen = GetCombatRating, GetCritChance, GetExpertise, GetSpellBonusDamage, GetSpellBonusHealing, GetSpellCritChance, GetManaRegen
local UnitRangedDamage, UnitRangedAttackPower, GetRangedCritChance, GetDodgeChance, GetParryChance, GetBlockChance = UnitRangedDamage, UnitRangedAttackPower, GetRangedCritChance, GetDodgeChance, GetParryChance, GetBlockChance

local C_ChallengeMode, C_MythicPlus, C_WeeklyRewards = C_ChallengeMode, C_MythicPlus, C_WeeklyRewards

-- *** Scanning functions ***
local function SortByLevelDesc(a, b)
	return a.level > b.level
end

local function ScanStats()
	local char = thisCharacter
	
	char.HealthMax = UnitHealthMax("player")
	-- info on power types here : http://www.wowwiki.com/API_UnitPowerType
	char.MaxPower = format("%d|%d", UnitPowerType("player"), UnitPowerMax("player"))
	
	local t = {}

	-- *** Base ***
	--	"strength | agility | stamina | intellect | spirit | armor"
	for i = 1, 4 do
		t[i] = UnitStat("player", i)
		-- stat, effectiveStat, posBuff, negBuff = UnitStat("player", statIndex);
	end
	t[5] = UnitArmor("player")
	char.Base = TableConcat(t, "|")
	
	-- *** Melee ***
	--	"Damage | Speed | Power | Hit rating | Crit chance | Expertise"
	local minDmg, maxDmg = UnitDamage("player")
	t[1] = format("%d-%d", floor(minDmg), ceil(maxDmg))	-- Damage "215-337"
	t[2] = format("%.2f", UnitAttackSpeed("player"))
	t[3] = UnitAttackPower("player")
	t[4] = GetCombatRating(CR_HIT_MELEE)
	t[5] = format("%.2f", GetCritChance())
	t[6] = GetExpertise()
	char.Melee = TableConcat(t, "|")
	
	-- *** Ranged ***
	--	"Damage | Speed | Power | Hit rating | Crit chance"
	local speed
	speed, minDmg, maxDmg = UnitRangedDamage("player")
	t[1] = format("%d-%d", floor(minDmg), ceil(maxDmg))
	t[2] = speed
	t[3] = UnitRangedAttackPower("player")
	t[4] = GetCombatRating(CR_HIT_RANGED)
	t[5] = format("%.2f", GetRangedCritChance())
	t[6] = nil
	char.Ranged = TableConcat(t, "|")
	
	-- *** Spell ***
	--	"+Damage | +Healing | Hit | Crit chance | Haste | Mana Regen"
	t[1] = GetSpellBonusDamage(2)			-- 2, since 1 = physical damage
	t[2] = GetSpellBonusHealing()
	t[3] = GetCombatRating(CR_HIT_SPELL)
	t[4] = format("%.2f", GetSpellCritChance(2))
	t[5] = GetCombatRating(CR_HASTE_SPELL)
	t[6] = floor(GetManaRegen() * 5.0)
	char.Spell = TableConcat(t, "|")
		
	-- *** Defense ***
	--	"Armor | Defense | Dodge | Parry | Block | Resilience"
	t[1] = UnitArmor("player")
	t[2] = 0		-- UnitDefense("player")	deprecated in 8.0
	t[3] = GetDodgeChance()
	t[4] = format("%.2f", GetParryChance())
	t[5] = format("%.2f", GetBlockChance())
	t[6] = GetCombatRating(COMBAT_RATING_RESILIENCE_PLAYER_DAMAGE_TAKEN)
	char.Defense = TableConcat(t, "|")

	-- *** PVP ***
	--	"honorable kills | dishonorable kills"
	wipe(t)
	t[1], t[2] = GetPVPLifetimeStats()
	char.PVP = TableConcat(t, "|")
	
	-- *** Arena Teams ***
	--[[
	for i = 1, MAX_ARENA_TEAMS do
		local teamName, teamSize = GetArenaTeam(i)
		if teamName then
			char["Arena"..teamSize] = TableConcat({ GetArenaTeam(i) }, "|")
			-- more info here : http://www.wowwiki.com/API_GetArenaTeam
		end
	end
	--]]
	
	thisCharacter.lastUpdate = time()
end

local function GetWeekliesTable()
	local id = DataStore:GetCharacterID(DataStore.ThisCharKey)
	DataStore_Stats_Weekly[id] = DataStore_Stats_Weekly[id] or {}
		
	return DataStore_Stats_Weekly[id]
end

local function GetDungeonsTable()
	local id = DataStore:GetCharacterID(DataStore.ThisCharKey)
	DataStore_Stats_Dungeons[id] = DataStore_Stats_Dungeons[id] or {}
		
	return DataStore_Stats_Dungeons[id]
end

local function GetDungeonMapTable(mapID)
	local dungeons = GetDungeonsTable()
	dungeons[mapID] = dungeons[mapID] or {}
	
	return dungeons[mapID]
end

local function ScanMythicPlusBestForMapInfo()
	local char = thisCharacter
	
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
		
		-- Weekly Best
		local durationSec, level = C_MythicPlus.GetWeeklyBestForMap(mapID)
		
		if level then
			-- save this map's info
			local info = GetDungeonMapTable(mapID)
			
			info.weeklyBestLevel = level
			info.weeklyBestTimeInSeconds = durationSec
			
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
			local info = GetDungeonMapTable(mapID)
		
			info.seasonBestLevel = intimeInfo.level
			info.seasonBestTimeInSeconds = intimeInfo.durationSec
		end
		
		if overtimeInfo and overtimeInfo.level then
			local info = GetDungeonMapTable(mapID)

			info.seasonBestOvertimeLevel = overtimeInfo.level
			info.seasonBestOvertimeTimeInSeconds = overtimeInfo.durationSec			
		end
	end
	
	-- Save the best map info
	if bestMapID then
		local name = C_ChallengeMode.GetMapUIInfo(bestMapID)
		local weeklies = GetWeekliesTable()
		
		weeklies.BestKeystoneName = name
		weeklies.BestKeystoneLevel = bestLevel
		weeklies.BestKeystoneTimeInSeconds = bestTime
	end

	char.dungeonScore = C_ChallengeMode.GetOverallDungeonScore()
	char.lastUpdate = time()
end

-- https://warcraft.wiki.gg/wiki/API_C_WeeklyRewards.GetActivityEncounterInfo
local rewardFields = { "ActivitiesReward", "RankedPvPReward", "RaidReward", "AlsoReceiveReward", "ConcessionReward", "WorldReward" }

local function ScanRewardType(rewardType)
	-- https://warcraft.wiki.gg/wiki/API_C_WeeklyRewards.GetActivities
	local activities = C_WeeklyRewards.GetActivities(rewardType)
	
	for _, activity in pairs(activities) do
		
		-- Ex: for M+, index 1 = 0/1,  index 2 = 0/4, index 3 = 0/8 .. we only care about index 3
		if activity.index == 3 then
		
			-- ex: char.MythicPlusReward = progress
			local weeklies = GetWeekliesTable()

			weeklies[rewardFields[activity.type]] = activity.progress
		end
	end
end

local function ScanRewards()
	local e = Enum.WeeklyRewardChestThresholdType
	
	ScanRewardType(e.Activities)
	ScanRewardType(e.RankedPvP)
	ScanRewardType(e.Raid)
	ScanRewardType(e.AlsoReceive)
	ScanRewardType(e.Concession)
	ScanRewardType(e.World)
end

local function ScanRunHistory()
	local includePreviousWeeks = false
	local includeIncompleteRuns = true
	
	local runs = C_MythicPlus.GetRunHistory(includePreviousWeeks, includeIncompleteRuns)
	if not runs or #runs == 0 then return end		-- no runs ? exit
	
	local dungeons = GetDungeonsTable()
	local top10 = {}
	
	-- clear the run history from previous scans
	for mapID, mapInfo in pairs(dungeons) do
		if mapInfo.weeklyRunHistory then
			wipe(mapInfo.weeklyRunHistory)
		end
	end

	-- loop through runs
	for i, runInfo in pairs(runs) do
		local mapID = runInfo.mapChallengeModeID
		local info = GetDungeonMapTable(mapID)

		-- Make room for the run history
		info.weeklyRunHistory = info.weeklyRunHistory or {}		-- Create if it does not exist yet
		TableInsert(info.weeklyRunHistory, { level = runInfo.level, completed = runInfo.completed })
		
		-- Track the top10 completed dungeons
		if runInfo.completed and #top10 < 10 then
			TableInsert(top10, { mapID = mapID, level = runInfo.level })
		end
	end

	-- sort the levels of each map
	for mapID, mapInfo in pairs(dungeons) do
		if mapInfo.weeklyRunHistory then
			TableSort(mapInfo.weeklyRunHistory, SortByLevelDesc)
		end
	end
	
	-- Sort the top 10 runs by level, descending
	TableSort(top10, SortByLevelDesc)

	local weeklies = GetWeekliesTable()
	weeklies.RunHistoryTop10 = top10
end

DataStore:OnAddonLoaded(addonName, function() 
	DataStore:RegisterModule({
		addon = addon,
		addonName = addonName,
		characterTables = {
			["DataStore_Stats_Characters"] = {
				GetStats = function(character, statType)
					local data = character[statType]
					if data then 
						return strsplit("|", data)
					end
				end,
				GetDungeonScore = function(character)
					return character.dungeonScore
				end,
			},
			["DataStore_Stats_Weekly"] = {
				GetWeeklyBestKeystoneName = function(character)
					return character.BestKeystoneName or ""
				end,
				GetWeeklyBestKeystoneLevel = function(character)
					return character.BestKeystoneLevel or 0
				end,
				GetWeeklyBestKeystoneTime = function(character)
					return character.BestKeystoneTimeInSeconds or 0
				end,
				GetWeeklyMythicPlusReward = function(character)
					return character.MythicPlusReward
				end,
				GetWeeklyActivitiesReward = function(character)
					return character.ActivitiesReward
				end,
				GetWeeklyRankedPvPReward = function(character)
					return character.RankedPvPReward
				end,
				GetWeeklyRaidReward = function(character)
					return character.RaidReward
				end,
				GetWeeklyAlsoReceiveReward = function(character)
					return character.AlsoReceiveReward
				end,
				GetWeeklyConcessionReward = function(character)
					return character.ConcessionReward
				end,
				GetWeeklyWorldReward = function(character)
					return character.WorldReward
				end,
				GetWeeklyTop10Runs = function(character)
					return character.RunHistoryTop10
				end,
			},
			["DataStore_Stats_Dungeons"] = {
				GetDungeonStats = function(character)
					return character
				end,
				GetWeeklyRunHistory = function(character, mapID)
					-- local info = character.Dungeons[mapID]
					local info = character[mapID]
					
					if info then
						return info.weeklyRunHistory
					end
				end,
				GetWeeklyBestByDungeon = function(character, mapID)
					-- local info = character.Dungeons[mapID]
					local info = character[mapID]
					
					if info then
						return info.weeklyBestLevel
					end
				end,
			},
		}
	})

	thisCharacter = DataStore:GetCharacterDB("DataStore_Stats_Characters", true)
end)

DataStore:OnPlayerLogin(function() 
	addon:ListenTo("PLAYER_ALIVE", function()
		ScanStats()
		
		-- This call will trigger the "CHALLENGE_MODE_MAPS_UPDATE" event
		-- It is necessary to ensure that the proper best times are read, because when logging on a character, it could still
		-- show the best times of the previous alt until the event is triggered. So clearly, on alt can read another alt's data.
		-- To avoid this, trigger the event from here (not before PLAYER_ALIVE, it's too soon)
		C_MythicPlus.RequestMapInfo()
		
		ScanRunHistory()
	end)
	addon:ListenTo("UNIT_INVENTORY_CHANGED", ScanStats)
	addon:ListenTo("WEEKLY_REWARDS_UPDATE", function() 
		ScanRewards()
		ScanMythicPlusBestForMapInfo()
	end)
	
	addon:ListenTo("CHALLENGE_MODE_MAPS_UPDATE", ScanMythicPlusBestForMapInfo)
	addon:ListenTo("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(event, interactionType)
		if interactionType == Enum.PlayerInteractionType.WeeklyRewards then
			ScanRewards()
		end
	end)	
	addon:ListenTo("PLAYER_ENTERING_WORLD", function(event, isLogin, isReload)
		if isLogin or isReload then
			ScanRewards()
		end
	end)
end)
