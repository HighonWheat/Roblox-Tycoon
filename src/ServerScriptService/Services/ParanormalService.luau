local RepStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local GameConfig = require(RepStorage.Configs.GameConfig)
local function getParaConfig()
	return GameConfig.Paranormal or {
		CheckInterval = 12,
		InitialEventDelay = 8,
		CooldownDuration = 25,
		EventTimeout = 90,
		ClueCount = 2,
		MaxCaptureAttempts = 2,
		AttemptCooldown = 1.0,
		TargetZone = { Min = 0.35, Max = 0.65 },
		BaseEctoplasmReward = 35,
		ClueInvestigationEctoplasm = 5,
		GhostDiscoverChance = 0.75,
		ConsolationCoins = 50,
	}
end
local GhostConfig = require(RepStorage.Configs.GhostConfig)
local Network = RepStorage.Network

local ParanormalEventUpdated = Network.ParanormalEventUpdated

local function safeFireClient(player, data)
	if typeof(player) == "Instance" and player:IsA("Player") then
		ParanormalEventUpdated:FireClient(player, data)
	end
end

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")
local DefaultEconomyService = require(Services:WaitForChild("EconomyService"))
local DefaultHotelService = require(Services:WaitForChild("HotelService"))

local ParanormalService = {}
ParanormalService.EconomyService = DefaultEconomyService
ParanormalService.HotelService = DefaultHotelService
_G.GhostshiftActiveEvents = _G.GhostshiftActiveEvents or {}
local activeEvents = _G.GhostshiftActiveEvents -- [plot] = EventStateTable
local isRunning = false

function ParanormalService.Init(economyService, hotelService)
	ParanormalService.EconomyService = economyService or DefaultEconomyService
	ParanormalService.HotelService = hotelService or DefaultHotelService
end

function ParanormalService.Start()
	if isRunning then return end
	isRunning = true

	task.spawn(function()
		task.wait(getParaConfig().InitialEventDelay or 8)
		while isRunning do
			task.wait(getParaConfig().CheckInterval)
			ParanormalService.CheckAllPlotsForEvents()
		end
	end)
end

function ParanormalService.Stop()
	isRunning = false
end

function ParanormalService.GetEvent(plot)
	return activeEvents[plot]
end

function ParanormalService.CheckAllPlotsForEvents()
	local hotelPlots = Workspace:FindFirstChild("HotelPlots")
	if not hotelPlots then return end

	for _, plot in ipairs(hotelPlots:GetChildren()) do
		local ownerId = plot:GetAttribute("OwnerUserId")
		if ownerId and ownerId > 0 then
			local event = activeEvents[plot]
			local now = os.time()

			if not event or event.State == "Inactive" or (event.State == "Cooldown" and now >= (event.CooldownUntil or 0)) then
				-- Check room availability for haunting
				local roomIds = {"Room1", "Room2"}
				local chosenRoomId = roomIds[math.random(1, #roomIds)]
				ParanormalService.TriggerEvent(plot, chosenRoomId)
			elseif event and (event.State == "CluesAvailable" or event.State == "CaptureAvailable") then
				-- Check timeout
				if now - event.StartTime >= getParaConfig().EventTimeout then
					ParanormalService.FailEvent(plot, "Event timed out")
				end
			end
		end
	end
end

function ParanormalService.TriggerEvent(plot, roomId)
	if not plot or typeof(plot) ~= "Instance" then return nil end
	local room = plot:FindFirstChild(roomId)
	if not room then return end

	local ownerUserId = plot:GetAttribute("OwnerUserId")
	local player = Players:GetPlayerByUserId(ownerUserId)

	local eventData = {
		Plot = plot,
		RoomId = roomId,
		State = "Starting",
		StartTime = os.time(),
		CooldownUntil = 0,
		Clues = {},
		ClueInstances = {},
		DisturbanceParts = {},
		FlickerRunning = true,
		GhostModel = nil,
		CaptureSession = nil,
		Player = player,
	}
	activeEvents[plot] = eventData

	-- 1. Visible Supernatural Disturbance
	-- Room Light Flicker & Teal Tint
	local roomLightPart = room:FindFirstChild("RoomLight")
	local pointLight = roomLightPart and roomLightPart:FindFirstChild("PointLight")
	local originalColor = pointLight and pointLight.Color or Color3.fromRGB(255, 200, 140)
	local originalBrightness = pointLight and pointLight.Brightness or 1.8

	if pointLight then
		pointLight.Color = Color3.fromRGB(80, 240, 220)
		task.spawn(function()
			while eventData.FlickerRunning and pointLight and pointLight.Parent do
				pointLight.Brightness = math.random(3, 35) / 10
				task.wait(0.12)
			end
			if pointLight and pointLight.Parent then
				pointLight.Color = originalColor
				pointLight.Brightness = originalBrightness
			end
		end)
	end

	-- Eerie Mist on Floor
	local mistEmitterPart = Instance.new("Part")
	mistEmitterPart.Name = "SpectralMistNode"
	mistEmitterPart.Size = Vector3.new(14, 0.2, 14)
	mistEmitterPart.CFrame = room.UpgradePad.CFrame * CFrame.new(0, 0.2, -6)
	mistEmitterPart.Transparency = 1
	mistEmitterPart.Anchored = true
	mistEmitterPart.CanCollide = false
	mistEmitterPart.Parent = room

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "MistParticles"
	mist.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 240, 220)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 80, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 180, 200)),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Rate = 18
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.Lifetime = NumberRange.new(2, 3.5)
	mist.Size = NumberSequence.new(2.5, 4.5)
	mist.Parent = mistEmitterPart
	table.insert(eventData.DisturbanceParts, mistEmitterPart)

	-- 2. Spawn Two Discoverable Clues
	-- Clue 1: Flickering Lamp / Ectoplasmic Residue (near Nightstand/Bed)
	local bedPos = room.GuestRestSpot.CFrame
	local clue1Part = Instance.new("Part")
	clue1Part.Name = "Clue_1"
	clue1Part.Shape = Enum.PartType.Ball
	clue1Part.Size = Vector3.new(1.4, 1.4, 1.4)
	clue1Part.CFrame = bedPos * CFrame.new(4.5, 2.8, -3)
	clue1Part.Color = Color3.fromRGB(80, 255, 220)
	clue1Part.Material = Enum.Material.Neon
	clue1Part.Anchored = true
	clue1Part.CanCollide = false
	clue1Part.Parent = room

	local clue1Light = Instance.new("PointLight")
	clue1Light.Color = Color3.fromRGB(90, 255, 220)
	clue1Light.Range = 8
	clue1Light.Brightness = 2
	clue1Light.Parent = clue1Part

	local prompt1 = Instance.new("ProximityPrompt")
	prompt1.Name = "CluePrompt"
	prompt1.ObjectText = "Ectoplasmic Residue"
	prompt1.ActionText = "Investigate Residue"
	prompt1.HoldDuration = 0.4
	prompt1.MaxActivationDistance = 9
	prompt1.Parent = clue1Part

	eventData.Clues["Clue_1"] = {
		Part = clue1Part,
		Claimed = false,
		Prompt = prompt1,
		Name = "Ectoplasmic Residue",
	}
	table.insert(eventData.ClueInstances, clue1Part)

	-- Clue 2: Glowing Spectral Footprints (near room entrance)
	local clue2Part = Instance.new("Part")
	clue2Part.Name = "Clue_2"
	clue2Part.Size = Vector3.new(3.5, 0.2, 3.5)
	clue2Part.CFrame = room.UpgradePad.CFrame * CFrame.new(0, 0.15, -4)
	clue2Part.Color = Color3.fromRGB(150, 100, 255)
	clue2Part.Material = Enum.Material.Neon
	clue2Part.Transparency = 0.3
	clue2Part.Anchored = true
	clue2Part.CanCollide = false
	clue2Part.Parent = room

	local clue2Light = Instance.new("PointLight")
	clue2Light.Color = Color3.fromRGB(170, 110, 255)
	clue2Light.Range = 7
	clue2Light.Brightness = 1.5
	clue2Light.Parent = clue2Part

	local prompt2 = Instance.new("ProximityPrompt")
	prompt2.Name = "CluePrompt"
	prompt2.ObjectText = "Spectral Footprints"
	prompt2.ActionText = "Scan Footprints"
	prompt2.HoldDuration = 0.4
	prompt2.MaxActivationDistance = 9
	prompt2.Parent = clue2Part

	eventData.Clues["Clue_2"] = {
		Part = clue2Part,
		Claimed = false,
		Prompt = prompt2,
		Name = "Spectral Footprints",
	}
	table.insert(eventData.ClueInstances, clue2Part)

	-- Hook server-side prompt triggers
	for clueId, clueObj in pairs(eventData.Clues) do
		clueObj.Prompt.Triggered:Connect(function(triggerPlayer)
			ParanormalService.InvestigateClue(triggerPlayer, clueId)
		end)
	end

	eventData.State = "CluesAvailable"

	-- Notify Owner
	if player and player.Parent then
		safeFireClient(player, {
			Event = "HauntingStarted",
			RoomId = roomId,
			RoomName = GameConfig.Rooms[roomId].Name,
			TotalClues = 2,
		})
		ParanormalService.EconomyService.SetTutorialStep(player, 3)
	end

	return eventData
end

function ParanormalService.InvestigateClue(player, clueId)
	local plot = ParanormalService.HotelService.GetPlayerPlot(player)
	if not plot then
		return false, "You do not own this hotel plot"
	end

	local event = activeEvents[plot]
	if not event or event.State ~= "CluesAvailable" then
		return false, "No active clue investigation in progress"
	end

	local clue = event.Clues[clueId]
	if not clue then
		return false, "Unknown clue identifier"
	end

	if clue.Claimed then
		return false, "Clue has already been examined"
	end

	-- Distance validation
	local character = player.Character
	local root = nil
	if typeof(character) == "Instance" then
		root = character:FindFirstChild("HumanoidRootPart")
	elseif typeof(character) == "table" then
		root = character.HumanoidRootPart
	end
	if not root or (root.Position - clue.Part.Position).Magnitude > 14 then
		return false, "You are too far from the clue"
	end

	-- Mark claimed
	clue.Claimed = true
	clue.Prompt.Enabled = false
	clue.Part.Color = Color3.fromRGB(255, 225, 90) -- turns golden
	if clue.Part:FindFirstChild("PointLight") then
		clue.Part.PointLight.Color = Color3.fromRGB(255, 230, 110)
	end

	-- Reward clue investigation bonus
	local clueEcto = getParaConfig().ClueInvestigationEctoplasm or 5
	ParanormalService.EconomyService.AddEctoplasm(player, clueEcto, "ClueInvestigated")

	-- Count total claimed
	local claimedCount = 0
	for _, c in pairs(event.Clues) do
		if c.Claimed then
			claimedCount = claimedCount + 1
		end
	end

	if claimedCount < getParaConfig().ClueCount then
		safeFireClient(player, {
			Event = "ClueFound",
			ClueId = clueId,
			ClaimedCount = claimedCount,
			TotalClues = getParaConfig().ClueCount,
			BonusEctoplasm = clueEcto,
		})
		return true, string.format("Found %s! (%d/%d clues)", clue.Name, claimedCount, getParaConfig().ClueCount), claimedCount
	else
		-- All clues found -> Manifest Ghost!
		event.State = "CaptureAvailable"
		ParanormalService.ManifestGhost(plot, event.RoomId)

		safeFireClient(player, {
			Event = "CaptureReady",
			RoomId = event.RoomId,
			GhostName = GhostConfig.Ghosts.Bellhop.Name,
			ClaimedCount = claimedCount,
			TotalClues = getParaConfig().ClueCount,
		})
		ParanormalService.EconomyService.SetTutorialStep(player, 4)

		return true, "All clues found! The entity has manifested!", claimedCount
	end
end

function ParanormalService.ManifestGhost(plot, roomId)
	local room = plot:FindFirstChild(roomId)
	local restSpot = room and room:FindFirstChild("GuestRestSpot")
	if not restSpot then return end

	local ghost = Instance.new("Model")
	ghost.Name = "ParanormalEntity_Jasper"

	local centerCF = restSpot.CFrame + Vector3.new(0, 3.2, 0)

	-- Torso
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(3.6, 2.2, 2.2)
	body.CFrame = centerCF * CFrame.Angles(0, 0, math.rad(90))
	body.Color = Color3.fromRGB(110, 240, 215)
	body.Material = Enum.Material.Neon
	body.Transparency = 0.35
	body.Anchored = true
	body.CanCollide = false
	body.Parent = ghost

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.CFrame = centerCF * CFrame.new(0, 2.1, 0)
	head.Color = Color3.fromRGB(130, 255, 230)
	head.Material = Enum.Material.Neon
	head.Transparency = 0.3
	head.Anchored = true
	head.CanCollide = false
	head.Parent = ghost

	-- Eyes
	local leftEye = Instance.new("Part")
	leftEye.Size = Vector3.new(0.4, 0.4, 0.4)
	leftEye.Shape = Enum.PartType.Ball
	leftEye.Color = Color3.fromRGB(30, 20, 50)
	leftEye.CFrame = centerCF * CFrame.new(-0.4, 2.3, -0.95)
	leftEye.Anchored = true
	leftEye.CanCollide = false
	leftEye.Parent = ghost

	local rightEye = Instance.new("Part")
	rightEye.Size = Vector3.new(0.4, 0.4, 0.4)
	rightEye.Shape = Enum.PartType.Ball
	rightEye.Color = Color3.fromRGB(30, 20, 50)
	rightEye.CFrame = centerCF * CFrame.new(0.4, 2.3, -0.95)
	rightEye.Anchored = true
	rightEye.CanCollide = false
	rightEye.Parent = ghost

	-- Bellhop Pillbox Cap (Recognizable signature)
	local cap = Instance.new("Part")
	cap.Name = "BellhopCap"
	cap.Shape = Enum.PartType.Cylinder
	cap.Size = Vector3.new(0.8, 1.6, 1.6)
	cap.CFrame = centerCF * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(90))
	cap.Color = Color3.fromRGB(160, 25, 45) -- Crimson vintage red
	cap.Material = Enum.Material.Fabric
	cap.Anchored = true
	cap.CanCollide = false
	cap.Parent = ghost

	-- Gold band trim
	local goldBand = Instance.new("Part")
	goldBand.Name = "GoldBand"
	goldBand.Shape = Enum.PartType.Cylinder
	goldBand.Size = Vector3.new(0.2, 1.65, 1.65)
	goldBand.CFrame = centerCF * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	goldBand.Color = Color3.fromRGB(255, 215, 0)
	goldBand.Material = Enum.Material.Metal
	goldBand.Anchored = true
	goldBand.CanCollide = false
	goldBand.Parent = ghost

	-- Floating BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "EntityGui"
	bb.Size = UDim2.new(0, 200, 0, 56)
	bb.StudsOffset = Vector3.new(0, 4.8, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(24, 16, 36)
	frame.BorderSizePixel = 0
	frame.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 230, 150)
	stroke.Thickness = 2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.5, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "👻 Jasper the Bellhop"
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(120, 255, 220)
	title.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 0, 0.5, 0)
	sub.Size = UDim2.new(1, 0, 0.5, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.Text = "UNCOMMON SPIRIT • [E] TO CAPTURE"
	sub.TextSize = 10
	sub.TextColor3 = Color3.fromRGB(255, 230, 120)
	sub.Parent = frame

	-- Capture Proximity Prompt
	local capturePrompt = Instance.new("ProximityPrompt")
	capturePrompt.Name = "CapturePrompt"
	capturePrompt.ActionText = "Initiate Containment"
	capturePrompt.ObjectText = "Jasper the Bellhop"
	capturePrompt.HoldDuration = 0.5
	capturePrompt.MaxActivationDistance = 9
	capturePrompt.Parent = head

	local event = activeEvents[plot]
	if event then
		event.GhostModel = ghost
		event.CapturePrompt = capturePrompt

		capturePrompt.Triggered:Connect(function(triggerPlayer)
			local ownerId = plot:GetAttribute("OwnerUserId")
			if triggerPlayer.UserId == ownerId then
				ParanormalService.StartCapture(triggerPlayer)
			end
		end)
	end

	ghost.PrimaryPart = head
	ghost.Parent = room
	return ghost
end

function ParanormalService.StartCapture(player)
	local plot = ParanormalService.HotelService.GetPlayerPlot(player)
	if not plot then
		return false, "You do not own this hotel plot"
	end

	local event = activeEvents[plot]
	if not event or event.State ~= "CaptureAvailable" then
		return false, "Ghost is not ready for capture"
	end

	local ghost = event.GhostModel
	if not ghost or not ghost.PrimaryPart then
		return false, "Ghost model is not manifested"
	end

	local character = player.Character
	local root = nil
	if typeof(character) == "Instance" then
		root = character:FindFirstChild("HumanoidRootPart")
	elseif typeof(character) == "table" then
		root = character.HumanoidRootPart
	end
	if not root or (root.Position - ghost.PrimaryPart.Position).Magnitude > 14 then
		return false, "You must be closer to initiate containment"
	end

	-- Create or reuse capture session
	local sessionToken = tostring(math.random(100000, 999999)) .. "_" .. tostring(os.time())
	event.CaptureSession = {
		Token = sessionToken,
		TargetMin = getParaConfig().TargetZone.Min,
		TargetMax = getParaConfig().TargetZone.Max,
		AttemptsLeft = event.CaptureSession and event.CaptureSession.AttemptsLeft or getParaConfig().MaxCaptureAttempts,
		ExpiresAt = os.time() + 25,
		LastAttemptTime = 0,
	}

	-- Notify client to open minigame
	safeFireClient(player, {
		Event = "OpenCaptureMinigame",
		Token = sessionToken,
		TargetMin = event.CaptureSession.TargetMin,
		TargetMax = event.CaptureSession.TargetMax,
		AttemptsLeft = event.CaptureSession.AttemptsLeft,
		GhostName = GhostConfig.Ghosts.Bellhop.Name,
		GhostRarity = GhostConfig.Ghosts.Bellhop.Rarity,
	})

	return true, {
		Token = sessionToken,
		TargetMin = event.CaptureSession.TargetMin,
		TargetMax = event.CaptureSession.TargetMax,
		AttemptsLeft = event.CaptureSession.AttemptsLeft,
	}
end

function ParanormalService.SubmitCaptureAttempt(player, token, normalizedPos)
	local plot = ParanormalService.HotelService.GetPlayerPlot(player)
	if not plot then
		return false, { Success = false, Message = "No active plot" }
	end

	local event = activeEvents[plot]
	if not event or event.State ~= "CaptureAvailable" then
		return false, { Success = false, Message = "Capture is not available" }
	end

	local session = event.CaptureSession
	if not session or session.Token ~= token then
		return false, { Success = false, Message = "Invalid capture session token" }
	end

	if os.time() > session.ExpiresAt then
		ParanormalService.FailEvent(plot, "Capture session expired")
		return false, { Success = false, Message = "Capture window expired" }
	end

	if session.AttemptsLeft <= 0 then
		return false, { Success = false, Message = "No attempts remaining" }
	end

	-- Cooldown between rapid clicks
	local now = tick()
	if now - session.LastAttemptTime < (getParaConfig().AttemptCooldown or 0.8) then
		return false, { Success = false, Message = "Wait before next attempt" }
	end
	session.LastAttemptTime = now
	session.AttemptsLeft = session.AttemptsLeft - 1

	local isHit = (typeof(normalizedPos) == "number") and (normalizedPos >= session.TargetMin and normalizedPos <= session.TargetMax)

	if isHit then
		-- SUCCESSFUL CAPTURE!
		event.State = "Completed"
		event.FlickerRunning = false

		-- Award Base Ectoplasm
		local ectoReward = getParaConfig().BaseEctoplasmReward or 35
		ParanormalService.EconomyService.AddEctoplasm(player, ectoReward, "GhostCaptured")

		-- Roll for Ghost Discovery (Jasper the Bellhop)
		local roll = math.random()
		local discoveredGhost = nil
		local bonusCoins = 0

		if roll <= getParaConfig().GhostDiscoverChance then
			discoveredGhost = "Bellhop"
			ParanormalService.EconomyService.AddDiscoveredGhost(player, "Bellhop")
		else
			bonusCoins = getParaConfig().ConsolationCoins or 50
			ParanormalService.EconomyService.AddCoins(player, bonusCoins, "GhostEscapeBonus")
		end

		ParanormalService.EconomyService.SetTutorialStep(player, 5)

		-- Notify client of victory
		safeFireClient(player, {
			Event = "EventCompleted",
			Success = true,
			DiscoveredGhost = discoveredGhost,
			GhostData = discoveredGhost and GhostConfig.Ghosts[discoveredGhost] or nil,
			Ectoplasm = ectoReward,
			Coins = bonusCoins,
		})

		-- Visual capture suction effect
		if event.GhostModel and event.GhostModel.PrimaryPart then
			task.spawn(function()
				for i = 1, 10 do
					if event.GhostModel and event.GhostModel.PrimaryPart then
						event.GhostModel.PrimaryPart.Size = event.GhostModel.PrimaryPart.Size * 0.8
					end
					task.wait(0.05)
				end
			end)
		end

		-- Clean up after delay & start cooldown
		task.delay(2.5, function()
			ParanormalService.CleanupEvent(plot)
			event.State = "Cooldown"
			event.CooldownUntil = os.time() + getParaConfig().CooldownDuration
		end)

		return true, {
			Success = true,
			DiscoveredGhost = discoveredGhost,
			GhostData = discoveredGhost and GhostConfig.Ghosts[discoveredGhost] or nil,
			Ectoplasm = ectoReward,
			Coins = bonusCoins,
		}
	else
		-- MISSED ATTEMPT
		if session.AttemptsLeft > 0 then
			return false, {
				Success = false,
				RetriesLeft = session.AttemptsLeft,
				Message = string.format("Containment slipped! %d attempt remaining.", session.AttemptsLeft),
			}
		else
			-- ALL ATTEMPTS EXHAUSTED -> FAIL
			ParanormalService.FailEvent(plot, "The spirit broke free and vanished!")
			return false, {
				Success = false,
				RetriesLeft = 0,
				Message = "The spirit broke free and fled into the walls!",
			}
		end
	end
end

function ParanormalService.FailEvent(plot, reason)
	local event = activeEvents[plot]
	if not event then return end

	event.State = "Failed"
	event.FlickerRunning = false

	if event.Player and event.Player.Parent then
		safeFireClient(event.Player, {
			Event = "EventFailed",
			Message = reason or "The paranormal disturbance subsided.",
		})
	end

	task.delay(2, function()
		ParanormalService.CleanupEvent(plot)
		event.State = "Cooldown"
		event.CooldownUntil = os.time() + getParaConfig().CooldownDuration
	end)
end

function ParanormalService.CleanupEvent(plot)
	local event = activeEvents[plot]
	if not event then return end

	event.FlickerRunning = false

	if event.GhostModel then
		event.GhostModel:Destroy()
		event.GhostModel = nil
	end

	for _, cluePart in ipairs(event.ClueInstances or {}) do
		if cluePart and cluePart.Parent then
			cluePart:Destroy()
		end
	end

	for _, part in ipairs(event.DisturbanceParts or {}) do
		if part and part.Parent then
			part:Destroy()
		end
	end

	event.ClueInstances = {}
	event.DisturbanceParts = {}
	event.CaptureSession = nil
end

function ParanormalService.CleanupPlot(plot)
	ParanormalService.CleanupEvent(plot)
	activeEvents[plot] = nil
end

return ParanormalService
