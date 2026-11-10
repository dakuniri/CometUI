--═══════════════════════════════════════════════════════════════════════
--  comet · sample
--  UIlib を使って組んだ最小構成のサンプル: Fly / ESP / Aimbot
--
--  使い方:
--      loadstring(game:HttpGet(
--          "https://raw.githubusercontent.com/dakuniri/CometUI/refs/heads/main/sample.luau"
--      ))()
--
--  または、このフォルダで:
--      loadstring(readfile("UI/sample.luau"))()
--
--  実行環境: Roblox エグゼキュータ（Drawing があれば 2D ボックス ESP、
--  無ければ Highlight + BillboardGui に自動フォールバック）
--═══════════════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local LP = Players.LocalPlayer
local CAMERA = Workspace.CurrentCamera

local HAS_DRAWING = (type(Drawing) == "table")

--──────────────────────────────────────────── UIlib 読み込み

local function loadUIlib()
	-- 1) ローカルの UI/main.luau
	local ok, lib = pcall(function()
		if isfile and isfile("UI/main.luau") then
			return loadstring(readfile("UI/main.luau"))()
		end
		return nil
	end)
	if ok and type(lib) == "table" then
		return lib
	end

	-- 2) GitHub raw
	local ok2, remote = pcall(function()
		return loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/dakuniri/CometUI/refs/heads/main/main.luau"
		))()
	end)
	if ok2 and type(remote) == "table" then
		return remote
	end

	error("comet UIlib を読み込めなかった")
end

local UIlib = loadUIlib()

--──────────────────────────────────────────── 設定

local Config = {
	aimbot = {
		enabled = false,
		hold = true,
		key = Enum.KeyCode.E,
		fov = 120,
		smooth = 0.65,
		part = "Head",
		teamCheck = true,
		visibleCheck = true,
		held = false,
	},
	esp = {
		enabled = false,
		name = true,
		health = true,
		distance = true,
		maxDistance = 600,
		color = Color3.fromRGB(138, 170, 255),
	},
	fly = {
		enabled = false,
		key = Enum.KeyCode.F,
		speed = 60,
	},
}

local ALIVE = true
local CONNS = {}

local function track(conn)
	CONNS[#CONNS + 1] = conn
	return conn
end

local function disconnectAll()
	ALIVE = false
	for _, c in ipairs(CONNS) do
		pcall(function() c:Disconnect() end)
	end
	CONNS = {}
end

--──────────────────────────────────────────── 共通ヘルパ

local function isAlive(player)
	local char = player.Character
	if not char then return false, nil, nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false, char, humanoid end
	return true, char, humanoid
end

local function sameTeam(player)
	if not Config.aimbot.teamCheck then return false end
	if not player.Team or not LP.Team then return false end
	return player.Team == LP.Team
end

local function isTeammate(player)
	if not player.Team or not LP.Team then return false end
	return player.Team == LP.Team
end

local function targetPart(char)
	return char:FindFirstChild(Config.aimbot.part)
		or char:FindFirstChild("Head")
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("HumanoidRootPart")
end

local function worldToViewport(pos)
	local v, onScreen = CAMERA:WorldToViewportPoint(pos)
	if not onScreen then return nil end
	return Vector2.new(v.X, v.Y), v.Z
end

local visibilityParams = RaycastParams.new()
visibilityParams.FilterType = Enum.RaycastFilterType.Exclude
visibilityParams.IgnoreWater = true

local function canSee(char, part)
	if not Config.aimbot.visibleCheck then return true end
	visibilityParams.FilterDescendantsInstances = { LP.Character, char }
	local hit = Workspace:Raycast(CAMERA.CFrame.Position, part.Position - CAMERA.CFrame.Position, visibilityParams)
	if not hit then return true end
	return hit.Instance:IsDescendantOf(char)
end

--──────────────────────────────────────────── ESP

local espObjects = {}

local function destroyESP()
	for player, obj in pairs(espObjects) do
		if HAS_DRAWING then
			for _, d in pairs(obj) do
				pcall(function() d:Remove() end)
			end
		else
			pcall(function() obj.highlight:Destroy() end)
			pcall(function() obj.billboard:Destroy() end)
		end
		espObjects[player] = nil
	end
end

local function makeESP(player)
	if HAS_DRAWING then
		local obj = {
			box       = Drawing.new("Square"),
			name      = Drawing.new("Text"),
			healthBg  = Drawing.new("Square"),
			healthFill= Drawing.new("Square"),
			distance  = Drawing.new("Text"),
		}
		obj.box.Thickness = 1
		obj.box.Filled = false
		obj.box.Transparency = 1

		obj.healthBg.Filled = true
		obj.healthBg.Color = Color3.fromRGB(20, 22, 28)
		obj.healthBg.Transparency = 0.35

		obj.healthFill.Filled = true
		obj.healthFill.Transparency = 0.15

		obj.name.Center = true
		obj.name.Outline = true
		obj.name.Font = 2
		obj.name.Size = 13
		obj.name.Transparency = 1

		obj.distance.Center = true
		obj.distance.Outline = true
		obj.distance.Font = 2
		obj.distance.Size = 11
		obj.distance.Color = Color3.fromRGB(200, 205, 215)
		obj.distance.Transparency = 1

		espObjects[player] = obj
		return obj
	end

	local char = player.Character
	if not char then return nil end

	local highlight = Instance.new("Highlight")
	highlight.Name = "comet_esp"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Config.esp.color
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = char
	highlight.Parent = char

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "comet_esp_tag"
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = Config.esp.maxDistance
	billboard.Parent = char

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Config.esp.color
	label.TextStrokeTransparency = 0.3
	label.Text = player.Name
	label.Parent = billboard

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(0.25, 0, 0, 22)
	barBg.Size = UDim2.new(0.5, 0, 0, 4)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	barBg.BorderSizePixel = 0
	barBg.Parent = billboard
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(70, 220, 120)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

	local obj = { character = char, highlight = highlight, billboard = billboard, label = label, barBg = barBg, barFill = barFill }
	espObjects[player] = obj
	return obj
end

local function hideESPObject(obj)
	if HAS_DRAWING then
		for _, d in pairs(obj) do
			if d.Visible then d.Visible = false end
		end
	else
		obj.billboard.Enabled = false
		obj.highlight.Enabled = false
	end
end

local function cleanupStaleESP()
	for player, obj in pairs(espObjects) do
		local alive, char = isAlive(player)
		local stale = not player.Parent
			or not char
			or not alive
			or (char ~= obj.character and not HAS_DRAWING)

		if not stale and not HAS_DRAWING and obj.highlight.Adornee ~= char then
			stale = true
		end

		if stale then
			if HAS_DRAWING then
				for _, d in pairs(obj) do
					pcall(function() d:Remove() end)
				end
			else
				pcall(function() obj.highlight:Destroy() end)
				pcall(function() obj.billboard:Destroy() end)
			end
			espObjects[player] = nil
		end
	end
end

local function updateESP()
	if not Config.esp.enabled then
		if next(espObjects) then destroyESP() end
		return
	end

	cleanupStaleESP()

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LP or isTeammate(player) then
			if espObjects[player] then hideESPObject(espObjects[player]) end
			continue
		end

		local alive, char, humanoid = isAlive(player)
		if not alive then
			if espObjects[player] then hideESPObject(espObjects[player]) end
			continue
		end

		local root = char:FindFirstChild("HumanoidRootPart")
		local head = char:FindFirstChild("Head")
		if not root or not head then continue end

		local distance = (CAMERA.CFrame.Position - root.Position).Magnitude
		if distance > Config.esp.maxDistance then
			if espObjects[player] then hideESPObject(espObjects[player]) end
			continue
		end

		local top = worldToViewport(head.Position + Vector3.new(0, 0.8, 0))
		local bottom = worldToViewport(root.Position - Vector3.new(0, 2.6, 0))
		if not top or not bottom then
			if espObjects[player] then hideESPObject(espObjects[player]) end
			continue
		end

		local height = math.abs(bottom.Y - top.Y)
		local width = height * 0.52
		local x = (top.X + bottom.X) / 2 - width / 2
		local y = math.min(top.Y, bottom.Y)

		local obj = espObjects[player]
		if not obj then
			obj = makeESP(player)
			if not obj then continue end
		end

		if HAS_DRAWING then
			obj.box.Visible = true
			obj.box.Color = Config.esp.color
			obj.box.Position = Vector2.new(x, y)
			obj.box.Size = Vector2.new(width, height)

			if Config.esp.name then
				obj.name.Visible = true
				obj.name.Text = player.Name
				obj.name.Color = Config.esp.color
				obj.name.Position = Vector2.new((top.X + bottom.X) / 2, y - 16)
			else
				obj.name.Visible = false
			end

			if Config.esp.health and humanoid then
				local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
				obj.healthBg.Visible = true
				obj.healthFill.Visible = true
				obj.healthBg.Position = Vector2.new(x - 6, y)
				obj.healthBg.Size = Vector2.new(3, height)
				obj.healthFill.Position = Vector2.new(x - 6, y + height * (1 - frac))
				obj.healthFill.Size = Vector2.new(3, height * frac)
				obj.healthFill.Color = Color3.fromRGB(70, 220, 120):Lerp(Color3.fromRGB(230, 70, 70), 1 - frac)
			else
				obj.healthBg.Visible = false
				obj.healthFill.Visible = false
			end

			if Config.esp.distance then
				obj.distance.Visible = true
				obj.distance.Text = string.format("%d m", math.floor(distance))
				obj.distance.Position = Vector2.new((top.X + bottom.X) / 2, y + height + 2)
			else
				obj.distance.Visible = false
			end
		else
			obj.highlight.Enabled = true
			obj.highlight.OutlineColor = Config.esp.color
			obj.billboard.Enabled = true
			obj.billboard.MaxDistance = Config.esp.maxDistance
			obj.label.Visible = Config.esp.name
			obj.label.Text = player.Name
			obj.label.TextColor3 = Config.esp.color
			obj.barBg.Visible = Config.esp.health
			if humanoid and humanoid.MaxHealth > 0 then
				obj.barFill.Size = UDim2.fromScale(
					math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1
				)
			end
		end
	end
end

--──────────────────────────────────────────── Aimbot

local aimTarget = nil

local fovCircleGui = Instance.new("ScreenGui")
fovCircleGui.Name = "comet_fov"
fovCircleGui.IgnoreGuiInset = true
fovCircleGui.ResetOnSpawn = false
fovCircleGui.DisplayOrder = 9998
fovCircleGui.Parent = LP:WaitForChild("PlayerGui")

local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.Parent = fovCircleGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Config.esp.color
fovStroke.Thickness = 1
fovStroke.Transparency = 0.35
fovStroke.Parent = fovCircle

local function updateFovCircle()
	local size = Config.aimbot.fov * 2
	fovCircle.Size = UDim2.fromOffset(size, size)
	fovCircle.Visible = Config.aimbot.enabled
	fovCircleGui.Enabled = Config.aimbot.enabled
end

local function findTarget()
	local viewport = CAMERA.ViewportSize
	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

	local best, bestDist = nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LP or sameTeam(player) then continue end

		local alive, char = isAlive(player)
		if not alive then continue end

		local part = targetPart(char)
		if not part then continue end
		if not canSee(char, part) then continue end

		local screen = worldToViewport(part.Position)
		if not screen then continue end

		local dist = (screen - center).Magnitude
		if dist <= Config.aimbot.fov and dist < bestDist then
			best = { player = player, part = part, screen = screen }
			bestDist = dist
		end
	end

	return best
end

local function updateAimbot()
	local shouldAim = Config.aimbot.enabled
		and (not Config.aimbot.hold or Config.aimbot.held)

	if not shouldAim then
		aimTarget = nil
		return
	end

	aimTarget = findTarget()
	if not aimTarget then return end

	local desired = CFrame.lookAt(CAMERA.CFrame.Position, aimTarget.part.Position)
	local factor = 1 - math.clamp(Config.aimbot.smooth / 100, 0, 0.98)
	CAMERA.CFrame = CAMERA.CFrame:Lerp(desired, factor)
end

--──────────────────────────────────────────── Fly

local flyConn = nil

local function setFly(on)
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	Config.fly.enabled = on

	if on then
		hrp.Anchored = true
		if flyConn then flyConn:Disconnect() end

		flyConn = RunService.RenderStepped:Connect(function(dt)
			if not Config.fly.enabled then return end
			local c = LP.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			if not root then return end

			local move = Vector3.zero
			local look = CAMERA.CFrame.LookVector
			local right = CAMERA.CFrame.RightVector

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				move *= 2
			end

			if move.Magnitude > 0 then
				move = move.Unit
			end

			root.CFrame = root.CFrame + move * Config.fly.speed * dt
			root.AssemblyLinearVelocity = Vector3.zero
		end)
	else
		if flyConn then
			flyConn:Disconnect()
			flyConn = nil
		end
		hrp.Anchored = false
	end
end

--──────────────────────────────────────────── 入力

track(UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if UserInputService:GetFocusedTextBox() then return end

	if input.KeyCode == Config.aimbot.key then
		Config.aimbot.held = true
	end
	if input.KeyCode == Config.fly.key then
		setFly(not Config.fly.enabled)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Config.aimbot.key then
		Config.aimbot.held = false
	end
end))

-- キャラクタ再生成時に fly を張り直す
track(LP.CharacterAdded:Connect(function()
	task.wait(0.5)
	if Config.fly.enabled then
		setFly(false)
		setFly(true)
	end
end))

--──────────────────────────────────────────── メインループ

track(RunService.RenderStepped:Connect(function()
	if not ALIVE then return end
	CAMERA = Workspace.CurrentCamera
	if not CAMERA then return end
	updateESP()
	updateAimbot()
	updateFovCircle()
end))

--──────────────────────────────────────────── UI

local win = UIlib:CreateWindow({
	Title = "comet",
	Subtitle = "sample loaded",
	Size = Vector2.new(720, 404),
})

--────────────────── Combat / Aimbot

local combat = win:Tab({ Name = "Combat", Side = "TopRight" })
local aimSub = combat:SubTab("Aimbot")
local aimSec = aimSub:Section("Aimbot")

aimSec:Toggle({
	Name = "Enabled",
	Default = Config.aimbot.enabled,
	Callback = function(v) Config.aimbot.enabled = v end,
})

aimSec:Toggle({
	Name = "Hold to Aim",
	Description = "オフで常時",
	Default = Config.aimbot.hold,
	Callback = function(v) Config.aimbot.hold = v end,
})

aimSec:Keybind({
	Name = "Aim Key",
	Default = Config.aimbot.key,
	Callback = function(key) Config.aimbot.key = key end,
})

aimSec:Slider({
	Name = "FOV",
	Min = 10, Max = 400,
	Default = Config.aimbot.fov,
	Step = 1,
	Suffix = " px",
	Callback = function(v) Config.aimbot.fov = v end,
})

aimSec:Slider({
	Name = "Smoothing",
	Min = 1, Max = 99,
	Default = 65,
	Step = 1,
	Suffix = "%",
	Callback = function(v) Config.aimbot.smooth = v end,
})

aimSec:Dropdown({
	Name = "Target Part",
	Options = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
	Default = Config.aimbot.part,
	Callback = function(v) Config.aimbot.part = v end,
})

aimSec:Toggle({
	Name = "Team Check",
	Default = Config.aimbot.teamCheck,
	Callback = function(v) Config.aimbot.teamCheck = v end,
})

aimSec:Toggle({
	Name = "Visibility Check",
	Default = Config.aimbot.visibleCheck,
	Callback = function(v) Config.aimbot.visibleCheck = v end,
})

--────────────────── Visual / ESP

local visual = win:Tab({ Name = "Visual", Side = "BottomLeft" })
local espSub = visual:SubTab("ESP")
local espSec = espSub:Section("ESP")

espSec:Toggle({
	Name = "Enabled",
	Default = Config.esp.enabled,
	Callback = function(v)
		Config.esp.enabled = v
		if not v then destroyESP() end
	end,
})

espSec:Toggle({
	Name = "Name",
	Default = Config.esp.name,
	Callback = function(v) Config.esp.name = v end,
})

espSec:Toggle({
	Name = "Health Bar",
	Default = Config.esp.health,
	Callback = function(v) Config.esp.health = v end,
})

espSec:Toggle({
	Name = "Distance",
	Default = Config.esp.distance,
	Callback = function(v) Config.esp.distance = v end,
})

espSec:Slider({
	Name = "Max Distance",
	Min = 50, Max = 2000,
	Default = Config.esp.maxDistance,
	Step = 10,
	Suffix = " m",
	Callback = function(v) Config.esp.maxDistance = v end,
})

espSec:Dropdown({
	Name = "Color",
	Options = { "Blue", "Purple", "Green", "Red", "White" },
	Default = "Blue",
	Callback = function(v)
		local map = {
			Blue   = Color3.fromRGB(138, 170, 255),
			Purple = Color3.fromRGB(196, 148, 255),
			Green  = Color3.fromRGB(90, 230, 150),
			Red    = Color3.fromRGB(255, 95, 110),
			White  = Color3.fromRGB(240, 242, 248),
		}
		Config.esp.color = map[v] or Config.esp.color
		fovStroke.Color = Config.esp.color
		destroyESP()
	end,
})

--────────────────── Misc / Fly

local misc = win:Tab({ Name = "Misc", Side = "BottomRight" })
local flySub = misc:SubTab("Fly")
local flySec = flySub:Section("Fly")

flySec:Toggle({
	Name = "Enabled",
	Default = Config.fly.enabled,
	Callback = function(v)
		if v ~= Config.fly.enabled then
			setFly(v)
		end
	end,
})

flySec:Keybind({
	Name = "Toggle Key",
	Default = Config.fly.key,
	Callback = function(key) Config.fly.key = key end,
})

flySec:Slider({
	Name = "Speed",
	Min = 10, Max = 300,
	Default = Config.fly.speed,
	Step = 5,
	Callback = function(v) Config.fly.speed = v end,
})

flySec:Label("WASD で移動 / Space 上昇 / LeftCtrl 下降 / LeftShift 加速")

--────────────────── Setting

local setting = win:Tab({ Name = "Setting", Side = "TopLeft" })
local cfgSub = setting:SubTab("Config")
local cfgSec = cfgSub:Section("Config")

cfgSec:Keybind({
	Name = "Toggle UI",
	Default = Enum.KeyCode.RightShift,
	Callback = function(key) win.ToggleKey = key end,
})

cfgSec:Button({
	Name = "Unload",
	Callback = function()
		disconnectAll()
		destroyESP()
		if Config.fly.enabled then setFly(false) end
		if fovCircleGui then fovCircleGui:Destroy() end
		win:Destroy()
	end,
})

cfgSec:Label("comet sample — Fly / ESP / Aimbot")

--──────────────────────────────────────────── 起動通知

task.delay(0.6, function()
	win:Notify({ Title = "comet", Text = "sample ready — RightShift で UI" })
end)
