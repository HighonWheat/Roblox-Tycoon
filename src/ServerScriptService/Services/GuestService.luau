-- ServerScriptService/Services/GuestService.lua
local RepStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SSS = game:GetService("ServerScriptService")

local GameConfig = require(RepStorage.Configs.GameConfig)
local GhostConfig = require(RepStorage.Configs.GhostConfig)
local Network = RepStorage.Network
local GuestStateChanged = Network.GuestStateChanged

local GuestService = {}
local isRunning = false

GuestService.EconomyService = require(SSS.Services.EconomyService)
GuestService.HotelService = require(SSS.Services.HotelService)

function GuestService.Init(economyService, hotelService)
	GuestService.EconomyService = economyService or GuestService.EconomyService
	GuestService.HotelService = hotelService or GuestService.HotelService
end

function GuestService.Start()
	if isRunning then return end
	isRunning = true

	task.spawn(function()
		while isRunning do
			task.wait(GameConfig.GuestArrivalInterval)
			GuestService.CheckAllPlotsForGuests()
		end
	end)
end

function GuestService.Stop()
	isRunning = false
end

function GuestService.CheckAllPlotsForGuests()
	local hotelPlots = Workspace:FindFirstChild("HotelPlots")
	if not hotelPlots then return end

	for _, plot in ipairs(hotelPlots:GetChildren()) do
		local ownerId = plot:GetAttribute("OwnerUserId")
		if ownerId and ownerId > 0 then
			GuestService.TrySpawnGuestForPlot(plot)
		end
	end
end

function GuestService.TrySpawnGuestForPlot(plot)
	local state = plot:FindFirstChild("PlotState")
	if not state then return end

	local availableRooms = {}
	if not state.Room1Occupied.Value then
		table.insert(availableRooms, "Room1")
	end
	if not state.Room2Occupied.Value then
		table.insert(availableRooms, "Room2")
	end

	if #availableRooms == 0 then
		return
	end

	local chosenRoomId = availableRooms[math.random(1, #availableRooms)]
	state[chosenRoomId .. "Occupied"].Value = true

	local ownerUserId = plot:GetAttribute("OwnerUserId")
	local player = game.Players:GetPlayerByUserId(ownerUserId)

	task.spawn(function()
		GuestService.RunGuestStay(plot, player, chosenRoomId)
	end)
end

function GuestService.CreateGhostGuestModel(startCFrame)
	local model = Instance.new("Model")
	model.Name = "GhostGuest"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(3.5, 2, 2)
	body.CFrame = startCFrame * CFrame.Angles(0, 0, math.rad(90))
	body.Color = Color3.fromRGB(150, 225, 255)
	body.Material = Enum.Material.Neon
	body.Transparency = 0.35
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.CFrame = startCFrame * CFrame.new(0, 2, 0)
	head.Color = Color3.fromRGB(180, 235, 255)
	head.Material = Enum.Material.Neon
	head.Transparency = 0.3
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	local leftEye = Instance.new("Part")
	leftEye.Size = Vector3.new(0.4, 0.4, 0.4)
	leftEye.Shape = Enum.PartType.Ball
	leftEye.Color = Color3.fromRGB(40, 20, 60)
	leftEye.CFrame = startCFrame * CFrame.new(-0.4, 2.2, -0.9)
	leftEye.Anchored = true
	leftEye.CanCollide = false
	leftEye.Parent = model

	local rightEye = Instance.new("Part")
	rightEye.Size = Vector3.new(0.4, 0.4, 0.4)
	rightEye.Shape = Enum.PartType.Ball
	rightEye.Color = Color3.fromRGB(40, 20, 60)
	rightEye.CFrame = startCFrame * CFrame.new(0.4, 2.2, -0.9)
	rightEye.Anchored = true
	rightEye.CanCollide = false
	rightEye.Parent = model

	local hat = Instance.new("Part")
	hat.Name = "TopHat"
	hat.Size = Vector3.new(1.4, 1.2, 1.4)
	hat.CFrame = startCFrame * CFrame.new(0, 3.4, 0)
	hat.Color = Color3.fromRGB(50, 30, 70)
	hat.Material = Enum.Material.Fabric
	hat.Anchored = true
	hat.CanCollide = false
	hat.Parent = model

	local brim = Instance.new("Part")
	brim.Name = "Brim"
	brim.Size = Vector3.new(2.2, 0.2, 2.2)
	brim.CFrame = startCFrame * CFrame.new(0, 2.8, 0)
	brim.Color = Color3.fromRGB(80, 40, 110)
	brim.Material = Enum.Material.Fabric
	brim.Anchored = true
	brim.CanCollide = false
	brim.Parent = model

	local statusGui = Instance.new("BillboardGui")
	statusGui.Name = "StatusGui"
	statusGui.Size = UDim2.new(0, 180, 0, 50)
	statusGui.StudsOffset = Vector3.new(0, 4.5, 0)
	statusGui.AlwaysOnTop = true
	statusGui.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "StatusLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
	label.Font = Enum.Font.GothamBold
	label.Text = "👻 Checking In..."
	label.TextColor3 = Color3.fromRGB(180, 235, 255)
	label.TextScaled = true
	label.Parent = statusGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	model.PrimaryPart = head
	return model
end

function GuestService.MoveModel(model, targetCFrame, duration)
	if not model or not model.PrimaryPart then return end
	local primary = model.PrimaryPart
	local startCF = primary.CFrame
	local offsetMap = {}

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			offsetMap[part] = startCF:ToObjectSpace(part.CFrame)
		end
	end

	local steps = math.max(1, math.floor(duration * 20))
	for i = 1, steps do
		local alpha = i / steps
		local currentCF = startCF:Lerp(targetCFrame, alpha)
		for part, relCF in pairs(offsetMap) do
			if part and part.Parent then
				part.CFrame = currentCF * relCF
			end
		end
		task.wait(duration / steps)
	end
end

function GuestService.RunGuestStay(plot, player, roomId)
	local lobby = plot:FindFirstChild("Lobby")
	local room = plot:FindFirstChild(roomId)
	if not lobby or not room then return end

	local checkInSpot = lobby:FindFirstChild("GuestCheckInSpot")
	local restSpot = room:FindFirstChild("GuestRestSpot")
	local entranceCF = plot.PlotSpawn.CFrame + Vector3.new(0, 2, 0)
	if not checkInSpot or not restSpot then return end

	local guest = GuestService.CreateGhostGuestModel(entranceCF)
	guest.Parent = plot

	local statusLabel = guest.Head.StatusGui.StatusLabel

	-- 1. Move to Reception
	GuestService.MoveModel(guest, checkInSpot.CFrame + Vector3.new(0, 2.5, 0), 1.6)
	statusLabel.Text = "🛎️ Ringing Bell..."
	task.wait(1.2)

	-- 2. Move to Room
	statusLabel.Text = "🛏️ Heading to " .. roomId .. "..."
	GuestService.MoveModel(guest, restSpot.CFrame + Vector3.new(0, 2.2, 0), 2.0)

	-- 3. Calculate Staff Bonuses (Housekeeper Turnover & Bellhop Tip)
	local tipBonus = 0
	local turnoverReduction = 0
	if player then
		local profile = GuestService.EconomyService.GetProfile(player)
		local assigned = GuestService.EconomyService.GetAssignedStaff(player)
		if profile and assigned then
			for slotIdx, ghostId in pairs(assigned) do
				if ghostId == "Bellhop" then
					local gData = profile.DiscoveredGhosts["Bellhop"]
					local lv = gData and gData.Level or 1
					tipBonus = tipBonus + GhostConfig.Ghosts.Bellhop.Ability.Calculate(lv)
				elseif ghostId == "Housekeeper" then
					local gData = profile.DiscoveredGhosts["Housekeeper"]
					local lv = gData and gData.Level or 1
					turnoverReduction = turnoverReduction + GhostConfig.Ghosts.Housekeeper.Ability.Calculate(lv)
				end
			end
		end
	end

	-- 4. Rest in room (Turnover time reduced by Housekeeper)
	local baseDuration = GameConfig.BaseStayDuration or 6
	local actualDuration = math.max(2, math.floor(baseDuration - turnoverReduction))
	for remaining = actualDuration, 1, -1 do
		if not plot or not plot.Parent then
			guest:Destroy()
			return
		end
		if turnoverReduction > 0 then
			statusLabel.Text = string.format("⚡ Quick Rest (%ds) [-%.1fs Maid]", remaining, turnoverReduction)
		else
			statusLabel.Text = string.format("💤 Resting... (%ds)", remaining)
		end
		task.wait(1)
	end

	-- 5. Payout with Bellhop tip bonus
	local state = plot:FindFirstChild("PlotState")
	local roomLevel = state and state[roomId .. "Level"].Value or 1
	local roomConfig = GameConfig.Rooms[roomId]
	local baseIncome = roomConfig and roomConfig.Upgrades[roomLevel] and roomConfig.Upgrades[roomLevel].Income or 15
	local totalIncome = baseIncome + tipBonus

	if player and player.Parent then
		GuestService.EconomyService.AddCoins(player, totalIncome, "GuestCompletedStay")
		GuestService.EconomyService.IncrementGuestsServed(player)

		GuestStateChanged:FireClient(player, {
			Event = "StayCompleted",
			RoomId = roomId,
			Income = totalIncome,
			BaseIncome = baseIncome,
			Tip = tipBonus,
			Position = restSpot.Position,
		})
	end

	if tipBonus > 0 then
		statusLabel.Text = string.format("✨ Paid +%d 🪙! (+%d Tip) ✨", totalIncome, tipBonus)
	else
		statusLabel.Text = string.format("✨ Paid +%d 🪙! ✨", totalIncome)
	end
	statusLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	task.wait(1.5)

	-- 6. Checkout
	statusLabel.Text = "👻 Checking out..."
	statusLabel.TextColor3 = Color3.fromRGB(180, 235, 255)
	GuestService.MoveModel(guest, entranceCF, 2.0)

	guest:Destroy()

	if state and state:FindFirstChild(roomId .. "Occupied") then
		state[roomId .. "Occupied"].Value = false
	end
end

function GuestService.CleanupPlotGuests(plot)
	for _, child in ipairs(plot:GetChildren()) do
		if child.Name == "GhostGuest" then
			child:Destroy()
		end
	end
end

return GuestService
