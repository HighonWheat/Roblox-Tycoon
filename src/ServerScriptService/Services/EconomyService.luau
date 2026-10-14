-- ServerScriptService/Services/EconomyService.luau
local RepStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")

local GameConfig = require(RepStorage.Configs.GameConfig)
local GhostConfig = require(RepStorage.Configs.GhostConfig)
local Network = RepStorage.Network
local PlayerStateUpdated = Network.PlayerStateUpdated

local EconomyService = {}
_G.GhostshiftProfiles = _G.GhostshiftProfiles or {}
local profiles = _G.GhostshiftProfiles
EconomyService.Profiles = _G.GhostshiftProfiles
local locks = {}

local DataService = require(SSS.Services.DataService)

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
	for roomId, level in pairs(profile.RoomLevels or {}) do
		local roomConfig = GameConfig.Rooms[roomId]
		if roomConfig and roomConfig.Upgrades[level] then
			total = total + roomConfig.Upgrades[level].Income
		end
	end
	return total
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
			RoomLevels = p.RoomLevels,
			DiscoveredGhosts = p.DiscoveredGhosts,
			AssignedStaff = p.AssignedStaff,
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
	
	-- Advance tutorial to step 5 (Staff Assignment) if on step 4
	if p.TutorialStep == 4 then
		EconomyService.SetTutorialStep(player, 5)
	end
	
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

	-- Requires 1 duplicate copy per level
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

	-- Check if already assigned to other slot
	local otherSlot = (slotIndex == 1 and 2 or 1)
	if p.AssignedStaff[otherSlot] == ghostId and ghost.CopiesOwned < 2 then
		return false, "This ghost is already assigned to Slot " .. otherSlot
	end

	p.AssignedStaff[slotIndex] = ghostId

	-- Advance tutorial to step 6 (Master Hotelier) if on step 5
	if p.TutorialStep == 5 then
		EconomyService.SetTutorialStep(player, 6)
	end

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
