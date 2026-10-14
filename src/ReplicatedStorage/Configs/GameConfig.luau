-- ReplicatedStorage/Configs/GameConfig.luau
local GameConfig = {
	StartingCoins = 100,
	StartingEctoplasm = 0,
	MaxPlots = 2,
	
	GuestArrivalInterval = 7, -- seconds between arrival checks per plot
	BaseStayDuration = 8,      -- seconds a guest occupies a room
	
	-- Capped Offline Earnings Tuning
	OfflineEarnings = {
		RateMultiplier = 0.50,       -- 50% of eligible passive rate
		MaxDurationSeconds = 10800,  -- 3 hours maximum
		MinDurationSeconds = 60,     -- 1 minute minimum away to earn
		AutosaveInterval = 180,      -- 3 minutes between automatic profile saves
	},
	
	-- Paranormal Event Tuning
	Paranormal = {
		CheckInterval = 12,       -- seconds between event availability checks per plot
		InitialEventDelay = 10,   -- delay before first event can occur
		CooldownDuration = 25,    -- seconds after event ends before next event
		EventTimeout = 90,        -- seconds before uninvestigated event expires
		ClueCount = 2,
		MaxCaptureAttempts = 2,
		AttemptCooldown = 1.0,    -- seconds between attempts
		TargetZone = { Min = 0.35, Max = 0.65 }, -- 30% width sweet spot
		
		-- Rewards
		BaseEctoplasmReward = 35,
		ClueInvestigationEctoplasm = 5,
		GhostDiscoverChance = 0.75,
		ConsolationCoins = 50,
	},
	
	Rooms = {
		Room1 = {
			Id = "Room1",
			Name = "Room 1 (Whispering Suite)",
			Upgrades = {
				[1] = {
					Level = 1,
					Cost = 0,
					Income = 15,
					Description = "Rustic Creaky Bed & Dim Lantern",
				},
				[2] = {
					Level = 2,
					Cost = 50,
					Income = 35,
					Description = "Velvet Canopy Bed & Floating Candlestick",
				},
				[3] = {
					Level = 3,
					Cost = 150,
					Income = 80,
					Description = "Royal Ghost Suite & Haunted Hearth",
				},
				[4] = {
					Level = 4,
					Cost = 350,
					Income = 180,
					Description = "Spectral Master Bedroom & Crystal Chandelier",
				},
			}
		},
		Room2 = {
			Id = "Room2",
			Name = "Room 2 (Phantom Parlor)",
			Upgrades = {
				[1] = {
					Level = 1,
					Cost = 0,
					Income = 20,
					Description = "Standard Spooky Quarters",
				},
				[2] = {
					Level = 2,
					Cost = 100,
					Income = 50,
					Description = "Ornate Victorian Wardrobe & Mystic Rug",
				},
				[3] = {
					Level = 3,
					Cost = 250,
					Income = 115,
					Description = "Haunted Grand Chamber & Ecto-Fireplace",
				},
				[4] = {
					Level = 4,
					Cost = 500,
					Income = 250,
					Description = "Poltergeist Penthouse & Floating Furniture",
				},
			}
		}
	},
	
	Tutorial = {
		[1] = {
			Step = 1,
			Title = "Welcome to Ghostshift!",
			Description = "A ghostly guest is arriving! Observe their stay to earn your first coin payout.",
		},
		[2] = {
			Step = 2,
			Title = "First Renovation",
			Description = "Upgrade Room 1 to Level 2 (50 coins) at the room pad or Renovations menu!",
		},
		[3] = {
			Step = 3,
			Title = "Paranormal Investigation",
			Description = "A disturbance detected! Investigate the clues in the haunted room.",
		},
		[4] = {
			Step = 4,
			Title = "Ghost Containment",
			Description = "The entity manifested! Initiate containment and trap the spirit in the minigame.",
		},
		[5] = {
			Step = 5,
			Title = "Staff Assignment",
			Description = "Put your spirit to work! Open the Ghost Journal and assign them to hotel duty.",
		},
		[6] = {
			Step = 6,
			Title = "Master Hotelier",
			Description = "Hotel fully operational! Expand rooms, hire more spirits, and progress your tycoon!",
		}
	}
}

return GameConfig
