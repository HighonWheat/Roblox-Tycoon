local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(RepStorage.Configs.GameConfig)
local GhostConfig = require(RepStorage.Configs.GhostConfig)
local Formatters = require(RepStorage.Shared.Formatters)

local Network = RepStorage.Network
local RequestUpgrade = Network.RequestUpgrade
local PlayerStateUpdated = Network.PlayerStateUpdated
local GuestStateChanged = Network.GuestStateChanged
local ParanormalEventUpdated = Network.ParanormalEventUpdated
local SubmitCaptureAttempt = Network.SubmitCaptureAttempt

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HotelHUD")
local captureGui = playerGui:WaitForChild("CaptureMinigameGui")

local HUDController = {}

function HUDController.Init()
	local stats = hud:WaitForChild("StatsContainer")
	local coinsLabel = stats.CoinsBadge.ValueLabel
	local incomeLabel = stats.IncomeBadge.ValueLabel
	local ectoLabel = stats.EctoBadge.ValueLabel
	local ghostLabel = stats.GhostBadge.ValueLabel

	local tutBanner = hud:WaitForChild("TutorialBanner")
	local tutTitle = tutBanner.TitleLabel
	local tutDesc = tutBanner.DescLabel

	local alertBanner = hud:WaitForChild("HauntingAlertBanner")
	local alertLabel = alertBanner.AlertLabel

	local toggleBtn = hud:WaitForChild("ToggleUpgradeBtn")
	local modal = hud:WaitForChild("UpgradeModal")
	local closeBtn = modal.CloseBtn
	local toast = modal.ToastLabel
	local cardsFrame = modal.CardsFrame

	-- Minigame Elements
	local minigameModal = captureGui:WaitForChild("MainModal")
	local needle = minigameModal.TrackFrame.Needle
	local targetZone = minigameModal.TrackFrame.TargetZone
	local attemptsLabel = minigameModal.AttemptsLabel
	local catchBtn = minigameModal.CatchBtn
	local minigameStatus = minigameModal.StatusLabel
	local abortBtn = minigameModal.AbortBtn

	local isMinigameActive = false
	local currentSessionToken = nil
	local minigameConnection = nil
	local needlePos = 0.5
	local oscillationSpeed = 2.2

	toggleBtn.MouseButton1Click:Connect(function()
		modal.Visible = not modal.Visible
	end)

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	abortBtn.MouseButton1Click:Connect(function()
		HUDController.CloseMinigame()
	end)

	local function showToast(message, isSuccess)
		toast.Text = message
		toast.TextColor3 = isSuccess and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
		task.delay(3, function()
			if toast.Text == message then
				toast.Text = "Tip: Upgrade rooms to earn more coins!"
				toast.TextColor3 = Color3.fromRGB(230, 220, 255)
			end
		end)
	end

	local function setupCard(roomId)
		local card = cardsFrame:WaitForChild(roomId .. "Card")
		local btn = card:WaitForChild("UpgradeBtn")

		btn.MouseButton1Click:Connect(function()
			btn.Text = "Upgrading..."
			local success, message, newBal, newLv = RequestUpgrade:InvokeServer(roomId)
			showToast(message, success)
		end)
	end

	setupCard("Room1")
	setupCard("Room2")

	-- Update UI with latest server state
	local function updateUI(data)
		coinsLabel.Text = Formatters.FormatNumber(data.Coins) .. " Coins"
		incomeLabel.Text = "+" .. Formatters.FormatNumber(data.IncomeRate) .. " / Stay"
		ectoLabel.Text = Formatters.FormatNumber(data.Ectoplasm or 0) .. " Ectoplasm"

		local ghostCount = 0
		if data.DiscoveredGhosts then
			for _ in pairs(data.DiscoveredGhosts) do
				ghostCount = ghostCount + 1
			end
		end
		ghostLabel.Text = string.format("Ghosts: %d/1", ghostCount)

		tutTitle.Text = data.TutorialTitle or "Ghostshift Tutorial"
		tutDesc.Text = data.TutorialDescription or ""

		-- Update Room Cards
		for _, roomId in ipairs({"Room1", "Room2"}) do
			local card = cardsFrame:FindFirstChild(roomId .. "Card")
			if card then
				local currentLv = data.RoomLevels[roomId] or 1
				local roomDef = GameConfig.Rooms[roomId]
				local nextUpgrade = roomDef.Upgrades[currentLv + 1]

				card.LevelLabel.Text = "Level " .. currentLv
				local curIncome = roomDef.Upgrades[currentLv] and roomDef.Upgrades[currentLv].Income or 15
				card.IncomeLabel.Text = "+" .. curIncome .. " 🪙 / stay"

				local btn = card.UpgradeBtn
				if nextUpgrade then
					local diff = nextUpgrade.Income - curIncome
					card.NextUpgradeLabel.Text = string.format("Next: %s (+%d income)", nextUpgrade.Description, diff)
					btn.Text = string.format("Upgrade (%d 🪙)", nextUpgrade.Cost)
					if data.Coins >= nextUpgrade.Cost then
						btn.BackgroundColor3 = Color3.fromRGB(110, 45, 170)
						btn.TextColor3 = Color3.fromRGB(255, 230, 120)
					else
						btn.BackgroundColor3 = Color3.fromRGB(60, 45, 75)
						btn.TextColor3 = Color3.fromRGB(180, 160, 190)
					end
				else
					card.NextUpgradeLabel.Text = "Fully Renovated to Maximum Level!"
					btn.Text = "★ MAX LEVEL ★"
					btn.BackgroundColor3 = Color3.fromRGB(45, 35, 55)
					btn.TextColor3 = Color3.fromRGB(150, 140, 160)
				end
			end
		end
	end

	PlayerStateUpdated.OnClientEvent:Connect(function(data)
		updateUI(data)
	end)

	GuestStateChanged.OnClientEvent:Connect(function(eventData)
		if eventData.Event == "StayCompleted" then
			showToast(string.format("✨ Guest completed stay in %s! (+%d 🪙)", eventData.RoomId, eventData.Income), true)
		end
	end)

	-- Minigame Oscillate Loop
	local function startNeedleOscillation()
		if minigameConnection then minigameConnection:Disconnect() end
		local t = 0
		minigameConnection = RunService.RenderStepped:Connect(function(dt)
			t = t + dt * oscillationSpeed
			-- Ping-pong between 0.05 and 0.95
			needlePos = 0.5 + 0.45 * math.sin(t * math.pi)
			needle.Position = UDim2.new(needlePos, 0, 0, -2)
		end)
	end

	function HUDController.CloseMinigame()
		isMinigameActive = false
		currentSessionToken = nil
		if minigameConnection then
			minigameConnection:Disconnect()
			minigameConnection = nil
		end
		minigameModal.Visible = false
	end

	local function doCaptureAttempt()
		if not isMinigameActive or not currentSessionToken then return end
		catchBtn.Text = "CHECKING..."
		catchBtn.Active = false

		local success, result = SubmitCaptureAttempt:InvokeServer(currentSessionToken, needlePos)

		if success then
			minigameStatus.Text = "✨ CONTAINMENT SUCCESSFUL! ✨"
			minigameStatus.TextColor3 = Color3.fromRGB(100, 255, 180)
			catchBtn.Text = "SPIRIT TRAPPED!"
			catchBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 120)

			task.delay(1.8, function()
				HUDController.CloseMinigame()
			end)
		else
			if result and result.RetriesLeft and result.RetriesLeft > 0 then
				attemptsLabel.Text = string.format("Attempts Remaining: %d / 2", result.RetriesLeft)
				minigameStatus.Text = result.Message or "Missed target! Try again!"
				minigameStatus.TextColor3 = Color3.fromRGB(255, 140, 140)
				catchBtn.Text = "⚡ STABILIZE & CONTAIN"
				catchBtn.Active = true
			else
				minigameStatus.Text = result and result.Message or "Spirit escaped!"
				minigameStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
				catchBtn.Text = "FAILED"
				catchBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
				task.delay(1.8, function()
					HUDController.CloseMinigame()
				end)
			end
		end
	end

	catchBtn.MouseButton1Click:Connect(doCaptureAttempt)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if isMinigameActive and not gameProcessed then
			if input.KeyCode == Enum.KeyCode.Space then
				doCaptureAttempt()
			end
		end
	end)

	-- Handle Paranormal Events from Server
	ParanormalEventUpdated.OnClientEvent:Connect(function(eventData)
		if eventData.Event == "HauntingStarted" then
			alertBanner.Visible = true
			alertBanner.BackgroundColor3 = Color3.fromRGB(45, 18, 35)
			alertLabel.Text = string.format("⚠️ HAUNTING IN %s! Investigate the clues!", eventData.RoomName or eventData.RoomId)
		elseif eventData.Event == "ClueFound" then
			alertBanner.Visible = true
			alertLabel.Text = string.format("🔎 Clues Discovered: (%d/%d)! (+%d Ectoplasm)", eventData.ClaimedCount, eventData.TotalClues, eventData.BonusEctoplasm or 5)
		elseif eventData.Event == "CaptureReady" then
			alertBanner.Visible = true
			alertBanner.BackgroundColor3 = Color3.fromRGB(18, 45, 40)
			alertLabel.Text = string.format("⚡ SPIRIT MANIFESTED! Approach %s to contain him!", eventData.GhostName or "Jasper")
		elseif eventData.Event == "OpenCaptureMinigame" then
			currentSessionToken = eventData.Token
			isMinigameActive = true

			targetZone.Position = UDim2.new(eventData.TargetMin or 0.35, 0, 0, 0)
			targetZone.Size = UDim2.new((eventData.TargetMax or 0.65) - (eventData.TargetMin or 0.35), 0, 1, 0)

			attemptsLabel.Text = string.format("Attempts Remaining: %d / 2", eventData.AttemptsLeft or 2)
			minigameStatus.Text = "Stop the needle inside the green zone!"
			minigameStatus.TextColor3 = Color3.fromRGB(200, 190, 220)
			catchBtn.Text = "⚡ STABILIZE & CONTAIN [SPACE / TAP]"
			catchBtn.Active = true
			catchBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 110)

			minigameModal.Visible = true
			startNeedleOscillation()
		elseif eventData.Event == "EventCompleted" then
			alertBanner.Visible = true
			if eventData.DiscoveredGhost then
				alertBanner.BackgroundColor3 = Color3.fromRGB(25, 55, 45)
				alertLabel.Text = string.format("🎉 CAPTURED JASPER THE BELLHOP! (+%d Ectoplasm)", eventData.Ectoplasm)
			else
				alertBanner.BackgroundColor3 = Color3.fromRGB(45, 40, 20)
				alertLabel.Text = string.format("✨ Entity Contained! (+%d Ectoplasm, +%d Coins)", eventData.Ectoplasm, eventData.Coins)
			end
			local currentMsg = alertLabel.Text
			task.delay(5, function()
				if alertLabel.Text == currentMsg then
					alertBanner.Visible = false
				end
			end)
		elseif eventData.Event == "EventFailed" then
			alertBanner.Visible = true
			alertBanner.BackgroundColor3 = Color3.fromRGB(55, 20, 25)
			alertLabel.Text = "👻 " .. (eventData.Message or "The spirit escaped.")
			task.delay(4, function()
				alertBanner.Visible = false
			end)
		end
	end)
end

return HUDController
