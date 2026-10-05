--!strict
-- Self-synthesized sound effects (tools/make_audio.py, uploaded via Open Cloud; IDs in ASSETS.md).
-- An ID of 0 means "no sound", so the game still works if an upload failed.

local SoundService = game:GetService("SoundService")

local Sfx = {}

local IDS: { [string]: number } = {
	swish = 78008721818395,
	pop = 76977355036789,
	gold = 81825272458625,
	dive = 123187782175662,
	buy = 80126301424736,
	error = 111412797258133,
	unlock = 109529757323933,
	full = 137240758560335,
	season = 87059013281231,
}
local MUSIC_ID = 104785926734135
Sfx.IDS = IDS

local cache: { [string]: Sound } = {}
local VOLUME: { [string]: number } = { swish = 0.35, pop = 0.45, gold = 0.6, dive = 0.8, buy = 0.6, error = 0.4, unlock = 0.7, full = 0.5, season = 0.8 }

function Sfx.play(name: string, pitch: number?)
	local id = IDS[name]
	if not id or id == 0 then
		return
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Sfx_" .. name
		s.SoundId = "rbxassetid://" .. id
		s.Volume = VOLUME[name] or 0.5
		s.Parent = SoundService
		cache[name] = s
	end
	if pitch then
		local c = s:Clone()
		c.PlaybackSpeed = pitch
		c.Parent = SoundService
		c:Play()
		c.Ended:Once(function()
			c:Destroy()
		end)
	else
		SoundService:PlayLocalSound(s)
	end
end

local music: Sound? = nil
local MUSIC_VOL = 0.25

function Sfx.startMusic()
	if music or MUSIC_ID == 0 then
		return
	end
	local m = Instance.new("Sound")
	m.Name = "LeafMusic"
	m.SoundId = "rbxassetid://" .. MUSIC_ID
	m.Looped = true
	m.Volume = MUSIC_VOL
	m.Parent = SoundService
	m:Play()
	music = m
end

function Sfx.setMusic(on: boolean)
	if music then
		music.Volume = if on then MUSIC_VOL else 0
	end
end

return Sfx
