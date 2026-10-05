--!strict
-- DataStore persistence: pcall + retries, UpdateAsync only, a session lock,
-- autosave every 60 s, save on leave and on server shutdown (BindToClose).
-- Saves are versioned (Profile.Version); migrate() upgrades older saves step by step.
-- Never rename Config.DataStoreName or remove fields: that would wipe players.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

export type Profile = {
	Version: number,
	Acorns: number,
	TotalAcorns: number,
	Bag: number, -- leaf points currently in the bag
	Rake: number, -- owned rake tier (tiers are bought in order)
	BagTier: number,
	Yards: number, -- yards unlocked (1..#Config.Yards)
	Season: number,
	BestDive: number, -- best dive height in studs
	Dives: number,
	LeavesRaked: number,
	PotionLeft: number, -- seconds of 2x Acorns left
	DailyStreak: number,
	LastDaily: number,
	Receipts: { string }, -- recent PurchaseIds already granted (ring buffer)
	TutorialDone: boolean,
	PlaySeconds: number,
	QuestDay: number,
	Quests: { { Id: string, P: number, C: boolean } },
}

local function defaultProfile(): Profile
	return {
		Version = Config.SaveVersion,
		Acorns = 0,
		TotalAcorns = 0,
		Bag = 0,
		Rake = 1,
		BagTier = 1,
		Yards = 1,
		Season = 0,
		BestDive = 0,
		Dives = 0,
		LeavesRaked = 0,
		PotionLeft = 0,
		DailyStreak = 0,
		LastDaily = 0,
		Receipts = {},
		TutorialDone = false,
		PlaySeconds = 0,
		QuestDay = 0,
		Quests = {},
	}
end
DataService.defaultProfile = defaultProfile

local LOCK_TIMEOUT = 180
local MAX_RECEIPTS = 100
local JOB = if RunService:IsStudio() then "studio-" .. HttpService:GenerateGUID(false) else game.JobId

-- Migration steps: MIGRATIONS[v] turns a version-v save table into version v+1.
-- Version 0 = the pre-release test format (unversioned; "Coins" instead of "Acorns",
-- "Yard" instead of "Yards"), kept as the worked example of the migration path.
local MIGRATIONS: { [number]: (any) -> any } = {
	[0] = function(d: any): any
		if d.Acorns == nil and type(d.Coins) == "number" then
			d.Acorns = d.Coins
		end
		if d.Yards == nil and type(d.Yard) == "number" then
			d.Yards = d.Yard
		end
		d.Coins = nil
		d.Yard = nil
		d.Version = 1
		return d
	end,
}

-- Upgrade any saved table to the current version, then fill/validate every field.
local function migrate(data: any): Profile
	local d = defaultProfile()
	if type(data) ~= "table" then
		return d
	end
	data = table.clone(data)
	local v = if type(data.Version) == "number" then data.Version else 0
	while v < Config.SaveVersion and MIGRATIONS[v] do
		data = MIGRATIONS[v](data)
		v += 1
	end
	for k, def in pairs(d) do
		if data[k] ~= nil and type(data[k]) == type(def) then
			(d :: any)[k] = data[k]
		end
	end
	d.Version = Config.SaveVersion
	-- clamp tiers to the current tables (a removed tier must never crash a player)
	d.Rake = math.clamp(math.floor(d.Rake), 1, #Config.Rakes)
	d.BagTier = math.clamp(math.floor(d.BagTier), 1, #Config.Bags)
	d.Yards = math.clamp(math.floor(d.Yards), 1, #Config.Yards)
	if d.Acorns ~= d.Acorns or d.Acorns < 0 then
		d.Acorns = 0
	end
	return d
end
DataService.migrate = migrate

local store: DataStore? = nil
local storeOk, storeErr = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not storeOk then
	warn("[Data] DataStore unavailable (" .. tostring(storeErr) .. "); progress will not save this session")
end

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}

local function key(userId: number): string
	return "u_" .. userId
end

local function retry<T>(label: string, attempts: number, fn: () -> T): (boolean, T?)
	local lastErr
	for i = 1, attempts do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		local msg = tostring(res)
		if msg:find("StudioAccessToApisNotAllowed") or msg:find("not allowed") or msg:find("403") then
			break -- permanent; retrying only delays the player
		end
		task.wait(math.min(2 ^ i, 8))
	end
	warn("[Data] " .. label .. " failed: " .. tostring(lastErr))
	return false, nil
end

function DataService.load(player: Player): Profile
	local profile = defaultProfile()
	if not store then
		profiles[player] = profile
		loaded[player] = false -- never save a blank profile over real data
		return profile
	end
	local ds = store :: DataStore
	local stolen = false
	local ok = false
	for attempt = 1, 4 do
		local result: any = nil
		local success = retry("load " .. player.UserId, 3, function()
			return ds:UpdateAsync(key(player.UserId), function(old: any)
				old = old or {}
				local lock = old.Lock
				if lock and lock.Job ~= JOB and os.time() - (lock.Time or 0) < LOCK_TIMEOUT and attempt < 4 then
					result = "locked"
					return nil -- cancel write; another server still holds the session
				end
				if lock and lock.Job ~= JOB and attempt == 4 then
					stolen = true
				end
				old.Lock = { Job = JOB, Time = os.time() }
				result = old
				return old
			end)
		end)
		if not success then
			break
		end
		if result ~= "locked" then
			profile = migrate(result and result.Data)
			ok = true
			break
		end
		task.wait(5)
	end
	if stolen then
		warn("[Data] took over a stale session lock for " .. player.UserId)
	end
	profiles[player] = profile
	loaded[player] = ok
	if not ok then
		warn("[Data] could not load " .. player.UserId .. "; this session will not overwrite saved data")
	end
	return profile
end

-- Studio test helper: replace a player's in-memory profile with a brand-new one.
function DataService.resetForTest(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	local fresh = defaultProfile()
	for k in pairs(p) do
		(p :: any)[k] = nil
	end
	for k, v in pairs(fresh) do
		(p :: any)[k] = v
	end
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.isLoaded(player: Player): boolean
	return loaded[player] == true
end

-- Studio test hook: force the next save(s) to fail (ProcessReceipt rollback test).
DataService.failSavesForTest = false

-- Returns true only if the write actually reached the DataStore.
function DataService.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not loaded[player] or not store then
		return false
	end
	if DataService.failSavesForTest then
		return false
	end
	local ds = store :: DataStore
	while saving[player] do
		task.wait(0.1)
	end
	saving[player] = true
	local snapshot = table.clone(profile)
	snapshot.Receipts = table.clone(profile.Receipts)
	snapshot.Quests = table.clone(profile.Quests)
	local wrote = false
	local ok = retry("save " .. player.UserId, 4, function()
		wrote = false
		return ds:UpdateAsync(key(player.UserId), function(old: any)
			old = old or {}
			if old.Lock and old.Lock.Job ~= JOB and os.time() - (old.Lock.Time or 0) < LOCK_TIMEOUT then
				-- another server took the session over; don't clobber it
				return nil
			end
			old.Data = snapshot
			old.Lock = if release then nil else { Job = JOB, Time = os.time() }
			old.SavedAt = os.time()
			wrote = true
			return old
		end)
	end)
	saving[player] = nil
	return ok and wrote
end

function DataService.addReceipt(profile: Profile, purchaseId: string)
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > MAX_RECEIPTS do
		table.remove(profile.Receipts, 1)
	end
end

function DataService.hasReceipt(profile: Profile, purchaseId: string): boolean
	return table.find(profile.Receipts, purchaseId) ~= nil
end

function DataService.release(player: Player)
	DataService.save(player, true)
	profiles[player] = nil
	loaded[player] = nil
end

function DataService.start(onBeforeSave: (Player) -> ())
	Players.PlayerRemoving:Connect(function(player)
		onBeforeSave(player)
		DataService.release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			for player in profiles do
				task.spawn(function()
					onBeforeSave(player)
					DataService.save(player)
				end)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				onBeforeSave(player)
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
