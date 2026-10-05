--!strict
-- HUD, hints, next goal, side buttons, panels (shop, store, quests, daily, season),
-- toasts, yard strip. Layouts for phone (667x375), tablet and desktop. On desktop the
-- Roblox chat window covers the top-left, so the left button column starts below it.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)

local Hud = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- autumn palette
Theme.Panel = Color3.fromRGB(70, 42, 28)
Theme.PanelLight = Color3.fromRGB(105, 66, 42)
Theme.Accent = Color3.fromRGB(255, 140, 40)
Theme.Gold = Color3.fromRGB(255, 205, 60)
Theme.Green = Color3.fromRGB(80, 200, 100)
Theme.Blue = Color3.fromRGB(70, 160, 255)
Theme.Red = Color3.fromRGB(235, 70, 60)
Theme.Muted = Color3.fromRGB(235, 210, 180)

local new = Theme.new
local gui: ScreenGui
local scale: UIScale
local isTouch = false
local isPhone = false

local refs: { [string]: any } = {}
local panels: { [string]: Frame } = {}
local refreshers: { [string]: () -> () } = {}
Hud.onRake = nil :: (() -> ())?
Hud.onAutoToggle = nil :: ((boolean) -> ())?
Hud.autoOn = false
Hud.musicOn = true

local function attr(name: string, default: any): any
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function bagCap(): number
	return attr("BagCap", 40)
end

local function pulse(obj: GuiObject, on: boolean)
	local key = "pulse_" .. obj:GetFullName()
	local existing = refs[key]
	if existing then
		existing:Cancel()
		refs[key] = nil
		obj.Rotation = 0
	end
	if on then
		local tw = TweenService:Create(obj, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 4 })
		tw:Play()
		refs[key] = tw
	end
end

---------------------------------------------------------------------------- toasts / popups

function Hud.toast(text: string, color: Color3?)
	local holder = refs.toasts :: Frame
	local t = Theme.label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextColor3 = color or Theme.Text,
		Font = Theme.Font,
		TextTransparency = 1,
		Parent = holder,
	})
	TweenService:Create(t, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	task.delay(3.2, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
	local kids = holder:GetChildren()
	local n = 0
	for _, k in kids do
		if k:IsA("TextLabel") then
			n += 1
		end
	end
	if n > 3 then
		for _, k in kids do
			if k:IsA("TextLabel") then
				k:Destroy()
				break
			end
		end
	end
end

-- big centre popup (dives, unlocks)
function Hud.popup(text: string, color: Color3?)
	local l = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(520, 70),
		Text = text,
		TextColor3 = color or Theme.Gold,
		Parent = gui,
	})
	local s = Instance.new("UIScale")
	s.Scale = 0.3
	s.Parent = l
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.3, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.35) }):Play()
		task.wait(0.55)
		l:Destroy()
	end)
end

-- small "+N" that floats up near the bag bar
function Hud.floatText(text: string, color: Color3?)
	local bar = refs.bagBar :: Frame
	local l = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.random(-60, 60), 1, 18),
		Size = UDim2.fromOffset(140, 26),
		Text = text,
		TextColor3 = color or Theme.Gold,
		Parent = bar,
	})
	TweenService:Create(l, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = l.Position + UDim2.fromOffset(0, 30), TextTransparency = 1 }):Play()
	task.delay(0.85, function()
		l:Destroy()
	end)
end

---------------------------------------------------------------------------- panels

local function closeAll()
	for _, p in panels do
		p.Visible = false
	end
end

local function openPanel(name: string)
	local p = panels[name]
	local was = p.Visible
	closeAll()
	p.Visible = not was
	if p.Visible and refreshers[name] then
		refreshers[name]()
	end
end
Hud.openPanel = openPanel

local function makePanel(name: string, title: string, color: Color3): (Frame, ScrollingFrame)
	local f = new("Frame", {
		Name = name .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(500, 360),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	Theme.corner(16).Parent = f
	Theme.stroke(Color3.fromRGB(30, 15, 5), 3).Parent = f
	Theme.label({ Size = UDim2.new(1, -60, 0, 44), Position = UDim2.fromOffset(16, 6), Text = title, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = f })
	local close = Theme.button({ Text = "X", Size = UDim2.fromOffset(42, 42), Position = UDim2.new(1, -50, 0, 8), BackgroundColor3 = Theme.Red, ZIndex = 21, Parent = f })
	close.MouseButton1Click:Connect(closeAll)
	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 1, -66),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = f,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	panels[name] = f
	return f, list
end

type Row = { frame: Frame, title: TextLabel, sub: TextLabel, button: TextButton }
local function row(list: Instance, order: number, onClick: () -> ()): Row
	local f = new("Frame", { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = Theme.PanelLight, LayoutOrder = order, ZIndex = 22, Parent = list })
	Theme.corner(10).Parent = f
	local title = Theme.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = f })
	local sub = Theme.label({ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -150, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.BodyFont, TextColor3 = Theme.Muted, ZIndex = 23, Parent = f })
	local b = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(128, 44), ZIndex = 23, Parent = f })
	b.MouseButton1Click:Connect(onClick)
	return { frame = f, title = title, sub = sub, button = b }
end

local function setButton(b: TextButton, text: string, color: Color3, active: boolean)
	b.Text = text
	b.BackgroundColor3 = color
	b.AutoButtonColor = active
	b.Active = active
end

local function buildShop()
	local f, list = makePanel("Shop", "🛒 SHOP", Theme.Gold)
	local tabs = new("Frame", { Position = UDim2.new(0, 150, 0, 10), Size = UDim2.new(1, -210, 0, 36), BackgroundTransparency = 1, ZIndex = 21, Parent = f })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabs })
	local current = "Rakes"
	local rows: { Row } = {}
	local function render()
		for _, r in rows do
			r.frame:Destroy()
		end
		table.clear(rows)
		local acorns = attr("Acorns", 0)
		if current == "Rakes" then
			local owned = attr("Rake", 1)
			for i, r in Config.Rakes do
				local rw = row(list, i, function()
					if i == attr("Rake", 1) + 1 then
						if attr("Acorns", 0) >= r.Cost then
							(remotes:WaitForChild("BuyRake") :: RemoteEvent):FireServer(i)
						else
							Sfx.play("error")
							Hud.toast("Need " .. Format.short(r.Cost - attr("Acorns", 0)) .. " more 🌰", Theme.Red)
						end
					end
				end)
				rw.title.Text = r.Name
				rw.title.TextColor3 = r.Color
				rw.sub.Text = "Reach " .. r.Radius .. " · leaves x" .. r.Mult
				if i <= owned then
					setButton(rw.button, if i == owned then "EQUIPPED" else "OWNED", Theme.Green, false)
				elseif i == owned + 1 then
					setButton(rw.button, Format.short(r.Cost) .. " 🌰", if acorns >= r.Cost then Theme.Accent else Color3.fromRGB(130, 100, 80), true)
				else
					setButton(rw.button, "🔒", Color3.fromRGB(90, 70, 60), false)
				end
				table.insert(rows, rw)
			end
		elseif current == "Bags" then
			local owned = attr("BagTier", 1)
			local mult = if attr("Pass_BigBag", false) then Config.BigBagMult else 1
			for i, b in Config.Bags do
				local rw = row(list, i, function()
					if i == attr("BagTier", 1) + 1 then
						if attr("Acorns", 0) >= b.Cost then
							(remotes:WaitForChild("BuyBag") :: RemoteEvent):FireServer(i)
						else
							Sfx.play("error")
							Hud.toast("Need " .. Format.short(b.Cost - attr("Acorns", 0)) .. " more 🌰", Theme.Red)
						end
					end
				end)
				rw.title.Text = b.Name
				rw.sub.Text = "Holds " .. Format.short(b.Cap * mult) .. " leaves"
				if i <= owned then
					setButton(rw.button, if i == owned then "EQUIPPED" else "OWNED", Theme.Green, false)
				elseif i == owned + 1 then
					setButton(rw.button, Format.short(b.Cost) .. " 🌰", if acorns >= b.Cost then Theme.Accent else Color3.fromRGB(130, 100, 80), true)
				else
					setButton(rw.button, "🔒", Color3.fromRGB(90, 70, 60), false)
				end
				table.insert(rows, rw)
			end
		else
			local owned = attr("Yards", 1)
			for i, y in Config.Yards do
				local rw = row(list, i, function()
					if i == attr("Yards", 1) + 1 then
						if attr("Acorns", 0) >= y.Cost then
							(remotes:WaitForChild("UnlockYard") :: RemoteEvent):FireServer(i)
						else
							Sfx.play("error")
							Hud.toast("Need " .. Format.short(y.Cost - attr("Acorns", 0)) .. " more 🌰", Theme.Red)
						end
					end
				end)
				rw.title.Text = y.Name
				rw.sub.Text = "Leaves x" .. y.Value .. " · tower " .. y.Tower .. " studs"
				if i <= owned then
					setButton(rw.button, "OPEN", Theme.Green, false)
				elseif i == owned + 1 then
					setButton(rw.button, Format.short(y.Cost) .. " 🌰", if acorns >= y.Cost then Theme.Accent else Color3.fromRGB(130, 100, 80), true)
				else
					setButton(rw.button, "🔒", Color3.fromRGB(90, 70, 60), false)
				end
				table.insert(rows, rw)
			end
		end
	end
	local tabButtons: { [string]: TextButton } = {}
	for _, name in { "Rakes", "Bags", "Yards" } do
		local b = Theme.button({ Text = string.upper(name), Size = UDim2.fromOffset(92, 34), BackgroundColor3 = Theme.PanelLight, ZIndex = 22, Parent = tabs })
		tabButtons[name] = b
		b.MouseButton1Click:Connect(function()
			current = name
			for n, tb in tabButtons do
				tb.BackgroundColor3 = if n == current then Theme.Accent else Theme.PanelLight
			end
			render()
		end)
	end
	tabButtons.Rakes.BackgroundColor3 = Theme.Accent
	refreshers.Shop = render
	Hud.shopTab = function(name: string)
		current = name
		for n, tb in tabButtons do
			tb.BackgroundColor3 = if n == current then Theme.Accent else Theme.PanelLight
		end
		render()
	end
end

local function buildStore()
	local _, list = makePanel("Store", "⭐ STORE", Theme.Green)
	local rows: { [string]: Row } = {}
	for i, key in Config.PassOrder do
		local pass = Config.Passes[key]
		local rw = row(list, i, function()
			if pass.Id ~= 0 and not attr("Pass_" .. key, false) then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end
		end)
		rw.title.Text = pass.Name .. "  (pass)"
		rw.sub.Text = pass.Desc
		rows["pass_" .. key] = rw
	end
	for i, key in Config.ProductOrder do
		local prod = Config.Products[key]
		local rw = row(list, 10 + i, function()
			if prod.Id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, prod.Id)
			end
		end)
		rw.title.Text = prod.Name
		rw.sub.Text = prod.Desc
		rows["prod_" .. key] = rw
	end
	refreshers.Store = function()
		for key, pass in Config.Passes do
			local rw = rows["pass_" .. key]
			if attr("Pass_" .. key, false) then
				setButton(rw.button, "OWNED", Theme.Green, false)
			else
				setButton(rw.button, "R$ " .. pass.Price, Theme.Blue, pass.Id ~= 0)
			end
		end
		for key, prod in Config.Products do
			setButton(rows["prod_" .. key].button, "R$ " .. prod.Price, Theme.Blue, prod.Id ~= 0)
		end
	end
end

local function buildQuests()
	local _, list = makePanel("Quests", "📜 DAILY QUESTS", Theme.Gold)
	local rows: { Row } = {}
	for i = 1, 3 do
		rows[i] = row(list, i, function()
			(remotes:WaitForChild("ClaimQuest") :: RemoteEvent):FireServer(i)
		end)
	end
	local note = Theme.label({ Size = UDim2.new(1, -10, 0, 22), Text = "New quests every day (UTC)", Font = Theme.BodyFont, TextColor3 = Theme.Muted, LayoutOrder = 9, ZIndex = 22, Parent = list })
	_ = note
	refreshers.Quests = function()
		local ok, data = pcall(HttpService.JSONDecode, HttpService, attr("Quests", "[]"))
		if not ok or type(data) ~= "table" then
			return
		end
		for i = 1, 3 do
			local q = data[i]
			local rw = rows[i]
			if q then
				rw.title.Text = q.text
				rw.sub.Text = string.format("%s / %s%s  ·  +%s 🌰", Format.short(q.progress), Format.short(q.target), if q.text:find("minutes") then " min" else "", Format.short(q.reward))
				if q.claimed then
					setButton(rw.button, "DONE ✓", Theme.Green, false)
				elseif q.progress >= q.target then
					setButton(rw.button, "CLAIM", Theme.Accent, true)
				else
					setButton(rw.button, "…", Color3.fromRGB(110, 90, 75), false)
				end
			end
		end
	end
end

local function buildDaily()
	local f, list = makePanel("Daily", "🎁 DAILY REWARD", Theme.Gold)
	_ = f
	local strip = new("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 22, Parent = list })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = strip })
	local days: { Frame } = {}
	for d = 1, Config.DailyMaxDay do
		local c = new("Frame", { Size = UDim2.fromOffset(58, 66), BackgroundColor3 = Theme.PanelLight, ZIndex = 22, Parent = strip })
		Theme.corner(8).Parent = c
		Theme.label({ Size = UDim2.new(1, 0, 0.5, 0), Text = "Day " .. d, ZIndex = 23, Parent = c })
		Theme.label({ Name = "Gift", Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0.5, 0), Text = if d == 7 then "🌰+⏱" else "🌰", ZIndex = 23, Parent = c })
		days[d] = c
	end
	local info = Theme.label({ Size = UDim2.new(1, -10, 0, 30), LayoutOrder = 2, ZIndex = 22, Parent = list })
	local claim = Theme.button({ Size = UDim2.fromOffset(200, 50), LayoutOrder = 3, ZIndex = 22, Parent = list })
	claim.MouseButton1Click:Connect(function()
		if attr("DailyReady", false) then
			(remotes:WaitForChild("ClaimDaily") :: RemoteEvent):FireServer()
		end
	end)
	Theme.label({ Size = UDim2.new(1, -10, 0, 22), Text = "Come back every day! Miss 2 days and the streak resets.", Font = Theme.BodyFont, TextColor3 = Theme.Muted, LayoutOrder = 4, ZIndex = 22, Parent = list })
	refreshers.Daily = function()
		local day = attr("DailyDay", 1)
		local ready = attr("DailyReady", false)
		for d, c in days do
			c.BackgroundColor3 = if d < day or (d == day and not ready) then Theme.Green elseif d == day then Theme.Accent else Theme.PanelLight
		end
		info.Text = "Day " .. day .. ": +" .. Format.short(attr("DailyAmount", 100)) .. " 🌰" .. (if day == 7 then " + 2x Acorns 10 min" else "")
		if ready then
			setButton(claim, "CLAIM!", Theme.Accent, true)
		else
			local left = attr("DailyNext", 0) - os.time()
			setButton(claim, "Next in " .. string.format("%dh %02dm", left // 3600, (left % 3600) // 60), Color3.fromRGB(110, 90, 75), false)
		end
	end
end

local function buildSeason()
	local _, list = makePanel("Season", "🍁 NEW SEASON", Theme.Accent)
	local info = Theme.label({ Size = UDim2.new(1, -10, 0, 60), Font = Theme.BodyFont, TextWrapped = true, LayoutOrder = 1, ZIndex = 22, Parent = list })
	local req = Theme.label({ Size = UDim2.new(1, -10, 0, 84), Font = Theme.BodyFont, TextColor3 = Theme.Muted, LayoutOrder = 2, ZIndex = 22, Parent = list })
	local btn = Theme.button({ Size = UDim2.fromOffset(240, 52), LayoutOrder = 3, ZIndex = 22, Parent = list })
	btn.MouseButton1Click:Connect(function()
		(remotes:WaitForChild("NewSeason") :: RemoteEvent):FireServer()
	end)
	refreshers.Season = function()
		local s = attr("Season", 0)
		local cost = Config.SeasonCost(s)
		info.Text = "Start Season " .. (s + 2) .. ": leaves worth x" .. (1 + Config.SeasonBonus * (s + 1)) .. " forever.\nResets Acorns, rake and bag. Yards stay open."
		local y = attr("Yards", 1) >= #Config.Yards
		local r = attr("Rake", 1) >= #Config.Rakes
		local a = attr("Acorns", 0) >= cost
		req.Text = string.format("%s All 6 yards open\n%s %s\n%s %s 🌰", if y then "✅" else "⬜", if r then "✅" else "⬜", Config.Rakes[#Config.Rakes].Name, if a then "✅" else "⬜", Format.short(cost))
		if y and r and a then
			setButton(btn, "START SEASON", Theme.Accent, true)
		else
			setButton(btn, "Not ready yet", Color3.fromRGB(110, 90, 75), false)
		end
	end
end

---------------------------------------------------------------------------- hints + next goal

function Hud.nextGoal(): string
	local acorns = attr("Acorns", 0)
	local rake, bag, yards = attr("Rake", 1), attr("BagTier", 1), attr("Yards", 1)
	local options = {}
	if bag < #Config.Bags then
		table.insert(options, { Config.Bags[bag + 1].Cost, Config.Bags[bag + 1].Name, "Bags" })
	end
	if rake < #Config.Rakes then
		table.insert(options, { Config.Rakes[rake + 1].Cost, Config.Rakes[rake + 1].Name, "Rakes" })
	end
	if yards < #Config.Yards then
		-- a new yard is the bigger goal once it's within reach of the cheaper buys
		table.insert(options, { Config.Yards[yards + 1].Cost * 0.6, Config.Yards[yards + 1].Name .. " yard", "Yards", Config.Yards[yards + 1].Cost })
	end
	if #options == 0 then
		local c = Config.SeasonCost(attr("Season", 0))
		return "Next: New Season (" .. Format.short(c) .. " 🌰)", acorns >= c
	end
	table.sort(options, function(a, b)
		return a[1] < b[1]
	end)
	local o = options[1]
	local cost = o[4] or o[1]
	refs.nextTab = o[3]
	return "Next: " .. o[2] .. " (" .. Format.short(cost) .. " 🌰)", acorns >= cost
end

-- Short hint (6 words or fewer), derived from state so it can't get stuck.
function Hud.hint(): (string?, string?)
	local bag, cap = attr("Bag", 0), bagCap()
	local dives = attr("Dives", 0)
	local tut = attr("TutorialDone", false)
	if bag >= cap then
		return "Bag full! Dive in the pile!", "pile"
	end
	if not tut then
		if dives == 0 and bag == 0 then
			return if isTouch then "Tap RAKE to rake leaves!" else "Click to rake leaves!", "leaf"
		elseif dives == 0 then
			return "Keep raking! Fill your bag", "leaf"
		elseif attr("BestDive", 0) < 10 then
			return "Climb the tower: higher = more!", "ladder"
		elseif attr("BagTier", 1) == 1 then
			return "Open SHOP: buy a Sack!", "shop"
		end
	end
	return nil, nil
end

---------------------------------------------------------------------------- build

local function sideButton(parent: Instance, text: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local b = Theme.button({ Text = text, Size = UDim2.fromOffset(118, 44), BackgroundColor3 = color, LayoutOrder = order, Parent = parent })
	b.MouseButton1Click:Connect(onClick)
	local dot = new("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Theme.Red, Visible = false, ZIndex = 5, Parent = b })
	Theme.corner(8).Parent = dot
	return b
end

local function layout()
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	isPhone = vp.Y < 520 or (isTouch and vp.X < 900)
	if vp.Y < 520 then
		isTouch = isTouch or UserInputService.TouchEnabled
	end
	local s = math.clamp(vp.Y / 820, 0.62, 1.1)
	scale.Scale = s
	local left = refs.left :: Frame
	local right = refs.right :: Frame
	local rakeBtn = refs.rakeBtn :: TextButton
	local strip = refs.strip :: Frame
	local inset = GuiService:GetGuiInset()
	_ = inset
	if isTouch or isPhone then
		-- touch: chat is collapsed; the thumbstick owns the bottom-left
		left.Position = UDim2.new(0, 8, 0, 8)
		rakeBtn.AnchorPoint = Vector2.new(1, 1)
		rakeBtn.Position = UDim2.new(1, -math.floor(175 / s), 1, -math.floor(26 / s))
		strip.Visible = vp.Y >= 520
	else
		-- desktop: the chat window covers the top-left; start below it
		left.Position = UDim2.new(0, 10, 0, math.floor(236 / s))
		rakeBtn.AnchorPoint = Vector2.new(1, 1)
		rakeBtn.Position = UDim2.new(1, -24, 1, -24)
		strip.Visible = true
	end
	right.Position = UDim2.new(1, -8, 0.5, 0)
	refs.isTouch = isTouch
end

function Hud.build()
	local pg = player:WaitForChild("PlayerGui")
	gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	scale = new("UIScale", { Parent = gui })

	-- top centre: acorns, bag bar, hint, next goal
	local top = new("Frame", { Name = "Top", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(360, 150), BackgroundTransparency = 1, Parent = gui })
	refs.acorns = Theme.label({ Size = UDim2.new(1, 0, 0, 44), Text = "🌰 0", TextColor3 = Theme.Gold, Parent = top })
	local bar = new("Frame", { Name = "BagBar", Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -40, 0, 28), BackgroundColor3 = Color3.fromRGB(60, 35, 20), Parent = top })
	Theme.corner(14).Parent = bar
	Theme.stroke(Color3.fromRGB(30, 15, 5), 2).Parent = bar
	refs.bagBar = bar
	refs.bagFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, Parent = bar })
	Theme.corner(14).Parent = refs.bagFill
	refs.bagText = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "🍂 0 / 40", ZIndex = 3, Parent = bar })
	refs.hint = Theme.label({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 30), Text = "", TextColor3 = Color3.fromRGB(255, 240, 140), Parent = top })
	refs.next = Theme.label({ Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 0, 22), Text = "", Font = Theme.BodyFont, TextColor3 = Theme.Text, Parent = top })
	refs.boosts = Theme.label({ Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 18), Text = "", Font = Theme.BodyFont, TextColor3 = Color3.fromRGB(150, 255, 170), Parent = top })
	refs.toasts = new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = UDim2.fromOffset(560, 130), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = refs.toasts })

	-- left column
	local left = new("Frame", { Name = "Left", Size = UDim2.fromOffset(118, 260), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	refs.left = left
	refs.shopBtn = sideButton(left, "🛒 SHOP", Theme.Accent, 1, function()
		openPanel("Shop")
		if panels.Shop.Visible and refs.nextTab and Hud.shopTab then
			Hud.shopTab(refs.nextTab)
		end
	end)
	refs.storeBtn = sideButton(left, "⭐ STORE", Theme.Green, 2, function()
		openPanel("Store")
	end)
	refs.questBtn = sideButton(left, "📜 QUESTS", Theme.Blue, 3, function()
		openPanel("Quests")
	end)
	refs.dailyBtn = sideButton(left, "🎁 DAILY", Color3.fromRGB(220, 80, 160), 4, function()
		openPanel("Daily")
	end)
	refs.seasonBtn = sideButton(left, "🍁 SEASON", Color3.fromRGB(200, 70, 50), 5, function()
		openPanel("Season")
	end)

	-- right column
	local right = new("Frame", { Name = "Right", AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(118, 160), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
	refs.right = right
	sideButton(right, "👋 INVITE", Theme.Blue, 1, function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			Hud.toast("Invites aren't available here", Theme.Muted)
		end
	end)
	local music = sideButton(right, "🎵 MUSIC", Color3.fromRGB(120, 90, 200), 2, function() end)
	music.MouseButton1Click:Connect(function()
		Hud.musicOn = not Hud.musicOn
		Sfx.setMusic(Hud.musicOn)
		music.Text = if Hud.musicOn then "🎵 MUSIC" else "🔇 MUSIC"
	end)
	refs.autoBtn = sideButton(right, "🤖 AUTO", Color3.fromRGB(110, 110, 120), 3, function()
		if not attr("Pass_AutoRake", false) then
			local id = Config.Passes.AutoRake.Id
			if id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, id)
			end
			return
		end
		Hud.autoOn = not Hud.autoOn
		if Hud.onAutoToggle then
			Hud.onAutoToggle(Hud.autoOn)
		end
		Hud.refresh()
	end)

	-- rake button (all devices; essential on touch)
	local rakeBtn = Theme.button({ Name = "RakeButton", Text = "🍂\nRAKE", Size = UDim2.fromOffset(112, 112), BackgroundColor3 = Theme.Accent, Parent = gui })
	Theme.corner(56).Parent = rakeBtn
	rakeBtn.MouseButton1Down:Connect(function()
		if Hud.onRake then
			Hud.onRake()
		end
	end)
	refs.rakeBtn = rakeBtn

	-- bottom: yard progress strip + event chip
	local strip = new("Frame", { Name = "YardStrip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(372, 48), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = strip })
	refs.strip = strip
	refs.stripCells = {}
	for i, y in Config.Yards do
		local c = new("Frame", { Size = UDim2.fromOffset(58, 30), BackgroundColor3 = Color3.fromRGB(70, 60, 55), Parent = strip })
		Theme.corner(8).Parent = c
		Theme.label({ Size = UDim2.fromScale(1, 1), Text = string.split(y.Name, " ")[1], Font = Theme.BodyFont, Parent = c })
		refs.stripCells[i] = c
	end
	refs.event = Theme.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -42), Size = UDim2.fromOffset(372, 18), Text = "", Font = Theme.BodyFont, TextColor3 = Color3.fromRGB(255, 220, 130), Parent = gui })

	buildShop()
	buildStore()
	buildQuests()
	buildDaily()
	buildSeason()

	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	player.AttributeChanged:Connect(function()
		Hud.refresh()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			Hud.refresh()
		end
	end)
	Hud.refresh()
end

local lastBag = 0
function Hud.refresh()
	if not gui then
		return
	end
	local acorns = attr("Acorns", 0)
	refs.acorns.Text = "🌰 " .. Format.commas(acorns)
	local bag, cap = attr("Bag", 0), bagCap()
	refs.bagText.Text = "🍂 " .. Format.short(bag) .. " / " .. Format.short(cap)
	local frac = math.clamp(bag / math.max(cap, 1), 0, 1)
	TweenService:Create(refs.bagFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(frac, 1) }):Play()
	refs.bagFill.BackgroundColor3 = if frac >= 1 then Theme.Red else Theme.Accent
	if bag > lastBag then
		Hud.floatText("+" .. Format.short(bag - lastBag), Theme.Gold)
	end
	lastBag = bag
	local h, target = Hud.hint()
	refs.hint.Text = h or ""
	refs.hintTarget = target
	local goal, affordable = Hud.nextGoal()
	refs.next.Text = goal
	refs.next.TextColor3 = if affordable then Color3.fromRGB(150, 255, 150) else Theme.Text
	-- boosts line
	local parts = {}
	local potion = attr("PotionLeft", 0)
	if potion > 0 then
		table.insert(parts, "2x 🌰 " .. Format.time(potion))
	end
	local fb = attr("FriendBoost", 0)
	if fb > 0 then
		table.insert(parts, "Friends +" .. math.floor(fb * 100 + 0.5) .. "%")
	end
	if attr("Season", 0) > 0 then
		table.insert(parts, "Season x" .. (1 + Config.SeasonBonus * attr("Season", 0)))
	end
	refs.boosts.Text = table.concat(parts, "  ·  ")
	-- buttons that want attention
	pulse(refs.shopBtn, target == "shop" or affordable)
	refs.shopBtn.Dot.Visible = affordable
	refs.questBtn.Dot.Visible = attr("QuestReady", false)
	refs.dailyBtn.Dot.Visible = attr("DailyReady", false)
	local seasonReady = attr("Yards", 1) >= #Config.Yards and attr("Rake", 1) >= #Config.Rakes and acorns >= Config.SeasonCost(attr("Season", 0))
	refs.seasonBtn.Dot.Visible = seasonReady
	refs.autoBtn.Text = if not attr("Pass_AutoRake", false) then "🤖 AUTO" elseif Hud.autoOn then "🤖 AUTO ON" else "🤖 AUTO OFF"
	refs.autoBtn.BackgroundColor3 = if Hud.autoOn then Theme.Green else Color3.fromRGB(110, 110, 120)
	-- yard strip
	local yards = attr("Yards", 1)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local here = if hrp then Config.YardAt((hrp :: BasePart).Position) else 0
	for i, c in refs.stripCells do
		local cell = c :: Frame
		cell.BackgroundColor3 = if i == here then Theme.Accent elseif i <= yards then Theme.Green else Color3.fromRGB(70, 60, 55)
	end
	local ev = Config.CurrentEvent()
	local left = Config.EventEndsAt(os.time()) - os.time()
	refs.event.Text = "🎉 " .. ev.Name .. ": " .. ev.Desc .. " (" .. (left // 86400) .. "d " .. ((left % 86400) // 3600) .. "h left)"
	for name, p in panels do
		if p.Visible and refreshers[name] then
			refreshers[name]()
		end
	end
end

function Hud.hintTarget(): string?
	return refs.hintTarget
end

function Hud.isTouch(): boolean
	return refs.isTouch == true
end

return Hud
