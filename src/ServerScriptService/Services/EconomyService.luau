-- ServerScriptService/Services/EconomyService.luau
local RepStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")

local GameConfig = require(RepStorage.Configs.GameConfig:Clone())
local GhostConfig = require(RepStorage.Configs.GhostConfig:Clone())
local Network = RepStorage.Network
local PlayerStateUpdated = Network.PlayerStateUpdated
local DailyQuestsUpdated = Network:FindFirstChild("DailyQuestsUpdated")
local FloorUnlockedEvent = Network:FindFirstChild("FloorUnlocked")

local EconomyService = {}
_G.GhostshiftProfiles = _G.GhostshiftProfiles or {}
local profiles = _G.GhostshiftProfiles
EconomyService.Profiles = _G.GhostshiftProfiles
local locks = {}

local DataService = require(SSS.Services.DataService:Clone())

local function getPlayerKey(player)
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player.UserId
	elseif typeof(player) == "table" and player.UserId then
		return player.UserId
	else
		return player
	end
end

function EconomyService.CalculateIncomeRate(profile)
	local total = 0
	local floorsUnlocked = profile.FloorsUnlocked or { [1] = true, [2] = false }

	for roomId, level in pairs(profile.RoomLevels or {}) do
		local roomConfig = GameConfig.Rooms[roomId]
		if roomConfig and roomConfig.Upgrades[level] then
			local floorIdx = roomConfig.Floor or 1
			if floorsUnlocked[floorIdx] == true then
				total = total + roomConfig.Upgrades[level].Income
			end
		end
	end

	-- Apply Reputation (Prestige) Multiplier
	local stars = profile.ReputationStars or 0
	local starMult = 1.0 + stars * (GameConfig.Reputation and GameConfig.Reputation.MultiplierPerStar or 0.15)
	return math.floor(total * starMult)
end

function EconomyService.InitializePlayer(player)
	local key = getPlayerKey(player)
	local profile, isNew, offlineRewards = DataService.LoadPlayerProfile(player)

	profiles[key] = profile
	if typeof(player) == "Instance" then
		profiles[player] = profile
	end

	EconomyService.SyncPlayerState(player)
	return profile, isNew, offlineRewards
end

function EconomyService.GetProfile(player)
	local key = getPlayerKey(player)
	return profiles[key] or profiles[player]
end

function EconomyService.GetCoins(player)
	local p = EconomyService.GetProfile(player)
	return p and p.Coins or 0
end

function EconomyService.GetEctoplasm(player)
	local p = EconomyService.GetProfile(player)
	return p and p.Ectoplasm or 0
end

function EconomyService.SyncPlayerState(player)
	local p = EconomyService.GetProfile(player)
	if not p then return end
	local incomeRate = EconomyService.CalculateIncomeRate(p)
	local tutStep = p.TutorialStep or 1
	local tutorialData = (GameConfig.Tutorial and GameConfig.Tutorial[tutStep]) or {
		Title = "Ghostshift Hotelier",
		Description = "Manage your hotel and capture roaming spirits!"
	}

	if typeof(player) == "Instance" and player:IsA("Player") then
		PlayerStateUpdated:FireClient(player, {
			Coins = p.Coins,
			Ectoplasm = p.Ectoplasm,
			IncomeRate = incomeRate,
			FloorsUnlocked = p.FloorsUnlocked or { [1] = true, [2] = false },
			RoomLevels = p.RoomLevels,
			DiscoveredGhosts = p.DiscoveredGhosts,
			AssignedStaff = p.AssignedStaff,
			ReputationStars = p.ReputationStars or 0,
			DailyObjectives = p.DailyObjectives,
			TutorialStep = p.TutorialStep,
			TutorialDismissed = p.TutorialDismissed == true,
			TutorialTitle = tutorialData.Title,
			TutorialDescription = tutorialData.Description,
			TotalGuestsServed = p.TotalGuestsServed or 0,
			TotalParanormalSolved = p.TotalParanormalSolved or 0,
		})
	end
end

function EconomyService.AddCoins(player, amount, reason)
	if amount <= 0 then return end
	local p = EconomyService.GetProfile(player)
	if not p then return end
	p.Coins = p.Coins + amount

	-- Quest tracking for Earnings
	EconomyService.IncrementQuestProgress(player, "Earnings", amount)

	EconomyService.SyncPlayerState(player)
	return p.Coins
end

function EconomyService.DeductCoins(player, amount, reason)
	if amount <= 0 then return false, "Invalid amount" end
	local p = EconomyService.GetProfile(player)
	if not p then return false, "No profile" end
	if p.Coins < amount then
		return false, "Insufficient coins"
	end
	p.Coins = p.Coins - amount
	EconomyService.SyncPlayerState(player)
	return true, p.Coins
end

function EconomyService.AddEctoplasm(player, amount, reason)
	if amount <= 0 then return end
	local p = EconomyService.GetProfile(player)
	if not p then return end
	p.Ectoplasm = p.Ectoplasm + amount
	EconomyService.SyncPlayerState(player)
	return p.Ectoplasm
end

function EconomyService.DeductEctoplasm(player, amount, reason)
	if amount <= 0 then return false, "Invalid amount" end
	local p = EconomyService.GetProfile(player)
	if not p then return false, "No profile" end
	if p.Ectoplasm < amount then
		return false, "Insufficient ectoplasm"
	end
	p.Ectoplasm = p.Ectoplasm - amount
	EconomyService.SyncPlayerState(player)
	return true, p.Ectoplasm
end

function EconomyService.AddDiscoveredGhost(player, ghostId)
	local p = EconomyService.GetProfile(player)
	if not p then return false, 0 end
	local isNew = false
	if not p.DiscoveredGhosts[ghostId] then
		p.DiscoveredGhosts[ghostId] = {
			Id = ghostId,
			Level = 1,
			CopiesOwned = 1,
			DiscoveredAt = os.time(),
		}
		isNew = true
	else
		p.DiscoveredGhosts[ghostId].CopiesOwned = p.DiscoveredGhosts[ghostId].CopiesOwned + 1
	end
	p.TotalParanormalSolved = (p.TotalParanormalSolved or 0) + 1
	
	if p.TutorialStep == 4 then
		EconomyService.SetTutorialStep(player, 5)
	end
	
	EconomyService.IncrementQuestProgress(player, "Haunting", 1)

	EconomyService.SyncPlayerState(player)
	return isNew, p.DiscoveredGhosts[ghostId].CopiesOwned
end

function EconomyService.HasDiscoveredGhost(player, ghostId)
	local p = EconomyService.GetProfile(player)
	return p and p.DiscoveredGhosts[ghostId] ~= nil and p.DiscoveredGhosts[ghostId].CopiesOwned >= 1
end

function EconomyService.LevelUpGhost(player, ghostId)
	local p = EconomyService.GetProfile(player)
	if not p then return false, "Profile not found" end
	local ghost = p.DiscoveredGhosts[ghostId]
	if not ghost then return false, "Ghost not discovered" end

	if ghost.CopiesOwned < 2 then
		return false, string.format("Need at least 1 duplicate copy to level up! (Owned: %d)", ghost.CopiesOwned)
	end

	if ghost.Level >= 5 then
		return false, "Ghost is already at maximum level!"
	end

	ghost.CopiesOwned = ghost.CopiesOwned - 1
	ghost.Level = ghost.Level + 1
	EconomyService.SyncPlayerState(player)
	return true, ghost.Level, ghost.CopiesOwned
end

function EconomyService.AssignStaff(player, slotIndex, ghostId)
	local p = EconomyService.GetProfile(player)
	if not p then return false, "Profile not found" end
	if slotIndex ~= 1 and slotIndex ~= 2 then
		return false, "Invalid staff slot"
	end

	local ghost = p.DiscoveredGhosts[ghostId]
	if not ghost or ghost.CopiesOwned < 1 then
		return false, "You do not own this ghost"
	end

	local otherSlot = (slotIndex == 1 and 2 or 1)
	if p.AssignedStaff[otherSlot] == ghostId and ghost.CopiesOwned < 2 then
		return false, "This ghost is already assigned to Slot " .. otherSlot
	end

	p.AssignedStaff[slotIndex] = ghostId

	if p.TutorialStep == 5 then
		EconomyService.SetTutorialStep(player, 6)
	end

	EconomyService.IncrementQuestProgress(player, "StaffDuty", 1)

	EconomyService.SyncPlayerState(player)
	return true, p.AssignedStaff
end

function EconomyService.UnassignStaff(player, slotIndex)
	local p = EconomyService.GetProfile(player)
	if not p then return false, "Profile not found" end
	if slotIndex ~= 1 and slotIndex ~= 2 then
		return false, "Invalid staff slot"
	end

	p.AssignedStaff[slotIndex] = nil
	EconomyService.SyncPlayerState(player)
	return true, p.AssignedStaff
end

function EconomyService.GetAssignedStaff(player)
	local p = EconomyService.GetProfile(player)
	return p and p.AssignedStaff or { [1] = nil, [2] = nil }
end

-- Unlock Floor 2
function EconomyService.UnlockFloor(player, floorIndex)
	local p = EconomyService.GetProfile(player)
	if not p then return false, "Profile not found" end

	if floorIndex ~= 2 then
		return false, "Invalid floor index"
	end

	if p.FloorsUnlocked and p.FloorsUnlocked[2] == true then
		return false, "Floor 2 is already unlocked!"
	end

	local floorConfig = GameConfig.Floors[2]
	if not floorConfig then return false, "Floor config missing" end

	-- Check prerequisites
	for reqRoom, reqLv in pairs(floorConfig.RequiredRoomLevels or {}) do
		local curLv = p.RoomLevels[reqRoom] or 1
		if curLv < reqLv then
			return false, string.format("Requires %s to be at least Level %d!", reqRoom, reqLv)
		end
	end

	if p.Coins < floorConfig.Cost then
		return false, string.format("Insufficient coins! Need %d 🪙 (You have %d 🪙)", floorConfig.Cost, p.Coins)
	end

	if not EconomyService.AcquireLock(player) then
		return false, "Transaction in progress"
	end

	p.Coins = p.Coins - floorConfig.Cost
	p.FloorsUnlocked[2] = true

	DataService.SavePlayerProfile(player)
	EconomyService.ReleaseLock(player)

	EconomyService.SyncPlayerState(player)

	if FloorUnlockedEvent and typeof(player) == "Instance" and player:IsA("Player") then
		FloorUnlockedEvent:FireClient(player, 2)
	end

	return true, "Successfully unlocked Floor 2 (Spectral Wing)!"
end

-- Request Grand Renovation (Prestige / Reputation)
function EconomyService.RequestPrestige(player)
	local p = EconomyService.GetProfile(player)
	if not p then return false, "Profile not found" end

	local repConfig = GameConfig.Reputation or {}
	local currentStars = p.ReputationStars or 0

	if currentStars >= (repConfig.MaxStars or 5) then
		return false, "You have already reached maximum Hotel Reputation (5 Stars)!"
	end

	-- Eligibility check: Floor 2 must be unlocked and Room 1 & 2 at least Lv 2
	if not p.FloorsUnlocked or not p.FloorsUnlocked[2] then
		return false, "You must unlock Floor 2 before initiating a Grand Renovation!"
	end

	for rId, minLv in pairs({ Room1 = 2, Room2 = 2 }) do
		if (p.RoomLevels[rId] or 1) < minLv then
			return false, string.format("%s must be at least Level %d to prestige!", rId, minLv)
		end
	end

	if not EconomyService.AcquireLock(player) then
		return false, "Transaction in progress"
	end

	-- Execute atomic reset
	p.ReputationStars = currentStars + 1
	p.Coins = GameConfig.StartingCoins or 100
	p.FloorsUnlocked = { [1] = true, [2] = false }
	p.RoomLevels = { Room1 = 1, Room2 = 1, Room3 = 1, Room4 = 1 }

	DataService.SavePlayerProfile(player)
	EconomyService.ReleaseLock(player)

	EconomyService.SyncPlayerState(player)
	print(string.format("[EconomyService] %s ascended to Hotel Reputation Star %d!", player.Name, p.ReputationStars))

	return true, string.format("Grand Renovation Complete! You earned Hotel Reputation Star ★%d (+%d%% permanent income)!",
		p.ReputationStars, math.floor(p.ReputationStars * (repConfig.MultiplierPerStar or 0.15) * 100))
end

-- Daily Objectives Management
function EconomyService.IncrementQuestProgress(player, questId, amount)
	local p = EconomyService.GetProfile(player)
	if not p or not p.DailyObjectives or not p.DailyObjectives.Quests then return end

	local quest = p.DailyObjectives.Quests[questId]
	if quest and not quest.Claimed then
		quest.Current = math.min(quest.Target, quest.Current + amount)
		if DailyQuestsUpdated and typeof(player) == "Instance" and player:IsA("Player") then
			DailyQuestsUpdated:FireClient(player, p.DailyObjectives)
		end
	end
end

function EconomyService.ClaimDailyReward(player, questId)
	local p = EconomyService.GetProfile(player)
	if not p or not p.DailyObjectives or not p.DailyObjectives.Quests then
		return false, "No active daily objectives"
	end

	local quest = p.DailyObjectives.Quests[questId]
	if not quest then
		return false, "Unknown quest"
	end

	if quest.Claimed then
		return false, "Quest reward has already been claimed today!"
	end

	if quest.Current < quest.Target then
		return false, string.format("Quest not completed yet! (%d/%d)", quest.Current, quest.Target)
	end

	local tpl = GameConfig.DailyObjectives and GameConfig.DailyObjectives[questId]
	if not tpl then return false, "Template not found" end

	quest.Claimed = true

	if tpl.RewardCoins and tpl.RewardCoins > 0 then
		p.Coins = p.Coins + tpl.RewardCoins
	end
	if tpl.RewardEctoplasm and tpl.RewardEctoplasm > 0 then
		p.Ectoplasm = p.Ectoplasm + tpl.RewardEctoplasm
	end

	DataService.SavePlayerProfile(player)
	EconomyService.SyncPlayerState(player)

	return true, string.format("Claimed reward: +%d 🪙 and +%d 🟣!", tpl.RewardCoins or 0, tpl.RewardEctoplasm or 0)
end

function EconomyService.SetTutorialStep(player, step)
	local p = EconomyService.GetProfile(player)
	if not p then return end
	if step > p.TutorialStep then
		p.TutorialStep = step
		EconomyService.SyncPlayerState(player)
	end
end

function EconomyService.IncrementGuestsServed(player)
	local p = EconomyService.GetProfile(player)
	if not p then return end
	p.TotalGuestsServed = (p.TotalGuestsServed or 0) + 1
	if p.TutorialStep == 1 then
		EconomyService.SetTutorialStep(player, 2)
	end

	EconomyService.IncrementQuestProgress(player, "GuestStays", 1)
	EconomyService.SyncPlayerState(player)
end

function EconomyService.AcquireLock(player)
	local key = getPlayerKey(player)
	if locks[key] then return false end
	locks[key] = true
	return true
end

function EconomyService.ReleaseLock(player)
	local key = getPlayerKey(player)
	locks[key] = nil
end

function EconomyService.RemovePlayer(player)
	local key = getPlayerKey(player)
	if DataService then
		DataService.UnloadPlayer(player)
	end
	profiles[key] = nil
	if typeof(player) == "Instance" then
		profiles[player] = nil
	end
	locks[key] = nil
end

return EconomyService
