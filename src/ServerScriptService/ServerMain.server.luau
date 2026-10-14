-- ServerScriptService/ServerMain.server.luau
local RepStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local GameConfig = require(RepStorage.Configs.GameConfig)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local HotelService = require(ServerScriptService.Services.HotelService)
local GuestService = require(ServerScriptService.Services.GuestService)
local ParanormalService = require(ServerScriptService.Services.ParanormalService)
local StaffService = require(ServerScriptService.Services.StaffService)
local DataService = require(ServerScriptService.Services.DataService)
local MonetizationService = require(ServerScriptService.Services.MonetizationService)

local Network = RepStorage.Network
local RequestUpgrade = Network:WaitForChild("RequestUpgrade")
local InvestigateClue = Network:WaitForChild("InvestigateClue")
local StartCapture = Network:WaitForChild("StartCapture")
local SubmitCaptureAttempt = Network:WaitForChild("SubmitCaptureAttempt")
local AssignStaff = Network:WaitForChild("AssignStaff")
local UnassignStaff = Network:WaitForChild("UnassignStaff")
local LevelUpGhost = Network:WaitForChild("LevelUpGhost")
local ClaimOfflineRewards = Network:WaitForChild("ClaimOfflineRewards")
local OfflineRewardReady = Network:WaitForChild("OfflineRewardReady")
local DismissTutorial = Network:WaitForChild("DismissTutorial")
local UnlockFloor = Network:WaitForChild("UnlockFloor")
local ClaimDailyReward = Network:WaitForChild("ClaimDailyReward")
local RequestPrestige = Network:WaitForChild("RequestPrestige")

-- Handle Upgrade Request (from HUD or Pad)
local function handleUpgradeRequest(player, roomId)
	if typeof(roomId) ~= "string" then
		return false, "Invalid room ID", 0, 0
	end
	if not GameConfig.Rooms[roomId] then
		return false, "Unknown room: " .. tostring(roomId), 0, 0
	end

	local profile = EconomyService.GetProfile(player)
	if not profile then
		return false, "Player data not loaded", 0, 0
	end

	local plot = HotelService.GetPlayerPlot(player)
	if not plot then
		return false, "You do not own a hotel plot", 0, 0
	end

	local roomConfig = GameConfig.Rooms[roomId]
	local floorIdx = roomConfig.Floor or 1
	if floorIdx == 2 and (not profile.FloorsUnlocked or not profile.FloorsUnlocked[2]) then
		return false, "Unlock Floor 2 first before upgrading this room!", profile.Coins, 1
	end

	local currentLevel = profile.RoomLevels[roomId] or 1
	local nextUpgrade = roomConfig.Upgrades[currentLevel + 1]
	if not nextUpgrade then
		return false, "Room is already fully upgraded!", profile.Coins, currentLevel
	end

	if not EconomyService.AcquireLock(player) then
		return false, "Transaction already in progress", profile.Coins, currentLevel
	end

	local ok, status, msg, bal, lv = pcall(function()
		local deducted, newBalance = EconomyService.DeductCoins(player, nextUpgrade.Cost, "Upgrade_" .. roomId)
		if not deducted then
			return false, string.format("Insufficient coins! Need %d 🪙 (You have %d 🪙)", nextUpgrade.Cost, profile.Coins), profile.Coins, currentLevel
		end

		local newLevel = currentLevel + 1
		profile.RoomLevels[roomId] = newLevel
		HotelService.ApplyRoomUpgradeVisuals(plot, roomId, newLevel)

		if roomId == "Room1" and newLevel >= 2 and profile.TutorialStep == 2 then
			EconomyService.SetTutorialStep(player, 3)
		end

		EconomyService.SyncPlayerState(player)
		return true, string.format("Upgraded %s to Level %d!", roomConfig.Name, newLevel), newBalance, newLevel
	end)

	EconomyService.ReleaseLock(player)

	if not ok then
		return false, "Internal error: " .. tostring(status), profile.Coins, currentLevel
	end

	return status, msg, bal, lv
end

-- Handle Floor Unlock Request
local function handleUnlockFloorRequest(player, floorIndex)
	local plot = HotelService.GetPlayerPlot(player)
	if not plot then
		return false, "You do not own a hotel plot"
	end

	local success, msg = EconomyService.UnlockFloor(player, floorIndex)
	if success then
		HotelService.UnlockPlotFloor(plot, floorIndex)
		print(string.format("[Ghostshift] %s unlocked Floor %d!", player.Name, floorIndex))
	end
	return success, msg
end

-- Handle Prestige / Grand Renovation Request
local function handlePrestigeRequest(player)
	local plot = HotelService.GetPlayerPlot(player)
	if not plot then
		return false, "You do not own a hotel plot"
	end

	local success, msg = EconomyService.RequestPrestige(player)
	if success then
		-- Reset room visuals on plot
		for _, rId in ipairs({"Room1", "Room2", "Room3", "Room4"}) do
			HotelService.ResetRoomVisuals(plot, rId)
			HotelService.UpdatePadDisplay(plot, rId, 1)
		end
		HotelService.LockPlotFloor(plot, 2)

		-- Update plot sign with star badge
		local sign = plot:FindFirstChild("Structure") and plot.Structure:FindFirstChild("SignBoard")
		if sign and sign:FindFirstChild("SignGui") and sign.SignGui:FindFirstChild("OwnerLabel") then
			local prof = EconomyService.GetProfile(player)
			local stars = prof and prof.ReputationStars or 1
			sign.SignGui.OwnerLabel.Text = string.format("%s %s - %s's Hotel", string.rep("★", stars), plot.Name, player.Name)
		end
	end
	return success, msg
end

RequestUpgrade.OnServerInvoke = function(player, roomId)
	return handleUpgradeRequest(player, roomId)
end

InvestigateClue.OnServerInvoke = function(player, clueId)
	return ParanormalService.InvestigateClue(player, clueId)
end

StartCapture.OnServerInvoke = function(player)
	return ParanormalService.StartCapture(player)
end

SubmitCaptureAttempt.OnServerInvoke = function(player, token, normalizedPos)
	return ParanormalService.SubmitCaptureAttempt(player, token, normalizedPos)
end

AssignStaff.OnServerInvoke = function(player, slotIndex, ghostId)
	return StaffService.AssignStaff(player, slotIndex, ghostId)
end

UnassignStaff.OnServerInvoke = function(player, slotIndex)
	return StaffService.UnassignStaff(player, slotIndex)
end

LevelUpGhost.OnServerInvoke = function(player, ghostId)
	return StaffService.LevelUpGhost(player, ghostId)
end

ClaimOfflineRewards.OnServerInvoke = function(player)
	return DataService.ClaimOfflineRewards(player)
end

DismissTutorial.OnServerInvoke = function(player)
	return DataService.DismissTutorial(player)
end

UnlockFloor.OnServerInvoke = function(player, floorIndex)
	return handleUnlockFloorRequest(player, floorIndex)
end

ClaimDailyReward.OnServerInvoke = function(player, questId)
	return EconomyService.ClaimDailyReward(player, questId)
end

RequestPrestige.OnServerInvoke = function(player)
	return handlePrestigeRequest(player)
end

-- Init Services
DataService.Init(EconomyService)
MonetizationService.Init(EconomyService)
HotelService.Init(EconomyService, handleUpgradeRequest, handleUnlockFloorRequest)
GuestService.Init(EconomyService, HotelService, MonetizationService)
GuestService.Start()

ParanormalService.Init(EconomyService, HotelService)
ParanormalService.Start()

StaffService.Init(EconomyService, HotelService)
StaffService.Start()

local function setupPlayer(player)
	print("[Ghostshift] Setting up player:", player.Name, player.UserId)
	local profile, isNew, offlineRewards = EconomyService.InitializePlayer(player)
	print("[Ghostshift] Profile initialized. Starting Coins:", profile and profile.Coins)
	
	local plot = HotelService.AssignPlot(player)
	if not plot then
		warn("[Ghostshift] No plots available for " .. player.Name)
	else
		print("[Ghostshift] Assigned plot:", plot.Name, "to", player.Name)

		-- Restore Floor 2 if already unlocked in saved profile
		if profile and profile.FloorsUnlocked and profile.FloorsUnlocked[2] == true then
			HotelService.UnlockPlotFloor(plot, 2)
		end

		-- Restore room upgrade visuals for loaded profile
		if profile and profile.RoomLevels then
			for roomId, level in pairs(profile.RoomLevels) do
				if level > 1 then
					HotelService.ApplyRoomUpgradeVisuals(plot, roomId, level)
				end
			end
		end

		-- Restore visual staff models for assigned staff
		if profile and profile.AssignedStaff then
			for slotIndex, ghostId in pairs(profile.AssignedStaff) do
				if ghostId then
					StaffService.UpdatePlotVisualStaff(player, slotIndex, ghostId)
				end
			end
		end
	end

	-- Notify client if offline earnings are pending
	if offlineRewards and (offlineRewards.Coins > 0 or offlineRewards.Ectoplasm > 0) then
		task.delay(1.5, function()
			if player and player.Parent then
				OfflineRewardReady:FireClient(player, offlineRewards)
			end
		end)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	local plot = HotelService.GetPlayerPlot(player)
	if plot then
		GuestService.CleanupPlotGuests(plot)
		ParanormalService.CleanupPlot(plot)
		StaffService.CleanupPlot(plot)
		HotelService.ReleasePlot(player)
	end
	EconomyService.RemovePlayer(player)
end)

game:BindToClose(function()
	DataService.BindToClose()
end)

print("[Ghostshift] ServerMain (Phase 5: Multi-Floor, Daily Quests, Guest Variety, Reputation & Monetization) initialized successfully.")
