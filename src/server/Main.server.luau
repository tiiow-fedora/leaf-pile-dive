--!strict
-- Server entry point: build the map, wire remotes, load/save players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local PropLoader = require(script.Parent.PropLoader)
local Leaderboard = require(script.Parent.Leaderboard)
local Quests = require(script.Parent.Quests)
local DataService = require(script.Parent.DataService)
local State = require(script.Parent.State)
local Passes = require(script.Parent.Passes)
local RateLimit = require(script.Parent.RateLimit)
local Gameplay = require(script.Parent.Gameplay)
local Shop = require(script.Parent.Shop)
local Monetization = require(script.Parent.Monetization)

StarterGui.ResetPlayerGuiOnSpawn = false

MapBuilder.setProps(PropLoader.load(8))
local layout = MapBuilder.build()
-- anyone who joined while the props were loading spawned before the SpawnLocation existed
-- (at the world origin, on the back fence): respawn them on the real spawn
for _, p in Players:GetPlayers() do
	if p.Character then
		task.spawn(p.LoadCharacter, p)
	end
end
Leaderboard.build(workspace:WaitForChild("Map"))
Leaderboard.start()

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local notify = remote("Notify")
local leafSync = remote("LeafSync")
local rake = remote("Rake")
local buyRake = remote("BuyRake")
local buyBag = remote("BuyBag")
local unlockYard = remote("UnlockYard")
local newSeason = remote("NewSeason")
local claimDaily = remote("ClaimDaily")
local claimQuest = remote("ClaimQuest")
local tutorialDone = remote("TutorialDone")
remotes.Parent = ReplicatedStorage

local function guarded(name: string, rate: number, burst: number, fn: (Player, ...any) -> ())
	return function(player: Player, ...)
		if not DataService.get(player) or not player:GetAttribute("Loaded") then
			return
		end
		if not RateLimit.allow(player, name, rate, burst) then
			return
		end
		fn(player, ...)
	end
end

rake.OnServerEvent:Connect(guarded("Rake", 3, 4, function(player: Player)
	Gameplay.rake(player)
end))
buyRake.OnServerEvent:Connect(guarded("BuyRake", 3, 4, Shop.buyRake))
buyBag.OnServerEvent:Connect(guarded("BuyBag", 3, 4, Shop.buyBag))
unlockYard.OnServerEvent:Connect(guarded("UnlockYard", 2, 3, Shop.unlockYard))
newSeason.OnServerEvent:Connect(guarded("NewSeason", 1, 1, Shop.newSeason))
claimDaily.OnServerEvent:Connect(guarded("ClaimDaily", 1, 2, Shop.claimDaily))
claimQuest.OnServerEvent:Connect(guarded("ClaimQuest", 2, 3, Quests.claim))
tutorialDone.OnServerEvent:Connect(guarded("TutorialDone", 1, 2, function(player: Player)
	local p = DataService.get(player)
	if p and not p.TutorialDone then
		p.TutorialDone = true
		player:SetAttribute("TutorialDone", true)
	end
end))

-- Gate prompts: same validation path as the SHOP button
for yard, gate in layout.Gates do
	local prompt = gate:FindFirstChild("UnlockPrompt") :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(guarded("UnlockYard", 2, 3, function(player: Player)
			Shop.unlockYard(player, yard)
		end))
	end
end

Gameplay.start(notify, leafSync)
Quests.setNotify(Gameplay.notify)
Passes.onGrant = function(player: Player, _key: string)
	State.sync(player)
	Gameplay.applyTrail(player)
end
Monetization.start()

local function onPlayerAdded(player: Player)
	State.setupLeaderstats(player)
	DataService.load(player)
	if player.Parent == nil then
		-- left while loading
		DataService.release(player)
		return
	end
	Gameplay.addPlayer(player)
	Passes.load(player)
	local firstJoin = Gameplay.welcomeIfNew(player)
	State.sync(player)
	Shop.refreshDaily(player)
	local prof = DataService.get(player)
	if prof then
		Quests.ensure(player, prof)
		Quests.sync(player)
	end
	player:SetAttribute("DataSaving", DataService.isLoaded(player))
	player:SetAttribute("Loaded", true)
	Gameplay.initLeaves(player)
	if firstJoin then
		task.delay(4, function()
			Gameplay.notify(player, "welcome", "Welcome gift: 2x Acorns for 3 minutes!")
		end)
	end
	player.CharacterAdded:Connect(function(character)
		Gameplay.onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(Gameplay.onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Gameplay.removePlayer(player)
	Passes.clear(player)
	RateLimit.clear(player)
end)

DataService.start(function(player: Player)
	local p = DataService.get(player)
	if p and DataService.isLoaded(player) then
		Leaderboard.submitTo("TopAcorns", player.UserId, p.TotalAcorns)
		Leaderboard.submitTo("BestDive", player.UserId, p.BestDive)
	end
end)

-- Studio-only hooks for the command bar (runs inside the game's own module cache):
--   game.ServerScriptService.DevRun:Invoke()            -> full DevTest
--   game.ServerScriptService.DevRun:Invoke("fresh", 1)  -> player 1 becomes a brand-new player
--   game.ServerScriptService.DevRun:Invoke("yard", 3)   -> unlock up to yard 3 and go there
--   game.ServerScriptService.DevRun:Invoke("acorns", n) -> give n acorns
if RunService:IsStudio() then
	local devRun = Instance.new("BindableFunction")
	devRun.Name = "DevRun"
	devRun.OnInvoke = function(what: string?, arg: any?)
		local player = Players:GetPlayers()[1]
		if what == "fresh" then
			player = Players:GetPlayers()[tonumber(arg) or 1]
			DataService.resetForTest(player)
			local welcomed = Gameplay.welcomeIfNew(player)
			State.sync(player)
			Shop.refreshDaily(player)
			local prof = DataService.get(player) :: DataService.Profile
			Quests.ensure(player, prof)
			Quests.sync(player)
			Gameplay.initLeaves(player)
			player:LoadCharacter()
			return player.Name .. " welcomed=" .. tostring(welcomed) .. " potion=" .. tostring(prof.PotionLeft)
		elseif what == "yard" then
			local p = DataService.get(player) :: DataService.Profile
			local n = math.clamp(tonumber(arg) or 1, 1, #Config.Yards)
			p.Yards = math.max(p.Yards, n)
			State.sync(player)
			Gameplay.teleport(player, Gameplay.yardSpawn(n))
			return true
		elseif what == "acorns" then
			local p = DataService.get(player) :: DataService.Profile
			p.Acorns += tonumber(arg) or 0
			State.sync(player)
			return p.Acorns
		elseif what == "welcome" then
			Gameplay.notify(player, "welcome", "Welcome gift: 2x Acorns for 3 minutes!")
			return true
		end
		return require(script.Parent.DevTest).run()
	end
	devRun.Parent = game:GetService("ServerScriptService")
end

print("[LeafPileDive] server ready, " .. #Config.Yards .. " yards, map parts " .. tostring(layout.PartCount))
