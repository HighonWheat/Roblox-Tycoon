-- StarterPlayerScripts/Controllers/HUDController.luau
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(RepStorage.Configs.GameConfig)
local GhostConfig = require(RepStorage.Configs.GhostConfig)
local Formatters = require(RepStorage.Shared.Formatters)

local Network = RepStorage.Network
local RequestUpgrade = Network:WaitForChild("RequestUpgrade")
local PlayerStateUpdated = Network:WaitForChild("PlayerStateUpdated")
local GuestStateChanged = Network:WaitForChild("GuestStateChanged")
local ParanormalEventUpdated = Network:WaitForChild("ParanormalEventUpdated")
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

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HotelHUD")
local captureGui = playerGui:WaitForChild("CaptureMinigameGui")
local journalGui = playerGui:WaitForChild("GhostJournalGui")
local wbGui = playerGui:WaitForChild("WelcomeBackGui")
local dqGui = playerGui:WaitForChild("DailyQuestsGui")

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
	local tutDismissBtn = tutBanner:FindFirstChild("DismissBtn")

	local alertBanner = hud:WaitForChild("HauntingAlertBanner")
	local alertLabel = alertBanner.AlertLabel

	-- Renovations Modal
	local toggleUpgradeBtn = hud:WaitForChild("ToggleUpgradeBtn")
	local upgradeModal = hud:WaitForChild("UpgradeModal")
	local upgradeCloseBtn = upgradeModal.CloseBtn
	local upgradeToast = upgradeModal.ToastLabel
	local cardsFrame = upgradeModal.CardsFrame
	local unlockF2Btn = upgradeModal:FindFirstChild("UnlockFloor2Btn")
	local prestigeBtn = upgradeModal:FindFirstChild("PrestigeBtn")

	-- Ghost Journal Modal
	local toggleJournalBtn = hud:WaitForChild("ToggleJournalBtn")
	local journalModal = journalGui:WaitForChild("MainModal")
	local journalCloseBtn = journalModal.CloseBtn
	local journalToast = journalModal.ToastLabel
	local staffSection = journalModal.StaffSection
	local rosterSection = journalModal.RosterSection

	-- Daily Quests Modal
	local toggleQuestsBtn = hud:WaitForChild("ToggleQuestsBtn")
	local dqBackdrop = dqGui:WaitForChild("Backdrop")
	local dqModal = dqBackdrop:WaitForChild("MainModal")
	local dqCloseBtn = dqModal.HeaderFrame.CloseBtn
	local dqToast = dqModal.ToastLabel
	local questsFrame = dqModal.QuestsFrame

	-- Minigame Elements
	local minigameModal = captureGui:WaitForChild("MainModal")
	local needle = minigameModal.TrackFrame.Needle
	local targetZone = minigameModal.TrackFrame.TargetZone
	local attemptsLabel = minigameModal.AttemptsLabel
	local catchBtn = minigameModal.CatchBtn
	local minigameStatus = minigameModal.StatusLabel
	local abortBtn = minigameModal.AbortBtn

	-- Welcome Back Modal Elements
	local wbBackdrop = wbGui:WaitForChild("Backdrop")
	local wbModal = wbBackdrop:WaitForChild("MainModal")
	local wbCloseBtn = wbModal.HeaderFrame.CloseBtn
	local wbAwayLabel = wbModal.AwayBadge.AwayLabel
	local wbCoinsCard = wbModal.CardsContainer.CoinsCard
	local wbEctoCard = wbModal.CardsContainer.EctoCard
	local wbClaimBtn = wbModal.ClaimBtn
	local wbToast = wbModal.ToastLabel

	local isMinigameActive = false
	local currentSessionToken = nil
	local minigameConnection = nil
	local needlePos = 0.5
	local oscillationSpeed = 2.2
	local latestData = nil

	-- Modal Mutual Exclusion (ensures only 1 modal is open on screen)
	local function closeAllModalsExcept(targetModal)
		if targetModal ~= upgradeModal then upgradeModal.Visible = false end
		if targetModal ~= journalModal then journalModal.Visible = false end
		if targetModal ~= wbBackdrop then wbBackdrop.Visible = false end
		if targetModal ~= dqBackdrop then dqBackdrop.Visible = false end
		if targetModal ~= minigameModal and isMinigameActive then
			HUDController.CloseMinigame()
		end
	end

	-- Modal Toggle Handlers
	toggleUpgradeBtn.MouseButton1Click:Connect(function()
		if not upgradeModal.Visible then
			closeAllModalsExcept(upgradeModal)
			upgradeModal.Visible = true
		else
			upgradeModal.Visible = false
		end
	end)

	upgradeCloseBtn.MouseButton1Click:Connect(function()
		upgradeModal.Visible = false
	end)

	toggleJournalBtn.MouseButton1Click:Connect(function()
		if not journalModal.Visible then
			closeAllModalsExcept(journalModal)
			journalModal.Visible = true
		else
			journalModal.Visible = false
		end
	end)

	journalCloseBtn.MouseButton1Click:Connect(function()
		journalModal.Visible = false
	end)

	toggleQuestsBtn.MouseButton1Click:Connect(function()
		if not dqBackdrop.Visible then
			closeAllModalsExcept(dqBackdrop)
			dqBackdrop.Visible = true
		else
			dqBackdrop.Visible = false
		end
	end)

	dqCloseBtn.MouseButton1Click:Connect(function()
		dqBackdrop.Visible = false
	end)

	abortBtn.MouseButton1Click:Connect(function()
		HUDController.CloseMinigame()
	end)

	wbCloseBtn.MouseButton1Click:Connect(function()
		wbBackdrop.Visible = false
	end)

	if tutDismissBtn then
		tutDismissBtn.MouseButton1Click:Connect(function()
			tutBanner.Visible = false
			task.spawn(function()
				DismissTutorial:InvokeServer()
			end)
		end)
	end

	local function showUpgradeToast(message, isSuccess)
		upgradeToast.Text = message
		upgradeToast.TextColor3 = isSuccess and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
		task.delay(3, function()
			if upgradeToast.Text == message then
				upgradeToast.Text = "Tip: Upgrade rooms and unlock Floor 2 for higher income!"
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

	local function showQuestToast(message, isSuccess)
		dqToast.Text = message
		dqToast.TextColor3 = isSuccess and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
		task.delay(3, function()
			if dqToast.Text == message then
				dqToast.Text = "Complete objectives and tap Claim to collect rewards!"
				dqToast.TextColor3 = Color3.fromRGB(190, 180, 215)
			end
		end)
	end

	-- Setup Room Upgrade Cards (Room 1, Room 2, Room 3, Room 4)
	local function setupUpgradeCard(roomId)
		local card = cardsFrame:WaitForChild(roomId .. "Card")
		local btn = card:WaitForChild("UpgradeBtn")

		btn.MouseButton1Click:Connect(function()
			btn.Text = "Upgrading..."
			local success, message, newBal, newLv = RequestUpgrade:InvokeServer(roomId)
			showUpgradeToast(message, success)
		end)
	end

	for _, rId in ipairs({"Room1", "Room2", "Room3", "Room4"}) do
		setupUpgradeCard(rId)
	end

	-- Unlock Floor 2 Button
	if unlockF2Btn then
		unlockF2Btn.MouseButton1Click:Connect(function()
			unlockF2Btn.Text = "Unlocking..."
			local success, message = UnlockFloor:InvokeServer(2)
			showUpgradeToast(message, success)
			if success then
				unlockF2Btn.Text = "✨ 2ND FLOOR UNLOCKED ✨"
				unlockF2Btn.BackgroundColor3 = Color3.fromRGB(40, 160, 100)
			else
				unlockF2Btn.Text = "🔒 UNLOCK 2ND FLOOR (250 🪙)"
			end
		end)
	end

	-- Grand Renovation (Prestige) Button
	if prestigeBtn then
		prestigeBtn.MouseButton1Click:Connect(function()
			prestigeBtn.Text = "Renovating..."
			local success, message = RequestPrestige:InvokeServer()
			showUpgradeToast(message, success)
			prestigeBtn.Text = "★ GRAND RENOVATION (PRESTIGE) ★"
		end)
	end

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

			local assigned = latestData.AssignedStaff or {}
			local targetSlot = 1
			if assigned[1] == ghostId then
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
				if assigned[1] == nil then
					targetSlot = 1
				elseif assigned[2] == nil then
					targetSlot = 2
				else
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

	-- Setup Daily Quests Claim Buttons
	for _, qId in ipairs({"GuestStays", "Haunting", "Earnings", "StaffDuty"}) do
		local qCard = questsFrame:FindFirstChild(qId .. "Card")
		if qCard then
			local claimBtn = qCard:FindFirstChild("ClaimBtn")
			if claimBtn then
				claimBtn.MouseButton1Click:Connect(function()
					local success, message = ClaimDailyReward:InvokeServer(qId)
					showQuestToast(message, success)
				end)
			end
		end
	end

	-- Welcome Back Offline Rewards Claim Handler
	local isClaiming = false
	wbClaimBtn.MouseButton1Click:Connect(function()
		if isClaiming then return end
		isClaiming = true
		wbClaimBtn.Text = "CLAIMING..."
		wbClaimBtn.Active = false

		local result = ClaimOfflineRewards:InvokeServer()
		if result and result.Success then
			wbClaimBtn.Text = "✨ CLAIMED! ✨"
			wbClaimBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 120)
			wbToast.Text = string.format("Added +%d 🪙 and +%d 🟣 to your vault!", result.ClaimedCoins or 0, result.ClaimedEctoplasm or 0)
			wbToast.TextColor3 = Color3.fromRGB(120, 255, 180)
			task.delay(1.5, function()
				wbBackdrop.Visible = false
				isClaiming = false
				wbClaimBtn.Text = "💰 CLAIM REWARDS"
				wbClaimBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 110)
				wbClaimBtn.Active = true
			end)
		else
			wbToast.Text = result and result.Message or "Claim error. Please try again."
			wbToast.TextColor3 = Color3.fromRGB(255, 120, 120)
			wbClaimBtn.Text = "CLAIM REWARDS"
			wbClaimBtn.Active = true
			isClaiming = false
		end
	end)

	OfflineRewardReady.OnClientEvent:Connect(function(rewardData)
		if not rewardData then return end
		local durationStr = Formatters.FormatDuration(rewardData.ElapsedSeconds or 0)
		wbAwayLabel.Text = string.format("⏳ Away for %s (Capped at 3h • 50%% passive rate)", durationStr)
		wbCoinsCard.AmountLabel.Text = string.format("+%s Coins", Formatters.FormatNumber(rewardData.Coins or 0))

		if rewardData.Ectoplasm and rewardData.Ectoplasm > 0 then
			wbEctoCard.Visible = true
			wbEctoCard.AmountLabel.Text = string.format("+%s Ectoplasm", Formatters.FormatNumber(rewardData.Ectoplasm))
		else
			wbEctoCard.Visible = false
		end

		wbToast.Text = "Press Claim to add earnings to your vault!"
		wbToast.TextColor3 = Color3.fromRGB(200, 190, 220)
		wbClaimBtn.Text = "💰 CLAIM REWARDS"
		wbClaimBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 110)
		wbClaimBtn.Active = true
		isClaiming = false

		closeAllModalsExcept(wbBackdrop)
		wbBackdrop.Visible = true
	end)

	-- Update Daily Quests UI
	local function updateDailyQuestsUI(dailyData)
		if not dailyData or not dailyData.Quests then return end
		for qId, qInfo in pairs(dailyData.Quests) do
			local card = questsFrame:FindFirstChild(qId .. "Card")
			if card then
				local cur = qInfo.Current or 0
				local target = qInfo.Target or 1
				local claimed = qInfo.Claimed == true
				local tpl = GameConfig.DailyObjectives and GameConfig.DailyObjectives[qId]
				local rewStr = ""
				if tpl then
					if tpl.RewardCoins and tpl.RewardCoins > 0 then rewStr = rewStr .. string.format("+%d 🪙 ", tpl.RewardCoins) end
					if tpl.RewardEctoplasm and tpl.RewardEctoplasm > 0 then rewStr = rewStr .. string.format("+%d 🟣", tpl.RewardEctoplasm) end
				end

				card.ProgressLabel.Text = string.format("Progress: %d/%d | Reward: %s", cur, target, rewStr)

				local claimBtn = card.ClaimBtn
				if claimed then
					claimBtn.Text = "CLAIMED ✓"
					claimBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 45)
					claimBtn.TextColor3 = Color3.fromRGB(120, 200, 150)
					claimBtn.Active = false
				elseif cur >= target then
					claimBtn.Text = "CLAIM!"
					claimBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 100)
					claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
					claimBtn.Active = true
				else
					claimBtn.Text = string.format("%d/%d", cur, target)
					claimBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 65)
					claimBtn.TextColor3 = Color3.fromRGB(160, 150, 175)
					claimBtn.Active = false
				end
			end
		end
	end

	-- Update UI with latest server state
	local function updateUI(data)
		latestData = data
		local repStars = data.ReputationStars or 0
		local starsPrefix = repStars > 0 and (string.rep("★", repStars) .. " ") or ""

		coinsLabel.Text = starsPrefix .. Formatters.FormatNumber(data.Coins) .. " Coins"
		incomeLabel.Text = "+" .. Formatters.FormatNumber(data.IncomeRate) .. " / Stay"
		ectoLabel.Text = Formatters.FormatNumber(data.Ectoplasm or 0) .. " Ectoplasm"

		local ghostCount = 0
		if data.DiscoveredGhosts then
			for _ in pairs(data.DiscoveredGhosts) do ghostCount = ghostCount + 1 end
		end
		ghostLabel.Text = string.format("Ghosts: %d/3", ghostCount)

		if data.TutorialDismissed == true or (data.TutorialStep and data.TutorialStep > 6) then
			tutBanner.Visible = false
		else
			tutBanner.Visible = true
			tutTitle.Text = data.TutorialTitle or "Ghostshift Tutorial"
			tutDesc.Text = data.TutorialDescription or ""
		end

		local isF2Unlocked = data.FloorsUnlocked and data.FloorsUnlocked[2] == true
		if unlockF2Btn then
			if isF2Unlocked then
				unlockF2Btn.Text = "✨ 2ND FLOOR UNLOCKED ✨"
				unlockF2Btn.BackgroundColor3 = Color3.fromRGB(35, 120, 75)
				unlockF2Btn.Active = false
			else
				unlockF2Btn.Text = "🔒 UNLOCK 2ND FLOOR (250 🪙)"
				unlockF2Btn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
				unlockF2Btn.Active = true
			end
		end

		if prestigeBtn then
			local bonusPct = math.floor(repStars * 0.15 * 100)
			prestigeBtn.Text = string.format("★ GRAND RENOVATION (Stars: %d • +%d%% Bonus) ★", repStars, bonusPct)
		end

		-- Update Room Upgrade Cards (Room 1-4)
		for _, roomId in ipairs({"Room1", "Room2", "Room3", "Room4"}) do
			local card = cardsFrame:FindFirstChild(roomId .. "Card")
			if card then
				local currentLv = data.RoomLevels[roomId] or 1
				local roomDef = GameConfig.Rooms[roomId]
				local nextUpgrade = roomDef and roomDef.Upgrades[currentLv + 1]
				local isFloor2Room = (roomDef and roomDef.Floor == 2)

				card.LevelLabel.Text = "Level " .. currentLv
				local curIncome = roomDef and roomDef.Upgrades[currentLv] and roomDef.Upgrades[currentLv].Income or 15
				card.IncomeLabel.Text = "+" .. curIncome .. " 🪙 / stay"

				local btn = card.UpgradeBtn
				if isFloor2Room and not isF2Unlocked then
					card.NextUpgradeLabel.Text = "Requires 2nd Floor Unlocked!"
					btn.Text = "Floor Locked"
					btn.BackgroundColor3 = Color3.fromRGB(45, 35, 50)
					btn.TextColor3 = Color3.fromRGB(130, 115, 140)
				elseif nextUpgrade then
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
		local discovered = data.DiscoveredGhosts or {}
		local assigned = data.AssignedStaff or {}
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

		-- Update Daily Quests
		if data.DailyObjectives then
			updateDailyQuestsUI(data.DailyObjectives)
		end
	end

	PlayerStateUpdated.OnClientEvent:Connect(function(data)
		updateUI(data)
	end)

	if DailyQuestsUpdated then
		DailyQuestsUpdated.OnClientEvent:Connect(function(dailyData)
			updateDailyQuestsUI(dailyData)
		end)
	end

	GuestStateChanged.OnClientEvent:Connect(function(eventData)
		if eventData.Event == "StayCompleted" then
			local gTypeName = eventData.GuestType or "Specter"
			local msg = string.format("✨ %s completed stay in %s! (+%d 🪙)", gTypeName, eventData.RoomId, eventData.Income)
			if eventData.Tip and eventData.Tip > 0 then
				msg = msg .. string.format(" [Tip: +%d 🪙]", eventData.Tip)
			end
			if eventData.BonusEctoplasm and eventData.BonusEctoplasm > 0 then
				msg = msg .. string.format(" [+%d 🟣 Ectoplasm!]", eventData.BonusEctoplasm)
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
			alertLabel.Text = string.format("⚠️ DISTURBANCE: %s! Investigate the clues!", eventData.RoomName or eventData.RoomId)
		elseif eventData.Event == "ClueFound" then
			alertBanner.Visible = true
			alertLabel.Text = string.format("🔎 Clues Discovered: (%d/%d)! (+%d Ectoplasm)", eventData.ClaimedCount, eventData.TotalClues, eventData.BonusEctoplasm or 5)
		elseif eventData.Event == "CaptureReady" then
			alertBanner.Visible = true
			alertBanner.BackgroundColor3 = Color3.fromRGB(18, 45, 40)
			alertLabel.Text = string.format("⚡ SPIRIT MANIFESTED: %s! Approach to contain!", eventData.GhostName or "Spirit")
		elseif eventData.Event == "OpenCaptureMinigame" then
			closeAllModalsExcept(minigameModal)
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
