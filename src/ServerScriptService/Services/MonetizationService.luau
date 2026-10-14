-- ServerScriptService/Services/MonetizationService.luau
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local GameConfig = require(RepStorage.Configs.GameConfig)

local MonetizationService = {}
local EconomyService = nil
local processedReceiptsCache = {} -- [purchaseId] = timestamp

function MonetizationService.Init(economyService)
	EconomyService = economyService

	-- Configure MarketplaceService.ProcessReceipt handler
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return MonetizationService.HandleProcessReceipt(receiptInfo)
	end
	print("[MonetizationService] ProcessReceipt handler registered.")
end

function MonetizationService.HandleProcessReceipt(receiptInfo, customPlayer, customProfile)
	local purchaseId = receiptInfo.PurchaseId
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId

	-- 1. Idempotency Check: Already processed in current server session
	if processedReceiptsCache[purchaseId] then
		print(string.format("[MonetizationService] PurchaseId %s already granted in session cache.", tostring(purchaseId)))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = customPlayer or Players:GetPlayerByUserId(playerId)
	if not player then
		-- Player left; return NotProcessedYet so Roblox retries next time they join
		warn(string.format("[MonetizationService] Player %d not found for PurchaseId %s; retrying later.", playerId, tostring(purchaseId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = customProfile or (EconomyService and EconomyService.GetProfile(player))
	if not profile then
		warn(string.format("[MonetizationService] Profile for player %d not loaded; retrying later.", playerId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Check persistent processed purchases table
	profile.ProcessedPurchases = profile.ProcessedPurchases or {}
	if profile.ProcessedPurchases[purchaseId] then
		print(string.format("[MonetizationService] PurchaseId %s already recorded in profile.", tostring(purchaseId)))
		processedReceiptsCache[purchaseId] = os.time()
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 2. Match Developer Product ID
	local matchedProduct = nil
	local devProds = GameConfig.Monetization and GameConfig.Monetization.DeveloperProducts or {}
	for key, prod in pairs(devProds) do
		if prod.Id > 0 and prod.Id == productId then
			matchedProduct = prod
			break
		end
	end

	-- If product ID is 0 or unconfigured (testing/staging mode)
	if not matchedProduct then
		-- In testing mode or unconfigured product
		print(string.format("[MonetizationService] Product ID %d is unconfigured placeholder. Granting mock coins for testing.", productId))
		EconomyService.AddCoins(player, 500, "DeveloperProduct_Mock")
	else
		-- Grant specific configured product rewards
		if matchedProduct.Coins and matchedProduct.Coins > 0 then
			EconomyService.AddCoins(player, matchedProduct.Coins, "DeveloperProduct_" .. matchedProduct.Name)
			print(string.format("[MonetizationService] Granted %d coins to %s", matchedProduct.Coins, player.Name))
		end

		if matchedProduct.DurationSeconds and matchedProduct.DurationSeconds > 0 then
			profile.SupernaturalBoostUntil = os.time() + matchedProduct.DurationSeconds
			EconomyService.SyncPlayerState(player)
			print(string.format("[MonetizationService] Activated Ghost Surge for %s until %d", player.Name, profile.SupernaturalBoostUntil))
		end
	end

	-- 3. Record purchase as granted
	profile.ProcessedPurchases[purchaseId] = os.time()
	processedReceiptsCache[purchaseId] = os.time()

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.HasDoubleCoins(player)
	local passConfig = GameConfig.Monetization and GameConfig.Monetization.GamePasses and GameConfig.Monetization.GamePasses.DoubleCoins
	if not passConfig or passConfig.Id <= 0 then
		return false
	end

	local userId = typeof(player) == "Instance" and player.UserId or player
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, passConfig.Id)
	end)
	return ok and owns == true
end

function MonetizationService.GetIncomeMultiplier(player)
	local mult = 1.0

	-- 1. Double Coins GamePass
	if MonetizationService.HasDoubleCoins(player) then
		mult = mult * 2.0
	end

	local profile = EconomyService and EconomyService.GetProfile(player)
	if profile then
		-- 2. Temporary Ghost Surge Boost
		if profile.SupernaturalBoostUntil and profile.SupernaturalBoostUntil > os.time() then
			mult = mult * 2.0
		end

		-- 3. Hotel Reputation (Prestige) Multiplier
		local stars = profile.ReputationStars or 0
		local starBonus = stars * (GameConfig.Reputation and GameConfig.Reputation.MultiplierPerStar or 0.15)
		mult = mult * (1.0 + starBonus)
	end

	return mult
end

return MonetizationService
