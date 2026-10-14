local GhostConfig = {
	Ghosts = {
		Bellhop = {
			Id = "Bellhop",
			Name = "Jasper the Bellhop",
			Rarity = "Uncommon",
			Title = "Spectral Porter",
			Catchphrase = "Luggage to the nether-suite, sir?",
			Description = "A dedicated hotel employee from 1928 who refuses to abandon his station.",
			Color = Color3.fromRGB(110, 240, 215), -- Ecto teal
			EmployeeRole = "Lobby Attendant",
			PerkSummary = "+25% Guest Check-In & Arrival Speed",
			BaseDropWeight = 100,
		}
	},
	RarityColors = {
		Common = Color3.fromRGB(190, 190, 190),
		Uncommon = Color3.fromRGB(90, 230, 150),
		Rare = Color3.fromRGB(90, 170, 255),
		Epic = Color3.fromRGB(190, 90, 255),
		Legendary = Color3.fromRGB(255, 210, 60),
	}
}

return GhostConfig
