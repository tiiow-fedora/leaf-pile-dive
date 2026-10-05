--!strict
-- World-space feedback: dive leaf explosion + bounce + camera shake, rake ring,
-- the floating ⬇ goal marker, and local gate visuals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Fx = {}

local player = Players.LocalPlayer
local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

local shakeUntil = 0
local shakeMag = 0
RunService:BindToRenderStep("LeafShake", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	if now < shakeUntil then
		local cam = workspace.CurrentCamera
		local k = (shakeUntil - now) * shakeMag
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end
end)

function Fx.shake(duration: number, magnitude: number)
	shakeUntil = os.clock() + duration
	shakeMag = magnitude / duration
end

local function hrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Leaf explosion at the pile + bounce the player up.
function Fx.dive(yard: number, mult: number)
	local c = Config.PileCenter(yard)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	local root = hrp()
	anchor.Position = if root then Vector3.new(root.Position.X, c.Y + 3, root.Position.Z) else c + Vector3.new(0, 3, 0)
	anchor.Parent = fxFolder
	local count = math.floor(40 + math.min(mult, 5) * 25)
	for k, col in Config.LeafColors do
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.Color = ColorSequence.new(col)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.6) })
		pe.Lifetime = NumberRange.new(1, 2)
		pe.Speed = NumberRange.new(25, 45 + mult * 6)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Acceleration = Vector3.new(0, -50, 0)
		pe.Drag = 1.5
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-200, 200)
		pe.LightEmission = 0.2
		pe.Rate = 0
		pe.Parent = anchor
		pe:Emit(math.floor(count / #Config.LeafColors) + (if k == 1 then 4 else 0))
	end
	task.delay(3, function()
		anchor:Destroy()
	end)
	if root then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, 55 + math.min(mult, 4) * 8, v.Z * 0.3)
	end
	Fx.shake(0.35, 1.5 + mult * 0.8)
end

-- Faint ring on the ground showing the rake's reach.
function Fx.rakeRing(radius: number)
	local root = hrp()
	if not root then
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 220, 120)
	ring.Transparency = 0.7
	ring.Size = Vector3.new(0.1, 1, 1)
	ring.CFrame = CFrame.new(root.Position.X, Config.GroundY + 0.15, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fxFolder
	local tw = TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1 })
	tw:Play()
	tw.Completed:Once(function()
		ring:Destroy()
	end)
end

-- Floating ⬇ marker over the current goal (pile / ladder / nothing)
local marker = Instance.new("Part")
marker.Name = "GoalMarker"
marker.Anchored = true
marker.CanCollide = false
marker.CanTouch = false
marker.CanQuery = false
marker.Transparency = 1
marker.Size = Vector3.new(1, 1, 1)
marker.Parent = fxFolder
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(70, 70)
bb.AlwaysOnTop = true
bb.LightInfluence = 0
bb.Parent = marker
local arrow = Instance.new("TextLabel")
arrow.Size = UDim2.fromScale(1, 1)
arrow.BackgroundTransparency = 1
arrow.Text = "⬇"
arrow.TextScaled = true
arrow.Font = Enum.Font.FredokaOne
arrow.TextColor3 = Color3.fromRGB(255, 220, 60)
arrow.Parent = bb
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(60, 30, 10)
stroke.Parent = arrow
bb.Enabled = false

function Fx.setMarker(target: string?, yard: number)
	if yard < 1 or not target or (target ~= "pile" and target ~= "ladder") then
		bb.Enabled = false
		return
	end
	local pos
	if target == "pile" then
		pos = Config.PileCenter(yard) + Vector3.new(0, Config.PileHeight + 9, 0)
	else
		pos = Config.TowerCenter(yard) + Vector3.new(4, 12, 0)
	end
	bb.Enabled = true
	marker.Position = pos + Vector3.new(0, math.sin(os.clock() * 4) * 1.2, 0)
end

-- Gates: passable + green for unlocked yards (local only; the server validates).
function Fx.updateGates(yardsUnlocked: number)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for i = 2, #Config.Yards do
		local f = map:FindFirstChild("Yard" .. i)
		local gate = f and f:FindFirstChild("Gate") :: BasePart?
		if gate then
			local open = i <= yardsUnlocked
			gate.CanCollide = not open
			gate.Color = if open then Color3.fromRGB(90, 230, 120) else Color3.fromRGB(255, 80, 70)
			gate.Transparency = if open then 0.75 else 0.35
			local prompt = gate:FindFirstChild("UnlockPrompt") :: ProximityPrompt?
			if prompt then
				prompt.Enabled = not open and i == yardsUnlocked + 1
			end
			local g = gate:FindFirstChildOfClass("BillboardGui")
			local label = g and g:FindFirstChildOfClass("TextLabel")
			if label then
				local y = Config.Yards[i]
				label.Text = if open then "✅ " .. string.upper(y.Name) else "🔒 " .. string.upper(y.Name) .. "\n" .. Format.short(y.Cost) .. " 🌰"
			end
		end
	end
end

return Fx
