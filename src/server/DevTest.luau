--!strict
-- Studio-only self test. Run from the command bar (Server context) during Play:
--   game.ServerScriptService.DevRun:Invoke()
-- (requiring this module from the command bar gets a separate module cache with no
-- players loaded, so it must go through the DevRun BindableFunction.)
-- Drives player 1 through raking, golden leaves, dives (real falls), shop, yards,
-- season, daily, quests, every product (receipt de-dupe + save-failure rollback),
-- save migration, weekly events and the anti-cheat; prints PASS/FAIL lines and
-- then restores the player's original progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local State = require(script.Parent.State)
local Gameplay = require(script.Parent.Gameplay)
local Shop = require(script.Parent.Shop)
local Monetization = require(script.Parent.Monetization)
local Quests = require(script.Parent.Quests)

local DevTest = {}

local function deepClone(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepClone(v)
	end
	return c
end

function DevTest.run()
	assert(RunService:IsStudio(), "DevTest is Studio-only")
	local player = Players:GetPlayers()[1]
	assert(player, "no player")
	local p = DataService.get(player) :: DataService.Profile
	local backup = deepClone(p)
	local rt = Gameplay.runtime(player) :: any
	local results = { pass = 0, fail = 0 }
	local RS = ReplicatedStorage
	RS:SetAttribute("ForceEvent", 3) -- Quest Bonus: no gold/dive/respawn changes during the core checks
	local function check(name: string, cond: boolean, detail: any?)
		if cond then
			results.pass += 1
			print("PASS " .. name)
		else
			results.fail += 1
			warn("FAIL " .. name .. (if detail ~= nil then " :: " .. tostring(detail) else ""))
		end
	end
	local function hrp(): BasePart
		return (player.Character :: Model):WaitForChild("HumanoidRootPart") :: BasePart
	end
	-- test teleport: no anti-cheat window, history kept unless asked
	local function tp(pos: Vector3, clearHistory: boolean?)
		rt.grace = os.clock() + 1
		rt.sampleFrom = nil
		if clearHistory then
			table.clear(rt.history)
		end
		hrp().AssemblyLinearVelocity = Vector3.zero;
		(player.Character :: Model):PivotTo(CFrame.new(pos))
	end
	local G = Config.GroundY

	-- 0. map sanity
	local map = workspace:FindFirstChild("Map") :: Folder
	local parts, touchy = 0, 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if not d.CanCollide and d.CanTouch then
				touchy += 1
			end
		end
	end
	check("map part count under 2500", parts > 50 and parts < 2500, parts)
	check("non-colliding map parts have CanTouch off", touchy == 0, touchy)
	local piles, towers = 0, 0
	for i = 1, #Config.Yards do
		local f = map:FindFirstChild("Yard" .. i)
		if f and f:FindFirstChild("Pile") then
			piles += 1
		end
		if f and f:FindFirstChild("Tower") then
			towers += 1
		end
	end
	check("a pile and a tower in every yard", piles == #Config.Yards and towers == #Config.Yards, piles .. "/" .. towers)
	check("Giant Oak landmark exists", map:FindFirstChild("GiantOak") ~= nil)
	local badSpot = 0
	for i = 1, #Config.Yards do
		for _, s in Config.LeafSpots(i) do
			local c = Config.PileCenter(i)
			if Vector2.new(s.X - c.X, s.Z - c.Z).Magnitude < Config.LeafClearRadius - 0.01 or Config.YardAt(s) ~= i then
				badSpot += 1
			end
		end
	end
	check("leaf spots inside their yard, clear of the pile", badSpot == 0, badSpot)
	check("80 leaves per yard", #Config.LeafSpots(1) == Config.LeavesPerYard and #Config.LeafSpots(6) == Config.LeavesPerYard, #Config.LeafSpots(1))

	-- 1. raking
	p.Yards = 1
	p.Rake = 1
	p.BagTier = 3
	p.Bag = 0
	p.PotionLeft = 0
	table.clear(rt.taken)
	table.clear(rt.gold)
	local spot = Config.LeafSpots(1)[1]
	tp(spot + Vector3.new(0, 3, 0), true)
	task.wait(0.2)
	local n, added = Gameplay.rake(player)
	check("rake collects nearby leaves", n > 0 and added > 0 and p.Bag == added, n .. " leaves, +" .. added)
	local n2 = Gameplay.rake(player)
	check("raked leaves are gone until they regrow", n2 == 0, n2)
	local farOk = true
	for idx, s in Config.LeafSpots(1) do
		local id = Config.LeafId(1, idx)
		if rt.taken[id] and Vector2.new(s.X - spot.X, s.Z - spot.Z).Magnitude > Config.Rakes[1].Radius + 1.6 then
			farOk = false
		end
	end
	check("only leaves inside the rake radius are taken", farOk)
	-- golden leaf is 10x
	table.clear(rt.taken)
	table.clear(rt.gold)
	for idx in Config.LeafSpots(1) do
		rt.gold[Config.LeafId(1, idx)] = true
	end
	p.Bag = 0
	local base = Gameplay.leafValue(player, p, 1)
	local gn, gadd = Gameplay.rake(player)
	check("golden leaves are worth 10x", gn > 0 and math.abs(gadd - gn * base * Config.GoldenMult) < 1e-6 or p.Bag >= State.bagCap(player, p), gadd)
	table.clear(rt.gold)
	-- can't rake from height
	table.clear(rt.taken)
	p.Bag = 0
	tp(spot + Vector3.new(0, 20, 0))
	local hn = Gameplay.rake(player)
	check("can't rake from 20 studs up", hn == 0, hn)
	-- full bag
	tp(spot + Vector3.new(0, 3, 0))
	p.Bag = State.bagCap(player, p)
	local fn = Gameplay.rake(player)
	check("full bag takes no leaves", fn == 0 and p.Bag == State.bagCap(player, p), fn)
	-- locked yard
	p.Bag = 0
	local s2 = Config.LeafSpots(2)[5]
	tp(s2 + Vector3.new(0, 3, 0))
	local ln = Gameplay.rake(player)
	check("can't rake in a locked yard", ln == 0, ln)
	task.wait(0.4)
	check("locked yard bounces you back to its gate", hrp().Position.Z < Config.FenceZ(2), hrp().Position.Z)

	-- 2. dives (real falls into the pile)
	local pile = Config.PileCenter(1)
	local am0 = Gameplay.acornMult(player, p)
	p.Bag = 100
	local a0, d0 = p.Acorns, p.Dives
	tp(pile + Vector3.new(0, 3, 0), true)
	task.wait(0.5)
	check("ground dive pays bag x1", p.Bag == 0 and p.Acorns - a0 >= math.floor(100 * am0) and p.Acorns - a0 <= math.floor(105 * am0) and p.Dives == d0 + 1, p.Acorns - a0)
	task.wait(Config.DiveCooldown)
	p.Bag = 100
	local a1 = p.Acorns
	tp(pile + Vector3.new(0, 3 + 20, 0), true)
	task.wait(1.4)
	local got = p.Acorns - a1
	check("20-stud dive pays about x1.8", got >= math.floor(160 * am0) and got <= math.floor(185 * am0), got)
	check("BestDive recorded", p.BestDive >= 18, p.BestDive)
	task.wait(Config.DiveCooldown)
	p.Bag = 100
	local a2 = p.Acorns
	tp(pile + Vector3.new(0, 3 + 150, 0), true)
	task.wait(3.5)
	local capMult = Config.DiveMult(1e9, 1)
	check("dive height is capped per yard", p.Acorns - a2 > 0 and p.Acorns - a2 <= math.floor(100 * capMult * am0) + 1, (p.Acorns - a2) .. " cap " .. capMult)
	task.wait(Config.DiveCooldown)
	p.Bag = 0
	local a3 = p.Acorns
	tp(pile + Vector3.new(0, 3, 0), true)
	task.wait(0.5)
	check("empty bag dive pays nothing", p.Acorns == a3)
	-- potion + VIP style multipliers apply at the dive
	p.PotionLeft = 100
	check("2x potion doubles dive acorns", math.abs(Gameplay.acornMult(player, p) - Config.PotionMult * (if player:GetAttribute("Pass_VIP") then Config.VipMult else 1)) < 1e-6)
	p.PotionLeft = 0

	-- 3. shop: rakes, bags, yards
	p.Rake, p.BagTier, p.Yards = 1, 1, 1
	p.Acorns = 10
	Shop.buyRake(player, 2)
	check("rake rejected when poor", p.Rake == 1)
	p.Acorns = Config.Rakes[2].Cost + 5
	Shop.buyRake(player, 3)
	check("can't skip a rake tier", p.Rake == 1)
	Shop.buyRake(player, 2)
	check("rake bought", p.Rake == 2 and p.Acorns == 5, p.Acorns)
	Shop.buyRake(player, "3")
	Shop.buyRake(player, 2.5)
	Shop.buyRake(player, 99)
	Shop.buyRake(player, nil)
	check("bad rake args ignored", p.Rake == 2 and p.Acorns == 5)
	task.wait(0.2)
	local tool = (player.Character :: Model):FindFirstChild("Rake") or (player:FindFirstChildOfClass("Backpack") :: Backpack):FindFirstChild("Rake")
	check("rake tool follows the tier", tool ~= nil and (tool :: Instance):GetAttribute("Tier") == 2)
	p.Acorns = Config.Bags[2].Cost
	Shop.buyBag(player, 2)
	check("bag bought", p.BagTier == 2 and p.Acorns == 0)
	Shop.buyBag(player, 2)
	check("same bag can't be bought twice", p.BagTier == 2)
	p.Acorns = 1e9
	Shop.unlockYard(player, 3)
	check("can't skip a yard", p.Yards == 1)
	Shop.unlockYard(player, 2)
	check("yard 2 unlocked", p.Yards == 2 and p.Acorns == 1e9 - Config.Yards[2].Cost)
	local gate = map.Yard2:FindFirstChild("Gate") :: BasePart
	check("gate is solid on the server", gate ~= nil and gate.CanCollide == true)

	-- 4. New Season
	p.Season = 0
	Shop.newSeason(player)
	check("season rejected when not ready", p.Season == 0)
	p.Yards, p.Rake, p.BagTier = #Config.Yards, #Config.Rakes, 5
	p.Acorns = Config.SeasonCost(0)
	Shop.newSeason(player)
	check("season works and resets", p.Season == 1 and p.Acorns == 0 and p.Rake == 1 and p.BagTier == 1 and p.Yards == #Config.Yards)
	check("season boosts leaf value", math.abs(Gameplay.leafValue(player, p, 1) / (Config.Rakes[1].Mult * (1 + math.min(rt.friends * Config.FriendBoostPer, Config.FriendBoostMax)) * (if player:GetAttribute("Pass_Leaves2x") then 2 else 1)) - 1.5) < 1e-6)
	p.Season = 0

	-- 5. daily reward
	p.LastDaily, p.DailyStreak = 0, 0
	Shop.refreshDaily(player)
	check("daily ready", player:GetAttribute("DailyReady") == true)
	local ad = p.Acorns
	Shop.claimDaily(player)
	check("daily pays day 1", p.Acorns == ad + Shop.dailyReward(player, p, 1), p.Acorns - ad)
	Shop.claimDaily(player)
	check("second daily claim rejected", p.Acorns == ad + Shop.dailyReward(player, p, 1) and player:GetAttribute("DailyReady") == false)
	p.LastDaily = os.time() - 25 * 3600
	p.DailyStreak = 6
	local pl0 = p.PotionLeft
	Shop.claimDaily(player)
	check("day 7 gives the 2x potion", p.DailyStreak == 7 and p.PotionLeft == pl0 + Config.PotionSeconds)
	p.LastDaily = os.time() - 50 * 3600
	Shop.claimDaily(player)
	check("streak resets after 48 h", p.DailyStreak == 1, p.DailyStreak)

	-- 6. quests
	p.QuestDay = 0
	Quests.ensure(player, p)
	local tiers = {}
	for _, q in p.Quests do
		local d = Quests.def(q.Id)
		table.insert(tiers, d and d.Tier or 0)
	end
	check("3 quests, one per tier", #p.Quests == 3 and tiers[1] == 1 and tiers[2] == 2 and tiers[3] == 3, table.concat(tiers, ","))
	p.Quests = { { Id = "rake100", P = 0, C = false }, { Id = "high3", P = 0, C = false }, { Id = "gold10", P = 0, C = false } }
	Quests.event(player, "leaf", 60)
	Quests.event(player, "leaf", 60)
	Quests.event(player, "highdive", 1)
	check("quest progress from events", p.Quests[1].P == 100 and p.Quests[2].P == 1, p.Quests[1].P)
	local aq = p.Acorns
	local qr = Quests.reward(player, p, Quests.def("rake100") :: any)
	Quests.claim(player, 1)
	check("quest claim pays", p.Acorns == aq + qr and p.Quests[1].C, p.Acorns - aq)
	Quests.claim(player, 1)
	Quests.claim(player, 2)
	Quests.claim(player, 7)
	Quests.claim(player, "1")
	check("double/unfinished/bad quest claims ignored", p.Acorns == aq + qr)

	-- 7. products: handlers, de-dupe, rollback on save failure
	p.Yards = 1
	p.Bag = 0
	Monetization.handlers.FillBag(player, p)
	check("FillBag fills to capacity", p.Bag == State.bagCap(player, p))
	local ac = p.Acorns
	Monetization.handlers.AcornCrate(player, p)
	check("AcornCrate amount", p.Acorns - ac == Monetization.crateAmount(player, p), p.Acorns - ac)
	Monetization.handlers.UnlockYard(player, p)
	check("UnlockYard opens the next yard", p.Yards == 2)
	local saving = DataService.isLoaded(player)
	check("DataStore loaded in Studio (API access on)", saving)
	if saving then
		for _, key in Config.ProductOrder do
			local prod = Config.Products[key]
			if prod.Id ~= 0 then
				local id = "devtest-" .. key .. "-" .. os.clock()
				local function snap()
					return string.format("%.0f|%.0f|%.0f|%d|%d", p.Bag, p.Acorns, p.PotionLeft, p.Yards, #p.Receipts)
				end
				p.Bag = 0
				local before = snap()
				local d1 = Monetization.processReceipt({ PlayerId = player.UserId, ProductId = prod.Id, PurchaseId = id })
				local mid = snap()
				local d2 = Monetization.processReceipt({ PlayerId = player.UserId, ProductId = prod.Id, PurchaseId = id })
				local after = snap()
				local Gd = Enum.ProductPurchaseDecision.PurchaseGranted
				check("receipt " .. key .. " granted exactly once", d1 == Gd and d2 == Gd and before ~= mid and mid == after, before .. " -> " .. mid .. " -> " .. after)
			else
				check("product " .. key .. " has an id", false)
			end
		end
		DataService.failSavesForTest = true
		local before = string.format("%.0f|%d", p.Acorns, #p.Receipts)
		local d = Monetization.processReceipt({ PlayerId = player.UserId, ProductId = Config.Products.AcornCrate.Id, PurchaseId = "devtest-fail-" .. os.clock() })
		DataService.failSavesForTest = false
		local after = string.format("%.0f|%d", p.Acorns, #p.Receipts)
		check("failed save rolls back and returns NotProcessedYet", d == Enum.ProductPurchaseDecision.NotProcessedYet and before == after, before .. " -> " .. after)
	end

	-- 8. save migration
	local v0 = { Coins = 500, Yard = 3, Rake = 2, BagTier = 2, Season = 1, Receipts = { "a" }, TutorialDone = true, PlaySeconds = 99 }
	local m = DataService.migrate(v0)
	check("migration v0 -> v1 keeps values", m.Version == 1 and m.Acorns == 500 and m.Yards == 3 and m.Rake == 2 and m.Season == 1 and #m.Receipts == 1 and m.TutorialDone)
	check("migration adds defaults", m.Bag == 0 and m.BestDive == 0 and type(m.Quests) == "table")
	local junk = DataService.migrate({ Version = 1, Acorns = "lots", Rake = 99, Yards = -4, Quests = 5 })
	check("migration rejects bad types and clamps tiers", junk.Acorns == 0 and junk.Rake == #Config.Rakes and junk.Yards == 1 and type(junk.Quests) == "table")
	local cur = DataService.migrate(deepClone(backup))
	check("current save round-trips", cur.Acorns == backup.Acorns and cur.Yards == backup.Yards and cur.Season == backup.Season)

	-- 9. weekly events
	local t0 = 1791331200 -- Monday 2026-10-05 00:00 UTC
	check("event stable within a week", Config.EventIndexAt(t0) == Config.EventIndexAt(t0 + 6 * 86400 + 86399))
	check("event advances weekly", Config.EventIndexAt(t0 + 7 * 86400) == Config.EventIndexAt(t0) % #Config.WeeklyEvents + 1)
	check("event ends next Monday", Config.EventEndsAt(t0 + 3600) == t0 + 7 * 86400)
	RS:SetAttribute("ForceEvent", 3)
	local am = Gameplay.acornMult(player, p)
	local qd = Quests.def("dive10") :: any
	local qBonus = Quests.reward(player, p, qd)
	RS:SetAttribute("ForceEvent", 2)
	check("Big Dive Week: +25% acorns", math.abs(Gameplay.acornMult(player, p) - am * 1.25) < 1e-6)
	check("Quest Bonus doubles quest rewards", qBonus == 2 * Quests.reward(player, p, qd))
	RS:SetAttribute("ForceEvent", 4)
	table.clear(rt.taken)
	p.Bag = 0
	tp(spot + Vector3.new(0, 3, 0), true)
	local wn = Gameplay.rake(player)
	local id1
	for id, at in rt.taken do
		id1 = at - os.clock()
		break
	end
	check("Windy Week: leaves regrow in half the time", wn > 0 and id1 ~= nil and id1 <= Config.LeafRespawn * 0.5 + 0.05, id1)
	RS:SetAttribute("ForceEvent", 3)

	-- 10. anti-cheat + falling
	tp(Config.YardCenter(1) + Vector3.new(-30, 3, -20), true)
	task.wait(0.3)
	local home = hrp().Position
	rt.grace = 0
	rt.sampleFrom = home
	rt.sampleT = os.clock() - 1.05;
	(player.Character :: Model):PivotTo(CFrame.new(home + Vector3.new(0, 0, 90)))
	task.wait(0.3)
	check("teleport/speed hack is rubber-banded", (hrp().Position - home).Magnitude < 10, (hrp().Position - home).Magnitude)
	tp(Config.YardCenter(1) + Vector3.new(0, -100, 0))
	task.wait(0.4)
	check("falling out of the world returns you", hrp().Position.Y > G, hrp().Position.Y)

	-- 11. welcome gift
	local fresh = DataService.defaultProfile()
	check("fresh profile is new", fresh.PlaySeconds == 0 and fresh.TotalAcorns == 0 and fresh.Yards == 1 and fresh.Rake == 1)

	-- restore
	RS:SetAttribute("ForceEvent", nil)
	for k in pairs(p) do
		(p :: any)[k] = nil
	end
	for k, v in backup do
		(p :: any)[k] = v
	end
	State.sync(player)
	Shop.refreshDaily(player)
	Quests.sync(player)
	Gameplay.giveRake(player)
	Gameplay.initLeaves(player)
	tp(Config.SpawnCFrame().Position, true)
	print(("DEVTEST DONE: %d pass, %d fail"):format(results.pass, results.fail))
	return results
end

return DevTest
