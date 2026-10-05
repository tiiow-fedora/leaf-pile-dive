--!strict
-- Every number the game uses lives here. The map is generated from this table on
-- every server start (MapBuilder), so content/balance changes are data changes.
-- Keep the economy numbers in sync with tools/balance_sim.py.

local Config = {}

Config.DataStoreName = "LeafPileDive_Profiles_v1"
Config.SaveVersion = 1

-- World
Config.GroundY = 0
Config.YardWidth = 120 -- X extent (-60..60)
Config.YardLength = 120 -- Z extent per yard
Config.YardGap = 10 -- fence strip between yards
Config.PileRadius = 15
Config.PileHeight = 9
Config.TowerOffsetZ = 26 -- tower centre, relative to the pile centre (+Z side)
Config.LeavesPerYard = 80
Config.LeafRespawn = 7
Config.LeafClearRadius = 20 -- no leaves this close to the pile centre
Config.KillY = -60

-- Rake
Config.SwingInterval = 0.5 -- client cadence; server bucket allows 3/s
Config.RakeHeightLimit = 10 -- can't rake from towers/trees (studs above ground)

-- Dive
Config.HeightDiv = 25 -- mult = 1 + height / HeightDiv
Config.DiveCapExtra = 10 -- height is capped at the yard's tower + this
Config.PeakWindow = 6 -- seconds of height history used for the dive
Config.DiveCooldown = 1.2

-- Leaves
Config.GoldenChance = 0.04
Config.GoldenMult = 10
Config.LeafColors = {
	Color3.fromRGB(255, 120, 30),
	Color3.fromRGB(235, 60, 40),
	Color3.fromRGB(255, 190, 40),
	Color3.fromRGB(205, 85, 35),
	Color3.fromRGB(250, 150, 55),
}
Config.GoldColor = Color3.fromRGB(255, 215, 60)

export type Yard = {
	Name: string,
	Cost: number,
	Value: number,
	Tower: number,
	Ground: Color3,
	Accent: Color3,
	Trees: number,
}
-- Cool grounds (greens/teals/blue-greys) so warm leaves, piles and gates pop.
Config.Yards = {
	{ Name = "Backyard", Cost = 0, Value = 1, Tower = 20, Ground = Color3.fromRGB(96, 190, 110), Accent = Color3.fromRGB(255, 140, 40), Trees = 6 },
	{ Name = "Park", Cost = 1500, Value = 3, Tower = 30, Ground = Color3.fromRGB(70, 180, 140), Accent = Color3.fromRGB(255, 90, 60), Trees = 7 },
	{ Name = "Orchard", Cost = 20000, Value = 8, Tower = 40, Ground = Color3.fromRGB(110, 175, 90), Accent = Color3.fromRGB(240, 60, 70), Trees = 9 },
	{ Name = "Pumpkin Patch", Cost = 144000, Value = 20, Tower = 55, Ground = Color3.fromRGB(80, 150, 120), Accent = Color3.fromRGB(255, 120, 20), Trees = 6 },
	{ Name = "Maple Woods", Cost = 960000, Value = 50, Tower = 70, Ground = Color3.fromRGB(70, 140, 150), Accent = Color3.fromRGB(230, 40, 60), Trees = 12 },
	{ Name = "Giant Oak", Cost = 6000000, Value = 120, Tower = 90, Ground = Color3.fromRGB(90, 130, 170), Accent = Color3.fromRGB(255, 200, 40), Trees = 4 },
} :: { Yard }

export type Rake = { Name: string, Cost: number, Radius: number, Mult: number, Color: Color3 }
Config.Rakes = {
	{ Name = "Old Rake", Cost = 0, Radius = 7, Mult = 1, Color = Color3.fromRGB(150, 110, 70) },
	{ Name = "Garden Rake", Cost = 600, Radius = 8.5, Mult = 2, Color = Color3.fromRGB(80, 200, 90) },
	{ Name = "Wide Rake", Cost = 4800, Radius = 10, Mult = 4, Color = Color3.fromRGB(70, 160, 255) },
	{ Name = "Steel Rake", Cost = 32000, Radius = 11.5, Mult = 8, Color = Color3.fromRGB(200, 210, 225) },
	{ Name = "Golden Rake", Cost = 200000, Radius = 13, Mult = 16, Color = Color3.fromRGB(255, 205, 50) },
	{ Name = "Maple Rake", Cost = 1200000, Radius = 14.5, Mult = 32, Color = Color3.fromRGB(235, 50, 50) },
	{ Name = "Storm Rake", Cost = 7200000, Radius = 16, Mult = 64, Color = Color3.fromRGB(160, 90, 255) },
} :: { Rake }

export type Bag = { Name: string, Cost: number, Cap: number }
Config.Bags = {
	{ Name = "Paper Bag", Cost = 0, Cap = 40 },
	{ Name = "Sack", Cost = 150, Cap = 150 },
	{ Name = "Wheelbarrow", Cost = 3600, Cap = 600 },
	{ Name = "Leaf Cart", Cost = 24000, Cap = 2500 },
	{ Name = "Trailer", Cost = 160000, Cap = 12000 },
	{ Name = "Leaf Silo", Cost = 1040000, Cap = 60000 },
	{ Name = "Mega Silo", Cost = 6400000, Cap = 300000 },
} :: { Bag }

-- New Season (rebirth)
Config.SeasonBonus = 0.5 -- +50% leaf value per season
function Config.SeasonCost(season: number): number
	return 20000000 * 2 ^ season
end

-- Boosts
Config.PotionMult = 2 -- 2x Acorns potion
Config.PotionSeconds = 600
Config.WelcomeSeconds = 180 -- first-join gift: 2x Acorns for 3 min
Config.VipMult = 1.25
Config.BigBagMult = 2
Config.LeavesPassMult = 2
Config.FriendBoostPer = 0.10
Config.FriendBoostMax = 0.30

-- Daily reward: day n pays n * max(DailyMin, bag capacity) Acorns; day 7 adds a 2x potion.
Config.DailyMin = 100
Config.DailyMaxDay = 7
Config.DailyCooldown = 20 * 3600
Config.DailyStreakWindow = 48 * 3600

-- Daily quests: reward = Mult * max(QuestMinBase, bag capacity) Acorns
export type QuestDef = { Id: string, Tier: number, Event: string, Target: number, Text: string, Mult: number }
Config.QuestMinBase = 100
Config.QuestPool = {
	{ Id = "rake100", Tier = 1, Event = "leaf", Target = 100, Text = "Rake 100 leaves", Mult = 2 },
	{ Id = "dive3", Tier = 1, Event = "dive", Target = 3, Text = "Dive 3 times", Mult = 2 },
	{ Id = "gold2", Tier = 1, Event = "gold", Target = 2, Text = "Find 2 golden leaves", Mult = 2 },
	{ Id = "rake500", Tier = 2, Event = "leaf", Target = 500, Text = "Rake 500 leaves", Mult = 5 },
	{ Id = "dive10", Tier = 2, Event = "dive", Target = 10, Text = "Dive 10 times", Mult = 5 },
	{ Id = "high3", Tier = 2, Event = "highdive", Target = 3, Text = "Dive from the tower top 3 times", Mult = 5 },
	{ Id = "play10", Tier = 2, Event = "play", Target = 600, Text = "Play for 10 minutes", Mult = 5 },
	{ Id = "rake1500", Tier = 3, Event = "leaf", Target = 1500, Text = "Rake 1,500 leaves", Mult = 10 },
	{ Id = "dive25", Tier = 3, Event = "dive", Target = 25, Text = "Dive 25 times", Mult = 10 },
	{ Id = "gold10", Tier = 3, Event = "gold", Target = 10, Text = "Find 10 golden leaves", Mult = 10 },
	{ Id = "play25", Tier = 3, Event = "play", Target = 1500, Text = "Play for 25 minutes", Mult = 10 },
} :: { QuestDef }

-- Weekly events: rotate by UTC week (Monday 00:00), no new build needed.
export type WeeklyEvent = { Name: string, Desc: string, GoldMult: number, DiveMult: number, QuestMult: number, RespawnMult: number }
Config.WeeklyEvents = {
	{ Name = "Golden Week", Desc = "Golden leaves 2.5x as common", GoldMult = 2.5, DiveMult = 1, QuestMult = 1, RespawnMult = 1 },
	{ Name = "Big Dive Week", Desc = "+25% Acorns from dives", GoldMult = 1, DiveMult = 1.25, QuestMult = 1, RespawnMult = 1 },
	{ Name = "Quest Bonus", Desc = "Quest rewards x2", GoldMult = 1, DiveMult = 1, QuestMult = 2, RespawnMult = 1 },
	{ Name = "Windy Week", Desc = "Leaves grow back 2x faster", GoldMult = 1, DiveMult = 1, QuestMult = 1, RespawnMult = 0.5 },
} :: { WeeklyEvent }

function Config.WeekIndex(t: number): number
	return (t + 3 * 86400) // 604800 -- the Unix epoch was a Thursday; shift so weeks start on Monday
end

function Config.EventIndexAt(t: number): number
	return Config.WeekIndex(t) % #Config.WeeklyEvents + 1
end

-- Studio tests can force one with the ReplicatedStorage attribute ForceEvent.
function Config.CurrentEvent(): WeeklyEvent
	local forced = game:GetService("ReplicatedStorage"):GetAttribute("ForceEvent")
	local idx = if typeof(forced) == "number" and Config.WeeklyEvents[forced] then forced else Config.EventIndexAt(os.time())
	return Config.WeeklyEvents[idx]
end

function Config.EventEndsAt(t: number): number
	return (Config.WeekIndex(t) + 1) * 604800 - 3 * 86400
end

-- Monetization. IDs filled in after creation through Open Cloud (MONETIZATION.md).
export type Pass = { Id: number, Name: string, Price: number, Desc: string }
Config.Passes = {
	Leaves2x = { Id = 0, Name = "2x Leaves", Price = 199, Desc = "Every leaf is worth 2x, forever" },
	BigBag = { Id = 0, Name = "Big Bag", Price = 149, Desc = "Bag holds 2x as many leaves, forever" },
	AutoRake = { Id = 0, Name = "Auto Rake", Price = 129, Desc = "Your rake swings by itself (toggle)" },
	VIP = { Id = 0, Name = "VIP", Price = 99, Desc = "1.25x Acorns, gold leaf trail, [VIP] tag" },
} :: { [string]: Pass }
Config.PassOrder = { "Leaves2x", "BigBag", "AutoRake", "VIP" }

export type Product = { Id: number, Name: string, Price: number, Desc: string }
Config.Products = {
	FillBag = { Id = 0, Name = "Fill My Bag", Price = 15, Desc = "Your bag is filled to the top right now" },
	Potion2x = { Id = 0, Name = "2x Acorns (10 min)", Price = 39, Desc = "2x Acorns from dives for 10 minutes" },
	AcornCrate = { Id = 0, Name = "Acorn Crate", Price = 49, Desc = "Acorns worth 5 full bags (min 500)" },
	UnlockYard = { Id = 0, Name = "Unlock Next Yard", Price = 79, Desc = "Opens the next locked yard now" },
} :: { [string]: Product }
Config.ProductOrder = { "FillBag", "Potion2x", "AcornCrate", "UnlockYard" }

-- Derived geometry ---------------------------------------------------------------

function Config.YardStartZ(i: number): number
	return (i - 1) * (Config.YardLength + Config.YardGap)
end

function Config.YardCenter(i: number): Vector3
	return Vector3.new(0, Config.GroundY, Config.YardStartZ(i) + Config.YardLength / 2)
end

function Config.PileCenter(i: number): Vector3
	return Config.YardCenter(i) + Vector3.new(0, 0, 6)
end

function Config.TowerCenter(i: number): Vector3
	return Config.PileCenter(i) + Vector3.new(0, 0, Config.TowerOffsetZ)
end

-- Which yard a world position is in (0 = outside every yard, e.g. a fence strip).
function Config.YardAt(pos: Vector3): number
	for i = 1, #Config.Yards do
		local z0 = Config.YardStartZ(i)
		if pos.Z >= z0 and pos.Z < z0 + Config.YardLength then
			return i
		end
	end
	return 0
end

-- Fence line between yard i-1 and yard i (centre Z of the gap)
function Config.FenceZ(i: number): number
	return Config.YardStartZ(i) - Config.YardGap / 2
end

function Config.LeafId(yard: number, i: number): number
	return yard * 1000 + i
end

-- Deterministic leaf spots: same on server and client, rebuilt each start.
local spotCache: { [number]: { Vector3 } } = {}
function Config.LeafSpots(yard: number): { Vector3 }
	local cached = spotCache[yard]
	if cached then
		return cached
	end
	local rng = Random.new(4242 + yard * 97)
	local pile = Config.PileCenter(yard)
	local tower = Config.TowerCenter(yard)
	local z0 = Config.YardStartZ(yard)
	local spots = {}
	if yard == 1 then
		-- guaranteed first leaves right in front of the spawn
		for k = 0, 5 do
			table.insert(spots, Vector3.new(-6 + k * 2.4, Config.GroundY + 0.2, z0 + 18 + (k % 2) * 2))
		end
	end
	local tries = 0
	while #spots < Config.LeavesPerYard and tries < 5000 do
		tries += 1
		local x = rng:NextNumber(-Config.YardWidth / 2 + 5, Config.YardWidth / 2 - 5)
		local z = rng:NextNumber(z0 + 6, z0 + Config.YardLength - 6)
		local p = Vector3.new(x, Config.GroundY + 0.2, z)
		local flat = Vector3.new(1, 0, 1)
		if ((p - pile) * flat).Magnitude > Config.LeafClearRadius and ((p - tower) * flat).Magnitude > 9 then
			-- leaves cluster a little (a second leaf near the first) so raking feels rewarding
			table.insert(spots, p)
			if #spots < Config.LeavesPerYard and rng:NextNumber() < 0.5 then
				local q = p + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
				if ((q - pile) * flat).Magnitude > Config.LeafClearRadius then
					table.insert(spots, q)
				end
			end
		end
	end
	spotCache[yard] = spots
	return spots
end

function Config.SpawnCFrame(): CFrame
	local z0 = Config.YardStartZ(1)
	return CFrame.lookAt(Vector3.new(0, Config.GroundY + 4, z0 + 10), Config.PileCenter(1) + Vector3.new(0, 4, 0))
end

function Config.DiveMult(height: number, yard: number): number
	local y = Config.Yards[yard] or Config.Yards[1]
	local h = math.clamp(height, 0, y.Tower + Config.DiveCapExtra)
	return 1 + h / Config.HeightDiv
end

return Config
