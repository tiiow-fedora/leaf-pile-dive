--!strict
-- Game passes + developer products. ProcessReceipt grants exactly once:
--  1. player missing / profile not loaded            -> NotProcessedYet
--  2. PurchaseId already recorded in the profile     -> PurchaseGranted (no second grant)
--  3. apply the grant, record the PurchaseId, save with UpdateAsync
--  4. save failed -> roll everything back            -> NotProcessedYet (Roblox retries)
--  5. only after a successful save                    -> PurchaseGranted

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local State = require(script.Parent.State)
local Passes = require(script.Parent.Passes)
local Gameplay = require(script.Parent.Gameplay)

local Monetization = {}

local function productKey(id: number): string?
	for key, prod in Config.Products do
		if prod.Id == id and id ~= 0 then
			return key
		end
	end
	return nil
end

local function crateAmount(player: Player, p: DataService.Profile): number
	return math.max(500, 5 * State.bagCap(player, p))
end

-- Each handler mutates the profile and returns a message for the player.
local handlers: { [string]: (Player, DataService.Profile) -> string } = {
	FillBag = function(player, p)
		p.Bag = State.bagCap(player, p)
		return "Bag filled! Dive in the pile!"
	end,
	Potion2x = function(_player, p)
		p.PotionLeft += Config.PotionSeconds
		return "2x Acorns for " .. Format.time(p.PotionLeft)
	end,
	AcornCrate = function(player, p)
		local n = crateAmount(player, p)
		p.Acorns += n
		p.TotalAcorns += n
		return "Acorn Crate! +" .. Format.commas(n) .. " 🌰"
	end,
	UnlockYard = function(player, p)
		if p.Yards < #Config.Yards then
			p.Yards += 1
			return Config.Yards[p.Yards].Name .. " unlocked!"
		end
		local n = crateAmount(player, p)
		p.Acorns += n
		p.TotalAcorns += n
		return "All yards open, so you got an Acorn Crate: +" .. Format.commas(n) .. " 🌰"
	end,
}
Monetization.handlers = handlers
Monetization.crateAmount = crateAmount

local SNAP_FIELDS = { "Bag", "Acorns", "TotalAcorns", "PotionLeft", "Yards" }

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local p = DataService.get(player)
	if not p or not DataService.isLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if DataService.hasReceipt(p, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productKey(receipt.ProductId)
	local handler = key and handlers[key]
	if not handler then
		warn("[Monetization] unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local before = {}
	for _, f in SNAP_FIELDS do
		before[f] = (p :: any)[f]
	end
	local function rollback()
		for f, v in before do
			(p :: any)[f] = v
		end
		local idx = table.find(p.Receipts, purchaseId)
		if idx then
			table.remove(p.Receipts, idx)
		end
	end
	local ok, msg = pcall(handler, player, p)
	if not ok then
		warn("[Monetization] handler error: " .. tostring(msg))
		rollback()
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.addReceipt(p, purchaseId)
	if not DataService.save(player) then
		rollback()
		State.sync(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	State.sync(player)
	Gameplay.notify(player, "purchase", msg :: string)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Monetization.processReceipt = processReceipt

function Monetization.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = Passes.keyForId(passId)
		if key then
			Passes.grant(player, key)
			State.sync(player) -- bag capacity changes with Big Bag
			Gameplay.applyTrail(player)
			Gameplay.notify(player, "purchase", "Thanks! " .. Config.Passes[key].Name .. " unlocked")
		end
	end)
end

return Monetization
