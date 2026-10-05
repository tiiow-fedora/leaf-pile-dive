--!strict
-- Builds the whole map from Config on every server start (deterministic).
-- Interactive things are warm (leaves, piles, gates, trees); grounds are cool.
-- Decor is Anchored, CanCollide/CanTouch/CanQuery off unless it is walkable.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MapBuilder = {}

export type Layout = { PartCount: number, Gates: { [number]: BasePart } }

local partCount = 0
local Props: Folder? = nil -- optional Blender meshes loaded by PropLoader

local function part(props: { [string]: any }, parent: Instance): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	partCount += 1
	return p
end

-- Non-collidable, non-touchable decor
local function decor(props: { [string]: any }, parent: Instance): BasePart
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	props.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	return part(props, parent)
end

local function ellipsoid(size: Vector3, cf: CFrame, color: Color3, parent: Instance, material: Enum.Material?): BasePart
	local p = decor({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic }, parent)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

local function billboard(adornee: BasePart, text: string, color: Color3, size: UDim2, offset: Vector3, maxDist: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffsetWorldSpace = offset
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDist or 250
	bb.LightInfluence = 0
	bb.Parent = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.Parent = bb
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(40, 25, 10)
	s.Parent = t
	return bb
end

local function prop(name: string): BasePart?
	if not Props then
		return nil
	end
	local p = (Props :: Folder):FindFirstChild(name)
	return if p and p:IsA("BasePart") then p:Clone() :: BasePart else nil
end

local function tree(pos: Vector3, scale: number, palette: { Color3 }, rng: Random, parent: Instance)
	local trunkH = 14 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH, 2.6 * scale, 2.6 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 70, 45),
		Material = Enum.Material.Wood,
	}, parent)
	for k = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-3, 3), trunkH + rng:NextNumber(-1, 4), rng:NextNumber(-3, 3)) * Vector3.new(scale, 1, scale)
		local s = rng:NextNumber(10, 14) * scale
		ellipsoid(Vector3.new(s, s * 0.85, s), CFrame.new(pos + off), palette[(k + rng:NextInteger(0, 4)) % #palette + 1], parent)
	end
end

local function pumpkin(pos: Vector3, s: number, parent: Instance)
	ellipsoid(Vector3.new(4, 3, 4) * s, CFrame.new(pos + Vector3.new(0, 1.3 * s, 0)), Color3.fromRGB(255, 125, 20), parent)
	decor({ Size = Vector3.new(0.5, 1.2, 0.5) * s, CFrame = CFrame.new(pos + Vector3.new(0, 3 * s, 0)), Color = Color3.fromRGB(70, 130, 50) }, parent)
end

local function buildPile(i: number, folder: Instance)
	local c = Config.PileCenter(i)
	local y = Config.Yards[i]
	local R, H = Config.PileRadius, Config.PileHeight
	local pile = Instance.new("Model")
	pile.Name = "Pile"
	pile.Parent = folder
	local main = prop("LeafPile")
	if main then
		main.Size = Vector3.new(R * 2.1, H * 1.15, R * 2.1)
		main.CFrame = CFrame.new(c + Vector3.new(0, H * 0.5, 0))
		main.Anchored = true
		main.CanCollide = false
		main.CanTouch = false
		main.CanQuery = false
		main.Name = "Mound"
		main.Parent = pile
		partCount += 1
	else
		local mound = ellipsoid(Vector3.new(R * 2, H * 2, R * 2), CFrame.new(c), Color3.fromRGB(240, 120, 30), pile)
		mound.Name = "Mound"
		local rng = Random.new(i * 31)
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2
			local r = rng:NextNumber(4, R - 5)
			ellipsoid(
				Vector3.new(9, 6, 9),
				CFrame.new(c + Vector3.new(math.cos(a) * r, H * 0.55 + rng:NextNumber(-1, 2), math.sin(a) * r)),
				Config.LeafColors[k % #Config.LeafColors + 1],
				pile
			)
		end
	end
	-- glowing ring that marks the cash-in zone
	local ring = decor({
		Name = "PileRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, R * 2 + 3, R * 2 + 3),
		CFrame = CFrame.new(c + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CastShadow = false,
	}, pile)
	local anchor = decor({ Name = "PileTop", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(c + Vector3.new(0, H + 2, 0)) }, pile)
	billboard(anchor, "🍂 DIVE HERE", Color3.fromRGB(255, 225, 120), UDim2.fromOffset(150, 34), Vector3.new(0, 4, 0), 90)
	-- drifting leaves over the pile
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 90, 40))
	pe.Size = NumberSequence.new(0.6)
	pe.Lifetime = NumberRange.new(2, 3)
	pe.Rate = 4
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.4
	pe.Parent = anchor
	pile:SetAttribute("Yard", i)
	ring:SetAttribute("Yard", i)
	return pile
end

local function buildTower(i: number, folder: Instance)
	local y = Config.Yards[i]
	local c = Config.TowerCenter(i)
	local H = y.Tower
	local model = Instance.new("Model")
	model.Name = "Tower"
	model.Parent = folder
	local wood = Color3.fromRGB(150, 95, 55)
	part({ Name = "Pillar", Size = Vector3.new(6, H, 6), CFrame = CFrame.new(c + Vector3.new(0, H / 2, 0)), Color = wood, Material = Enum.Material.WoodPlanks }, model)
	-- ladder on the +X side, just outside the deck's edge (a ladder under the deck
	-- overhang traps the climber's head), in the gap the +X railing leaves open
	part({
		ClassName = "TrussPart",
		Name = "Ladder",
		Size = Vector3.new(2, H + 3, 2),
		CFrame = CFrame.new(c + Vector3.new(8.1, (H + 3) / 2, -4)),
		Color = Color3.fromRGB(255, 200, 70),
		Material = Enum.Material.Metal,
	}, model)
	part({ Name = "Deck", Size = Vector3.new(14, 1, 14), CFrame = CFrame.new(c + Vector3.new(0, H + 0.5, 0)), Color = Color3.fromRGB(180, 120, 70), Material = Enum.Material.WoodPlanks }, model)
	-- railings on the back and sides (the front -Z edge opens onto the board)
	local rail = Color3.fromRGB(255, 255, 255)
	part({ Name = "Rail", Size = Vector3.new(14, 3, 0.6), CFrame = CFrame.new(c + Vector3.new(0, H + 2.5, 6.7)), Color = rail }, model)
	part({ Name = "Rail", Size = Vector3.new(0.6, 3, 14), CFrame = CFrame.new(c + Vector3.new(-6.7, H + 2.5, 0)), Color = rail }, model)
	part({ Name = "Rail", Size = Vector3.new(0.6, 3, 8), CFrame = CFrame.new(c + Vector3.new(6.7, H + 2.5, 3)), Color = rail }, model)
	-- diving board toward the pile
	local boardLen = Config.TowerOffsetZ - 7 - 4
	part({
		Name = "Board",
		Size = Vector3.new(4, 0.6, boardLen),
		CFrame = CFrame.new(c + Vector3.new(0, H + 0.7, -7 - boardLen / 2)),
		Color = Color3.fromRGB(70, 170, 255),
	}, model)
	local sign = decor({ Name = "TowerSign", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(c + Vector3.new(0, H + 7, -2)) }, model)
	billboard(sign, string.format("x%.1f DIVE!", Config.DiveMult(H + 3, i)), Color3.fromRGB(120, 230, 255), UDim2.fromOffset(140, 34), Vector3.zero, 110)
	local lad = decor({ Name = "LadderSign", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(c + Vector3.new(10, 7, -4)) }, model)
	billboard(lad, "⬆ CLIMB", Color3.fromRGB(255, 230, 120), UDim2.fromOffset(100, 28), Vector3.zero, 60)
end

local function buildFence(i: number, folder: Instance, layout: Layout)
	-- fence between yard i-1 and yard i, with a gate that is solid until yard i is unlocked
	local z = Config.FenceZ(i)
	local W = Config.YardWidth
	local gateW = 18
	local segW = (W - gateW) / 2
	local wood = Color3.fromRGB(235, 225, 205)
	for side = -1, 1, 2 do
		part({
			Name = "Fence",
			Size = Vector3.new(segW, 8, 1.5),
			CFrame = CFrame.new(side * (gateW / 2 + segW / 2), Config.GroundY + 4, z),
			Color = wood,
			Material = Enum.Material.WoodPlanks,
		}, folder)
	end
	-- tall invisible barrier above the fence so it can't be hopped from a tower
	part({ Name = "FenceBarrier", Size = Vector3.new(W, 200, 1.5), CFrame = CFrame.new(0, Config.GroundY + 108, z), Transparency = 1, CanTouch = false, CanQuery = false }, folder)
	local gate = part({
		Name = "Gate",
		Size = Vector3.new(gateW, 12, 1.5),
		CFrame = CFrame.new(0, Config.GroundY + 6, z),
		Color = Color3.fromRGB(255, 80, 70),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanTouch = false,
	}, folder)
	gate:SetAttribute("Yard", i)
	layout.Gates[i] = gate
	local y = Config.Yards[i]
	billboard(gate, "🔒 " .. string.upper(y.Name) .. "\n" .. Format.short(y.Cost) .. " 🌰", Color3.fromRGB(255, 240, 200), UDim2.fromOffset(160, 60), Vector3.new(0, 9, 0), 110)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockPrompt"
	prompt.ActionText = "Unlock " .. y.Name
	prompt.ObjectText = Format.short(y.Cost) .. " Acorns"
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.F -- E is the rake key
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate
end

local function buildYard(i: number, root: Instance, layout: Layout)
	local y = Config.Yards[i]
	local folder = Instance.new("Folder")
	folder.Name = "Yard" .. i
	folder:SetAttribute("Yard", i)
	folder.Parent = root
	local c = Config.YardCenter(i)
	local z0 = Config.YardStartZ(i)
	part({ Name = "Ground", Size = Vector3.new(Config.YardWidth, 2, Config.YardLength), CFrame = CFrame.new(c - Vector3.new(0, 1, 0)), Color = y.Ground, Material = Enum.Material.Grass }, folder)
	-- path from fence to fence
	decor({ Name = "Path", Size = Vector3.new(10, 0.2, Config.YardLength), CFrame = CFrame.new(c + Vector3.new(-30, 0.05, 0)), Color = Color3.fromRGB(200, 190, 170), Material = Enum.Material.Pebble, CastShadow = false }, folder)
	if i > 1 then
		buildFence(i, folder, layout)
		-- the fence strip ground
		part({ Name = "Strip", Size = Vector3.new(Config.YardWidth, 2, Config.YardGap), CFrame = CFrame.new(0, Config.GroundY - 1, Config.FenceZ(i)), Color = Color3.fromRGB(120, 130, 150), Material = Enum.Material.Slate }, folder)
	end
	-- side fences (low, decorative) + tall invisible walls
	for side = -1, 1, 2 do
		part({ Name = "SideFence", Size = Vector3.new(1, 4, Config.YardLength), CFrame = CFrame.new(side * (Config.YardWidth / 2 + 0.5), Config.GroundY + 2, c.Z), Color = Color3.fromRGB(235, 225, 205), Material = Enum.Material.WoodPlanks }, folder)
		part({ Name = "SideWall", Size = Vector3.new(1, 300, Config.YardLength + Config.YardGap), CFrame = CFrame.new(side * (Config.YardWidth / 2 + 1.5), Config.GroundY + 150, c.Z), Transparency = 1, CanTouch = false, CanQuery = false }, folder)
	end
	buildPile(i, folder)
	buildTower(i, folder)
	-- trees along the sides, out of the leaf field's centre
	local rng = Random.new(900 + i)
	local palette = { Color3.fromRGB(255, 130, 30), Color3.fromRGB(235, 70, 45), Color3.fromRGB(255, 195, 45), y.Accent }
	for k = 1, y.Trees do
		local side = if k % 2 == 0 then 1 else -1
		local x = side * rng:NextNumber(44, 54)
		local z = z0 + 10 + (k - 1) / math.max(1, y.Trees - 1) * (Config.YardLength - 20)
		tree(Vector3.new(x, Config.GroundY, z), rng:NextNumber(0.9, 1.25), palette, rng, folder)
	end
	-- yard-specific decor
	if i == 2 then
		for k = 1, 3 do
			part({ Name = "Bench", Size = Vector3.new(6, 1, 2), CFrame = CFrame.new(-30, 1.5, z0 + 20 + k * 25), Color = Color3.fromRGB(70, 120, 200) }, folder)
		end
	elseif i == 3 then
		for k = 1, 5 do
			local p = Vector3.new(-50 + rng:NextNumber(-3, 3), 0, z0 + 10 + k * 20)
			for d = 1, 4 do
				ellipsoid(Vector3.new(1.4, 1.4, 1.4), CFrame.new(p + Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(12, 18), rng:NextNumber(-5, 5))), Color3.fromRGB(230, 30, 40), folder)
			end
		end
	elseif i == 4 then
		for k = 1, 14 do
			pumpkin(Vector3.new(rng:NextNumber(-56, -36) * (if k % 2 == 0 then -1 else 1), Config.GroundY, z0 + rng:NextNumber(8, Config.YardLength - 8)), rng:NextNumber(0.8, 1.6), folder)
		end
	end
	-- yard name sign at its entrance
	local signAnchor = decor({ Name = "YardSign", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(-30, Config.GroundY + 8, z0 + 8) }, folder)
	billboard(signAnchor, y.Name .. "\nleaves x" .. y.Value, Color3.fromRGB(255, 250, 230), UDim2.fromOffset(140, 50), Vector3.zero, 80)
	return folder
end

local function buildGiantOak(root: Instance)
	-- the landmark: visible from the spawn, at the back of the last yard
	local n = #Config.Yards
	local base = Vector3.new(-28, Config.GroundY, Config.YardStartZ(n) + Config.YardLength - 18)
	local model = Instance.new("Model")
	model.Name = "GiantOak"
	model.Parent = root
	local mesh = prop("GiantOak")
	if mesh then
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh.Size = mesh.Size * (200 / mesh.Size.Y)
		mesh.CFrame = CFrame.new(base + Vector3.new(0, mesh.Size.Y / 2, 0))
		mesh.Parent = model
		partCount += 1
	else
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(120, 22, 22),
			CFrame = CFrame.new(base + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 75, 45),
			Material = Enum.Material.Wood,
		}, model)
		local glow = { Color3.fromRGB(255, 150, 30), Color3.fromRGB(255, 200, 50), Color3.fromRGB(240, 90, 40) }
		local rng = Random.new(77)
		for k = 1, 9 do
			local off = Vector3.new(rng:NextNumber(-40, 40), 125 + rng:NextNumber(-10, 45), rng:NextNumber(-40, 40))
			local s = rng:NextNumber(55, 80)
			ellipsoid(Vector3.new(s, s * 0.8, s), CFrame.new(base + off), glow[k % #glow + 1], model)
		end
	end
	local light = decor({ Name = "OakGlow", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(base + Vector3.new(0, 150, 0)) }, model)
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 190, 90)
	pl.Range = 60
	pl.Brightness = 2
	pl.Parent = light
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 210, 90))
	pe.Size = NumberSequence.new(2.5)
	pe.Lifetime = NumberRange.new(6, 9)
	pe.Rate = 6
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -2, 0)
	pe.LightEmission = 0.6
	pe.Parent = light
end

local function lighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	for _, c in Lighting:GetChildren() do
		c:Destroy()
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.24
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(255, 225, 190)
	atm.Decay = Color3.fromRGB(150, 180, 230)
	atm.Glare = 0.2
	atm.Haze = 0.6
	atm.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 248, 238)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 2.4
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting
end

function MapBuilder.setProps(folder: Folder?)
	Props = folder
end

function MapBuilder.build(): Layout
	partCount = 0
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	-- the Studio template's baseplate and spawn would sit on top of yard 1
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	local root = Instance.new("Folder")
	root.Name = "Map"
	local layout: Layout = { PartCount = 0, Gates = {} }
	for i = 1, #Config.Yards do
		buildYard(i, root, layout)
	end
	-- back wall behind the spawn and end wall after the last yard
	local endZ = Config.YardStartZ(#Config.Yards) + Config.YardLength
	part({ Name = "BackFence", Size = Vector3.new(Config.YardWidth, 4, 1), CFrame = CFrame.new(0, 2, -0.5), Color = Color3.fromRGB(235, 225, 205), Material = Enum.Material.WoodPlanks }, root)
	part({ Name = "BackWall", Size = Vector3.new(Config.YardWidth + 4, 300, 1), CFrame = CFrame.new(0, 150, -1.5), Transparency = 1, CanTouch = false, CanQuery = false }, root)
	part({ Name = "EndWall", Size = Vector3.new(Config.YardWidth + 4, 300, 1), CFrame = CFrame.new(0, 150, endZ + 0.5), Transparency = 1, CanTouch = false, CanQuery = false }, root)
	-- outer meadow so the edges don't fall into the void visually
	decor({ Name = "Meadow", Size = Vector3.new(900, 1, endZ + 600), CFrame = CFrame.new(0, -2.6, endZ / 2), Color = Color3.fromRGB(90, 160, 120), Material = Enum.Material.Grass, CastShadow = false }, root)
	buildGiantOak(root)
	-- spawn
	local spawnCF = Config.SpawnCFrame()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	-- SpawnLocation's front (-Z) must face +Z (toward the pile), so turn it around
	spawn.CFrame = CFrame.new(spawnCF.Position.X, Config.GroundY + 0.1, spawnCF.Position.Z) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = Color3.fromRGB(255, 190, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 0.2
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.CanTouch = true
	spawn.Parent = root
	partCount += 1
	root.Parent = workspace
	lighting()
	layout.PartCount = partCount
	return layout
end

return MapBuilder
