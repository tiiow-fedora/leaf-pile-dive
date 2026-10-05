--!strict
-- Renders this player's leaves locally (the server owns which leaves exist and
-- what they are worth; see Gameplay.rake). Leaves are cheap anchored parts with
-- no collision, touch or query.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Leaves = {}

local player = Players.LocalPlayer
local folder: Folder
local parts: { [number]: BasePart } = {}
local homes: { [number]: CFrame } = {}
local colors: { [number]: Color3 } = {}
local version: { [number]: number } = {} -- bumps on every take so stale regrow timers are ignored

local SIZE = Vector3.new(2.3, 0.35, 2.3)
local GOLD_SIZE = Vector3.new(2.8, 0.42, 2.8)

local function sparkle(p: BasePart, on: boolean)
	local pe = p:FindFirstChild("Sparkle") :: ParticleEmitter?
	if on and not pe then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sparkle"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
		e.Size = NumberSequence.new(0.5, 0)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Rate = 4
		e.Speed = NumberRange.new(1, 2)
		e.LightEmission = 1
		e.Parent = p
	elseif not on and pe then
		pe:Destroy()
	end
end

local function style(id: number, golden: boolean)
	local p = parts[id]
	if not p then
		return
	end
	if golden then
		p.Color = Config.GoldColor
		p.Material = Enum.Material.Neon
		p.Size = GOLD_SIZE
	else
		p.Color = colors[id]
		p.Material = Enum.Material.SmoothPlastic
		p.Size = SIZE
	end
	p:SetAttribute("Golden", golden)
	sparkle(p, golden)
end

function Leaves.build()
	local old = workspace:FindFirstChild("Leaves")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Leaves"
	local rng = Random.new(1234)
	local props = ReplicatedStorage:WaitForChild("Props", 6)
	local template = props and props:FindFirstChild("MapleLeaf") :: MeshPart?
	for yard = 1, #Config.Yards do
		for idx, pos in Config.LeafSpots(yard) do
			local id = Config.LeafId(yard, idx)
			local p: BasePart = if template then template:Clone() else Instance.new("Part")
			p.Name = "Leaf"
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Size = SIZE
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			local cf = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-8, 8)))
			p.CFrame = cf
			colors[id] = Config.LeafColors[rng:NextInteger(1, #Config.LeafColors)]
			p.Color = colors[id]
			p.Material = Enum.Material.SmoothPlastic
			p:SetAttribute("Id", id)
			p.Parent = folder
			parts[id] = p
			homes[id] = cf
			version[id] = 0
		end
	end
	folder.Parent = workspace
end

-- Server sent the full state (join / reset): all leaves visible, these are golden.
function Leaves.init(goldList: { number })
	local gold = {}
	for _, id in goldList do
		gold[id] = true
	end
	for id, p in parts do
		version[id] += 1
		p.Transparency = 0
		p.CFrame = homes[id]
		style(id, gold[id] == true)
	end
end

local function regrow(id: number, v: number, golden: boolean)
	if version[id] ~= v then
		return
	end
	local p = parts[id]
	style(id, golden)
	local home = homes[id]
	p.CFrame = home * CFrame.new(0, 1.5, 0)
	p.Transparency = 0
	TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = home }):Play()
end

-- Server confirmed a rake: fly the leaves into the player, regrow them later.
function Leaves.take(ids: { number }, respawn: number, newGold: { number })
	local gold = {}
	for _, id in newGold do
		gold[id] = true
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, id in ids do
		local p = parts[id]
		if p then
			version[id] += 1
			local v = version[id]
			if hrp then
				local target = CFrame.new((hrp :: BasePart).Position + Vector3.new(0, 1, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
				local tw = TweenService:Create(p, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = target, Transparency = 0.6 })
				tw:Play()
				tw.Completed:Once(function()
					if version[id] == v then
						p.Transparency = 1
					end
				end)
			else
				p.Transparency = 1
			end
			task.delay(respawn, regrow, id, v, gold[id] == true)
		end
	end
end

-- Nearest visible leaf to a position (used for the auto-rake and the hint marker).
function Leaves.nearestVisible(pos: Vector3, yard: number): Vector3?
	local best, bestD = nil, math.huge
	for idx in Config.LeafSpots(yard) do
		local p = parts[Config.LeafId(yard, idx)]
		if p and p.Transparency == 0 then
			local d = (p.Position - pos).Magnitude
			if d < bestD then
				best, bestD = p.Position, d
			end
		end
	end
	return best
end

function Leaves.visibleWithin(pos: Vector3, radius: number): number
	local n = 0
	local yard = Config.YardAt(pos)
	if yard == 0 then
		return 0
	end
	for idx, s in Config.LeafSpots(yard) do
		local p = parts[Config.LeafId(yard, idx)]
		if p and p.Transparency == 0 and Vector2.new(s.X - pos.X, s.Z - pos.Z).Magnitude <= radius then
			n += 1
		end
	end
	return n
end

return Leaves
