local GhostConfig = {
	MaxStaffSlots = 2,
	
	Rarities = {
		Common = { Name = "Common", Color = Color3.fromRGB(180, 180, 180), Order = 1 },
		Rare = { Name = "Rare", Color = Color3.fromRGB(90, 180, 255), Order = 2 },
		Epic = { Name = "Epic", Color = Color3.fromRGB(190, 90, 255), Order = 3 },
	},
	
	Ghosts = {
		Bellhop = {
			Id = "Bellhop",
			Name = "Jasper the Bellhop",
			Rarity = "Common",
			Role = "Lobby Porter",
			Title = "Spectral Porter",
			Catchphrase = "Luggage to the nether-suite, sir?",
			Description = "A polite spirit from 1928 who greets incoming guests with immaculate ghostly etiquette.",
			Color = Color3.fromRGB(110, 240, 215), -- Ecto teal
			Station = "Lobby",
			DropWeight = 55,
			
			Ability = {
				Type = "TipBonus",
				Name = "Gracious Hospitality",
				Description = "Awards bonus tip coins on every completed guest room stay.",
				BaseValue = 15,
				PerLevel = 10,
				Calculate = function(level)
					local lv = math.max(1, level or 1)
					return 15 + (lv - 1) * 10 -- Lv1: 15, Lv2: 25, Lv3: 35
				end,
				Format = function(level)
					local lv = math.max(1, level or 1)
					local val = 15 + (lv - 1) * 10
					return string.format("+%d Coins Guest Tip", val)
				end,
			}
		},
		
		Housekeeper = {
			Id = "Housekeeper",
			Name = "Mildred the Maid",
			Rarity = "Rare",
			Role = "Room Attendant",
			Title = "Spectral Housekeeper",
			Catchphrase = "Dusting the cobwebs... or making new ones?",
			Description = "Obsessed with spotless rooms, she rapidly prepares beds so rooms are immediately ready for guests.",
			Color = Color3.fromRGB(200, 160, 255), -- Lavender
			Station = "Hallway",
			DropWeight = 30,
			
			Ability = {
				Type = "TurnoverReduction",
				Name = "Ghostly Tidying",
				Description = "Cuts the stay and turnaround time for guest rooms, accelerating turnover.",
				BaseValue = 3.0,
				PerLevel = 1.0,
				Calculate = function(level)
					local lv = math.max(1, level or 1)
					return math.min(5.5, 3.0 + (lv - 1) * 1.0) -- Lv1: 3.0s, Lv2: 4.0s, Lv3: 5.0s faster
				end,
				Format = function(level)
					local lv = math.max(1, level or 1)
					local val = math.min(5.5, 3.0 + (lv - 1) * 1.0)
					return string.format("-%.1fs Room Turnover", val)
				end,
			}
		},
		
		Poltergeist = {
			Id = "Poltergeist",
			Name = "Grimm the Poltergeist",
			Rarity = "Epic",
			Role = "Energy Disturber",
			Title = "Ectoplasmic Generator",
			Catchphrase = "Things that go clatter in the night!",
			Description = "A mischievous poltergeist whose chaotic kinetic energy generates pure Ectoplasm continuously.",
			Color = Color3.fromRGB(160, 45, 240), -- Deep violet
			Station = "Pedestal",
			DropWeight = 15,
			
			Ability = {
				Type = "EctoGenerator",
				Name = "Supernatural Conduit",
				Description = "Generates Ectoplasm every 10 seconds while assigned to hotel staff.",
				BaseValue = 8,
				PerLevel = 4,
				Interval = 10,
				Calculate = function(level)
					local lv = math.max(1, level or 1)
					return 8 + (lv - 1) * 4 -- Lv1: 8, Lv2: 12, Lv3: 16
				end,
				Format = function(level)
					local lv = math.max(1, level or 1)
					local val = 8 + (lv - 1) * 4
					return string.format("+%d Ectoplasm / 10s", val)
				end,
			}
		}
	},
	
	RarityColors = {
		Common = Color3.fromRGB(180, 180, 180),
		Rare = Color3.fromRGB(90, 180, 255),
		Epic = Color3.fromRGB(190, 90, 255),
	}
}

return GhostConfig
