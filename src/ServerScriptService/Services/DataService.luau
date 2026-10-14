-- ServerScriptService/Services/DataService.luau
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(RepStorage.Configs.GameConfig)
local GhostConfig = require(RepStorage.Configs.GhostConfig)

local Network = RepStorage.Network
local OfflineRewardReady = Network:WaitForChild("OfflineRewardReady")

local DataService = {}
local DATA_STORE_NAME = "Ghostshift_PlayerData_v1"
local CURRENT_SCHEMA_VERSION = 1
local MAX_RETRIES = 3
local RETRY_DELAY = 1

local liveDataStore = nil
local isLiveDataStoreAvailable = false
local mockSessionStore = {} -- [userId] = profile data
local saveLocks = {}        -- [userId] = boolean
local activeProfiles = {}   -- [userId] = live profile reference
local isClosing = false

-- Reference to EconomyService (injected or required)
local EconomyService = nil

-- Default Profile definition
local function getFreshProfile(userId)
	return {
		SchemaVersion = CURRENT_SCHEMA_VERSION,
		UserId = userId,
		Coins = GameConfig.StartingCoins or 100,
		Ectoplasm = GameConfig.StartingEctoplasm or 0,
		RoomLevels = {
			Room1 = 1,
			Room2 = 1,
		},
		DiscoveredGhosts = {}, -- [ghostId] = { Id = ghostId, Level = 1, CopiesOwned = 1, DiscoveredAt = os.time() }
		AssignedStaff = {
			[1] = nil,
			[2] = nil,
		},
		TutorialStep = 1,
		TutorialDismissed = false,
		TotalGuestsServed = 0,
		TotalParanormalSolved = 0,
		LastSaveTime = os.time(),
		LastSessionTime = os.time(),
		PendingOfflineRewards = nil,
		_isLoaded = true,
		_loadFailed = false,
	}
end

-- Deep copy utility
local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Validate and migrate profile schema
local function migrateProfile(raw, userId)
	if type(raw) ~= "table" then
		return getFreshProfile(userId)
	end

	local migrated = getFreshProfile(userId)
	migrated.SchemaVersion = CURRENT_SCHEMA_VERSION
	migrated.UserId = userId

	-- Validate currencies
	if type(raw.Coins) == "number" and raw.Coins >= 0 then
		migrated.Coins = math.floor(raw.Coins)
	end
	if type(raw.Ectoplasm) == "number" and raw.Ectoplasm >= 0 then
		migrated.Ectoplasm = math.floor(raw.Ectoplasm)
	end

	-- Validate RoomLevels
	if type(raw.RoomLevels) == "table" then
		for roomId, defaultLv in pairs(migrated.RoomLevels) do
			local lv = raw.RoomLevels[roomId]
			if type(lv) == "number" and lv >= 1 and lv <= 4 then
				migrated.RoomLevels[roomId] = math.floor(lv)
			end
		end
	end

	-- Validate DiscoveredGhosts
	if type(raw.DiscoveredGhosts) == "table" then
		for ghostId, gData in pairs(raw.DiscoveredGhosts) do
			if type(gData) == "table" then
				migrated.DiscoveredGhosts[ghostId] = {
					Id = ghostId,
					Level = math.clamp(math.floor(gData.Level or 1), 1, 5),
					CopiesOwned = math.max(1, math.floor(gData.CopiesOwned or 1)),
					DiscoveredAt = tonumber(gData.DiscoveredAt) or os.time(),
				}
			end
		end
	end

	-- Validate AssignedStaff
	if type(raw.AssignedStaff) == "table" then
		for slot = 1, 2 do
			local gId = raw.AssignedStaff[slot] or raw.AssignedStaff[tostring(slot)]
			if gId and migrated.DiscoveredGhosts[gId] then
				migrated.AssignedStaff[slot] = gId
			else
				migrated.AssignedStaff[slot] = nil
			end
		end
	end

	-- Validate Tutorial
	if type(raw.TutorialStep) == "number" and raw.TutorialStep >= 1 and raw.TutorialStep <= 6 then
		migrated.TutorialStep = math.floor(raw.TutorialStep)
	end
	if raw.TutorialDismissed == true then
		migrated.TutorialDismissed = true
	else
		migrated.TutorialDismissed = false
	end

	-- Validate counters
	if type(raw.TotalGuestsServed) == "number" and raw.TotalGuestsServed >= 0 then
		migrated.TotalGuestsServed = math.floor(raw.TotalGuestsServed)
	end
	if type(raw.TotalParanormalSolved) == "number" and raw.TotalParanormalSolved >= 0 then
		migrated.TotalParanormalSolved = math.floor(raw.TotalParanormalSolved)
	end

	-- Timestamps
	migrated.LastSaveTime = tonumber(raw.LastSaveTime) or os.time()
	migrated.LastSessionTime = tonumber(raw.LastSessionTime) or os.time()
	migrated._isLoaded = true
	migrated._loadFailed = false

	return migrated
end

-- Initialize DataStore connection
function DataService.Init(economyService)
	EconomyService = economyService
	
	-- Test DataStoreService availability
	local success, storeOrErr = pcall(function()
		return DataStoreService:GetDataStore(DATA_STORE_NAME)
	end)

	if success and storeOrErr then
		liveDataStore = storeOrErr
		-- Test a light probe to check if API permissions are enabled
		local probeOk, _ = pcall(function()
			liveDataStore:GetAsync("__probe_test__")
		end)
		if probeOk then
			isLiveDataStoreAvailable = true
			print("[Ghostshift DataService] Live DataStore connected successfully:", DATA_STORE_NAME)
		else
			isLiveDataStoreAvailable = false
			print("[Ghostshift DataService] Live DataStore unavailable (local Studio/unpublished place); running in MockDataStore mode.")
		end
	else
		isLiveDataStoreAvailable = false
		print("[Ghostshift DataService] DataStoreService unavailable; running in MockDataStore mode.")
	end

	-- Start Autosave Loop
	task.spawn(function()
		local interval = GameConfig.OfflineEarnings and GameConfig.OfflineEarnings.AutosaveInterval or 180
		while not isClosing do
			task.wait(interval)
			if not isClosing then
				DataService.AutosaveAll()
			end
		end
	end)
end

-- Calculate Capped Offline Earnings
function DataService.CalculateOfflineEarnings(profile)
	if not profile then return nil end

	local now = os.time()
	local lastTime = profile.LastSaveTime or profile.LastSessionTime or now
	local elapsed = math.max(0, now - lastTime)

	local config = GameConfig.OfflineEarnings or {
		RateMultiplier = 0.50,
		MaxDurationSeconds = 10800, -- 3 hours
		MinDurationSeconds = 60,    -- 1 minute
	}

	-- Clamp elapsed time to max duration (e.g. 3 hours)
	local cappedElapsed = math.min(elapsed, config.MaxDurationSeconds or 10800)

	-- If time away was less than minimum (e.g. 60s), no offline payout
	if cappedElapsed < (config.MinDurationSeconds or 60) then
		return nil
	end

	-- 1. Base Room Income per Guest Stay Cycle
	local baseIncomePerCycle = 0
	for roomId, level in pairs(profile.RoomLevels or {}) do
		local roomConfig = GameConfig.Rooms[roomId]
		if roomConfig and roomConfig.Upgrades[level] then
			baseIncomePerCycle = baseIncomePerCycle + roomConfig.Upgrades[level].Income
		end
	end

	-- 2. Staff Perks: Bellhop Tip Bonus & Housekeeper Cycle Reduction
	local tipBonusPerCycle = 0
	local turnoverReduction = 0
	local poltergeistEctoRate = 0 -- ecto per 10s

	for _, ghostId in pairs(profile.AssignedStaff or {}) do
		if ghostId == "Bellhop" then
			local gData = profile.DiscoveredGhosts["Bellhop"]
			local lv = gData and gData.Level or 1
			local bDef = GhostConfig.Ghosts and GhostConfig.Ghosts.Bellhop
			if bDef and bDef.Ability and bDef.Ability.Calculate then
				tipBonusPerCycle = tipBonusPerCycle + bDef.Ability.Calculate(lv)
			else
				tipBonusPerCycle = tipBonusPerCycle + (15 + (lv - 1) * 10)
			end
		elseif ghostId == "Housekeeper" then
			local gData = profile.DiscoveredGhosts["Housekeeper"]
			local lv = gData and gData.Level or 1
			local mDef = GhostConfig.Ghosts and GhostConfig.Ghosts.Housekeeper
			if mDef and mDef.Ability and mDef.Ability.Calculate then
				turnoverReduction = turnoverReduction + mDef.Ability.Calculate(lv)
			else
				turnoverReduction = turnoverReduction + math.min(5.5, 3.0 + (lv - 1) * 1.0)
			end
		elseif ghostId == "Poltergeist" then
			local gData = profile.DiscoveredGhosts["Poltergeist"]
			local lv = gData and gData.Level or 1
			local pDef = GhostConfig.Ghosts and GhostConfig.Ghosts.Poltergeist
			if pDef and pDef.Ability and pDef.Ability.Calculate then
				poltergeistEctoRate = poltergeistEctoRate + pDef.Ability.Calculate(lv)
			else
				poltergeistEctoRate = poltergeistEctoRate + (8 + (lv - 1) * 4)
			end
		end
	end

	-- Effective guest cycle time: arrival + stay - turnoverReduction (minimum 6s per cycle)
	local standardCycle = (GameConfig.GuestArrivalInterval or 7) + (GameConfig.BaseStayDuration or 8)
	local effectiveCycle = math.max(6, standardCycle - turnoverReduction)

	local cyclesCompleted = math.floor(cappedElapsed / effectiveCycle)
	local coinGross = cyclesCompleted * (baseIncomePerCycle + tipBonusPerCycle)
	local offlineCoins = math.floor(coinGross * (config.RateMultiplier or 0.50))

	-- Poltergeist Ectoplasm generation (runs every 10s)
	local ectoGross = 0
	if poltergeistEctoRate > 0 then
		local ectoTicks = math.floor(cappedElapsed / 10)
		ectoGross = math.floor(ectoTicks * poltergeistEctoRate * (config.RateMultiplier or 0.50))
	end

	if offlineCoins <= 0 and ectoGross <= 0 then
		return nil
	end

	return {
		ElapsedSeconds = cappedElapsed,
		Coins = math.max(0, offlineCoins),
		Ectoplasm = math.max(0, ectoGross),
		Cycles = cyclesCompleted,
	}
end

-- Load Player Profile with Retries and Studio Mock Fallback
function DataService.LoadPlayerProfile(player)
	local userId = player.UserId
	local storeKey = "Player_" .. userId

	if activeProfiles[userId] then
		return activeProfiles[userId], false, nil
	end

	local loadedData = nil
	local isNew = false
	local loadSuccess = false

	if isLiveDataStoreAvailable and liveDataStore then
		for attempt = 1, MAX_RETRIES do
			local ok, result = pcall(function()
				return liveDataStore:GetAsync(storeKey)
			end)
			if ok then
				loadSuccess = true
				loadedData = result
				break
			else
				warn(string.format("[DataService] Load attempt %d failed for user %d: %s", attempt, userId, tostring(result)))
				if attempt < MAX_RETRIES then
					task.wait(RETRY_DELAY * attempt)
				end
			end
		end
	else
		-- Fallback to session MockDataStore
		loadSuccess = true
		loadedData = mockSessionStore[storeKey]
	end

	if not loadSuccess then
		warn(string.format("[DataService] CRITICAL: Failed to load profile for user %d after retries. Safe mode enabled.", userId))
		local safeProfile = getFreshProfile(userId)
		safeProfile._isLoaded = false
		safeProfile._loadFailed = true
		activeProfiles[userId] = safeProfile
		return safeProfile, false, nil
	end

	local profile
	if loadedData == nil then
		isNew = true
		profile = getFreshProfile(userId)
		print(string.format("[DataService] Created new profile for user %s (%d)", player.Name, userId))
	else
		profile = migrateProfile(loadedData, userId)
		print(string.format("[DataService] Loaded profile for user %s (%d). Version: %d", player.Name, userId, profile.SchemaVersion))
	end

	-- Check for Capped Offline Earnings (only for returning players)
	local offlineRewards = nil
	if not isNew and profile.LastSaveTime and profile.LastSaveTime > 0 then
		offlineRewards = DataService.CalculateOfflineEarnings(profile)
		if offlineRewards and (offlineRewards.Coins > 0 or offlineRewards.Ectoplasm > 0) then
			profile.PendingOfflineRewards = offlineRewards
			print(string.format("[DataService] Offline earnings calculated for %s: +%d Coins, +%d Ectoplasm (Away %ds)",
				player.Name, offlineRewards.Coins, offlineRewards.Ectoplasm, offlineRewards.ElapsedSeconds))
		end
	end

	profile.LastSessionTime = os.time()
	activeProfiles[userId] = profile

	return profile, isNew, offlineRewards
end

-- Save Player Profile with Concurrency Lock and Retries
function DataService.SavePlayerProfile(player)
	local userId = player.UserId
	local storeKey = "Player_" .. userId
	local profile = activeProfiles[userId]

	if not profile then
		return false, "No active profile to save"
	end

	-- Prevent overwriting if initial load failed
	if profile._loadFailed then
		warn(string.format("[DataService] ABORT SAVE: Profile for user %d marked loadFailed. Preserving original DataStore data.", userId))
		return false, "Load failed safety guard active"
	end

	-- Concurrency Lock
	if saveLocks[userId] then
		return false, "Save already in progress"
	end
	saveLocks[userId] = true

	profile.LastSaveTime = os.time()

	-- Prepare persistent payload (strip runtime-only tags)
	local dataToSave = {
		SchemaVersion = CURRENT_SCHEMA_VERSION,
		UserId = userId,
		Coins = profile.Coins,
		Ectoplasm = profile.Ectoplasm,
		RoomLevels = deepCopy(profile.RoomLevels),
		DiscoveredGhosts = deepCopy(profile.DiscoveredGhosts),
		AssignedStaff = deepCopy(profile.AssignedStaff),
		TutorialStep = profile.TutorialStep,
		TutorialDismissed = profile.TutorialDismissed == true,
		TotalGuestsServed = profile.TotalGuestsServed or 0,
		TotalParanormalSolved = profile.TotalParanormalSolved or 0,
		LastSaveTime = profile.LastSaveTime,
		LastSessionTime = profile.LastSessionTime,
	}

	local saveSuccess = false
	local errMessage = nil

	if isLiveDataStoreAvailable and liveDataStore then
		for attempt = 1, MAX_RETRIES do
			local ok, err = pcall(function()
				liveDataStore:SetAsync(storeKey, dataToSave)
			end)
			if ok then
				saveSuccess = true
				break
			else
				errMessage = tostring(err)
				warn(string.format("[DataService] Save attempt %d failed for user %d: %s", attempt, userId, errMessage))
				if attempt < MAX_RETRIES then
					task.wait(RETRY_DELAY * attempt)
				end
			end
		end
	else
		-- Save to MockDataStore
		mockSessionStore[storeKey] = deepCopy(dataToSave)
		saveSuccess = true
	end

	saveLocks[userId] = nil

	if saveSuccess then
		print(string.format("[DataService] Successfully saved profile for user %s (%d). Coins: %d, Ecto: %d",
			player.Name, userId, profile.Coins, profile.Ectoplasm))
		return true
	else
		warn(string.format("[DataService] CRITICAL: Failed to save profile for user %d: %s", userId, tostring(errMessage)))
		return false, errMessage
	end
end

-- Claim Offline Rewards (Atomic Server Validation)
function DataService.ClaimOfflineRewards(player)
	local userId = player.UserId
	local profile = activeProfiles[userId]

	if not profile then
		return { Success = false, Message = "Profile not found." }
	end

	local pending = profile.PendingOfflineRewards
	if not pending or (pending.Coins <= 0 and pending.Ectoplasm <= 0) then
		return { Success = false, Message = "No pending offline rewards to claim." }
	end

	local claimedCoins = pending.Coins or 0
	local claimedEcto = pending.Ectoplasm or 0

	-- Atomically award currencies
	profile.Coins = profile.Coins + claimedCoins
	profile.Ectoplasm = profile.Ectoplasm + claimedEcto
	profile.PendingOfflineRewards = nil

	-- Sync state to client
	if EconomyService then
		EconomyService.SyncPlayerState(player)
	end

	print(string.format("[DataService] %s claimed offline rewards: +%d 🪙, +%d 🟣", player.Name, claimedCoins, claimedEcto))

	return {
		Success = true,
		ClaimedCoins = claimedCoins,
		ClaimedEctoplasm = claimedEcto,
		ElapsedSeconds = pending.ElapsedSeconds or 0,
		Message = string.format("Claimed +%d Coins and +%d Ectoplasm!", claimedCoins, claimedEcto)
	}
end

-- Dismiss Tutorial Banner
function DataService.DismissTutorial(player)
	local userId = player.UserId
	local profile = activeProfiles[userId]
	if not profile then return false end

	profile.TutorialDismissed = true
	if EconomyService then
		EconomyService.SyncPlayerState(player)
	end
	return true
end

-- Autosave all connected players
function DataService.AutosaveAll()
	print("[DataService] Running periodic autosave...")
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			DataService.SavePlayerProfile(player)
		end)
	end
end

-- Unload player on leave
function DataService.UnloadPlayer(player)
	local userId = player.UserId
	-- Save first
	DataService.SavePlayerProfile(player)
	activeProfiles[userId] = nil
	saveLocks[userId] = nil
end

-- BindToClose shutdown handler
function DataService.BindToClose()
	isClosing = true
	print("[DataService] Server shutting down. Flushing all player profiles to storage...")

	local playersToSave = Players:GetPlayers()
	local savesRemaining = #playersToSave

	if savesRemaining == 0 then
		print("[DataService] No active players to flush on shutdown.")
		return
	end

	local bindToCloseThread = coroutine.running()

	for _, player in ipairs(playersToSave) do
		task.spawn(function()
			DataService.SavePlayerProfile(player)
			savesRemaining = savesRemaining - 1
			if savesRemaining <= 0 then
				task.spawn(bindToCloseThread)
			end
		end)
	end

	-- Wait for saves to finish with timeout
	task.delay(10, function()
		if savesRemaining > 0 then
			warn(string.format("[DataService] BindToClose timed out with %d saves pending.", savesRemaining))
			task.spawn(bindToCloseThread)
		end
	end)

	coroutine.yield()
	print("[DataService] Shutdown flush complete.")
end

-- Expose internal session store for inspection and testing
function DataService.GetMockStore()
	return mockSessionStore
end

function DataService.GetActiveProfile(player)
	local userId = typeof(player) == "Instance" and player.UserId or player
	return activeProfiles[userId]
end

return DataService
