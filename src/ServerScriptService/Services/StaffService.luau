-- ServerScriptService/Services/StaffService.lua
local RepStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")

local GhostConfig = require(RepStorage.Configs.GhostConfig)
local Network = RepStorage.Network

local StaffService = {}
local isRunning = false
local staffModels = {} -- [plot] = { [1] = Model, [2] = Model }

StaffService.EconomyService = require(SSS.Services.EconomyService)
StaffService.HotelService = require(SSS.Services.HotelService)

function StaffService.Init(economyService, hotelService)
	StaffService.EconomyService = economyService or StaffService.EconomyService
	StaffService.HotelService = hotelService or StaffService.HotelService
end

function StaffService.Start()
	if isRunning then return end
	isRunning = true

	-- Poltergeist periodic generation loop (every 10s)
	task.spawn(function()
		while isRunning do
			task.wait(10)
			StaffService.ProcessPoltergeistTicks()
		end
	end)
end

function StaffService.Stop()
	isRunning = false
end

function StaffService.ProcessPoltergeistTicks()
	local hotelPlots = Workspace:FindFirstChild("HotelPlots")
	if not hotelPlots then return end

	for _, plot in ipairs(hotelPlots:GetChildren()) do
		local ownerId = plot:GetAttribute("OwnerUserId")
		if ownerId and ownerId > 0 then
			local player = Players:GetPlayerByUserId(ownerId)
			if player then
				local staff = StaffService.EconomyService.GetAssignedStaff(player)
				for slotIndex, ghostId in pairs(staff) do
					if ghostId == "Poltergeist" then
						local prof = StaffService.EconomyService.GetProfile(player)
						local ghostData = prof and prof.DiscoveredGhosts["Poltergeist"]
						local level = ghostData and ghostData.Level or 1
						local ectoReward = GhostConfig.Ghosts.Poltergeist.Ability.Calculate(level)

						StaffService.EconomyService.AddEctoplasm(player, ectoReward, "PoltergeistPassive")

						-- Floating text effect on staff model
						local models = staffModels[plot]
						local poltergeistModel = models and models[slotIndex]
						if poltergeistModel and poltergeistModel.PrimaryPart then
							local head = poltergeistModel.PrimaryPart
							local gui = head:FindFirstChild("StaffGui")
							local frame = gui and (gui:FindFirstChild("Frame") or gui:FindFirstChildWhichIsA("Frame"))
							if frame and frame:FindFirstChild("SubLabel") then
								local origText = frame.SubLabel.Text
								frame.SubLabel.Text = string.format("⚡ GENERATED +%d ECTOPLASM! ⚡", ectoReward)
								frame.SubLabel.TextColor3 = Color3.fromRGB(120, 255, 180)
								task.delay(2, function()
									if frame and frame:FindFirstChild("SubLabel") then
										frame.SubLabel.Text = origText
										frame.SubLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
									end
								end)
							end
						end
					end
				end
			end
		end
	end
end

function StaffService.BuildGhostModel(ghostId, level, slotIndex, rootCFrame)
	local def = GhostConfig.Ghosts[ghostId]
	if not def then return nil end

	local model = Instance.new("Model")
	model.Name = string.format("Staff_Slot%d_%s", slotIndex, ghostId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(3.4, 2, 2)
	body.CFrame = rootCFrame * CFrame.Angles(0, 0, math.rad(90))
	body.Color = def.Color
	body.Material = Enum.Material.Neon
	body.Transparency = 0.35
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.1, 2.1, 2.1)
	head.CFrame = rootCFrame * CFrame.new(0, 2, 0)
	head.Color = def.Color
	head.Material = Enum.Material.Neon
	head.Transparency = 0.3
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	-- Eyes
	local leftEye = Instance.new("Part")
	leftEye.Size = Vector3.new(0.35, 0.35, 0.35)
	leftEye.Shape = Enum.PartType.Ball
	leftEye.Color = Color3.fromRGB(30, 20, 45)
	leftEye.CFrame = rootCFrame * CFrame.new(-0.35, 2.2, -0.9)
	leftEye.Anchored = true
	leftEye.CanCollide = false
	leftEye.Parent = model

	local rightEye = Instance.new("Part")
	rightEye.Size = Vector3.new(0.35, 0.35, 0.35)
	rightEye.Shape = Enum.PartType.Ball
	rightEye.Color = Color3.fromRGB(30, 20, 45)
	rightEye.CFrame = rootCFrame * CFrame.new(0.35, 2.2, -0.9)
	rightEye.Anchored = true
	rightEye.CanCollide = false
	rightEye.Parent = model

	-- Custom Accessories
	if ghostId == "Bellhop" then
		-- Crimson pillbox cap + gold band
		local cap = Instance.new("Part")
		cap.Name = "BellhopCap"
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(0.7, 1.5, 1.5)
		cap.CFrame = rootCFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90))
		cap.Color = Color3.fromRGB(160, 25, 45)
		cap.Material = Enum.Material.Fabric
		cap.Anchored = true
		cap.CanCollide = false
		cap.Parent = model

		local goldBand = Instance.new("Part")
		goldBand.Name = "GoldBand"
		goldBand.Shape = Enum.PartType.Cylinder
		goldBand.Size = Vector3.new(0.2, 1.55, 1.55)
		goldBand.CFrame = rootCFrame * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, 0, math.rad(90))
		goldBand.Color = Color3.fromRGB(255, 215, 0)
		goldBand.Material = Enum.Material.Metal
		goldBand.Anchored = true
		goldBand.CanCollide = false
		goldBand.Parent = model

	elseif ghostId == "Housekeeper" then
		-- White ruffled maid bonnet
		local bonnet = Instance.new("Part")
		bonnet.Name = "MaidBonnet"
		bonnet.Shape = Enum.PartType.Ball
		bonnet.Size = Vector3.new(2.3, 1.2, 2.3)
		bonnet.CFrame = rootCFrame * CFrame.new(0, 2.8, 0.2)
		bonnet.Color = Color3.fromRGB(245, 240, 255)
		bonnet.Material = Enum.Material.Fabric
		bonnet.Anchored = true
		bonnet.CanCollide = false
		bonnet.Parent = model

		-- Spectral Feather Duster
		local dusterHandle = Instance.new("Part")
		dusterHandle.Name = "DusterHandle"
		dusterHandle.Size = Vector3.new(0.3, 2.2, 0.3)
		dusterHandle.CFrame = rootCFrame * CFrame.new(1.4, 0.5, -0.6) * CFrame.Angles(0, 0, math.rad(-25))
		dusterHandle.Color = Color3.fromRGB(80, 50, 30)
		dusterHandle.Anchored = true
		dusterHandle.CanCollide = false
		dusterHandle.Parent = model

		local feathers = Instance.new("Part")
		feathers.Name = "Feathers"
		feathers.Size = Vector3.new(1.0, 1.4, 1.0)
		feathers.CFrame = rootCFrame * CFrame.new(1.8, 1.6, -0.6)
		feathers.Color = Color3.fromRGB(230, 200, 255)
		feathers.Material = Enum.Material.Neon
		feathers.Anchored = true
		feathers.CanCollide = false
		feathers.Parent = model

	elseif ghostId == "Poltergeist" then
		-- Spooky floating horns / ears
		local horn1 = Instance.new("Part")
		horn1.Size = Vector3.new(0.5, 1.2, 0.5)
		horn1.CFrame = rootCFrame * CFrame.new(-0.8, 3.2, 0) * CFrame.Angles(0, 0, math.rad(25))
		horn1.Color = Color3.fromRGB(80, 255, 120)
		horn1.Material = Enum.Material.Neon
		horn1.Anchored = true
		horn1.CanCollide = false
		horn1.Parent = model

		local horn2 = Instance.new("Part")
		horn2.Size = Vector3.new(0.5, 1.2, 0.5)
		horn2.CFrame = rootCFrame * CFrame.new(0.8, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-25))
		horn2.Color = Color3.fromRGB(80, 255, 120)
		horn2.Material = Enum.Material.Neon
		horn2.Anchored = true
		horn2.CanCollide = false
		horn2.Parent = model

		-- Floating Core Orb
		local core = Instance.new("Part")
		core.Size = Vector3.new(1.2, 1.2, 1.2)
		core.Shape = Enum.PartType.Ball
		core.CFrame = rootCFrame * CFrame.new(0, 0, -1.2)
		core.Color = Color3.fromRGB(80, 255, 120)
		core.Material = Enum.Material.Neon
		core.Anchored = true
		core.CanCollide = false
		core.Parent = model
	end

	-- Floating Staff BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "StaffGui"
	bb.Size = UDim2.new(0, 220, 0, 56)
	bb.StudsOffset = Vector3.new(0, 4.6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(24, 16, 36)
	frame.BorderSizePixel = 0
	frame.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = def.Color
	stroke.Thickness = 2
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = string.format("👻 %s (Lv. %d)", def.Name, level)
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = def.Color
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubLabel"
	subLabel.Position = UDim2.new(0, 0, 0.5, 0)
	subLabel.Size = UDim2.new(1, 0, 0.5, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.Text = "Active: " .. def.Ability.Format(level)
	subLabel.TextSize = 11
	subLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	subLabel.Parent = frame

	model.PrimaryPart = head
	return model
end

function StaffService.GetStationCFrame(plot, slotIndex)
	local rootCF = plot:GetPivot()
	if slotIndex == 1 then
		-- Lobby Station (next to reception desk)
		return rootCF * CFrame.new(5.5, 2.5, 4.5)
	else
		-- Hallway Station (central divider between Room 1 and Room 2)
		return rootCF * CFrame.new(0, 2.5, -3.5)
	end
end

function StaffService.UpdatePlotVisualStaff(player, slotIndex, ghostId)
	local plot = StaffService.HotelService.GetPlayerPlot(player)
	if not plot then return end

	staffModels[plot] = staffModels[plot] or {}
	local existingModel = staffModels[plot][slotIndex]
	if existingModel and existingModel.Parent then
		existingModel:Destroy()
		staffModels[plot][slotIndex] = nil
	end

	if ghostId then
		local prof = StaffService.EconomyService.GetProfile(player)
		local ghostData = prof and prof.DiscoveredGhosts[ghostId]
		local level = ghostData and ghostData.Level or 1

		local stationCF = StaffService.GetStationCFrame(plot, slotIndex)
		local model = StaffService.BuildGhostModel(ghostId, level, slotIndex, stationCF)
		if model then
			model.Parent = plot
			staffModels[plot][slotIndex] = model
		end
	end
end

function StaffService.AssignStaff(player, slotIndex, ghostId)
	local success, result = StaffService.EconomyService.AssignStaff(player, slotIndex, ghostId)
	if success then
		StaffService.UpdatePlotVisualStaff(player, slotIndex, ghostId)
		local def = GhostConfig.Ghosts[ghostId]
		local prof = StaffService.EconomyService.GetProfile(player)
		local lv = prof and prof.DiscoveredGhosts[ghostId] and prof.DiscoveredGhosts[ghostId].Level or 1
		return true, string.format("Assigned %s to Slot %d! (%s)", def.Name, slotIndex, def.Ability.Format(lv)), result
	else
		return false, result
	end
end

function StaffService.UnassignStaff(player, slotIndex)
	local success, result = StaffService.EconomyService.UnassignStaff(player, slotIndex)
	if success then
		StaffService.UpdatePlotVisualStaff(player, slotIndex, nil)
		return true, string.format("Unassigned staff slot %d", slotIndex), result
	else
		return false, result
	end
end

function StaffService.LevelUpGhost(player, ghostId)
	local success, newLevel, copiesLeft = StaffService.EconomyService.LevelUpGhost(player, ghostId)
	if success then
		-- Update any visual models currently spawned on the plot
		local plot = StaffService.HotelService.GetPlayerPlot(player)
		if plot and staffModels[plot] then
			for slotIdx, m in pairs(staffModels[plot]) do
				local prof = StaffService.EconomyService.GetProfile(player)
				if prof and prof.AssignedStaff[slotIdx] == ghostId then
					StaffService.UpdatePlotVisualStaff(player, slotIdx, ghostId)
				end
			end
		end
		local def = GhostConfig.Ghosts[ghostId]
		return true, string.format("Leveled up %s to Level %d! New Perk: %s", def.Name, newLevel, def.Ability.Format(newLevel)), newLevel, copiesLeft
	else
		return false, newLevel, copiesLeft
	end
end

function StaffService.CleanupPlot(plot)
	if staffModels[plot] then
		for _, m in pairs(staffModels[plot]) do
			if m and m.Parent then
				m:Destroy()
			end
		end
		staffModels[plot] = nil
	end
end

return StaffService
