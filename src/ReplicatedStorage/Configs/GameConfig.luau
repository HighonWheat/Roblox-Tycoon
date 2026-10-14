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
	
	-- Multi-Floor Expansion
	Floors = {
		[1] = {
			FloorIndex = 1,
			Name = "Ground Floor (The Haunt)",
			Cost = 0,
			RequiredRoomLevels = {},
			Rooms = { "Room1", "Room2" },
		},
		[2] = {
			FloorIndex = 2,
			Name = "Second Floor (Spectral Wing)",
			Cost = 250,
			RequiredRoomLevels = { Room1 = 2, Room2 = 2 },
			Rooms = { "Room3", "Room4" },
			Description = "Unlocks the Spectral Wing: Room 3 (Spectral Library) & Room 4 (Phantom Ballroom)!",
		}
	},
	
	-- Guest Variety & Satisfaction Tuning
	GuestTypes = {
		Regular = {
			Id = "Regular",
			Name = "Ordinary Specter",
			Weight = 60,
			PayoutMultiplier = 1.0,
			Color = Color3.fromRGB(150, 225, 255),
			BonusTip = 0,
			Description = "A typical supernatural traveler seeking a pleasant night's rest.",
		},
		VIP = {
			Id = "VIP",
			Name = "Gilded Phantom (VIP)",
			Weight = 25,
			PayoutMultiplier = 2.0,
			Color = Color3.fromRGB(255, 215, 80),
			BonusTip = 20,
			Description = "An aristocratic spirit traveling in luxury! Pays double coins and generous tips.",
		},
		Occultist = {
			Id = "Occultist",
			Name = "Supernatural Enthusiast",
			Weight = 15,
			PayoutMultiplier = 1.25,
			Color = Color3.fromRGB(180, 90, 255),
			BonusTip = 10,
			BonusEctoplasm = 15,
			Description = "An eccentric paranormal investigator. Pays bonus Ectoplasm upon completing their stay!",
		}
	},
	
	-- Daily Objectives Templates
	DailyObjectives = {
		GuestStays = {
			Id = "GuestStays",
			Title = "Hospitality Deluxe",
			Description = "Accommodate 3 hotel guests in any room.",
			Target = 3,
			RewardCoins = 120,
			RewardEctoplasm = 0,
		},
		Haunting = {
			Id = "Haunting",
			Title = "Spectral Cleanup",
			Description = "Investigate 1 paranormal disturbance.",
			Target = 1,
			RewardCoins = 0,
			RewardEctoplasm = 30,
		},
		Earnings = {
			Id = "Earnings",
			Title = "Golden Treasury",
			Description = "Earn 200 coins from guest stays and operations.",
			Target = 200,
			RewardCoins = 150,
			RewardEctoplasm = 0,
		},
		StaffDuty = {
			Id = "StaffDuty",
			Title = "Supernatural Workforce",
			Description = "Keep at least 1 ghost employee on hotel duty.",
			Target = 1,
			RewardCoins = 60,
			RewardEctoplasm = 15,
		}
	},
	
	-- Hotel Reputation (Prestige)
	Reputation = {
		RequiredFloor = 2,
		RequiredMinRoomLevel = 2,
		RequiredLifetimeCoins = 500,
		MultiplierPerStar = 0.15, -- +15% permanent income per star
		MaxStars = 5,
	},
	
	-- Monetization Configuration (Placeholder IDs: 0 = disabled until configured)
	Monetization = {
		GamePasses = {
			DoubleCoins = {
				Id = 0,
				Multiplier = 2.0,
				Name = "2x Hotel Income",
				Description = "Doubles all coin income permanently across all rooms!",
			},
			VIPTheme = {
				Id = 0,
				Name = "VIP Velvet Theme",
				Description = "Cosmetic theme with golden chandeliers and purple plush carpets.",
			}
		},
		DeveloperProducts = {
			CoinBundleSmall = {
				Id = 0,
				Coins = 500,
				Name = "Sack of 500 Coins",
			},
			CoinBundleLarge = {
				Id = 0,
				Coins = 2000,
				Name = "Chest of 2,000 Coins",
			},
			SupernaturalBoost = {
				Id = 0,
				DurationSeconds = 900, -- 15 minutes
				SpeedMultiplier = 2.0,
				Name = "15m Ghost Surge (2x Turnover Speed)",
			}
		}
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
			Floor = 1,
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
			Floor = 1,
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
		},
		Room3 = {
			Id = "Room3",
			Floor = 2,
			Name = "Room 3 (Spectral Library)",
			Upgrades = {
				[1] = {
					Level = 1,
					Cost = 0,
					Income = 45,
					Description = "Haunted Bookshelves & Dim Reading Lamp",
				},
				[2] = {
					Level = 2,
					Cost = 200,
					Income = 110,
					Description = "Floating Grimoires & Mystic Reading Chair",
				},
				[3] = {
					Level = 3,
					Cost = 450,
					Income = 240,
					Description = "Arcane Astral Study & Glowing Glyphs",
				},
				[4] = {
					Level = 4,
					Cost = 900,
					Income = 450,
					Description = "Grand Sorcery Suite & Levitation Orbs",
				},
			}
		},
		Room4 = {
			Id = "Room4",
			Floor = 2,
			Name = "Room 4 (Phantom Ballroom)",
			Upgrades = {
				[1] = {
					Level = 1,
					Cost = 0,
					Income = 70,
					Description = "Vintage Phonograph & Gilded Mirror",
				},
				[2] = {
					Level = 2,
					Cost = 300,
					Income = 160,
					Description = "Crystal Waltz Chandelier & Velvet Drapes",
				},
				[3] = {
					Level = 3,
					Cost = 650,
					Income = 320,
					Description = "Spectral Grand Piano & Haunted Fireplace",
				},
				[4] = {
					Level = 4,
					Cost = 1200,
					Income = 600,
					Description = "Imperial Spirit Ballroom & Floating Dance Floor",
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
