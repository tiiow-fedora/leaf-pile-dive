--!strict
-- Client entry: rake input (tool click/tap, RAKE button, E key), auto rake,
-- server notifications -> sound/visual feedback, leaves, marker, VIP chat tag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)
local Leaves = require(script.Parent.Leaves)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local rakeRemote = remotes:WaitForChild("Rake") :: RemoteEvent
local notify = remotes:WaitForChild("Notify") :: RemoteEvent
local leafSync = remotes:WaitForChild("LeafSync") :: RemoteEvent
local tutorialDone = remotes:WaitForChild("TutorialDone") :: RemoteEvent

-- leaves first so the init message has parts to style
Leaves.build()
local pendingInit: { number }? = nil
local leavesReady = true
leafSync.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, added: any, golds: any)
	if kind == "init" then
		if leavesReady then
			Leaves.init(a)
		else
			pendingInit = a
		end
	elseif kind == "take" then
		Leaves.take(a, b, c)
		if typeof(golds) == "number" and golds > 0 then
			Sfx.play("gold")
			Hud.toast("✨ Golden leaf! x" .. Config.GoldenMult, Config.GoldColor)
		else
			Sfx.play("pop", 0.9 + math.random() * 0.3)
		end
	end
end)
if pendingInit then
	Leaves.init(pendingInit)
end

while not player:GetAttribute("Loaded") do
	task.wait(0.1)
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

Hud.build()
Sfx.startMusic()

---------------------------------------------------------------------------- rake

local lastSwing = 0
local function currentTool(): Tool?
	local c = player.Character
	return c and c:FindFirstChild("Rake") :: Tool?
end

local function swing()
	local now = os.clock()
	if now - lastSwing < Config.SwingInterval then
		return
	end
	lastSwing = now
	local tool = currentTool()
	if tool then
		-- the default Animate script plays the tool slash when it sees this value
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
	end
	local rake = Config.Rakes[player:GetAttribute("Rake") :: number? or 1] or Config.Rakes[1]
	Fx.rakeRing(rake.Radius)
	Sfx.play("swish", 0.95 + math.random() * 0.1)
	rakeRemote:FireServer()
end
Hud.onRake = swing

local function equip(character: Model)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChild("Rake") :: Tool?
	if tool then
		hum:EquipTool(tool)
	end
end

local function watchTools(character: Model)
	-- keep the rake in hand (the hotbar is hidden; re-equip after tier changes)
	task.spawn(function()
		while character.Parent do
			if not character:FindFirstChild("Rake") then
				equip(character)
			end
			local tool = character:FindFirstChild("Rake") :: Tool?
			if tool and not tool:GetAttribute("Hooked") then
				tool:SetAttribute("Hooked", true)
				tool.Activated:Connect(swing)
			end
			task.wait(0.4)
		end
	end)
end

-- start every life looking down the yard (+Z, toward the pile), camera behind the
-- character. Re-applied a few times: the camera module can reset it right after spawn.
local function frameCamera(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local look = Vector3.new(0, 0, 1)
	for _, delay in { 0.1, 0.4, 1.0 } do
		task.wait(delay)
		if not root.Parent then
			return
		end
		local cam = workspace.CurrentCamera
		cam.CFrame = CFrame.lookAt(root.Position - look * 12 + Vector3.new(0, 6, 0), root.Position + look * 6 + Vector3.new(0, 2, 0))
	end
end

player.CharacterAdded:Connect(function(character)
	watchTools(character)
	task.spawn(frameCamera, character)
end)
if player.Character then
	watchTools(player.Character)
	task.spawn(frameCamera, player.Character)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR2 then
		swing()
	end
end)

-- auto rake (pass): swing while standing in an open yard with room in the bag
local autoOn = false
Hud.onAutoToggle = function(on: boolean)
	autoOn = on
end
task.spawn(function()
	while true do
		task.wait(Config.SwingInterval + 0.02)
		if autoOn and player:GetAttribute("Pass_AutoRake") then
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local bag, cap = player:GetAttribute("Bag") :: number? or 0, player:GetAttribute("BagCap") :: number? or 1
			if root and bag < cap and root.Position.Y < Config.GroundY + Config.RakeHeightLimit then
				local yard = Config.YardAt(root.Position)
				if yard >= 1 and yard <= (player:GetAttribute("Yards") :: number? or 1) then
					swing()
				end
			end
		end
	end
end)

---------------------------------------------------------------------------- notifications

notify.OnClientEvent:Connect(function(kind: string, text: string, extra: any)
	if kind == "dive" then
		Sfx.play("dive")
		local mult = if type(extra) == "table" then extra.mult or 1 else 1
		Fx.dive(if type(extra) == "table" then extra.yard or 1 else 1, mult)
		Hud.popup(text, if mult > 2.5 then Color3.fromRGB(255, 120, 60) else Color3.fromRGB(255, 215, 60))
	elseif kind == "bagfull" then
		Sfx.play("full")
		Hud.toast(text, Color3.fromRGB(255, 170, 80))
	elseif kind == "buy" or kind == "purchase" then
		Sfx.play("buy")
		Hud.toast(text, Color3.fromRGB(150, 255, 150))
	elseif kind == "unlock" then
		Sfx.play("unlock")
		Hud.popup(text, Color3.fromRGB(120, 255, 140))
	elseif kind == "season" then
		Sfx.play("season")
		Hud.popup(text, Color3.fromRGB(255, 120, 60))
	elseif kind == "error" or kind == "locked" then
		Sfx.play("error")
		Hud.toast(text, Color3.fromRGB(255, 110, 100))
	elseif kind == "welcome" then
		Sfx.play("unlock")
		Hud.popup("🎁 " .. text, Color3.fromRGB(255, 220, 120))
	elseif kind == "quest" then
		Sfx.play("buy")
		Hud.toast(text, Color3.fromRGB(255, 230, 120))
	else
		Hud.toast(text)
	end
end)

---------------------------------------------------------------------------- gates, marker, tutorial

local function yardsChanged()
	Fx.updateGates(player:GetAttribute("Yards") :: number? or 1)
end
player:GetAttributeChangedSignal("Yards"):Connect(yardsChanged)
task.spawn(function()
	workspace:WaitForChild("Map")
	yardsChanged()
end)

RunService.Heartbeat:Connect(function()
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local yard = if root then Config.YardAt(root.Position) else 1
	Fx.setMarker(Hud.hintTarget(), yard)
end)

-- the tutorial ends once the player has dived from height and owns a second bag
task.spawn(function()
	while not player:GetAttribute("TutorialDone") do
		task.wait(1)
		if (player:GetAttribute("BagTier") :: number? or 1) >= 2 and (player:GetAttribute("BestDive") :: number? or 0) >= 10 then
			tutorialDone:FireServer()
			break
		end
	end
end)

---------------------------------------------------------------------------- VIP chat tag

pcall(function()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local src = message.TextSource
		if src then
			local who = Players:GetPlayerByUserId(src.UserId)
			if who and who:GetAttribute("Pass_VIP") then
				props.PrefixText = "<font color='#FFD23C'>[VIP]</font> " .. message.PrefixText
			end
		end
		return props
	end
end)

print("[LeafPileDive] client ready")
