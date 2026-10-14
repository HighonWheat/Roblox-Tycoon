local RepStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(RepStorage.Configs.GameConfig)
local Network = RepStorage.Network
local PlayerStateUpdated = Network.PlayerStateUpdated

local EconomyService = {}
_G.GhostshiftProfiles = _G.GhostshiftProfiles or {}
local profiles = _G.GhostshiftProfiles
local locks = {}

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
	for roomId, level in pairs(profile.RoomLevels) do
		local roomConfig = GameConfig.Rooms[roomId]
		if roomConfig and roomConfig.Upgrades[level] then
			total = total + roomConfig.Upgrades[level].Income
		end
	end
	return total
end

function EconomyService.InitializePlayer(player)
	local key = getPlayerKey(player)
	profiles[key] = {
		Coins = GameConfig.StartingCoins,
		Ectoplasm = GameConfig.StartingEctoplasm or 0,
		RoomLevels = {
			Room1 = 1,
			Room2 = 1,
		},
		DiscoveredGhosts = {},
		TutorialStep = 1,
		TotalGuestsServed = 0,
		TotalParanormalSolved = 0,
	}
	if typeof(player) == "Instance" then
		profiles[player] = profiles[key]
	end
	EconomyService.SyncPlayerState(player)
	return profiles[key]
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
	local tutorialData = GameConfig.Tutorial[p.TutorialStep] or GameConfig.Tutorial[5]

	if typeof(player) == "Instance" and player:IsA("Player") then
		PlayerStateUpdated:FireClient(player, {
			Coins = p.Coins,
			Ectoplasm = p.Ectoplasm,
			IncomeRate = incomeRate,
			RoomLevels = p.RoomLevels,
			DiscoveredGhosts = p.DiscoveredGhosts,
			TutorialStep = p.TutorialStep,
			TutorialTitle = tutorialData.Title,
			TutorialDescription = tutorialData.Description,
			TotalGuestsServed = p.TotalGuestsServed,
			TotalParanormalSolved = p.TotalParanormalSolved,
		})
	end
end

function EconomyService.AddCoins(player, amount, reason)
	if amount <= 0 then return end
	local p = EconomyService.GetProfile(player)
	if not p then return end
	p.Coins = p.Coins + amount
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
	if not p then return false end
	local isNew = false
	if not p.DiscoveredGhosts[ghostId] then
		p.DiscoveredGhosts[ghostId] = {
			Id = ghostId,
			DiscoveredAt = os.time(),
			Level = 1,
		}
		isNew = true
	end
	p.TotalParanormalSolved = p.TotalParanormalSolved + 1
	EconomyService.SyncPlayerState(player)
	return isNew
end

function EconomyService.HasDiscoveredGhost(player, ghostId)
	local p = EconomyService.GetProfile(player)
	return p and p.DiscoveredGhosts[ghostId] ~= nil
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
	p.TotalGuestsServed = p.TotalGuestsServed + 1
	if p.TutorialStep == 1 then
		EconomyService.SetTutorialStep(player, 2)
	end
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
	profiles[key] = nil
	if typeof(player) == "Instance" then
		profiles[player] = nil
	end
	locks[key] = nil
end

return EconomyService
