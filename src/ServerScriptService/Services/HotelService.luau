-- ServerScriptService/Services/HotelService.luau
local RepStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local GameConfig = require(RepStorage.Configs.GameConfig)
local HotelPlots = Workspace:WaitForChild("HotelPlots")

local HotelService = {}
_G.GhostshiftPlayerPlots = _G.GhostshiftPlayerPlots or {}
local playerPlots = _G.GhostshiftPlayerPlots
local promptConnections = {}

function HotelService.Init(economyService, onUpgradeRequested, onUnlockFloorRequested)
	HotelService.EconomyService = economyService
	HotelService.OnUpgradeRequested = onUpgradeRequested
	HotelService.OnUnlockFloorRequested = onUnlockFloorRequested
end

function HotelService.GetPlayerPlot(player)
	if playerPlots[player] then
		return playerPlots[player]
	end
	local userId = (typeof(player) == "Instance" and player.UserId) or (typeof(player) == "table" and player.UserId)
	if userId then
		for _, plot in ipairs(HotelPlots:GetChildren()) do
			if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == userId then
				playerPlots[player] = plot
				return plot
			end
		end
	end
	return nil
end

function HotelService.IsFloorUnlocked(plot, floorIndex)
	if floorIndex == 1 then return true end
	local state = plot:FindFirstChild("PlotState")
	if state and state:FindFirstChild("Floor2Unlocked") then
		return state.Floor2Unlocked.Value == true
	end
	return false
end

function HotelService.UnlockPlotFloor(plot, floorIndex)
	if floorIndex == 2 then
		local state = plot:FindFirstChild("PlotState")
		if state and state:FindFirstChild("Floor2Unlocked") then
			state.Floor2Unlocked.Value = true
		end

		local f2 = plot:FindFirstChild("Floor2")
		if f2 then
			local barrier = f2:FindFirstChild("Floor2_LockedBarrier")
			if barrier then
				barrier.Transparency = 1
				barrier.CanCollide = false
				local prompt = barrier:FindFirstChild("UnlockPrompt")
				if prompt then prompt.Enabled = false end
				local gui = barrier:FindFirstChild("LockGui")
				if gui then gui.Enabled = false end
			end

			-- Illuminate chandeliers
			for _, child in ipairs(f2:GetChildren()) do
				if child:IsA("BasePart") and string.find(child.Name, "Chandelier") then
					local light = child:FindFirstChildWhichIsA("PointLight")
					if light then light.Enabled = true end
				end
			end
		end

		-- Setup prompts for Room 3 and Room 4
		local ownerId = plot:GetAttribute("OwnerUserId")
		local player = ownerId and Players:GetPlayerByUserId(ownerId)
		if player then
			HotelService.SetupRoomPrompt(player, plot, "Room3")
			HotelService.SetupRoomPrompt(player, plot, "Room4")
		end

		HotelService.UpdatePadDisplay(plot, "Room3", 1)
		HotelService.UpdatePadDisplay(plot, "Room4", 1)
	end
end

function HotelService.LockPlotFloor(plot, floorIndex)
	if floorIndex == 2 then
		local state = plot:FindFirstChild("PlotState")
		if state and state:FindFirstChild("Floor2Unlocked") then
			state.Floor2Unlocked.Value = false
		end

		local f2 = plot:FindFirstChild("Floor2")
		if f2 then
			local barrier = f2:FindFirstChild("Floor2_LockedBarrier")
			if barrier then
				barrier.Transparency = 0.4
				barrier.CanCollide = true
				local prompt = barrier:FindFirstChild("UnlockPrompt")
				if prompt then prompt.Enabled = true end
				local gui = barrier:FindFirstChild("LockGui")
				if gui then gui.Enabled = true end
			end
		end
	end
end

function HotelService.AssignPlot(player)
	local userId = player.UserId
	local userName = player.DisplayName or player.Name

	-- 1. Check if player already has an assigned plot
	for _, plot in ipairs(HotelPlots:GetChildren()) do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == userId then
			playerPlots[player] = plot
			HotelService.SetupPlotPrompts(player, plot)
			return plot
		end
	end

	-- 2. Find first vacant plot
	for _, plot in ipairs(HotelPlots:GetChildren()) do
		if plot:IsA("Model") then
			local currentOwner = plot:GetAttribute("OwnerUserId")
			if not currentOwner or currentOwner == 0 then
				plot:SetAttribute("OwnerUserId", userId)
				plot:SetAttribute("OwnerName", userName)

				local sign = plot:FindFirstChild("Structure") and plot.Structure:FindFirstChild("SignBoard")
				if sign and sign:FindFirstChild("SignGui") and sign.SignGui:FindFirstChild("OwnerLabel") then
					local starsText = ""
					local prof = HotelService.EconomyService and HotelService.EconomyService.GetProfile(player)
					local stars = prof and prof.ReputationStars or 0
					if stars > 0 then
						starsText = string.rep("★", stars) .. " "
					end
					sign.SignGui.OwnerLabel.Text = string.format("%s%s - %s's Hotel", starsText, plot.Name, userName)
				end

				playerPlots[player] = plot
				HotelService.SetupPlotPrompts(player, plot)

				if typeof(player) == "Instance" and player:IsA("Player") then
					task.spawn(function()
						local character = player.Character or player.CharacterAdded:Wait()
						local root = character:WaitForChild("HumanoidRootPart", 5)
						local spawnPart = plot:FindFirstChild("PlotSpawn")
						if root and spawnPart then
							root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
						end
					end)
				end

				for _, rId in ipairs({"Room1", "Room2", "Room3", "Room4"}) do
					HotelService.UpdatePadDisplay(plot, rId, 1)
				end

				return plot
			end
		end
	end
	return nil
end

function HotelService.ReleasePlot(player)
	local plot = playerPlots[player]
	if not plot then return end

	if promptConnections[plot] then
		for _, conn in ipairs(promptConnections[plot]) do
			conn:Disconnect()
		end
		promptConnections[plot] = nil
	end

	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "Vacant")

	local sign = plot:FindFirstChild("Structure") and plot.Structure:FindFirstChild("SignBoard")
	if sign and sign:FindFirstChild("SignGui") and sign.SignGui:FindFirstChild("OwnerLabel") then
		sign.SignGui.OwnerLabel.Text = plot.Name .. " - [VACANT]"
	end

	local state = plot:FindFirstChild("PlotState")
	if state then
		state.Room1Occupied.Value = false
		state.Room2Occupied.Value = false
		if state:FindFirstChild("Room3Occupied") then state.Room3Occupied.Value = false end
		if state:FindFirstChild("Room4Occupied") then state.Room4Occupied.Value = false end
		state.Room1Level.Value = 1
		state.Room2Level.Value = 1
		if state:FindFirstChild("Room3Level") then state.Room3Level.Value = 1 end
		if state:FindFirstChild("Room4Level") then state.Room4Level.Value = 1 end
		if state:FindFirstChild("Floor2Unlocked") then state.Floor2Unlocked.Value = false end
	end

	for _, rId in ipairs({"Room1", "Room2", "Room3", "Room4"}) do
		HotelService.ResetRoomVisuals(plot, rId)
	end
	HotelService.LockPlotFloor(plot, 2)

	playerPlots[player] = nil
end

function HotelService.ResetRoomVisuals(plot, roomId)
	local room = plot:FindFirstChild(roomId)
	if not room then return end
	local decor2 = room:FindFirstChild("Decor_Lv2")
	if decor2 then
		for _, p in ipairs(decor2:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = 1; p.CanCollide = false end
			if p:IsA("Light") then p.Enabled = false end
		end
	end
	local decor3 = room:FindFirstChild("Decor_Lv3")
	if decor3 then
		for _, p in ipairs(decor3:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = 1; p.CanCollide = false end
			if p:IsA("Light") then p.Enabled = false end
		end
	end
end

function HotelService.ApplyRoomUpgradeVisuals(plot, roomId, newLevel)
	local room = plot:FindFirstChild(roomId)
	if not room then return end

	local state = plot:FindFirstChild("PlotState")
	if state and state:FindFirstChild(roomId .. "Level") then
		state[roomId .. "Level"].Value = newLevel
	end

	if newLevel >= 2 then
		local decor2 = room:FindFirstChild("Decor_Lv2")
		if decor2 then
			for _, p in ipairs(decor2:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Transparency = (p.Name == "EdgeTrim" and 0.3 or 0)
					p.CanCollide = (p.Name == "FloatingCandle" or p.Name == "FloatingBook" and false or true)
				elseif p:IsA("Light") then
					p.Enabled = true
				end
			end
		end
	end

	if newLevel >= 3 then
		local decor3 = room:FindFirstChild("Decor_Lv3")
		if decor3 then
			for _, p in ipairs(decor3:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Transparency = 0
					p.CanCollide = (p.Name == "CrystalOrb" or p.Name == "MagicGlobe" and false or true)
				elseif p:IsA("Light") then
					p.Enabled = true
				end
			end
		end
	end

	HotelService.UpdatePadDisplay(plot, roomId, newLevel)
end

function HotelService.UpdatePadDisplay(plot, roomId, currentLevel)
	local room = plot:FindFirstChild(roomId)
	if not room then return end
	local pad = room:FindFirstChild("UpgradePad")
	if not pad then return end

	local prompt = pad:FindFirstChild("UpgradePrompt")
	local gui = pad:FindFirstChild("PadGui")
	local frame = gui and gui:FindFirstChild("Frame")

	local roomConfig = GameConfig.Rooms[roomId]
	if not roomConfig then return end
	local nextUpgrade = roomConfig.Upgrades[currentLevel + 1]

	if nextUpgrade then
		if frame then
			frame.Title.Text = roomId .. " (Lv. " .. currentLevel .. ")"
			frame.CostLabel.Text = "Upgrade: " .. nextUpgrade.Cost .. " 🪙"
			frame.HintLabel.Text = "[E] to Upgrade"
		end
		if prompt then
			prompt.ActionText = "Upgrade " .. roomId .. " (Lv." .. (currentLevel + 1) .. ")"
			prompt.ObjectText = nextUpgrade.Cost .. " Coins"
			prompt.Enabled = true
		end
	else
		if frame then
			frame.Title.Text = roomId .. " (Lv. " .. currentLevel .. ")"
			frame.CostLabel.Text = "★ MAX LEVEL ★"
			frame.HintLabel.Text = "Fully Renovated"
		end
		if prompt then
			prompt.ActionText = "Max Level"
			prompt.ObjectText = "Maxed"
			prompt.Enabled = false
		end
	end
end

function HotelService.SetupRoomPrompt(player, plot, roomId)
	local room = plot:FindFirstChild(roomId)
	local pad = room and room:FindFirstChild("UpgradePad")
	local prompt = pad and pad:FindFirstChild("UpgradePrompt")
	if prompt then
		local conn = prompt.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer == player and HotelService.OnUpgradeRequested then
				HotelService.OnUpgradeRequested(player, roomId)
			end
		end)
		table.insert(promptConnections[plot], conn)
	end
end

function HotelService.SetupPlotPrompts(player, plot)
	promptConnections[plot] = {}

	-- Room Upgrade Pads (Room 1 & Room 2)
	for _, roomId in ipairs({"Room1", "Room2"}) do
		HotelService.SetupRoomPrompt(player, plot, roomId)
	end

	-- If Floor 2 already unlocked, setup Room 3 & Room 4 prompts
	if HotelService.IsFloorUnlocked(plot, 2) then
		for _, roomId in ipairs({"Room3", "Room4"}) do
			HotelService.SetupRoomPrompt(player, plot, roomId)
		end
	end

	-- Floor 2 Unlock Barrier Prompt
	local f2 = plot:FindFirstChild("Floor2")
	local barrier = f2 and f2:FindFirstChild("Floor2_LockedBarrier")
	local unlockPrompt = barrier and barrier:FindFirstChild("UnlockPrompt")
	if unlockPrompt then
		local conn = unlockPrompt.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer == player and HotelService.OnUnlockFloorRequested then
				HotelService.OnUnlockFloorRequested(player, 2)
			end
		end)
		table.insert(promptConnections[plot], conn)
	end
end

return HotelService
