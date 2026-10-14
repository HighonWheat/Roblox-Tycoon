-- StarterPlayerScripts/Controllers/HUDController.lua
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
local AssignStaff = Network.AssignStaff
local UnassignStaff = Network.UnassignStaff
local LevelUpGhost = Network.LevelUpGhost

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HotelHUD")
local captureGui = playerGui:WaitForChild("CaptureMinigameGui")
local journalGui = playerGui:WaitForChild("GhostJournalGui")

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

	-- Renovations Modal
	local toggleUpgradeBtn = hud:WaitForChild("ToggleUpgradeBtn")
	local upgradeModal = hud:WaitForChild("UpgradeModal")
	local upgradeCloseBtn = upgradeModal.CloseBtn
	local upgradeToast = upgradeModal.ToastLabel
	local cardsFrame = upgradeModal.CardsFrame

	-- Ghost Journal Modal
	local toggleJournalBtn = hud:WaitForChild("ToggleJournalBtn")
	local journalModal = journalGui:WaitForChild("MainModal")
	local journalCloseBtn = journalModal.CloseBtn
	local journalToast = journalModal.ToastLabel
	local staffSection = journalModal.StaffSection
	local rosterSection = journalModal.RosterSection

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
	local latestData = nil

	-- Modal Toggle Handlers
	toggleUpgradeBtn.MouseButton1Click:Connect(function()
		upgradeModal.Visible = not upgradeModal.Visible
		if upgradeModal.Visible then
			journalModal.Visible = false
		end
	end)

	upgradeCloseBtn.MouseButton1Click:Connect(function()
		upgradeModal.Visible = false
	end)

	toggleJournalBtn.MouseButton1Click:Connect(function()
		journalModal.Visible = not journalModal.Visible
		if journalModal.Visible then
			upgradeModal.Visible = false
		end
	end)

	journalCloseBtn.MouseButton1Click:Connect(function()
		journalModal.Visible = false
	end)

	abortBtn.MouseButton1Click:Connect(function()
		HUDController.CloseMinigame()
	end)

	local function showUpgradeToast(message, isSuccess)
		upgradeToast.Text = message
		upgradeToast.TextColor3 = isSuccess and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
		task.delay(3, function()
			if upgradeToast.Text == message then
				upgradeToast.Text = "Tip: Upgrade rooms to earn more coins!"
				upgradeToast.TextColor3 = Color3.fromRGB(230, 220, 255)
			end
		end)
	end

	local function showJournalToast(message, isSuccess)
		journalToast.Text = message
		journalToast.TextColor3 = isSuccess and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
		task.delay(3.5, function()
			if journalToast.Text == message then
				journalToast.Text = "Tip: Assign ghosts to boost tips, turnover, and passive Ectoplasm!"
				journalToast.TextColor3 = Color3.fromRGB(230, 220, 255)
			end
		end)
	end

	-- Setup Room Upgrade Cards
	local function setupUpgradeCard(roomId)
		local card = cardsFrame:WaitForChild(roomId .. "Card")
		local btn = card:WaitForChild("UpgradeBtn")

		btn.MouseButton1Click:Connect(function()
			btn.Text = "Upgrading..."
			local success, message, newBal, newLv = RequestUpgrade:InvokeServer(roomId)
			showUpgradeToast(message, success)
		end)
	end

	setupUpgradeCard("Room1")
	setupUpgradeCard("Room2")

	-- Setup Staff Slots Unassign Buttons
	for slotIdx = 1, 2 do
		local card = staffSection:WaitForChild(string.format("Slot_%dCard", slotIdx))
		local unassignBtn = card:WaitForChild("UnassignBtn")
		unassignBtn.MouseButton1Click:Connect(function()
			unassignBtn.Text = "..."
			local success, msg = UnassignStaff:InvokeServer(slotIdx)
			showJournalToast(msg, success)
		end)
	end

	-- Setup Roster Cards Actions
	for ghostId, _ in pairs(GhostConfig.Ghosts) do
		local card = rosterSection:WaitForChild(ghostId .. "Card")
		local actions = card:WaitForChild("ActionsFrame")
		local assignBtn = actions:WaitForChild("AssignBtn")
		local levelUpBtn = actions:WaitForChild("LevelUpBtn")

		assignBtn.MouseButton1Click:Connect(function()
			if not latestData or not latestData.DiscoveredGhosts or not latestData.DiscoveredGhosts[ghostId] then
				showJournalToast("You haven't discovered this spirit yet! Investigate hauntings to find them.", false)
				return
			end

			-- Determine which slot to assign to
			local assigned = latestData.AssignedStaff or {}
			local targetSlot = 1
			if assigned[1] == ghostId then
				-- Already in Slot 1; try switching to Slot 2 or notify
				if assigned[2] == nil then
					targetSlot = 2
				else
					showJournalToast(ghostId .. " is already on duty in Slot 1!", false)
					return
				end
			elseif assigned[2] == ghostId then
				showJournalToast(ghostId .. " is already on duty in Slot 2!", false)
				return
			else
				-- Find first empty slot
				if assigned[1] == nil then
					targetSlot = 1
				elseif assigned[2] == nil then
					targetSlot = 2
				else
					-- Both full, replace slot 1
					targetSlot = 1
				end
			end

			assignBtn.Text = "Assigning..."
			local success, msg = AssignStaff:InvokeServer(targetSlot, ghostId)
			showJournalToast(msg, success)
		end)

		levelUpBtn.MouseButton1Click:Connect(function()
			if not latestData or not latestData.DiscoveredGhosts or not latestData.DiscoveredGhosts[ghostId] then
				showJournalToast("Ghost not discovered yet!", false)
				return
			end
			levelUpBtn.Text = "Ascending..."
			local success, msg = LevelUpGhost:InvokeServer(ghostId)
			showJournalToast(msg, success)
		end)
	end

	-- Update Ghost Journal UI
	local function updateJournalUI(data)
		local discovered = data.DiscoveredGhosts or {}
		local assigned = data.AssignedStaff or {}

		-- Update Staff Slots
		for slotIdx = 1, 2 do
			local card = staffSection:FindFirstChild(string.format("Slot_%dCard", slotIdx))
			if card then
				local assignedGhostId = assigned[slotIdx]
				local unassignBtn = card.UnassignBtn
				if assignedGhostId and GhostConfig.Ghosts[assignedGhostId] then
					local def = GhostConfig.Ghosts[assignedGhostId]
					local ghostData = discovered[assignedGhostId]
					local lv = ghostData and ghostData.Level or 1
					card.GhostLabel.Text = string.format("👻 %s (Lv. %d)", def.Name, lv)
					card.GhostLabel.TextColor3 = def.Color
					card.PerkLabel.Text = def.Ability.Format(lv)
					card.PerkLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
					unassignBtn.Visible = true
					unassignBtn.Text = "Dismiss"
				else
					card.GhostLabel.Text = "[VACANT]"
					card.GhostLabel.TextColor3 = Color3.fromRGB(150, 140, 160)
					card.PerkLabel.Text = "Assign a ghost from the roster below"
					card.PerkLabel.TextColor3 = Color3.fromRGB(130, 120, 140)
					unassignBtn.Visible = false
				end
			end
		end

		-- Update Roster Cards
		for ghostId, def in pairs(GhostConfig.Ghosts) do
			local card = rosterSection:FindFirstChild(ghostId .. "Card")
			if card then
				local ghostData = discovered[ghostId]
				local isDiscovered = (ghostData ~= nil and (ghostData.CopiesOwned or 0) >= 1)
				local actions = card.ActionsFrame
				local assignBtn = actions.AssignBtn
				local levelUpBtn = actions.LevelUpBtn
				local stroke = card:FindFirstChild("CardStroke")

				if isDiscovered then
					local lv = ghostData.Level or 1
					local copies = ghostData.CopiesOwned or 1
					card.NameLabel.Text = def.Name
					card.NameLabel.TextColor3 = def.Color
					card.RarityBadge.Text = string.format("[%s] • Lv. %d (Owned: %d)", string.upper(def.Rarity), lv, copies)
					card.RarityBadge.TextColor3 = GhostConfig.RarityColors[def.Rarity] or Color3.fromRGB(200, 200, 200)
					card.PerkLabel.Text = string.format("%s: %s", def.Ability.Name, def.Ability.Format(lv))
					card.PerkLabel.TextColor3 = Color3.fromRGB(240, 230, 255)
					if stroke then stroke.Color = def.Color end

					-- Check assignment status
					local isAssignedTo = nil
					if assigned[1] == ghostId then isAssignedTo = 1
					elseif assigned[2] == ghostId then isAssignedTo = 2 end

					if isAssignedTo then
						assignBtn.Text = string.format("On Duty (Slot %d)", isAssignedTo)
						assignBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 80)
						assignBtn.TextColor3 = Color3.fromRGB(160, 255, 200)
					else
						assignBtn.Text = "Assign Staff"
						assignBtn.BackgroundColor3 = Color3.fromRGB(90, 45, 140)
						assignBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
					end

					-- Level Up status
					if lv >= 5 then
						levelUpBtn.Text = "★ MAX LEVEL ★"
						levelUpBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 55)
						levelUpBtn.TextColor3 = Color3.fromRGB(150, 140, 160)
					elseif copies >= 2 then
						levelUpBtn.Text = string.format("Level Up (%d/1 Dupe)", copies - 1)
						levelUpBtn.BackgroundColor3 = Color3.fromRGB(140, 90, 30)
						levelUpBtn.TextColor3 = Color3.fromRGB(255, 230, 120)
					else
						levelUpBtn.Text = "Need Dupe (0/1)"
						levelUpBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
						levelUpBtn.TextColor3 = Color3.fromRGB(140, 130, 150)
					end
				else
					-- Undiscovered silhouette state
					card.NameLabel.Text = "??? (Undiscovered)"
					card.NameLabel.TextColor3 = Color3.fromRGB(120, 110, 130)
					card.RarityBadge.Text = string.format("[%s] • Locked", string.upper(def.Rarity))
					card.RarityBadge.TextColor3 = Color3.fromRGB(100, 90, 110)
					card.PerkLabel.Text = "Investigate paranormal hauntings in your hotel rooms to discover this spirit!"
					card.PerkLabel.TextColor3 = Color3.fromRGB(110, 100, 120)
					if stroke then stroke.Color = Color3.fromRGB(55, 45, 75) end

					assignBtn.Text = "Locked"
					assignBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
					assignBtn.TextColor3 = Color3.fromRGB(110, 100, 120)

					levelUpBtn.Text = "Locked"
					levelUpBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
					levelUpBtn.TextColor3 = Color3.fromRGB(110, 100, 120)
				end
			end
		end
	end

	-- Update UI with latest server state
	local function updateUI(data)
		latestData = data
		coinsLabel.Text = Formatters.FormatNumber(data.Coins) .. " Coins"
		incomeLabel.Text = "+" .. Formatters.FormatNumber(data.IncomeRate) .. " / Stay"
		ectoLabel.Text = Formatters.FormatNumber(data.Ectoplasm or 0) .. " Ectoplasm"

		local ghostCount = 0
		if data.DiscoveredGhosts then
			for _ in pairs(data.DiscoveredGhosts) do
				ghostCount = ghostCount + 1
			end
		end
		ghostLabel.Text = string.format("Ghosts: %d/3", ghostCount)

		tutTitle.Text = data.TutorialTitle or "Ghostshift Tutorial"
		tutDesc.Text = data.TutorialDescription or ""

		-- Update Room Upgrade Cards
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

		-- Update Ghost Journal
		updateJournalUI(data)
	end

	PlayerStateUpdated.OnClientEvent:Connect(function(data)
		updateUI(data)
	end)

	GuestStateChanged.OnClientEvent:Connect(function(eventData)
		if eventData.Event == "StayCompleted" then
			local msg = string.format("✨ Guest completed stay in %s! (+%d 🪙)", eventData.RoomId, eventData.Income)
			if eventData.Tip and eventData.Tip > 0 then
				msg = msg .. string.format(" [Tip: +%d 🪙!]", eventData.Tip)
			end
			showUpgradeToast(msg, true)
		end
	end)

	-- Minigame Oscillate Loop
	local function startNeedleOscillation()
		if minigameConnection then minigameConnection:Disconnect() end
		local t = 0
		minigameConnection = RunService.RenderStepped:Connect(function(dt)
			t = t + dt * oscillationSpeed
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
				local def = GhostConfig.Ghosts[eventData.DiscoveredGhost]
				local gName = def and def.Name or eventData.DiscoveredGhost
				alertBanner.BackgroundColor3 = Color3.fromRGB(25, 55, 45)
				alertLabel.Text = string.format("🎉 CAPTURED %s! (+%d Ectoplasm)", string.upper(gName), eventData.Ectoplasm)
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
