local RepStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local GameConfig = require(RepStorage.Configs.GameConfig)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local HotelService = require(ServerScriptService.Services.HotelService)
local GuestService = require(ServerScriptService.Services.GuestService)
local ParanormalService = require(ServerScriptService.Services.ParanormalService)

local Network = RepStorage.Network
local RequestUpgrade = Network.RequestUpgrade
local InvestigateClue = Network.InvestigateClue
local StartCapture = Network.StartCapture
local SubmitCaptureAttempt = Network.SubmitCaptureAttempt

-- Handle Upgrade Request (from HUD or Pad)
local function handleUpgradeRequest(player, roomId)
	if typeof(roomId) ~= "string" then
		return false, "Invalid room ID", 0, 0
	end
	if roomId ~= "Room1" and roomId ~= "Room2" then
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

	local currentLevel = profile.RoomLevels[roomId] or 1
	local roomConfig = GameConfig.Rooms[roomId]
	if not roomConfig then
		return false, "Room configuration not found", profile.Coins, currentLevel
	end

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
		elseif roomId == "Room2" and newLevel >= 2 and profile.TutorialStep == 3 then
			EconomyService.SetTutorialStep(player, 4)
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

-- Init Services
HotelService.Init(EconomyService, handleUpgradeRequest)
GuestService.Init(EconomyService, HotelService)
GuestService.Start()

ParanormalService.Init(EconomyService, HotelService)
ParanormalService.Start()

local function setupPlayer(player)
	local profile = EconomyService.InitializePlayer(player)
	local plot = HotelService.AssignPlot(player)
	if not plot then
		warn("[Ghostshift] No plots available for " .. player.Name)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	local plot = HotelService.GetPlayerPlot(player)
	if plot then
		GuestService.CleanupPlotGuests(plot)
		ParanormalService.CleanupPlot(plot)
		HotelService.ReleasePlot(player)
	end
	EconomyService.RemovePlayer(player)
end)

print("[Ghostshift] ServerMain (Phase 2 with ParanormalService) initialized successfully.")
