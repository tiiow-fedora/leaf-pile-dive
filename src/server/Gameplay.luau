--!strict
-- Raking, leaves, dives, yard access, anti-cheat, friend boost, rake tool.
-- Every decision about currency/progress happens here on the server.
-- Leaves are per player: the server knows every spot (Config.LeafSpots) and when
-- each player's copy of each leaf regrows; clients only render them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local State = require(script.Parent.State)
local Passes = require(script.Parent.Passes)
local Quests = require(script.Parent.Quests)

local Gameplay = {}

type Runtime = {
	taken: { [number]: number }, -- leaf id -> os.clock() when it regrows
	gold: { [number]: boolean },
	history: { { t: number, y: number } }, -- recent HRP heights for the dive
	lastDive: number,
	friends: number,
	grace: number, -- os.clock() until which movement checks are skipped (after teleports)
	sampleFrom: Vector3?,
	sampleT: number,
	fullWarned: boolean,
	lastLockedWarn: number,
}

local runtime: { [Player]: Runtime } = {}
local notify: RemoteEvent
local leafSync: RemoteEvent

function Gameplay.runtime(player: Player): Runtime?
	return runtime[player]
end

function Gameplay.notify(player: Player, kind: string, text: string, extra: any?)
	if notify then
		notify:FireClient(player, kind, text, extra)
	end
end

function Gameplay.announce(text: string, except: Player?)
	for p in runtime do
		if p ~= except then
			notify:FireClient(p, "announce", text)
		end
	end
end

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Value of one leaf for this player right now (before golden).
function Gameplay.leafValue(player: Player, p: DataService.Profile, yard: number): number
	local y = Config.Yards[yard] or Config.Yards[1]
	local rake = Config.Rakes[p.Rake] or Config.Rakes[1]
	local v = y.Value * rake.Mult * (1 + Config.SeasonBonus * p.Season)
	if Passes.has(player, "Leaves2x") then
		v *= Config.LeavesPassMult
	end
	local rt = runtime[player]
	if rt then
		v *= 1 + math.min(rt.friends * Config.FriendBoostPer, Config.FriendBoostMax)
	end
	return v
end

-- Multiplier applied to Acorns at the moment of the dive (besides the height).
function Gameplay.acornMult(player: Player, p: DataService.Profile): number
	local m = Config.CurrentEvent().DiveMult
	if Passes.has(player, "VIP") then
		m *= Config.VipMult
	end
	if p.PotionLeft > 0 then
		m *= Config.PotionMult
	end
	return m
end

-- First-ever join (loaded profile, never played): 2x Acorns for 3 minutes.
function Gameplay.welcomeIfNew(player: Player): boolean
	local p = DataService.get(player)
	if p and DataService.isLoaded(player) and p.PlaySeconds == 0 and p.TotalAcorns == 0 then
		p.PotionLeft += Config.WelcomeSeconds
		return true
	end
	return false
end

function Gameplay.teleport(player: Player, cf: CFrame)
	local c = player.Character
	local hrp = hrpOf(player)
	local rt = runtime[player]
	if not c or not hrp then
		return
	end
	if rt then
		rt.grace = os.clock() + 1.5
		rt.sampleFrom = nil
		table.clear(rt.history)
	end
	hrp.AssemblyLinearVelocity = Vector3.zero
	c:PivotTo(cf)
end

function Gameplay.yardSpawn(yard: number): CFrame
	if yard <= 1 then
		return Config.SpawnCFrame()
	end
	local z0 = Config.YardStartZ(yard)
	return CFrame.lookAt(Vector3.new(-30, Config.GroundY + 4, z0 + 6), Vector3.new(-30, Config.GroundY + 4, z0 + 40))
end

local function rollGold(): boolean
	return math.random() < Config.GoldenChance * Config.CurrentEvent().GoldMult
end

-- (Re)build a player's leaf state and send it to their client.
function Gameplay.initLeaves(player: Player)
	local rt = runtime[player]
	if not rt then
		return
	end
	table.clear(rt.taken)
	table.clear(rt.gold)
	local goldList = {}
	for yard = 1, #Config.Yards do
		for idx in Config.LeafSpots(yard) do
			local id = Config.LeafId(yard, idx)
			-- the third leaf in front of the spawn is always golden (first-minute reward)
			if (yard == 1 and idx == 3) or rollGold() then
				rt.gold[id] = true
				table.insert(goldList, id)
			end
		end
	end
	leafSync:FireClient(player, "init", goldList)
end

-- Server side of one rake swing. Returns (leaves taken, value added).
function Gameplay.rake(player: Player): (number, number)
	local p = DataService.get(player)
	local rt = runtime[player]
	local hrp = hrpOf(player)
	if not p or not rt or not hrp then
		return 0, 0
	end
	local pos = hrp.Position
	if pos.Y - Config.GroundY > Config.RakeHeightLimit + 3 then
		return 0, 0
	end
	local yard = Config.YardAt(pos)
	if yard == 0 or yard > p.Yards then
		return 0, 0
	end
	local cap = State.bagCap(player, p)
	if p.Bag >= cap then
		Gameplay.notify(player, "bagfull", "Bag full! Dive in the pile!")
		return 0, 0
	end
	local rake = Config.Rakes[p.Rake] or Config.Rakes[1]
	local r = rake.Radius + 1.5 -- tolerance for network lag
	local now = os.clock()
	local base = Gameplay.leafValue(player, p, yard)
	local respawn = Config.LeafRespawn * Config.CurrentEvent().RespawnMult
	local ids, newGold = {}, {}
	local added, golds = 0, 0
	for idx, s in Config.LeafSpots(yard) do
		if p.Bag >= cap then
			break
		end
		local id = Config.LeafId(yard, idx)
		local back = rt.taken[id]
		if (back == nil or back <= now) and Vector2.new(s.X - pos.X, s.Z - pos.Z).Magnitude <= r then
			local v = base
			if rt.gold[id] then
				v *= Config.GoldenMult
				golds += 1
			end
			local before = p.Bag
			p.Bag = math.min(cap, p.Bag + v)
			added += p.Bag - before
			rt.taken[id] = now + respawn
			local g = rollGold()
			rt.gold[id] = g
			table.insert(ids, id)
			if g then
				table.insert(newGold, id)
			end
		end
	end
	if #ids == 0 then
		return 0, 0
	end
	p.LeavesRaked += #ids
	leafSync:FireClient(player, "take", ids, respawn, newGold, added, golds)
	State.syncBag(player, p)
	Quests.event(player, "leaf", #ids)
	if golds > 0 then
		Quests.event(player, "gold", golds)
	end
	if p.Bag >= cap and not rt.fullWarned then
		rt.fullWarned = true
		Gameplay.notify(player, "bagfull", "Bag full! Dive in the pile!")
	end
	return #ids, added
end

-- Cash in the bag. Called from the 10 Hz loop when the player lands in a pile.
function Gameplay.dive(player: Player, p: DataService.Profile, yard: number, height: number)
	local rt = runtime[player] :: Runtime
	local y = Config.Yards[yard]
	local mult = Config.DiveMult(height, yard)
	local h = math.clamp(height, 0, y.Tower + Config.DiveCapExtra)
	local acorns = math.floor(p.Bag * mult * Gameplay.acornMult(player, p))
	p.Bag = 0
	p.Acorns += acorns
	p.TotalAcorns += acorns
	p.Dives += 1
	if h > p.BestDive then
		p.BestDive = h
	end
	rt.lastDive = os.clock()
	rt.fullWarned = false
	table.clear(rt.history)
	State.sync(player)
	Quests.event(player, "dive", 1)
	if h >= y.Tower - 2 then
		Quests.event(player, "highdive", 1)
	end
	local text = if mult > 1.05
		then string.format("x%.1f DIVE! +%s 🌰", mult, Format.commas(acorns))
		else "+" .. Format.commas(acorns) .. " 🌰"
	Gameplay.notify(player, "dive", text, { acorns = acorns, mult = mult, height = h, yard = yard })
	if h >= 60 then
		Gameplay.announce(player.DisplayName .. " dove from " .. math.floor(h) .. " studs! 🍂", player)
	end
end

function Gameplay.applyTrail(player: Player)
	local hrp = hrpOf(player)
	if not hrp then
		return
	end
	local old = hrp:FindFirstChild("VipTrail")
	if old then
		old:Destroy()
	end
	if not Passes.has(player, "VIP") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = hrp
	local t = Instance.new("Trail")
	t.Name = "VipTrail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 120, 30))
	t.Transparency = NumberSequence.new(0.2, 1)
	t.Lifetime = 0.5
	t.LightEmission = 0.5
	t.Parent = hrp
end

-- The rake tool. Rebuilt when the rake tier changes (colour/size follow the tier).
function Gameplay.giveRake(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local rake = Config.Rakes[p.Rake] or Config.Rakes[1]
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, t in (container :: Instance):GetChildren() do
				if t:IsA("Tool") and t.Name == "Rake" then
					t:Destroy()
				end
			end
		end
	end
	local tool = Instance.new("Tool")
	tool.Name = "Rake"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = rake.Name
	tool:SetAttribute("Tier", p.Rake)
	-- long axis along -Z (forward from the hand), head at the far end, tilted toward the ground
	tool.Grip = CFrame.new(0, 0, 1.6) * CFrame.Angles(math.rad(35), 0, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 6)
	handle.Color = Color3.fromRGB(150, 105, 65)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	local headW = 1.6 + rake.Radius * 0.12
	local function piece(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
		local x = Instance.new("Part")
		x.Size = size
		x.CFrame = cf
		x.Color = color
		x.Material = mat or Enum.Material.SmoothPlastic
		x.CanCollide = false
		x.CanTouch = false
		x.CanQuery = false
		x.Massless = true
		x.Parent = tool
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = x
		w.Parent = x
	end
	piece(Vector3.new(headW, 0.3, 0.4), CFrame.new(0, 0, -3.1), rake.Color, Enum.Material.Metal)
	local tines = 5
	for k = 0, tines - 1 do
		local x = -headW / 2 + 0.1 + k * (headW - 0.2) / (tines - 1)
		piece(Vector3.new(0.12, 0.9, 0.12), CFrame.new(x, -0.45, -3.2), rake.Color, Enum.Material.Metal)
	end
	tool.Parent = player:FindFirstChildOfClass("Backpack") or player
end

function Gameplay.addPlayer(player: Player)
	runtime[player] = {
		taken = {},
		gold = {},
		history = {},
		lastDive = 0,
		friends = 0,
		grace = os.clock() + 3,
		sampleFrom = nil,
		sampleT = 0,
		fullWarned = false,
		lastLockedWarn = 0,
	}
end

function Gameplay.removePlayer(player: Player)
	runtime[player] = nil
end

function Gameplay.onCharacter(player: Player, character: Model)
	local rt = runtime[player]
	if rt then
		rt.grace = os.clock() + 3
		rt.sampleFrom = nil
		table.clear(rt.history)
	end
	-- (facing +Z on spawn is done by the client: a server pivot here can run before the
	-- character is placed on the SpawnLocation and drops it at the world origin)
	character:WaitForChild("HumanoidRootPart", 10)
	Gameplay.giveRake(player)
	Gameplay.applyTrail(player)
end

local function refreshFriends()
	local list = Players:GetPlayers()
	for _, a in list do
		local rt = runtime[a]
		if rt then
			local n = 0
			for _, b in list do
				if a ~= b then
					local ok, isFriend = pcall(a.IsFriendsWith, a, b.UserId)
					if ok and isFriend then
						n += 1
					end
				end
			end
			rt.friends = n
			a:SetAttribute("FriendBoost", math.min(n * Config.FriendBoostPer, Config.FriendBoostMax))
		end
	end
end

-- 10 Hz: dive detection, yard access, anti-cheat, falling.
local function step(player: Player, rt: Runtime, now: number)
	local p = DataService.get(player)
	local hrp = hrpOf(player)
	if not p or not hrp then
		return
	end
	local pos = hrp.Position
	-- falling out of the world
	if pos.Y < Config.KillY then
		Gameplay.teleport(player, Gameplay.yardSpawn(math.max(1, math.min(Config.YardAt(pos), p.Yards))))
		return
	end
	-- yard access: past a locked gate -> back in front of it
	local yard = Config.YardAt(pos)
	if yard > p.Yards then
		local firstLocked = p.Yards + 1
		Gameplay.teleport(player, CFrame.lookAt(
			Vector3.new(math.clamp(pos.X, -50, 50), Config.GroundY + 4, Config.FenceZ(firstLocked) - 10),
			Vector3.new(math.clamp(pos.X, -50, 50), Config.GroundY + 4, Config.FenceZ(firstLocked))
		))
		if now - rt.lastLockedWarn > 3 then
			rt.lastLockedWarn = now
			Gameplay.notify(player, "locked", "Locked! Unlock " .. Config.Yards[firstLocked].Name .. " in SHOP")
		end
		return
	end
	-- movement sanity: 1 s windows, horizontal speed + upward speed
	if now >= rt.grace then
		if not rt.sampleFrom then
			rt.sampleFrom = pos
			rt.sampleT = now
		elseif now - rt.sampleT >= 1 then
			local dt = now - rt.sampleT
			local from = rt.sampleFrom :: Vector3
			local d = pos - from
			local hum = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
			local ws = if hum then hum.WalkSpeed else 16
			local allowedH = (2 * ws + 40) * dt
			local allowedUp = 70 * dt
			local horiz = Vector2.new(d.X, d.Z).Magnitude
			if horiz > allowedH or d.Y > allowedUp then
				warn(("[AntiCheat] %s moved %.0f studs (up %.0f) in %.1fs; rubber-banded"):format(player.Name, horiz, d.Y, dt))
				Gameplay.teleport(player, CFrame.new(from))
				return
			end
			rt.sampleFrom = pos
			rt.sampleT = now
		end
	end
	-- height history for the dive
	table.insert(rt.history, { t = now, y = pos.Y })
	while #rt.history > 0 and now - rt.history[1].t > Config.PeakWindow do
		table.remove(rt.history, 1)
	end
	-- landing in the pile cashes in the bag
	if yard >= 1 and p.Bag > 0 and now - rt.lastDive > Config.DiveCooldown then
		local c = Config.PileCenter(yard)
		local flat = Vector2.new(pos.X - c.X, pos.Z - c.Z).Magnitude
		if flat < Config.PileRadius and pos.Y < Config.GroundY + Config.PileHeight * 0.6 + 3 then
			local peak = pos.Y
			for _, h in rt.history do
				if h.y > peak then
					peak = h.y
				end
			end
			Gameplay.dive(player, p, yard, peak - (Config.GroundY + 3))
		end
	end
end

function Gameplay.start(notifyRemote: RemoteEvent, leafRemote: RemoteEvent)
	notify = notifyRemote
	leafSync = leafRemote
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local now = os.clock()
		for player, rt in runtime do
			step(player, rt, now)
		end
	end)
	-- 1 s: play time, potion timer, quests
	task.spawn(function()
		local n = 0
		while true do
			task.wait(1)
			n += 1
			for player in runtime do
				local p = DataService.get(player)
				if p then
					p.PlaySeconds += 1
					if p.PotionLeft > 0 then
						p.PotionLeft = math.max(0, p.PotionLeft - 1)
						player:SetAttribute("PotionLeft", math.floor(p.PotionLeft))
					end
					Quests.event(player, "play", 1)
				end
			end
			if n % 15 == 1 then
				task.spawn(refreshFriends)
			end
		end
	end)
end

return Gameplay
