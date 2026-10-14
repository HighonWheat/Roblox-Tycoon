local RepStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local GameConfig = require(RepStorage.Configs.GameConfig)
local HotelPlots = Workspace:WaitForChild("HotelPlots")

local HotelService = {}
_G.GhostshiftPlayerPlots = _G.GhostshiftPlayerPlots or {}
local playerPlots = _G.GhostshiftPlayerPlots
local promptConnections = {}

function HotelService.Init(economyService, onUpgradeRequested)
	HotelService.EconomyService = economyService
	HotelService.OnUpgradeRequested = onUpgradeRequested
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

function HotelService.AssignPlot(player)
	for _, plot in ipairs(HotelPlots:GetChildren()) do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName or player.Name)

			local sign = plot:FindFirstChild("Structure") and plot.Structure:FindFirstChild("SignBoard")
			if sign and sign:FindFirstChild("SignGui") and sign.SignGui:FindFirstChild("OwnerLabel") then
				sign.SignGui.OwnerLabel.Text = plot.Name .. " - " .. (player.DisplayName or player.Name) .. "'s Hotel"
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

			HotelService.UpdatePadDisplay(plot, "Room1", 1)
			HotelService.UpdatePadDisplay(plot, "Room2", 1)

			return plot
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
		state.Room1Level.Value = 1
		state.Room2Level.Value = 1
	end

	HotelService.ResetRoomVisuals(plot, "Room1")
	HotelService.ResetRoomVisuals(plot, "Room2")

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
					p.CanCollide = (p.Name == "FloatingCandle" and false or true)
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
					p.CanCollide = (p.Name == "CrystalOrb" and false or true)
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

function HotelService.SetupPlotPrompts(player, plot)
	promptConnections[plot] = {}
	for _, roomId in ipairs({"Room1", "Room2"}) do
		local room = plot:FindFirstChild(roomId)
		local pad = room and room:FindFirstChild("UpgradePad")
		local prompt = pad and pad:FindFirstChild("UpgradePrompt")
		if prompt then
			local conn = prompt.Triggered:Connect(function(triggerPlayer)
				if triggerPlayer == player then
					HotelService.OnUpgradeRequested(player, roomId)
				end
			end)
			table.insert(promptConnections[plot], conn)
		end
	end
end

return HotelService
