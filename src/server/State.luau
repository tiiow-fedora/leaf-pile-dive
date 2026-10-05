--!strict
-- Mirrors each player's profile into replicated Player attributes + leaderstats.
-- The profile in server memory is authoritative; attributes are display-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)

local State = {}

function State.bagCap(player: Player, p: DataService.Profile): number
	local cap = (Config.Bags[p.BagTier] or Config.Bags[1]).Cap
	if Passes.has(player, "BigBag") then
		cap *= Config.BigBagMult
	end
	return cap
end

function State.setupLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local a = Instance.new("NumberValue")
	a.Name = "Acorns"
	a.Parent = ls
	local s = Instance.new("IntValue")
	s.Name = "Season"
	s.Parent = ls
	ls.Parent = player
end

function State.sync(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	player:SetAttribute("Acorns", math.floor(p.Acorns))
	player:SetAttribute("Bag", math.floor(p.Bag))
	player:SetAttribute("BagCap", State.bagCap(player, p))
	player:SetAttribute("Rake", p.Rake)
	player:SetAttribute("BagTier", p.BagTier)
	player:SetAttribute("Yards", p.Yards)
	player:SetAttribute("Season", p.Season)
	player:SetAttribute("BestDive", math.floor(p.BestDive))
	player:SetAttribute("Dives", p.Dives)
	player:SetAttribute("PotionLeft", math.floor(p.PotionLeft))
	player:SetAttribute("TutorialDone", p.TutorialDone)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls:FindFirstChild("Acorns") :: NumberValue).Value = math.floor(p.Acorns);
		(ls:FindFirstChild("Season") :: IntValue).Value = p.Season
	end
end

-- Cheap path for the bag (called on every rake)
function State.syncBag(player: Player, p: DataService.Profile)
	player:SetAttribute("Bag", math.floor(p.Bag))
end

return State
