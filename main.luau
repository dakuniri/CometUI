--═══════════════════════════════════════════════════════════════════════
--  comet · UIlib
--  self-contained acrylic UI for Roblox — no external assets, no deps
--
--  win  = UIlib:CreateWindow({ Title = "comet", Size = Vector2.new(720, 404) })
--  tab  = win:Tab({ Name = "Combat", Side = "TopRight" })
--  sub  = tab:SubTab("Aimbot")
--  sect = sub:Section("Targeting")
--  sect:Toggle({ Name = "Enabled", Default = false, Callback = function(v) end })
--═══════════════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")

local LP = Players.LocalPlayer

--──────────────────────────────────────────── utilities

local function pickFont(name, fallback)
	local ok, f = pcall(function()
		return Enum.Font[name]
	end)
	if ok and f then return f end
	return fallback
end

local function create(class, props)
	local inst = Instance.new(class)
	for k, v in next, props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

local function round(v, step)
	if not step or step <= 0 then
		return v
	end
	return math.floor(v / step + 0.5) * step
end

local function formatNumber(v)
	if v == math.floor(v) then
		return tostring(math.floor(v))
	end
	return string.format("%.2f", v)
end

local function strokeOf(parent, color, transparency, thickness)
	return create("UIStroke", {
		Parent = parent,
		Color = color or Color3.fromRGB(255, 255, 255),
		Transparency = transparency or 0.86,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function gradient(parent, rotation, stops)
	local g = create("UIGradient", {
		Parent = parent,
		Rotation = rotation or 90,
	})
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, stops[1][1]),
		ColorSequenceKeypoint.new(1, stops[2][1]),
	})
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, stops[1][2]),
		NumberSequenceKeypoint.new(1, stops[2][2]),
	})
	return g
end

local function guiParent()
	local ok, hui = pcall(gethui)
	if ok and typeof(hui) == "Instance" then
		return hui
	end
	return LP:WaitForChild("PlayerGui")
end

--──────────────────────────────────────────── theme

local Theme = {
	Accent      = Color3.fromRGB(138, 170, 255),
	AccentAlt   = Color3.fromRGB(196, 148, 255),
	Text        = Color3.fromRGB(238, 241, 249),
	TextDim     = Color3.fromRGB(148, 155, 172),
	Base        = Color3.fromRGB(13, 14, 19),
	Surface     = Color3.fromRGB(255, 255, 255),
	Stroke      = Color3.fromRGB(255, 255, 255),
	Radius      = 9,
	BlurSize    = 16,
	Font        = pickFont("Gotham", Enum.Font.SourceSans),
	FontMedium  = pickFont("GothamMedium", pickFont("GothamSemibold", Enum.Font.SourceSans)),
	FontBold    = pickFont("GothamBold", Enum.Font.SourceSansBold),
	FontMono    = pickFont("Code", Enum.Font.Code),
}

local Ease = {
	Out    = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	In     = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	InOut  = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
	Fast   = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

--──────────────────────────────────────────── acrylic backdrop

local Acrylic = { depth = 0, effect = nil }

local function acrylicPush(size)
	Acrylic.depth += 1
	if not Acrylic.effect then
		Acrylic.effect = create("BlurEffect", {
			Name = "comet_acrylic",
			Size = size or Theme.BlurSize,
			Parent = Lighting,
		})
	else
		Acrylic.effect.Size = math.max(Acrylic.effect.Size, size or Theme.BlurSize)
	end
end

local function acrylicPop()
	Acrylic.depth = math.max(0, Acrylic.depth - 1)
	if Acrylic.depth == 0 and Acrylic.effect then
		Acrylic.effect:Destroy()
		Acrylic.effect = nil
	end
end

--──────────────────────────────────────────── UIlib root

local UIlib = {}
UIlib.Theme = Theme
UIlib.Acrylic = Acrylic

--──────────────────────────────────────────── window

local Window = {}
Window.__index = Window

local SIDES = {
	TopRight    = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16) },
	BottomLeft  = { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -16) },
	BottomRight = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -16) },
	TopLeft     = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 18, 0, 16) },
}

function UIlib:CreateWindow(cfg)
	cfg = cfg or {}

	local state = {
		alive = true,
		conns = {},
		visible = true,
		notifyStack = {},
	}

	local function track(conn)
		state.conns[#state.conns + 1] = conn
		return conn
	end

	local gui = create("ScreenGui", {
		Name = "comet_ui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9999,
		Parent = guiParent(),
	})

	local root = create("CanvasGroup", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(720, 404),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = gui,
	})
	root.Size = UDim2.fromOffset((cfg.Size and cfg.Size.X) or 720, (cfg.Size and cfg.Size.Y) or 404)

	local scale = create("UIScale", { Parent = root, Scale = 0.94 })

	-- soft shadow stack
	for i = 3, 1, -1 do
		local s = create("Frame", {
			Name = "Shadow" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 22 * i, 1, 22 * i),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.86 + (0.03 * (3 - i)),
			ZIndex = 1,
			Parent = root,
		})
		create("UICorner", { Parent = s, CornerRadius = UDim.new(0, Theme.Radius + 8 * i) })
	end

	-- acrylic panel
	local panel = create("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Base,
		BackgroundTransparency = 0.30,
		ZIndex = 2,
		Parent = root,
	})
	create("UICorner", { Parent = panel, CornerRadius = UDim.new(0, Theme.Radius) })
	strokeOf(panel, Theme.Stroke, 0.86, 1)

	local wash = create("Frame", {
		Name = "Wash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = panel,
	})
	create("UICorner", { Parent = wash, CornerRadius = UDim.new(0, Theme.Radius) })
	gradient(wash, 118, {
		{ Color3.fromRGB(255, 255, 255), 0.955 },
		{ Color3.fromRGB(120, 145, 200), 0.905 },
	})

	-- gloss band (static diagonal sheen)
	local gloss = create("Frame", {
		Name = "Gloss",
		Size = UDim2.new(0.62, 0, 1.5, 0),
		Position = UDim2.new(-0.10, 0, -0.25, 0),
		Rotation = -18,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		ZIndex = 4,
		Parent = panel,
	})
	gradient(gloss, 0, {
		{ Color3.fromRGB(255, 255, 255), 1 },
		{ Color3.fromRGB(255, 255, 255), 1 },
	})
	local glossGradient = gloss:FindFirstChildOfClass("UIGradient")
	glossGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.52, 0.80),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1.00, 1),
	})

	-- glare sweep (animated across the whole window)
	local sweep = create("Frame", {
		Name = "Sweep",
		Size = UDim2.new(1.6, 0, 1.6, 0),
		Position = UDim2.new(-0.3, 0, -0.3, 0),
		BackgroundColor3 = Color3.fromRGB(190, 215, 255),
		ZIndex = 5,
		Parent = panel,
	})
	local sweepGradient = create("UIGradient", { Parent = sweep, Rotation = 20 })
	sweepGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	sweepGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1),
		NumberSequenceKeypoint.new(0.44, 1),
		NumberSequenceKeypoint.new(0.50, 0.88),
		NumberSequenceKeypoint.new(0.56, 1),
		NumberSequenceKeypoint.new(1.00, 1),
	})

	-- inner hairline
	local innerLine = create("Frame", {
		Name = "InnerLine",
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = panel,
	})
	create("UICorner", { Parent = innerLine, CornerRadius = UDim.new(0, Theme.Radius - 1) })
	strokeOf(innerLine, Theme.Stroke, 0.94, 1)

	-- chamfer accents (the slanted corner cut reads as one continuous outline)
	local chamfer = 14
	local function accentLine(ax, ay, rot, len)
		local line = create("Frame", {
			Name = "Chamfer",
			AnchorPoint = Vector2.new(ax, ay),
			Position = UDim2.new(ax, 0, ay, 0),
			Size = UDim2.fromOffset(len, 1),
			Rotation = rot,
			BackgroundColor3 = Theme.Stroke,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = panel,
		})
		return line
	end
	accentLine(0, 0, 45, chamfer * 1.42)
	accentLine(1, 0, -45, chamfer * 1.42)
	accentLine(0, 1, -45, chamfer * 1.42)
	accentLine(1, 1, 45, chamfer * 1.42)

	--──────────────────────────────────────── content scaffolding

	local content = create("CanvasGroup", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(1, -64, 1, -120),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		GroupTransparency = 0,
		ZIndex = 10,
		Parent = root,
	})

	local subBar = create("Frame", {
		Name = "SubBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 17),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = root,
	})
	local subLayout = create("UIListLayout", {
		Parent = subBar,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	subLayout.Padding = UDim.new(0, 4)

	local dragZone = create("Frame", {
		Name = "DragZone",
		Size = UDim2.new(1, -140, 0, 50),
		Position = UDim2.fromOffset(70, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = root,
	})

	local notifyHolder = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -60),
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = root,
	})
	create("UIListLayout", {
		Parent = notifyHolder,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})

	--──────────────────────────────────────── window animation

	local function playOpen()
		scale.Scale = 0.94
		root.GroupTransparency = 1
		root.Position = UDim2.new(0.5, 0, 0.5, 14)
		tween(scale, Ease.Spring, { Scale = 1 })
		tween(root, Ease.Out, {
			GroupTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
		})
	end

	local function playClose()
		tween(scale, Ease.In, { Scale = 0.96 })
		tween(root, Ease.In, {
			GroupTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 10),
		})
	end

	--──────────────────────────────────────── window state

	local win = setmetatable({
		Gui = gui,
		Root = root,
		Panel = panel,
		Content = content,
		Title = cfg.Title or "comet",
		Size = root.Size,
		Tabs = {},
		ActiveTab = nil,
		ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift,
	}, Window)

	win._state = state
	win._track = track
	win._subBar = subBar
	win._selectTab = nil

	function win:SetVisible(v)
		if not state.alive then return end
		if v == state.visible then return end
		state.visible = v
		if v then
			gui.Enabled = true
			playOpen()
			acrylicPush(Theme.BlurSize)
		else
			acrylicPop()
			playClose()
			task.delay(0.18, function()
				if state.alive and not state.visible then
					gui.Enabled = false
				end
			end)
		end
	end

	function win:Destroy()
		if not state.alive then return end
		state.alive = false
		if state.visible then
			acrylicPop()
		end
		for _, c in ipairs(state.conns) do
			pcall(function() c:Disconnect() end)
		end
		state.conns = {}
		pcall(function() gui:Destroy() end)
	end

	function win:Notify(opt)
		opt = opt or {}
		local card = create("Frame", {
			Name = "Notify",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Base,
			BackgroundTransparency = 0.12,
			Parent = notifyHolder,
		})
		create("UICorner", { Parent = card, CornerRadius = UDim.new(0, 8) })
		strokeOf(card, Theme.Accent, 0.55, 1)

		local body = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = card,
		})
		create("UIPadding", {
			Parent = body,
			PaddingTop = UDim.new(0, 9),
			PaddingBottom = UDim.new(0, 9),
			PaddingLeft = UDim.new(0, 11),
			PaddingRight = UDim.new(0, 11),
		})
		create("UIListLayout", { Parent = body, Padding = UDim.new(0, 2) })

		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 15),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			Text = opt.Title or "comet",
			TextSize = 11,
			TextColor3 = Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		})
		create("TextLabel", {
			Size = UDim2.new(1, -2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Theme.FontMedium,
			Text = opt.Text or "",
			TextSize = 12,
			TextWrapped = true,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = body,
		})

		card.Position = UDim2.new(1, 30, 0, 0)
		tween(card, Ease.Out, { Position = UDim2.new(0, 0, 0, 0) })

		task.delay(opt.Duration or 3, function()
			if not state.alive then return end
			tween(card, Ease.In, { Position = UDim2.new(1, 40, 0, 0) })
			task.delay(0.18, function()
				if card and card.Parent then
					card:Destroy()
				end
			end)
		end)
	end

	--──────────────────────────────────────── dragging

	local dragging, dragStart, dragOrigin = false, nil, nil
	track(dragZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			dragOrigin = root.Position
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			root.Position = UDim2.new(
				dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X,
				dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y
			)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	--──────────────────────────────────────── toggle key

	track(UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == win.ToggleKey then
			win:SetVisible(not state.visible)
		end
	end))

	--──────────────────────────────────────── corner tabs

	local tabOrder = 0

	function win:Tab(opt)
		opt = opt or {}
		tabOrder += 1
		local side = SIDES[opt.Side or "TopRight"]
		local name = opt.Name or ("Tab " .. tabOrder)

		local btn = create("TextButton", {
			Name = "Tab_" .. name,
			AnchorPoint = side.AnchorPoint,
			Position = side.Position,
			Size = UDim2.fromOffset(92, 28),
			BackgroundColor3 = Theme.Surface,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 30,
			LayoutOrder = tabOrder,
			Parent = root,
		})
		create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 6) })
		local btnStroke = strokeOf(btn, Theme.Stroke, 0.96, 1)

		local label = create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.FontMedium,
			Text = name:upper(),
			TextSize = 11,
			TextColor3 = Theme.TextDim,
			Parent = btn,
		})
		create("UIScale", { Parent = label, Scale = 1 })

		local glow = create("Frame", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -1),
			Size = UDim2.fromOffset(0, 2),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			ZIndex = 31,
			Parent = btn,
		})
		create("UICorner", { Parent = glow, CornerRadius = UDim.new(1, 0) })

		local tab = {
			Name = name,
			Button = btn,
			Label = label,
			Glow = glow,
			Subtabs = {},
			Active = false,
			Window = win,
		}

		local function setHover(on)
			if tab.Active then return end
			tween(btn, Ease.Fast, {
				BackgroundTransparency = on and 0.93 or 1,
				BackgroundColor3 = Theme.Surface,
			})
			tween(label, Ease.Fast, {
				TextColor3 = on and Theme.Text or Theme.TextDim,
			})
		end

		track(btn.MouseEnter:Connect(function() setHover(true) end))
		track(btn.MouseLeave:Connect(function() setHover(false) end))

		track(btn.MouseButton1Down:Connect(function()
			tween(btn, Ease.Fast, { BackgroundTransparency = 0.90 })
		end))
		track(btn.MouseButton1Up:Connect(function()
			tween(btn, Ease.Fast, { BackgroundTransparency = tab.Active and 0.90 or 1 })
		end))

		track(btn.MouseButton1Click:Connect(function()
			win:SelectTab(tab)
		end))

		tab.SetActive = function(self, active)
			self.Active = active
			tween(btn, Ease.Out, {
				BackgroundTransparency = active and 0.90 or 1,
				BackgroundColor3 = active and Theme.Accent or Theme.Surface,
			})
			tween(label, Ease.Out, {
				TextColor3 = active and Theme.Text or Theme.TextDim,
				TextSize = active and 12 or 11,
			})
			tween(glow, Ease.Out, {
				Size = UDim2.fromOffset(active and 26 or 0, 2),
				BackgroundTransparency = active and 0 or 1,
			})
			tween(btnStroke, Ease.Out, {
				Transparency = active and 0.55 or 0.96,
				Color = active and Theme.Accent or Theme.Stroke,
			})
		end

		--──────────────────────────────────── subtabs

		function tab:SubTab(subName)
			local frame = create("ScrollingFrame", {
				Name = "Sub_" .. tostring(subName),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Theme.Accent,
				ScrollBarImageTransparency = 0.35,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Visible = false,
				Parent = content,
			})
			create("UIPadding", {
				Parent = frame,
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			})
			create("UIListLayout", {
				Parent = frame,
				Padding = UDim.new(0, 9),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})

			local sub = {
				Name = subName,
				Frame = frame,
				Tab = tab,
				Sections = {},
			}

			table.insert(tab.Subtabs, sub)
			if win.ActiveTab == tab then
				win:SelectTab(tab, true)
			end
			return setmetatable(sub, SubTab)
		end

		table.insert(win.Tabs, tab)
		win:SelectTab(tab, true)
		return tab
	end

	--──────────────────────────────────────── tab selection

	local fadeToken = 0

	function win:SelectTab(tab, silent)
		if not tab then return end
		if win.ActiveTab == tab and not silent then return end

		for _, t in ipairs(win.Tabs) do
			t.SetActive(t, t == tab)
		end
		win.ActiveTab = tab

		-- rebuild sub tab strip
		for _, child in ipairs(subBar:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		local order = 0
		for _, sub in ipairs(tab.Subtabs) do
			order += 1
			local sb = create("TextButton", {
				Name = "SubTab_" .. tostring(sub.Name),
				Size = UDim2.fromOffset(0, 26),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Surface,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = order,
				Parent = subBar,
			})
			create("UIPadding", {
				Parent = sb,
				PaddingLeft = UDim.new(0, 11),
				PaddingRight = UDim.new(0, 11),
			})
			create("UICorner", { Parent = sb, CornerRadius = UDim.new(0, 5) })
			local sStroke = strokeOf(sb, Theme.Stroke, 0.95, 1)

			local sLabel = create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = Theme.FontMedium,
				Text = tostring(sub.Name),
				TextSize = 11,
				TextColor3 = Theme.TextDim,
				Parent = sb,
			})
			local sGlow = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.fromOffset(0, 2),
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 1,
			})
			create("UICorner", { Parent = sGlow, CornerRadius = UDim.new(1, 0) })

			local function paint(active)
				tween(sb, Ease.Out, {
					BackgroundTransparency = active and 0.90 or 1,
					BackgroundColor3 = active and Theme.Accent or Theme.Surface,
				})
				tween(sLabel, Ease.Out, { TextColor3 = active and Theme.Text or Theme.TextDim })
				tween(sGlow, Ease.Out, {
					Size = UDim2.fromOffset(active and 18 or 0, 2),
					BackgroundTransparency = active and 0 or 1,
				})
				tween(sStroke, Ease.Out, {
					Transparency = active and 0.55 or 0.95,
					Color = active and Theme.Accent or Theme.Stroke,
				})
			end

			track(sb.MouseEnter:Connect(function()
				if tab.ActiveSub ~= sub then
					tween(sLabel, Ease.Fast, { TextColor3 = Theme.Text })
				end
			end))
			track(sb.MouseLeave:Connect(function()
				if tab.ActiveSub ~= sub then
					tween(sLabel, Ease.Fast, { TextColor3 = Theme.TextDim })
				end
			end))
			track(sb.MouseButton1Click:Connect(function()
				win:SelectSub(tab, sub)
			end))

			sb:SetAttribute("SubIndex", order)
			sub._button = { sb = sb, paint = paint, label = sLabel }
		end

		-- restore previous sub selection or first
		local target = tab.ActiveSub or tab.Subtabs[1]
		if target then
			win:SelectSub(tab, target, silent)
		end
	end

	function win:SelectSub(tab, sub, silent)
		if not tab or not sub then return end
		tab.ActiveSub = sub

		for _, s in ipairs(tab.Subtabs) do
			if s._button then
				s._button.paint(s == sub)
			end
		end

		local token = fadeToken + 1
		fadeToken = token

		if silent then
			for _, s in ipairs(tab.Subtabs) do
				s.Frame.Visible = (s == sub)
			end
			content.GroupTransparency = 0
			return
		end

		tween(content, Ease.Fast, { GroupTransparency = 1 })
		task.delay(0.09, function()
			if not state.alive or fadeToken ~= token then return end
			for _, s in ipairs(tab.Subtabs) do
				s.Frame.Visible = (s == sub)
			end
			tween(content, Ease.Out, { GroupTransparency = 0 })
		end)
	end

	--──────────────────────────────────────── sweep animation

	track(RunService.Heartbeat:Connect(function(dt)
		if not state.alive or not state.visible then return end
		local phase = (tick() * 0.11) % 1
		sweepGradient.Offset = Vector2.new(-1.1 + phase * 2.6, 0)
	end))

	--──────────────────────────────────────── boot

	acrylicPush(Theme.BlurSize)
	playOpen()

	if cfg.OpenNotification ~= false then
		task.delay(0.35, function()
			if state.alive then
				win:Notify({
					Title = win.Title,
					Text = cfg.Subtitle or "loaded",
				})
			end
		end)
	end

	return win
end

--──────────────────────────────────────────── subtab / section

local SubTab = {}
SubTab.__index = SubTab

local Section = {}
Section.__index = Section

local function sectionRow(parent, name, description, height)
	height = height or (description and 46 or 36)
	local row = create("Frame", {
		Name = "Row",
		Size = UDim2.new(1, -4, 0, height),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local textTop = description and 6 or 0
	create("TextLabel", {
		Size = UDim2.new(1, -110, 0, 16),
		Position = UDim2.fromOffset(0, textTop),
		BackgroundTransparency = 1,
		Font = Theme.FontMedium,
		Text = name,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = row,
	})
	if description then
		create("TextLabel", {
			Size = UDim2.new(1, -110, 0, 14),
			Position = UDim2.fromOffset(0, textTop + 17),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			Text = description,
			TextSize = 11,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = row,
		})
	end
	return row
end

function SubTab:Section(name)
	local holder = create("Frame", {
		Name = "Section_" .. tostring(name),
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.965,
		Parent = self.Frame,
	})
	create("UICorner", { Parent = holder, CornerRadius = UDim.new(0, 8) })
	strokeOf(holder, Theme.Stroke, 0.94, 1)
	create("UIPadding", {
		Parent = holder,
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})
	create("UIListLayout", {
		Parent = holder,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	create("TextLabel", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 15),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = string.upper(tostring(name)),
		TextSize = 10,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local body = create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	create("UIListLayout", {
		Parent = body,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	table.insert(self.Sections, holder)
	return setmetatable({ Frame = body, Holder = holder }, Section)
end

--──────────────────────────────────────────── components

function Section:Toggle(opt)
	opt = opt or {}
	local value = opt.Default == true
	local row = sectionRow(self.Frame, opt.Name or "Toggle", opt.Description)

	local track = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = value and Theme.Accent or Color3.fromRGB(48, 51, 62),
		BackgroundTransparency = value and 0.1 or 0.25,
		Parent = row,
	})
	create("UICorner", { Parent = track, CornerRadius = UDim.new(1, 0) })
	strokeOf(track, Theme.Stroke, 0.92, 1)

	local knob = create("Frame", {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, value and 21 or 3, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = track,
	})
	create("UICorner", { Parent = knob, CornerRadius = UDim.new(1, 0) })
	create("UIScale", { Parent = knob, Scale = 1 })

	local hit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})

	local api = { Value = value }

	local function apply(v, silent)
		api.Value = v
		tween(track, Ease.Out, {
			BackgroundColor3 = v and Theme.Accent or Color3.fromRGB(48, 51, 62),
			BackgroundTransparency = v and 0.1 or 0.25,
		})
		tween(knob, Ease.Spring, { Position = UDim2.new(0, v and 21 or 3, 0.5, 0) })
		if not silent and opt.Callback then
			task.spawn(opt.Callback, v)
		end
	end

	hit.MouseButton1Click:Connect(function()
		apply(not api.Value)
	end)
	hit.MouseEnter:Connect(function()
		tween(knob, Ease.Fast, { BackgroundColor3 = Color3.fromRGB(235, 242, 255) })
	end)
	hit.MouseLeave:Connect(function()
		tween(knob, Ease.Fast, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
	end)

	api.Set = function(v) apply(v, true) end
	api.Row = row
	return api
end

function Section:Slider(opt)
	opt = opt or {}
	local min = opt.Min or 0
	local max = opt.Max or 100
	local step = opt.Step
	local value = math.clamp(opt.Default or min, min, max)

	local row = create("Frame", {
		Size = UDim2.new(1, -4, 0, 44),
		BackgroundTransparency = 1,
		Parent = self.Frame,
	})
	local title = create("TextLabel", {
		Size = UDim2.new(1, -80, 0, 17),
		BackgroundTransparency = 1,
		Font = Theme.FontMedium,
		Text = opt.Name or "Slider",
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = row,
	})
	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 0),
		Size = UDim2.fromOffset(78, 17),
		BackgroundTransparency = 1,
		Font = Theme.FontMono,
		Text = formatNumber(value) .. (opt.Suffix or ""),
		TextSize = 12,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = row,
	})

	local track = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, -2, 0, 12),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local rail = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(58, 62, 76),
		BackgroundTransparency = 0.25,
		Parent = track,
	})
	create("UICorner", { Parent = rail, CornerRadius = UDim.new(1, 0) })

	local fill = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		Parent = rail,
	})
	create("UICorner", { Parent = fill, CornerRadius = UDim.new(1, 0) })

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = track,
	})
	create("UICorner", { Parent = knob, CornerRadius = UDim.new(1, 0) })
	create("UIScale", { Parent = knob, Scale = 1 })
	strokeOf(knob, Theme.Accent, 0.2, 2)

	local api = { Value = value }

	local function percentOf(v)
		if max == min then return 0 end
		return (v - min) / (max - min)
	end

	local function paint()
		local p = percentOf(api.Value)
		fill.Size = UDim2.new(p, 0, 1, 0)
		knob.Position = UDim2.new(p, 0, 0.5, 0)
		valueLabel.Text = formatNumber(api.Value) .. (opt.Suffix or "")
	end

	local function commit(v, silent)
		v = math.clamp(v, min, max)
		if step then v = math.clamp(round(v, step), min, max) end
		api.Value = v
		paint()
		if not silent and opt.Callback then
			task.spawn(opt.Callback, v)
		end
	end

	paint()

	local dragging = false

	local function fromInput(input)
		local abs = track.AbsolutePosition
		local w = track.AbsoluteSize.X
		if w <= 0 then return end
		local p = math.clamp((input.Position.X - abs.X) / w, 0, 1)
		commit(min + (max - min) * p)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tween(knob, Ease.Fast, { Size = UDim2.fromOffset(13, 13) })
			fromInput(input)
		end
	end)

	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			tween(knob, Ease.Out, { Size = UDim2.fromOffset(11, 11) })
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			fromInput(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob, Ease.Out, { Size = UDim2.fromOffset(11, 11) })
		end
	end)

	api.Set = function(v) commit(v, true) end
	api.Row = row
	return api
end

function Section:Dropdown(opt)
	opt = opt or {}
	local items = opt.Options or {}
	local selected = opt.Default or items[1]
	local isOpen = false
	local rowHeight = 36
	local itemHeight = 26

	local holder = create("Frame", {
		Size = UDim2.new(1, -4, 0, rowHeight),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Frame,
	})

	local header = create("TextButton", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.97,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	})
	create("UICorner", { Parent = header, CornerRadius = UDim.new(0, 6) })
	strokeOf(header, Theme.Stroke, 0.93, 1)

	create("TextLabel", {
		Size = UDim2.new(0.5, -8, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontMedium,
		Text = opt.Name or "Dropdown",
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local selectedLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -26, 0, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = tostring(selected),
		TextSize = 12,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	local chevron = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "v",
		TextSize = 10,
		TextColor3 = Theme.TextDim,
		Parent = header,
	})
	create("UIScale", { Parent = chevron, Scale = 1 })

	local list = create("Frame", {
		Position = UDim2.fromOffset(0, rowHeight + 4),
		Size = UDim2.new(1, 0, 0, #items * itemHeight),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	create("UIListLayout", { Parent = list, Padding = UDim.new(0, 2) })

	local api = { Value = selected }

	local buttons = {}
	local function paintSelection()
		for value, btn in pairs(buttons) do
			local on = value == api.Value
			tween(btn, Ease.Fast, {
				BackgroundTransparency = on and 0.90 or 1,
				BackgroundColor3 = on and Theme.Accent or Theme.Surface,
			})
			local lbl = btn:FindFirstChildOfClass("TextLabel")
			if lbl then
				tween(lbl, Ease.Fast, { TextColor3 = on and Theme.Text or Theme.TextDim })
			end
		end
	end

	for _, item in ipairs(items) do
		local btn = create("TextButton", {
			Size = UDim2.new(1, 0, 0, itemHeight),
			BackgroundColor3 = Theme.Surface,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = list,
		})
		create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 5) })
		create("TextLabel", {
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			Text = tostring(item),
			TextSize = 12,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})
		buttons[item] = btn
		btn.MouseButton1Click:Connect(function()
			api.Value = item
			selectedLabel.Text = tostring(item)
			paintSelection()
			if opt.Callback then
				task.spawn(opt.Callback, item)
			end
		end)
	end
	paintSelection()

	local function setOpen(open)
		isOpen = open
		local target = open and (rowHeight + 4 + #items * itemHeight + 4) or rowHeight
		tween(holder, Ease.Out, { Size = UDim2.new(1, -4, 0, target) })
		chevron.Text = open and "^" or "v"
		tween(chevron, Ease.Out, {
			TextColor3 = open and Theme.Accent or Theme.TextDim,
		})
	end

	header.MouseButton1Click:Connect(function()
		setOpen(not isOpen)
	end)
	header.MouseEnter:Connect(function()
		tween(header, Ease.Fast, { BackgroundTransparency = 0.93 })
	end)
	header.MouseLeave:Connect(function()
		tween(header, Ease.Fast, { BackgroundTransparency = 0.97 })
	end)

	api.Set = function(v)
		if buttons[v] then
			api.Value = v
			selectedLabel.Text = tostring(v)
			paintSelection()
		end
	end
	api.Row = holder
	return api
end

function Section:Keybind(opt)
	opt = opt or {}
	local key = opt.Default or Enum.KeyCode.RightShift
	local listening = false

	local row = sectionRow(self.Frame, opt.Name or "Keybind", opt.Description)

	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(74, 24),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.94,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 5) })
	local btnStroke = strokeOf(btn, Theme.Stroke, 0.9, 1)

	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.FontMono,
		Text = tostring(key),
		TextSize = 11,
		TextColor3 = Theme.Text,
		Parent = btn,
	})

	local api = { Value = key }

	local function setListening(on)
		listening = on
		label.Text = on and "..." or tostring(api.Value)
		tween(btn, Ease.Fast, {
			BackgroundTransparency = on and 0.85 or 0.94,
			BackgroundColor3 = on and Theme.Accent or Theme.Surface,
		})
		tween(btnStroke, Ease.Fast, {
			Transparency = on and 0.4 or 0.9,
			Color = on and Theme.Accent or Theme.Stroke,
		})
	end

	btn.MouseButton1Click:Connect(function()
		setListening(not listening)
	end)

	local conn
	conn = UserInputService.InputBegan:Connect(function(input, gpe)
		if not listening then return end
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			api.Value = input.KeyCode
			setListening(false)
			if opt.Callback then
				task.spawn(opt.Callback, input.KeyCode)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2 then
			api.Value = input.UserInputType
			setListening(false)
			if opt.Callback then
				task.spawn(opt.Callback, input.UserInputType)
			end
		end
	end)

	api.Row = row
	api.Connection = conn
	return api
end

function Section:Button(opt)
	opt = opt or {}
	local btn = create("TextButton", {
		Size = UDim2.new(1, -4, 0, 30),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.95,
		AutoButtonColor = false,
		Text = "",
		Parent = self.Frame,
	})
	create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 6) })
	local stroke = strokeOf(btn, Theme.Stroke, 0.9, 1)
	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.FontMedium,
		Text = opt.Name or "Button",
		TextSize = 12,
		TextColor3 = Theme.Text,
		Parent = btn,
	})
	create("UIScale", { Parent = btn, Scale = 1 })

	btn.MouseEnter:Connect(function()
		tween(btn, Ease.Fast, { BackgroundTransparency = 0.88, BackgroundColor3 = Theme.Accent })
		tween(stroke, Ease.Fast, { Transparency = 0.55, Color = Theme.Accent })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, Ease.Fast, { BackgroundTransparency = 0.95, BackgroundColor3 = Theme.Surface })
		tween(stroke, Ease.Fast, { Transparency = 0.9, Color = Theme.Stroke })
	end)
	btn.MouseButton1Down:Connect(function()
		tween(btn:FindFirstChildOfClass("UIScale"), Ease.Fast, { Scale = 0.98 })
	end)
	btn.MouseButton1Up:Connect(function()
		tween(btn:FindFirstChildOfClass("UIScale"), Ease.Spring, { Scale = 1 })
	end)
	btn.MouseButton1Click:Connect(function()
		if opt.Callback then
			task.spawn(opt.Callback)
		end
	end)

	return { Row = btn, Label = label }
end

function Section:Textbox(opt)
	opt = opt or {}
	local row = sectionRow(self.Frame, opt.Name or "Textbox", opt.Description, 40)

	local box = create("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(130, 24),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.95,
		Font = Theme.Font,
		PlaceholderText = opt.Placeholder or "input",
		PlaceholderColor3 = Theme.TextDim,
		Text = opt.Default or "",
		TextSize = 12,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = row,
	})
	create("UIPadding", {
		Parent = box,
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	create("UICorner", { Parent = box, CornerRadius = UDim.new(0, 5) })
	local stroke = strokeOf(box, Theme.Stroke, 0.9, 1)

	box.Focused:Connect(function()
		tween(box, Ease.Fast, { BackgroundTransparency = 0.9 })
		tween(stroke, Ease.Fast, { Transparency = 0.5, Color = Theme.Accent })
	end)
	box.FocusLost:Connect(function()
		tween(box, Ease.Fast, { BackgroundTransparency = 0.95 })
		tween(stroke, Ease.Fast, { Transparency = 0.9, Color = Theme.Stroke })
		if opt.Callback then
			task.spawn(opt.Callback, box.Text)
		end
	end)

	return { Row = row, Box = box, Value = box.Text }
end

function Section:Label(text)
	local label = create("TextLabel", {
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = text or "",
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = self.Frame,
	})
	return { Row = label }
end

function Section:Divider()
	local line = create("Frame", {
		Size = UDim2.new(1, -4, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Parent = self.Frame,
	})
	return { Row = line }
end

return UIlib
