-- ServerScriptService/Services/GuestService.luau
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
local guestModels = {}

GuestService.EconomyService = require(SSS.Services.EconomyService)
GuestService.HotelService = require(SSS.Services.HotelService)
local MonetizationService = nil

function GuestService.Init(economyService, hotelService, monetizationService)
	GuestService.EconomyService = economyService or GuestService.EconomyService
	GuestService.HotelService = hotelService or GuestService.HotelService
	MonetizationService = monetizationService or require(SSS.Services.MonetizationService)
end

function GuestService.Start()
	if isRunning then return end
	isRunning = true

	task.spawn(function()
		while isRunning do
			task.wait(GameConfig.GuestArrivalInterval or 7)
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

-- Pick guest type by weight
local function rollGuestType()
	local types = GameConfig.GuestTypes or {}
	local totalWeight = 0
	for _, gType in pairs(types) do
		totalWeight = totalWeight + (gType.Weight or 10)
	end

	local roll = math.random(1, math.max(1, totalWeight))
	local current = 0
	for _, gType in pairs(types) do
		current = current + (gType.Weight or 10)
		if roll <= current then
			return gType
		end
	end
	return types.Regular or { Id = "Regular", Name = "Ordinary Specter", PayoutMultiplier = 1.0, Color = Color3.fromRGB(150, 225, 255) }
end

function GuestService.TrySpawnGuestForPlot(plot)
	local state = plot:FindFirstChild("PlotState")
	if not state then return end

	local isF2Unlocked = GuestService.HotelService.IsFloorUnlocked(plot, 2)
	local availableRooms = {}

	for roomId, roomConfig in pairs(GameConfig.Rooms) do
		local floorIdx = roomConfig.Floor or 1
		local eligible = (floorIdx == 1) or (floorIdx == 2 and isF2Unlocked)
		local occVal = state:FindFirstChild(roomId .. "Occupied")
		if eligible and occVal and occVal.Value == false then
			table.insert(availableRooms, roomId)
		end
	end

	if #availableRooms == 0 then
		return
	end

	local chosenRoomId = availableRooms[math.random(1, #availableRooms)]
	state[chosenRoomId .. "Occupied"].Value = true

	local ownerUserId = plot:GetAttribute("OwnerUserId")
	local player = game.Players:GetPlayerByUserId(ownerUserId)

	local guestType = rollGuestType()

	task.spawn(function()
		GuestService.RunGuestStay(plot, player, chosenRoomId, guestType)
	end)
end

function GuestService.CreateGhostGuestModel(startCFrame, guestType)
	local model = Instance.new("Model")
	model.Name = "GhostGuest_" .. guestType.Id

	local baseColor = guestType.Color or Color3.fromRGB(150, 225, 255)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(3.5, 2, 2)
	body.CFrame = startCFrame * CFrame.Angles(0, 0, math.rad(90))
	body.Color = baseColor
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
	head.Color = baseColor
	head.Material = Enum.Material.Neon
	head.Transparency = 0.3
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	-- Guest Type Special Effects
	if guestType.Id == "VIP" then
		-- Golden Sparkles ParticleEmitter
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "VIPSparkles"
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 100))
		sparkles.Size = NumberSequence.new(0.4, 0.8)
		sparkles.Rate = 12
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.Lifetime = NumberRange.new(1, 2)
		sparkles.Parent = head

		-- Golden Halo / Tophat
		local hat = Instance.new("Part")
		hat.Name = "VIPHat"
		hat.Shape = Enum.PartType.Cylinder
		hat.Size = Vector3.new(0.8, 1.6, 1.6)
		hat.CFrame = startCFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90))
		hat.Color = Color3.fromRGB(240, 190, 40)
		hat.Material = Enum.Material.Metal
		hat.Anchored = true
		hat.CanCollide = false
		hat.Parent = model
	elseif guestType.Id == "Occultist" then
		-- Purple occult runes particle
		local runes = Instance.new("ParticleEmitter")
		runes.Name = "OccultRunes"
		runes.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255))
		runes.Size = NumberSequence.new(0.5, 1.0)
		runes.Rate = 10
		runes.Speed = NumberRange.new(0.5, 1.5)
		runes.Lifetime = NumberRange.new(1.5, 2.5)
		runes.Parent = head
	end

	-- Overhead Guest Type Label
	local bb = Instance.new("BillboardGui")
	bb.Name = "GuestGui"
	bb.Size = UDim2.new(0, 150, 0, 36)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = guestType.Name
	label.TextColor3 = baseColor
	label.TextSize = 12
	label.Parent = bb

	model.PrimaryPart = head
	return model
end

function GuestService.MoveModelSmoothly(model, targetCFrame, duration)
	local startTime = os.clock()
	local startCFrame = model:GetPivot()

	while os.clock() - startTime < duration do
		local alpha = (os.clock() - startTime) / duration
		alpha = math.clamp(alpha, 0, 1)
		local currentCF = startCFrame:Lerp(targetCFrame, alpha)
		model:PivotTo(currentCF)
		task.wait(0.03)
	end
	model:PivotTo(targetCFrame)
end

function GuestService.CalculateSatisfaction(player, plot, roomLevel)
	local satisfaction = 100 -- Base

	-- Room Quality: +10% per level above 1
	satisfaction = satisfaction + (roomLevel - 1) * 10

	-- Staff Presence
	if player then
		local staff = GuestService.EconomyService.GetAssignedStaff(player)
		if staff[1] or staff[2] then
			satisfaction = satisfaction + 15
		end
		if staff[1] == "Bellhop" or staff[2] == "Bellhop" then
			satisfaction = satisfaction + 10
		end
	end

	return math.clamp(satisfaction, 80, 175)
end

function GuestService.RunGuestStay(plot, player, roomId, guestType)
	local state = plot:FindFirstChild("PlotState")
	local room = plot:FindFirstChild(roomId)
	local lobby = plot:FindFirstChild("Lobby")
	local spawnPart = plot:FindFirstChild("PlotSpawn")

	if not room or not lobby or not spawnPart then
		if state and state:FindFirstChild(roomId .. "Occupied") then
			state[roomId .. "Occupied"].Value = false
		end
		return
	end

	local checkInSpot = lobby:FindFirstChild("GuestCheckInSpot")
	local restSpot = room:FindFirstChild("GuestRestSpot")

	if not checkInSpot or not restSpot then
		if state and state:FindFirstChild(roomId .. "Occupied") then
			state[roomId .. "Occupied"].Value = false
		end
		return
	end

	local guestModel = GuestService.CreateGhostGuestModel(spawnPart.CFrame + Vector3.new(0, 1.5, 0), guestType)
	guestModel.Parent = plot

	guestModels[plot] = guestModels[plot] or {}
	table.insert(guestModels[plot], guestModel)

	-- 1. Walk from Spawn to Reception Desk
	GuestService.MoveModelSmoothly(guestModel, checkInSpot.CFrame + Vector3.new(0, 1.5, 0), 2.0)
	task.wait(1.0) -- Check-in moment

	-- 2. Walk to Room
	GuestService.MoveModelSmoothly(guestModel, restSpot.CFrame + Vector3.new(0, 1.5, 0), 2.5)

	-- 3. Room Stay Duration (modified by Housekeeper and active boosts)
	local roomLevel = state[roomId .. "Level"].Value or 1
	local stayDuration = GameConfig.BaseStayDuration or 8

	if player then
		local staff = GuestService.EconomyService.GetAssignedStaff(player)
		for _, ghostId in pairs(staff) do
			if ghostId == "Housekeeper" then
				local prof = GuestService.EconomyService.GetProfile(player)
				local lv = prof and prof.DiscoveredGhosts["Housekeeper"] and prof.DiscoveredGhosts["Housekeeper"].Level or 1
				local reduction = GhostConfig.Ghosts.Housekeeper.Ability.Calculate(lv)
				stayDuration = math.max(3.0, stayDuration - reduction)
			end
		end
	end

	task.wait(stayDuration)

	-- 4. Calculate Authoritative Payout with Satisfaction & Guest Type Multipliers
	if player and player.Parent then
		local satisfaction = GuestService.CalculateSatisfaction(player, plot, roomLevel)
		local roomConfig = GameConfig.Rooms[roomId]
		local baseIncome = (roomConfig and roomConfig.Upgrades[roomLevel] and roomConfig.Upgrades[roomLevel].Income) or 15

		local satisfactionMultiplier = satisfaction / 100.0
		local guestTypeMultiplier = guestType.PayoutMultiplier or 1.0

		-- Monetization & Reputation Multipliers
		local serverMultiplier = 1.0
		if MonetizationService then
			serverMultiplier = MonetizationService.GetIncomeMultiplier(player)
		end

		local earnedCoins = math.floor(baseIncome * satisfactionMultiplier * guestTypeMultiplier * serverMultiplier)

		-- Tip calculation
		local tip = guestType.BonusTip or 0
		local staff = GuestService.EconomyService.GetAssignedStaff(player)
		for _, ghostId in pairs(staff) do
			if ghostId == "Bellhop" then
				local prof = GuestService.EconomyService.GetProfile(player)
				local lv = prof and prof.DiscoveredGhosts["Bellhop"] and prof.DiscoveredGhosts["Bellhop"].Level or 1
				tip = tip + GhostConfig.Ghosts.Bellhop.Ability.Calculate(lv)
			end
		end

		local totalPayout = earnedCoins + tip
		GuestService.EconomyService.AddCoins(player, totalPayout, "GuestCheckout_" .. roomId)
		GuestService.EconomyService.IncrementGuestsServed(player)

		-- Occultist Bonus Ectoplasm
		local bonusEcto = guestType.BonusEctoplasm or 0
		if bonusEcto > 0 then
			GuestService.EconomyService.AddEctoplasm(player, bonusEcto, "OccultistBonus")
		end

		GuestStateChanged:FireClient(player, {
			Event = "StayCompleted",
			RoomId = roomId,
			GuestType = guestType.Name,
			Satisfaction = satisfaction,
			Income = earnedCoins,
			Tip = tip,
			BonusEctoplasm = bonusEcto,
		})
	end

	-- 5. Departure
	GuestService.MoveModelSmoothly(guestModel, spawnPart.CFrame + Vector3.new(0, 1.5, 0), 2.2)

	-- Cleanup
	if guestModel and guestModel.Parent then
		guestModel:Destroy()
	end

	if state and state:FindFirstChild(roomId .. "Occupied") then
		state[roomId .. "Occupied"].Value = false
	end
end

function GuestService.CleanupPlotGuests(plot)
	if guestModels[plot] then
		for _, m in ipairs(guestModels[plot]) do
			if m and m.Parent then
				m:Destroy()
			end
		end
		guestModels[plot] = nil
	end
end

return GuestService
