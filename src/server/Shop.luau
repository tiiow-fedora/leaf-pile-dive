--!strict
-- Acorn purchases (rakes, bags, yards), New Season, daily reward.
-- Every argument from the client is validated; prices come from Config only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local State = require(script.Parent.State)
local Gameplay = require(script.Parent.Gameplay)

local Shop = {}

local function isIndex(v: any, max: number): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0 and v >= 1 and v <= max
end

local function spend(player: Player, p: DataService.Profile, cost: number): boolean
	if p.Acorns < cost then
		Gameplay.notify(player, "error", "Need " .. Format.short(cost - p.Acorns) .. " more 🌰")
		return false
	end
	p.Acorns -= cost
	return true
end

-- Tiers are bought in order: the client sends the tier it wants, which must be the next one.
function Shop.buyRake(player: Player, tier: any)
	local p = DataService.get(player)
	if not p or not isIndex(tier, #Config.Rakes) or tier ~= p.Rake + 1 then
		return
	end
	local r = Config.Rakes[tier]
	if not spend(player, p, r.Cost) then
		return
	end
	p.Rake = tier
	State.sync(player)
	Gameplay.giveRake(player)
	Gameplay.notify(player, "buy", r.Name .. "! Bigger reach, x" .. r.Mult .. " leaves")
end

function Shop.buyBag(player: Player, tier: any)
	local p = DataService.get(player)
	if not p or not isIndex(tier, #Config.Bags) or tier ~= p.BagTier + 1 then
		return
	end
	local b = Config.Bags[tier]
	if not spend(player, p, b.Cost) then
		return
	end
	p.BagTier = tier
	local rt = Gameplay.runtime(player)
	if rt then
		rt.fullWarned = false
	end
	State.sync(player)
	Gameplay.notify(player, "buy", b.Name .. "! Holds " .. Format.short(State.bagCap(player, p)) .. " leaves")
end

function Shop.unlockYard(player: Player, yard: any)
	local p = DataService.get(player)
	if not p or not isIndex(yard, #Config.Yards) or yard ~= p.Yards + 1 then
		return
	end
	local y = Config.Yards[yard]
	if not spend(player, p, y.Cost) then
		return
	end
	p.Yards = yard
	State.sync(player)
	Gameplay.notify(player, "unlock", y.Name .. " unlocked! Leaves x" .. y.Value, { yard = yard })
	Gameplay.announce(player.DisplayName .. " unlocked " .. y.Name .. "! 🍂", player)
end

function Shop.seasonReady(p: DataService.Profile): boolean
	return p.Yards >= #Config.Yards and p.Rake >= #Config.Rakes and p.Acorns >= Config.SeasonCost(p.Season)
end

function Shop.newSeason(player: Player)
	local p = DataService.get(player)
	if not p or not Shop.seasonReady(p) then
		return
	end
	p.Season += 1
	p.Acorns = 0
	p.Bag = 0
	p.Rake = 1
	p.BagTier = 1
	State.sync(player)
	Gameplay.giveRake(player)
	Gameplay.notify(player, "season", "Season " .. (p.Season + 1) .. "! Leaves now x" .. (1 + Config.SeasonBonus * p.Season))
	Gameplay.announce(player.DisplayName .. " started Season " .. (p.Season + 1) .. "! 🍁", player)
end

-- Daily reward -----------------------------------------------------------------

function Shop.dailyReward(player: Player, p: DataService.Profile, day: number): number
	return day * math.max(Config.DailyMin, State.bagCap(player, p))
end

function Shop.refreshDaily(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local now = os.time()
	local ready = now - p.LastDaily >= Config.DailyCooldown
	local streak = p.DailyStreak
	if now - p.LastDaily > Config.DailyStreakWindow then
		streak = 0
	end
	local nextDay = math.min(streak + 1, Config.DailyMaxDay)
	player:SetAttribute("DailyReady", ready)
	player:SetAttribute("DailyDay", nextDay)
	player:SetAttribute("DailyStreak", streak)
	player:SetAttribute("DailyNext", p.LastDaily + Config.DailyCooldown)
	player:SetAttribute("DailyAmount", Shop.dailyReward(player, p, nextDay))
end

function Shop.claimDaily(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local now = os.time()
	if now - p.LastDaily < Config.DailyCooldown then
		return
	end
	if now - p.LastDaily > Config.DailyStreakWindow then
		p.DailyStreak = 0
	end
	p.DailyStreak = math.min(p.DailyStreak + 1, Config.DailyMaxDay)
	if p.DailyStreak >= Config.DailyMaxDay and p.LastDaily > 0 and now - p.LastDaily <= Config.DailyStreakWindow then
		-- day 7 keeps paying the day-7 reward while the streak is kept
		p.DailyStreak = Config.DailyMaxDay
	end
	p.LastDaily = now
	local acorns = Shop.dailyReward(player, p, p.DailyStreak)
	p.Acorns += acorns
	p.TotalAcorns += acorns
	local msg = "Day " .. p.DailyStreak .. " reward: +" .. Format.commas(acorns) .. " 🌰"
	if p.DailyStreak == Config.DailyMaxDay then
		p.PotionLeft += Config.PotionSeconds
		msg ..= " + 2x Acorns (10 min)!"
	end
	State.sync(player)
	Shop.refreshDaily(player)
	Gameplay.notify(player, "buy", msg)
end

return Shop
