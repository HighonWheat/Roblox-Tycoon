-- ServerScriptService/Services/ParanormalService.luau
local RepStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")

local GameConfig = require(RepStorage.Configs.GameConfig)
local GhostConfig = require(RepStorage.Configs.GhostConfig)
local Network = RepStorage.Network
local ParanormalEventUpdated = Network.ParanormalEventUpdated

local ParanormalService = {}
local isRunning = false
local activeEvents = {} -- [plot] = eventData

ParanormalService.EconomyService = require(SSS.Services.EconomyService)
ParanormalService.HotelService = require(SSS.Services.HotelService)

local function getParaConfig()
	return GameConfig.Paranormal or {
		CheckInterval = 12,
		CooldownDuration = 25,
		EventTimeout = 90,
		ClueCount = 2,
		MaxCaptureAttempts = 2,
		TargetZone = { Min = 0.35, Max = 0.65 },
		BaseEctoplasmReward = 35,
		ClueInvestigationEctoplasm = 5,
		GhostDiscoverChance = 0.75,
		ConsolationCoins = 50,
	}
end

local function safeFireClient(player, data)
	if typeof(player) == "Instance" and player:IsA("Player") and player.Parent then
		ParanormalEventUpdated:FireClient(player, data)
	end
end

function ParanormalService.Init(economyService, hotelService)
	ParanormalService.EconomyService = economyService or ParanormalService.EconomyService
	ParanormalService.HotelService = hotelService or ParanormalService.HotelService
end

function ParanormalService.Start()
	if isRunning then return end
	isRunning = true

	task.spawn(function()
		task.wait(getParaConfig().InitialEventDelay or 10)
		while isRunning do
			task.wait(getParaConfig().CheckInterval or 12)
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
				-- Roll available event types based on plot expansion
				local isF2Unlocked = ParanormalService.HotelService.IsFloorUnlocked(plot, 2)
				local eventPool = { "HauntedRoom", "LivingLuggage" }
				if isF2Unlocked then
					table.insert(eventPool, "MirrorVisitor")
				end

				local chosenType = eventPool[math.random(1, #eventPool)]
				ParanormalService.TriggerEvent(plot, chosenType)
			elseif event and (event.State == "CluesAvailable" or event.State == "CaptureAvailable") then
				if now - event.StartTime >= getParaConfig().EventTimeout then
					ParanormalService.FailEvent(plot, "Event timed out")
				end
			end
		end
	end
end

function ParanormalService.TriggerEvent(plot, eventType)
	if not plot or typeof(plot) ~= "Instance" then return nil end

	local ownerUserId = plot:GetAttribute("OwnerUserId")
	local player = Players:GetPlayerByUserId(ownerUserId)

	local eventData = {
		Plot = plot,
		EventType = eventType or "HauntedRoom",
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

	if eventType == "LivingLuggage" then
		ParanormalService.SetupLivingLuggageEvent(plot, eventData)
	elseif eventType == "MirrorVisitor" then
		ParanormalService.SetupMirrorVisitorEvent(plot, eventData)
	else
		ParanormalService.SetupHauntedRoomEvent(plot, eventData)
	end

	eventData.State = "CluesAvailable"
	return eventData
end

-- EVENT 1: Standard Haunted Room
function ParanormalService.SetupHauntedRoomEvent(plot, eventData)
	local isF2Unlocked = ParanormalService.HotelService.IsFloorUnlocked(plot, 2)
	local eligibleRooms = { "Room1", "Room2" }
	if isF2Unlocked then
		table.insert(eligibleRooms, "Room3")
		table.insert(eligibleRooms, "Room4")
	end

	local roomId = eligibleRooms[math.random(1, #eligibleRooms)]
	local room = plot:FindFirstChild(roomId)
	if not room then return end

	eventData.RoomId = roomId

	-- 1. Flickering Lights & Mist
	local roomLightPart = room:FindFirstChild("RoomLight")
	local pointLight = roomLightPart and roomLightPart:FindFirstChild("PointLight")
	local origColor = pointLight and pointLight.Color or Color3.fromRGB(255, 200, 140)
	local origBright = pointLight and pointLight.Brightness or 1.8

	if pointLight then
		pointLight.Color = Color3.fromRGB(80, 240, 220)
		task.spawn(function()
			while eventData.FlickerRunning and pointLight and pointLight.Parent do
				pointLight.Brightness = math.random(3, 35) / 10
				task.wait(0.12)
			end
			if pointLight and pointLight.Parent then
				pointLight.Color = origColor
				pointLight.Brightness = origBright
			end
		end)
	end

	local bedPos = room:FindFirstChild("GuestRestSpot") and room.GuestRestSpot.CFrame or room:GetPivot()

	-- Clue 1: Ectoplasmic Residue
	local clue1Part = Instance.new("Part")
	clue1Part.Name = "Clue_1"
	clue1Part.Shape = Enum.PartType.Ball
	clue1Part.Size = Vector3.new(1.4, 1.4, 1.4)
	clue1Part.CFrame = bedPos * CFrame.new(4, 2.5, -2)
	clue1Part.Color = Color3.fromRGB(80, 255, 220)
	clue1Part.Material = Enum.Material.Neon
	clue1Part.Anchored = true
	clue1Part.CanCollide = false
	clue1Part.Parent = room

	local p1 = Instance.new("ProximityPrompt")
	p1.Name = "CluePrompt"
	p1.ObjectText = "Ectoplasmic Residue"
	p1.ActionText = "Investigate Residue"
	p1.HoldDuration = 0.4
	p1.MaxActivationDistance = 9
	p1.Parent = clue1Part

	eventData.Clues["Clue_1"] = { Part = clue1Part, Claimed = false, Prompt = p1, Name = "Ectoplasmic Residue" }
	table.insert(eventData.ClueInstances, clue1Part)

	-- Clue 2: Spectral Footprints
	local clue2Part = Instance.new("Part")
	clue2Part.Name = "Clue_2"
	clue2Part.Size = Vector3.new(3.5, 0.2, 3.5)
	clue2Part.CFrame = bedPos * CFrame.new(-3, 0.1, 4)
	clue2Part.Color = Color3.fromRGB(150, 100, 255)
	clue2Part.Material = Enum.Material.Neon
	clue2Part.Transparency = 0.3
	clue2Part.Anchored = true
	clue2Part.CanCollide = false
	clue2Part.Parent = room

	local p2 = Instance.new("ProximityPrompt")
	p2.Name = "CluePrompt"
	p2.ObjectText = "Spectral Footprints"
	p2.ActionText = "Inspect Footprints"
	p2.HoldDuration = 0.4
	p2.MaxActivationDistance = 9
	p2.Parent = clue2Part

	eventData.Clues["Clue_2"] = { Part = clue2Part, Claimed = false, Prompt = p2, Name = "Spectral Footprints" }
	table.insert(eventData.ClueInstances, clue2Part)

	local roomConfig = GameConfig.Rooms[roomId]
	safeFireClient(eventData.Player, {
		Event = "HauntingStarted",
		EventType = "HauntedRoom",
		RoomId = roomId,
		RoomName = roomConfig and roomConfig.Name or roomId,
		TimeoutSeconds = getParaConfig().EventTimeout,
	})
end

-- EVENT 2: Living Luggage (Moving possessed steamer trunk)
function ParanormalService.SetupLivingLuggageEvent(plot, eventData)
	local lobby = plot:FindFirstChild("Lobby")
	local rootCF = lobby and lobby:GetPivot() or plot:GetPivot()
	eventData.RoomId = "Lobby"

	-- Spawn possessed steamer trunk
	local trunk = Instance.new("Part")
	trunk.Name = "LivingTrunk"
	trunk.Size = Vector3.new(3.6, 2.4, 2.4)
	trunk.CFrame = rootCF * CFrame.new(-7, 1.2, 8)
	trunk.Color = Color3.fromRGB(65, 35, 20)
	trunk.Material = Enum.Material.WoodPlanks
	trunk.Anchored = true
	trunk.CanCollide = true
	trunk.Parent = plot
	table.insert(eventData.DisturbanceParts, trunk)

	-- Green glowing supernatural aura particles
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "EctoSparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(90, 255, 140))
	sparks.Size = NumberSequence.new(0.3, 0.7)
	sparks.Rate = 18
	sparks.Speed = NumberRange.new(1.5, 3.5)
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Parent = trunk

	-- Trunk gentle rattle animation loop
	local rattleRunning = true
	local origTrunkCF = trunk.CFrame
	task.spawn(function()
		local t = 0
		while rattleRunning and trunk and trunk.Parent do
			t = t + 0.15
			local offset = Vector3.new(math.sin(t * 12) * 0.1, math.abs(math.sin(t * 8)) * 0.15, 0)
			trunk.CFrame = origTrunkCF + offset
			task.wait(0.05)
		end
	end)
	table.insert(eventData.DisturbanceParts, { Stop = function() rattleRunning = false end })

	-- Clue 1: Rattling Brass Latch
	local latch = Instance.new("Part")
	latch.Name = "Clue_1"
	latch.Size = Vector3.new(0.8, 0.8, 0.4)
	latch.CFrame = trunk.CFrame * CFrame.new(0, 0.4, 1.3)
	latch.Color = Color3.fromRGB(240, 210, 80)
	latch.Material = Enum.Material.Metal
	latch.Anchored = true
	latch.CanCollide = false
	latch.Parent = plot

	local p1 = Instance.new("ProximityPrompt")
	p1.Name = "CluePrompt"
	p1.ObjectText = "Possessed Steamer Trunk"
	p1.ActionText = "Soothe Rattling Latch"
	p1.HoldDuration = 0.4
	p1.MaxActivationDistance = 9
	p1.Parent = latch

	eventData.Clues["Clue_1"] = { Part = latch, Claimed = false, Prompt = p1, Name = "Rattling Brass Latch" }
	table.insert(eventData.ClueInstances, latch)

	-- Clue 2: Ghostly Luggage Tag
	local tag = Instance.new("Part")
	tag.Name = "Clue_2"
	tag.Size = Vector3.new(0.7, 0.9, 0.1)
	tag.CFrame = trunk.CFrame * CFrame.new(1.4, 0.2, 1.3) * CFrame.Angles(0, 0, math.rad(-15))
	tag.Color = Color3.fromRGB(180, 240, 220)
	tag.Material = Enum.Material.Neon
	tag.Anchored = true
	tag.CanCollide = false
	tag.Parent = plot

	local p2 = Instance.new("ProximityPrompt")
	p2.Name = "CluePrompt"
	p2.ObjectText = "Antique Luggage Tag"
	p2.ActionText = "Read Spirit Name: Property of Mildred"
	p2.HoldDuration = 0.4
	p2.MaxActivationDistance = 9
	p2.Parent = tag

	eventData.Clues["Clue_2"] = { Part = tag, Claimed = false, Prompt = p2, Name = "Ghostly Luggage Tag" }
	table.insert(eventData.ClueInstances, tag)

	safeFireClient(eventData.Player, {
		Event = "HauntingStarted",
		EventType = "LivingLuggage",
		RoomId = "Lobby",
		RoomName = "Hotel Lobby (Living Luggage)",
		TimeoutSeconds = getParaConfig().EventTimeout,
	})
end

-- EVENT 3: Mirror Visitor
function ParanormalService.SetupMirrorVisitorEvent(plot, eventData)
	local room4 = plot:FindFirstChild("Room4")
	local targetRoom = room4 or plot:FindFirstChild("Room2")
	local roomName = room4 and "Room 4 (Phantom Ballroom)" or "Room 2 (Phantom Parlor)"
	eventData.RoomId = targetRoom.Name

	local mirrorPos = targetRoom and targetRoom:GetPivot() or plot:GetPivot()

	-- Eerie frost aura on the wall mirror
	local frostPart = Instance.new("Part")
	frostPart.Name = "MirrorFrost"
	frostPart.Size = Vector3.new(7, 6, 0.2)
	frostPart.CFrame = mirrorPos * CFrame.new(0, 4.5, -7)
	frostPart.Color = Color3.fromRGB(140, 220, 255)
	frostPart.Material = Enum.Material.Ice
	frostPart.Transparency = 0.4
	frostPart.Anchored = true
	frostPart.CanCollide = false
	frostPart.Parent = plot
	table.insert(eventData.DisturbanceParts, frostPart)

	-- Clue 1: Ectoplasmic Handprint
	local handprint = Instance.new("Part")
	handprint.Name = "Clue_1"
	handprint.Shape = Enum.PartType.Ball
	handprint.Size = Vector3.new(1.2, 1.2, 0.3)
	handprint.CFrame = frostPart.CFrame * CFrame.new(-1.2, 0.5, 0.2)
	handprint.Color = Color3.fromRGB(110, 255, 230)
	handprint.Material = Enum.Material.Neon
	handprint.Anchored = true
	handprint.CanCollide = false
	handprint.Parent = plot

	local p1 = Instance.new("ProximityPrompt")
	p1.Name = "CluePrompt"
	p1.ObjectText = "Haunted Mirror"
	p1.ActionText = "Examine Spectral Handprint"
	p1.HoldDuration = 0.4
	p1.MaxActivationDistance = 9
	p1.Parent = handprint

	eventData.Clues["Clue_1"] = { Part = handprint, Claimed = false, Prompt = p1, Name = "Ectoplasmic Handprint" }
	table.insert(eventData.ClueInstances, handprint)

	-- Clue 2: Mystic Candle Reflection
	local candle = Instance.new("Part")
	candle.Name = "Clue_2"
	candle.Size = Vector3.new(0.8, 1.8, 0.8)
	candle.CFrame = frostPart.CFrame * CFrame.new(1.8, -1.2, 1.2)
	candle.Color = Color3.fromRGB(240, 160, 255)
	candle.Material = Enum.Material.Neon
	candle.Anchored = true
	candle.CanCollide = false
	candle.Parent = plot

	local p2 = Instance.new("ProximityPrompt")
	p2.Name = "CluePrompt"
	p2.ObjectText = "Mystic Reflection"
	p2.ActionText = "Align Reflection Angle"
	p2.HoldDuration = 0.4
	p2.MaxActivationDistance = 9
	p2.Parent = candle

	eventData.Clues["Clue_2"] = { Part = candle, Claimed = false, Prompt = p2, Name = "Mystic Reflection" }
	table.insert(eventData.ClueInstances, candle)

	safeFireClient(eventData.Player, {
		Event = "HauntingStarted",
		EventType = "MirrorVisitor",
		RoomId = targetRoom.Name,
		RoomName = roomName .. " (Mirror Visitor)",
		TimeoutSeconds = getParaConfig().EventTimeout,
	})
end

-- Unified Clue Investigation
function ParanormalService.InvestigateClue(player, clueId)
	local plot = ParanormalService.HotelService.GetPlayerPlot(player)
	if not plot then return false, "No hotel plot" end

	local event = activeEvents[plot]
	if not event or event.State ~= "CluesAvailable" then
		return false, "No active investigation"
	end

	local clue = event.Clues[clueId]
	if not clue then return false, "Unknown clue" end
	if clue.Claimed then return false, "Clue already investigated" end

	clue.Claimed = true
	if clue.Prompt then clue.Prompt.Enabled = false end
	if clue.Part then clue.Part.Transparency = 0.85 end

	local clueEcto = getParaConfig().ClueInvestigationEctoplasm or 5
	ParanormalService.EconomyService.AddEctoplasm(player, clueEcto, "ClueInvestigation_" .. clueId)

	local claimedCount = 0
	for _, c in pairs(event.Clues) do
		if c.Claimed then claimedCount = claimedCount + 1 end
	end

	if claimedCount < getParaConfig().ClueCount then
		safeFireClient(player, {
			Event = "ClueFound",
			RoomId = event.RoomId,
			ClaimedCount = claimedCount,
			TotalClues = getParaConfig().ClueCount,
			BonusEctoplasm = clueEcto,
		})
		return true, string.format("Found %s! (%d/%d clues)", clue.Name, claimedCount, getParaConfig().ClueCount), claimedCount
	else
		event.State = "CaptureAvailable"
		ParanormalService.ManifestGhost(plot, event.RoomId, event.EventType)

		safeFireClient(player, {
			Event = "CaptureReady",
			RoomId = event.RoomId,
			GhostName = (event.EventType == "LivingLuggage" and "Mildred the Maid") or (event.EventType == "MirrorVisitor" and "Grimm the Poltergeist") or "Jasper the Bellhop",
			ClaimedCount = claimedCount,
			TotalClues = getParaConfig().ClueCount,
		})
		ParanormalService.EconomyService.SetTutorialStep(player, 4)

		return true, "All clues found! The entity has manifested!", claimedCount
	end
end

function ParanormalService.ManifestGhost(plot, roomId, eventType)
	local room = plot:FindFirstChild(roomId) or plot:FindFirstChild("Lobby")
	local restSpot = room and room:FindFirstChild("GuestRestSpot") or room:FindFirstChild("GuestCheckInSpot") or plot:GetPivot()
	local centerCF = (typeof(restSpot) == "Instance" and restSpot:GetPivot() or restSpot) + Vector3.new(0, 3.2, 0)

	local ghost = Instance.new("Model")
	ghost.Name = "ParanormalEntity_Active"

	local ghostColor = (eventType == "MirrorVisitor" and Color3.fromRGB(180, 80, 255)) or (eventType == "LivingLuggage" and Color3.fromRGB(200, 160, 255)) or Color3.fromRGB(110, 240, 215)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(3.6, 2.2, 2.2)
	body.CFrame = centerCF * CFrame.Angles(0, 0, math.rad(90))
	body.Color = ghostColor
	body.Material = Enum.Material.Neon
	body.Transparency = 0.35
	body.Anchored = true
	body.CanCollide = false
	body.Parent = ghost

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.CFrame = centerCF * CFrame.new(0, 2.1, 0)
	head.Color = ghostColor
	head.Material = Enum.Material.Neon
	head.Transparency = 0.3
	head.Anchored = true
	head.CanCollide = false
	head.Parent = ghost

	local bb = Instance.new("BillboardGui")
	bb.Name = "CaptureGui"
	bb.Size = UDim2.new(0, 180, 0, 48)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CapturePrompt"
	prompt.ObjectText = "Manifested Spirit"
	prompt.ActionText = "Initiate Containment"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = head

	ghost.PrimaryPart = head
	ghost.Parent = plot

	local event = activeEvents[plot]
	if event then
		event.GhostModel = ghost
		prompt.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer == event.Player then
				ParanormalService.StartCapture(triggerPlayer)
			end
		end)
	end
end

function ParanormalService.StartCapture(player)
	local plot = ParanormalService.HotelService.GetPlayerPlot(player)
	if not plot then return false, "No plot" end

	local event = activeEvents[plot]
	if not event or event.State ~= "CaptureAvailable" then
		return false, "Capture is not available right now"
	end

	local sessionToken = "Cap_" .. player.UserId .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
	local session = {
		Token = sessionToken,
		AttemptsRemaining = getParaConfig().MaxCaptureAttempts,
		TargetMin = getParaConfig().TargetZone.Min,
		TargetMax = getParaConfig().TargetZone.Max,
		Completed = false,
		LastAttemptTime = 0,
	}
	event.CaptureSession = session

	safeFireClient(player, {
		Event = "OpenCaptureMinigame",
		Token = sessionToken,
		AttemptsLeft = session.AttemptsRemaining,
		TargetMin = session.TargetMin,
		TargetMax = session.TargetMax,
	})

	return true, "Minigame started", sessionToken
end

function ParanormalService.SubmitCaptureAttempt(player, token, normalizedPos)
	local plot = ParanormalService.HotelService.GetPlayerPlot(player)
	if not plot then return false, { Message = "No plot" } end

	local event = activeEvents[plot]
	if not event or not event.CaptureSession then
		return false, { Message = "No active capture session" }
	end

	local session = event.CaptureSession
	if session.Token ~= token or session.Completed then
		return false, { Message = "Invalid or expired session" }
	end

	session.AttemptsRemaining = session.AttemptsRemaining - 1
	local isSuccess = (normalizedPos >= session.TargetMin and normalizedPos <= session.TargetMax)

	if isSuccess then
		session.Completed = true
		ParanormalService.CompleteEvent(plot, true)
		return true, { Message = "Containment successful!", Success = true }
	else
		if session.AttemptsRemaining > 0 then
			return false, {
				Message = "Missed the sweet spot! Try again!",
				Success = false,
				RetriesLeft = session.AttemptsRemaining,
			}
		else
			session.Completed = true
			ParanormalService.CompleteEvent(plot, false)
			return false, {
				Message = "Containment failed. Spirit escaped!",
				Success = false,
				RetriesLeft = 0,
			}
		end
	end
end

function ParanormalService.CompleteEvent(plot, wasSuccess)
	local event = activeEvents[plot]
	if not event then return end

	local player = event.Player

	if wasSuccess then
		local ectoReward = getParaConfig().BaseEctoplasmReward
		ParanormalService.EconomyService.AddEctoplasm(player, ectoReward, "ParanormalEventSuccess")

		-- Determine ghost reward pool based on event type
		local discoveredGhost = nil
		local roll = math.random()
		if roll <= getParaConfig().GhostDiscoverChance then
			if event.EventType == "LivingLuggage" then
				discoveredGhost = "Housekeeper"
			elseif event.EventType == "MirrorVisitor" then
				discoveredGhost = "Poltergeist"
			else
				discoveredGhost = "Bellhop"
			end
			ParanormalService.EconomyService.AddDiscoveredGhost(player, discoveredGhost)
		else
			ParanormalService.EconomyService.AddCoins(player, getParaConfig().ConsolationCoins, "GhostDiscoveryMiss")
		end

		safeFireClient(player, {
			Event = "EventCompleted",
			Success = true,
			Ectoplasm = ectoReward,
			Coins = discoveredGhost == nil and getParaConfig().ConsolationCoins or 0,
			DiscoveredGhost = discoveredGhost,
		})
	else
		safeFireClient(player, {
			Event = "EventFailed",
			Message = "The entity dispersed into the ether.",
		})
	end

	ParanormalService.EndEvent(plot)
end

function ParanormalService.FailEvent(plot, reason)
	local event = activeEvents[plot]
	if event and event.Player then
		safeFireClient(event.Player, {
			Event = "EventFailed",
			Message = reason or "Event ended.",
		})
	end
	ParanormalService.EndEvent(plot)
end

function ParanormalService.EndEvent(plot)
	local event = activeEvents[plot]
	if not event then return end

	event.FlickerRunning = false

	for _, p in ipairs(event.ClueInstances or {}) do
		if p and p.Parent then p:Destroy() end
	end
	for _, p in ipairs(event.DisturbanceParts or {}) do
		if typeof(p) == "table" and p.Stop then
			p.Stop()
		elseif typeof(p) == "Instance" and p.Parent then
			p:Destroy()
		end
	end
	if event.GhostModel and event.GhostModel.Parent then
		event.GhostModel:Destroy()
	end

	event.State = "Cooldown"
	event.CooldownUntil = os.time() + getParaConfig().CooldownDuration
	event.Clues = {}
	event.ClueInstances = {}
	event.DisturbanceParts = {}
	event.GhostModel = nil
	event.CaptureSession = nil
end

function ParanormalService.CleanupPlot(plot)
	ParanormalService.EndEvent(plot)
	activeEvents[plot] = nil
end

return ParanormalService
