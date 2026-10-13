-- ═══════════════════════════════════════════════════════════
-- ⚔️ KENTO CAMLOCK | Project Smash Edition v5.2
-- ═══════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==================== WINDUI ====================
local WindUI
for _, url in ipairs({
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://cdn.jsdelivr.net/gh/Footagesus/WindUI@main/main.lua",
}) do
    local ok, res = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and res then WindUI = res break end
end
if not WindUI then
    StarterGui:SetCore("SendNotification", {Title="Kento", Text="WindUI fail", Duration=5})
    return
end

-- ==================== КОНФИГ ====================
local Config = {
    Camlock = {
        Enabled = false,
        Key = Enum.KeyCode.C,
        Smoothness = 0.75,
        MaxDistance = 300,
        LockMode = "Nearest",
        AutoSwitch = true,
        FOV = 0,
    },
    ESP = {
        Enabled = false,
        ShowName = true,
        ShowDistance = true,
        ShowChams = true,
        ShowSnapline = false,
        MaxDistance = 500,
        TeamCheck = false,
    },
    AutoM1 = {
        Enabled = false,
        Range = 12,
        Rate = 0.15,
        OnlyWithTarget = true,
    },
    AntiVoid = {
        Enabled = false,
        Threshold = -150,
    },
    AutoBlock = {
        Enabled = false,
        Range = 20,
        HoldTime = 0.3,
        Cooldown = 1.2,
    },
}

-- ==================== СТЕЙТ ====================
local State = {
    Target = nil,
    LastTargetUpdate = 0,

    -- AUTO M1
    LastM1 = 0,
    M1Busy = false,

    -- AUTO BLOCK
    -- Режимы: "idle" | "blocking" | "cooldown"
    BlockMode = "idle",
    BlockCooldownUntil = 0,
    EnemyLastDist = {},

    -- ESP
    ESPCache = {},
    ESPEnabled = false,

    -- FOV
    FOVCircle = nil,

    -- CAMLOCK
    CamlockConnection = nil,

    -- КНОПКА
    Button = nil,

    -- ANTI VOID
    LastSafePos = nil,
    LastSafeTick = 0,
}

-- ==================== ХЕЛПЕРЫ ====================
local function GetRoot(p)
    local char = p and p.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(p)
    local char = p and p.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return true
end

local function IsSameTeam(p)
    if not Config.ESP.TeamCheck then return false end
    return p.Team == LocalPlayer.Team
end

local function GetAimPosition(target)
    local char = target and target.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head then return head.Position end
    local upper = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if upper then return upper.Position end
    local root = char:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end

local function GetNearestPlayer(maxDist)
    local myRoot = GetRoot(LocalPlayer)
    if not myRoot then return nil end
    maxDist = maxDist or Config.Camlock.MaxDistance
    local best, bestDist = nil, maxDist
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsAlive(p) and not IsSameTeam(p) then
            local r = GetRoot(p)
            if r then
                local d = (myRoot.Position - r.Position).Magnitude
                if d < bestDist then bestDist = d; best = p end
            end
        end
    end
    return best
end

local function GetPlayerUnderMouse()
    local mouse = LocalPlayer:GetMouse()
    if not mouse.Target then return nil end
    local model = mouse.Target:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    local p = Players:GetPlayerFromCharacter(model)
    if p and p ~= LocalPlayer and IsAlive(p) and not IsSameTeam(p) then return p end
    return nil
end

local function Notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title="Kento", Text=text, Duration=2})
    end)
end

-- ==================== FOV CIRCLE ====================
local function DestroyFOVCircle()
    if State.FOVCircle then
        State.FOVCircle:Remove()
        State.FOVCircle = nil
    end
end

local function CreateFOVCircle()
    if State.FOVCircle then return end
    State.FOVCircle = Drawing.new("Circle")
    State.FOVCircle.Thickness = 1.5
    State.FOVCircle.NumSides = 60
    State.FOVCircle.Color = Color3.fromRGB(255, 210, 50)
    State.FOVCircle.Filled = false
    State.FOVCircle.Transparency = 0.7
    State.FOVCircle.Visible = false
end

-- ==================== CAMLOCK ====================
local function StartCamlockLoop()
    if State.CamlockConnection then return end
    State.CamlockConnection = RunService.RenderStepped:Connect(function(dt)
        if tick() - State.LastTargetUpdate > 0.15 then
            State.LastTargetUpdate = tick()
            if not State.Target or not IsAlive(State.Target) then
                if Config.Camlock.AutoSwitch then
                    State.Target = (Config.Camlock.LockMode == "Mouse")
                        and (GetPlayerUnderMouse() or GetNearestPlayer())
                        or GetNearestPlayer()
                end
            end
        end

        local t = State.Target
        if not t then return end
        local aimPos = GetAimPosition(t)
        if not aimPos then return end

        local camPos = Camera.CFrame.Position
        local targetCF = CFrame.new(camPos, aimPos)
        local smooth = math.clamp(Config.Camlock.Smoothness, 0.01, 0.99)
        local alpha = 1 - smooth ^ (dt * 60)
        Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
    end)
end

local function StopCamlockLoop()
    if State.CamlockConnection then
        State.CamlockConnection:Disconnect()
        State.CamlockConnection = nil
    end
    State.Target = nil
end

-- ==================== КНОПКА ====================
local function UpdateButtonVisual()
    local btn = State.Button
    if not btn then return end
    if Config.Camlock.Enabled then
        btn.BackgroundColor3 = Color3.fromRGB(60, 50, 10)
        btn.TextColor3 = Color3.fromRGB(0, 255, 120)
        local s = btn:FindFirstChildOfClass("UIStroke")
        if s then s.Color = Color3.fromRGB(0, 255, 120) end
    else
        btn.BackgroundColor3 = Color3.fromRGB(45, 38, 15)
        btn.TextColor3 = Color3.fromRGB(255, 210, 50)
        local s = btn:FindFirstChildOfClass("UIStroke")
        if s then s.Color = Color3.fromRGB(255, 200, 40) end
    end
end

local function ToggleCamlock()
    Config.Camlock.Enabled = not Config.Camlock.Enabled
    if Config.Camlock.Enabled then
        State.Target = (Config.Camlock.LockMode == "Mouse")
            and (GetPlayerUnderMouse() or GetNearestPlayer())
            or GetNearestPlayer()
        StartCamlockLoop()
        Notify("Camlock ON")
    else
        StopCamlockLoop()
        Notify("Camlock OFF")
    end
    UpdateButtonVisual()
end

local function CreateCamlockButton()
    if State.Button then
        local gui = State.Button:FindFirstAncestorOfClass("ScreenGui")
        if gui and gui.Parent then return end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Kento_CamlockBtn"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = CoreGui

    local btn = Instance.new("TextButton")
    btn.Name = "CamlockButton"
    btn.Size = UDim2.new(0, 65, 0, 65)
    btn.Position = UDim2.new(0, 20, 0.5, -32)
    btn.BackgroundColor3 = Color3.fromRGB(45, 38, 15)
    btn.Text = "🎯"
    btn.TextColor3 = Color3.fromRGB(255, 210, 50)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 28
    btn.Active = true
    btn.AutoButtonColor = false
    btn.Parent = gui
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 40)
    stroke.Thickness = 2
    stroke.Parent = btn

    State.Button = btn
    UpdateButtonVisual()

    local dragging, dragStart, startPos, moved = false, nil, nil, false

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; moved = false
            dragStart = input.Position; startPos = btn.Position
        end
    end)

    local connMove = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then moved = true end
            btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                     startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local connEnd = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved then ToggleCamlock() end
            dragging = false
        end
    end)

    gui.Destroying:Connect(function()
        connMove:Disconnect(); connEnd:Disconnect()
    end)
end

local function RemoveCamlockButton()
    if State.Button then
        local gui = State.Button:FindFirstAncestorOfClass("ScreenGui")
        if gui then gui:Destroy() end
        State.Button = nil
    end
end

-- ==================== AUTO M1 ====================
local function DoM1Click()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

-- ==================== AUTO BLOCK ====================
local function DoBlockPress()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    task.wait(Config.AutoBlock.HoldTime)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
end

-- ==================== ANTI VOID ====================
-- 1. Пока Y нормальный — запоминаем позицию раз в секунду
-- 2. При падении — телепорт через SetPrimaryPartCFrame (надёжнее чем root.CFrame)
-- 3. Не трогаем если персонаж уже мёртв
-- 4. Пауза 2с после телепорта чтобы не спамить

local AntiVoidCooldown = false

local function CheckAntiVoid()
    if not Config.AntiVoid.Enabled then return end
    if AntiVoidCooldown then return end

    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")

    -- Персонаж мёртв — не вмешиваемся, respawn сам разберётся
    if hum and hum.Health <= 0 then return end

    local y = root.Position.Y

    -- Нормальная высота — обновляем безопасную позицию
    if y > Config.AntiVoid.Threshold + 20 then
        if tick() - State.LastSafeTick > 1 then
            State.LastSafePos = root.Position + Vector3.new(0, 5, 0)
            State.LastSafeTick = tick()
        end
        return
    end

    -- Упали за порог
    AntiVoidCooldown = true
    local safePos = State.LastSafePos or Vector3.new(0, 50, 0)

    local ok = pcall(function()
        char:SetPrimaryPartCFrame(CFrame.new(safePos))
    end)
    if not ok then
        pcall(function() root.CFrame = CFrame.new(safePos) end)
    end

    Notify("Anti Void! (" .. math.floor(y) .. ")")

    task.delay(2, function()
        AntiVoidCooldown = false
    end)
end

-- ==================== КЛАВИША C ====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.Camlock.Key then ToggleCamlock() end
end)

-- ==================== УМНАЯ ЛОГИКА M1 + BLOCK ====================
--
-- Стейт-машина (тик каждые 0.05с):
--
--   IDLE → враг резко сближается (>1.5 студа за тик) → BLOCKING
--   IDLE → враг в радиусе M1, не блокируем → бьём M1
--   BLOCKING → держим F на HoldTime → COOLDOWN
--   COOLDOWN → ждём Cooldown секунд → IDLE
--
-- M1 молчит пока BlockMode != "idle"

task.spawn(function()
    while task.wait(0.05) do
        if not Config.AutoM1.Enabled and not Config.AutoBlock.Enabled then
            continue
        end

        local myRoot = GetRoot(LocalPlayer)
        if not myRoot then continue end

        -- Цель для M1
        local m1Target = nil
        if Config.AutoM1.Enabled then
            m1Target = State.Target
            if not m1Target or not IsAlive(m1Target) then
                m1Target = (not Config.AutoM1.OnlyWithTarget)
                    and GetNearestPlayer(Config.AutoM1.Range)
                    or nil
            end
        end

        -- Ближайший враг для блока
        local blockTarget = Config.AutoBlock.Enabled
            and GetNearestPlayer(Config.AutoBlock.Range)
            or nil

        -- Детект сближения
        local enemyApproaching = false
        if blockTarget then
            local theirRoot = GetRoot(blockTarget)
            if theirRoot then
                local dist = (myRoot.Position - theirRoot.Position).Magnitude
                local prev = State.EnemyLastDist[blockTarget] or dist
                if (prev - dist) > 1.5 then
                    enemyApproaching = true
                end
                State.EnemyLastDist[blockTarget] = dist
            end
        end

        -- Чистим устаревшие записи
        for p in pairs(State.EnemyLastDist) do
            if not IsAlive(p) then State.EnemyLastDist[p] = nil end
        end

        local now = tick()

        if State.BlockMode == "idle" then

            -- Блок имеет приоритет над M1
            if Config.AutoBlock.Enabled and enemyApproaching
            and blockTarget and now >= State.BlockCooldownUntil then
                State.BlockMode = "blocking"
                task.spawn(function()
                    DoBlockPress()
                    State.BlockMode = "cooldown"
                    State.BlockCooldownUntil = tick() + Config.AutoBlock.Cooldown
                    task.wait(Config.AutoBlock.Cooldown)
                    State.BlockMode = "idle"
                end)

            elseif Config.AutoM1.Enabled and m1Target and not State.M1Busy then
                local theirRoot = GetRoot(m1Target)
                if theirRoot then
                    local dist = (myRoot.Position - theirRoot.Position).Magnitude
                    if dist <= Config.AutoM1.Range and now - State.LastM1 >= Config.AutoM1.Rate then
                        State.LastM1 = now
                        State.M1Busy = true
                        task.spawn(function()
                            DoM1Click()
                            State.M1Busy = false
                        end)
                    end
                end
            end
        end
        -- blocking / cooldown — ничего не делаем, task.spawn выше сам рулит
    end
end)

-- ==================== ГЛАВНЫЙ ЦИКЛ ====================
RunService.RenderStepped:Connect(function(dt)
    CheckAntiVoid()

    if State.FOVCircle then
        if Config.Camlock.FOV <= 0 then
            State.FOVCircle.Visible = false
        else
            State.FOVCircle.Visible = true
            State.FOVCircle.Position = Vector2.new(
                Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            State.FOVCircle.Radius = Config.Camlock.FOV
        end
    end
end)

-- ==================== ESP ====================
local function CreateESP(player)
    if State.ESPCache[player] then return end
    if not player.Character then return end
    local data = {}

    if Config.ESP.ShowChams then
        local h = Instance.new("Highlight")
        h.FillColor = Color3.fromRGB(255, 210, 50)
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.FillTransparency = 0.55
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = player.Character
        h.Parent = player.Character
        data.Highlight = h
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = player.Character
    billboard.Parent = player.Character

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Text = player.Name
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, 0, 0, 16)
    distLabel.Position = UDim2.new(0, 0, 0, 20)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(230, 210, 140)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12
    distLabel.Parent = billboard

    if Config.ESP.ShowSnapline then
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Color = Color3.fromRGB(255, 210, 50)
        line.Transparency = 0.7
        line.Visible = false
        data.Snapline = line
    end

    data.Billboard = billboard
    data.NameLabel = nameLabel
    data.DistLabel = distLabel
    State.ESPCache[player] = data
end

local function RemoveESP(player)
    local data = State.ESPCache[player]
    if not data then return end
    if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
    if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
    if data.Snapline then pcall(function() data.Snapline:Remove() end) end
    State.ESPCache[player] = nil
end

local function SetupPlayer(p)
    if p == LocalPlayer then return end
    p.CharacterAdded:Connect(function()
        task.wait(0.3)
        if Config.ESP.Enabled then CreateESP(p) end
    end)
    if Config.ESP.Enabled and p.Character then CreateESP(p) end
end

Players.PlayerAdded:Connect(SetupPlayer)
Players.PlayerRemoving:Connect(RemoveESP)
for _, p in ipairs(Players:GetPlayers()) do SetupPlayer(p) end

task.spawn(function()
    while task.wait(0.05) do
        if not Config.ESP.Enabled then
            if State.ESPEnabled then
                State.ESPEnabled = false
                for p in pairs(State.ESPCache) do RemoveESP(p) end
            end
        else
            State.ESPEnabled = true
            local myRoot = GetRoot(LocalPlayer)
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                local alive = IsAlive(p) and not IsSameTeam(p)
                local cached = State.ESPCache[p]
                if alive then
                    if not cached then CreateESP(p) end
                    local data = State.ESPCache[p]
                    local theirRoot = GetRoot(p)
                    if data and data.Billboard and theirRoot and myRoot then
                        local dist = (myRoot.Position - theirRoot.Position).Magnitude
                        local vis = dist <= Config.ESP.MaxDistance
                        if data.NameLabel then
                            data.NameLabel.Text = p.Name
                            data.NameLabel.Visible = Config.ESP.ShowName
                        end
                        if data.DistLabel then
                            data.DistLabel.Text = math.floor(dist) .. " studs"
                            data.DistLabel.Visible = Config.ESP.ShowDistance
                        end
                        data.Billboard.Enabled = vis
                        if data.Highlight then data.Highlight.Enabled = vis end
                        if data.Snapline then
                            if vis then
                                local sp, on = Camera:WorldToViewportPoint(theirRoot.Position)
                                if on then
                                    local vp = Camera.ViewportSize
                                    data.Snapline.From = Vector2.new(vp.X/2, vp.Y)
                                    data.Snapline.To = Vector2.new(sp.X, sp.Y)
                                    data.Snapline.Visible = true
                                else
                                    data.Snapline.Visible = false
                                end
                            else
                                data.Snapline.Visible = false
                            end
                        end
                    end
                else
                    if cached then RemoveESP(p) end
                end
            end
        end
    end
end)

-- ==================== WINDUI ====================
pcall(function()
    WindUI:AddTheme({
        Name = "Kento_Gold",
        Accent = Color3.fromRGB(255, 210, 50),
        Dialog = Color3.fromRGB(30, 25, 8),
        Outline = Color3.fromRGB(200, 160, 40),
        Text = Color3.fromRGB(255, 245, 200),
        Placeholder = Color3.fromRGB(180, 150, 60),
        Background = Color3.fromRGB(18, 16, 8),
        Button = Color3.fromRGB(200, 160, 40),
        Icon = Color3.fromRGB(255, 220, 90),
    })
end)

local Window = WindUI:CreateWindow({
    Title = "⚔️ Kento Camlock | PS",
    Icon = "crosshair",
    Author = "Kento",
    Folder = "KentoPS",
    Size = UDim2.fromOffset(480, 460),
    Theme = "Kento_Gold",
})

-- ── TAB: CAMLOCK ──
local CamTab = Window:Tab({Title = "🎯 Camlock", Icon = "crosshair"})
CamTab:Toggle({
    Title = "🎯 Camlock",
    Desc = "Включает camlock + кнопку на экране",
    Value = false,
    Callback = function(v)
        Config.Camlock.Enabled = v
        if v then
            CreateCamlockButton()
            State.Target = (Config.Camlock.LockMode == "Mouse")
                and (GetPlayerUnderMouse() or GetNearestPlayer())
                or GetNearestPlayer()
            StartCamlockLoop()
            Notify("Camlock ON")
        else
            RemoveCamlockButton()
            StopCamlockLoop()
            Notify("Camlock OFF")
        end
    end,
})
CamTab:Toggle({Title = "Auto Switch", Value = true,
    Callback = function(v) Config.Camlock.AutoSwitch = v end})
CamTab:Dropdown({Title = "Mode", Values = {"Nearest","Mouse"}, Value = "Nearest",
    Callback = function(v) Config.Camlock.LockMode = v end})
CamTab:Slider({Title = "Smoothness", Value = {Min=0, Max=100, Default=75},
    Callback = function(v) Config.Camlock.Smoothness = v/100 end})
CamTab:Slider({Title = "Distance", Value = {Min=50, Max=1000, Default=300},
    Callback = function(v) Config.Camlock.MaxDistance = v end})
CamTab:Slider({Title = "FOV (0=off)", Value = {Min=0, Max=600, Default=0},
    Callback = function(v)
        Config.Camlock.FOV = v
        if v > 0 then CreateFOVCircle() else DestroyFOVCircle() end
    end})

-- ── TAB: AUTO ──
local AutoTab = Window:Tab({Title = "⚡ Auto", Icon = "zap"})
AutoTab:Section({Title = "⚔️ Бой — Auto M1"})
AutoTab:Toggle({Title = "Auto M1", Desc = "Авто-удары. Не бьёт во время блока.", Value = false,
    Callback = function(v)
        Config.AutoM1.Enabled = v
        Notify(v and "Auto M1 ON" or "Auto M1 OFF")
    end})
AutoTab:Slider({Title = "M1 Range", Value = {Min=5, Max=50, Default=12},
    Callback = function(v) Config.AutoM1.Range = v end})
AutoTab:Slider({Title = "M1 Rate (ms)", Value = {Min=5, Max=100, Default=15},
    Callback = function(v) Config.AutoM1.Rate = v/100 end})
AutoTab:Toggle({Title = "Only With Target", Value = true,
    Callback = function(v) Config.AutoM1.OnlyWithTarget = v end})

AutoTab:Section({Title = "🛡️ Защита — Auto Block"})
AutoTab:Toggle({
    Title = "Auto Block",
    Desc = "Блокирует только при резком сближении врага. Кулдаун между блоками.",
    Value = false,
    Callback = function(v)
        Config.AutoBlock.Enabled = v
        if not v then State.BlockMode = "idle" end
        Notify(v and "Auto Block ON" or "Auto Block OFF")
    end})
AutoTab:Slider({Title = "Block Range", Value = {Min=5, Max=50, Default=20},
    Callback = function(v) Config.AutoBlock.Range = v end})
AutoTab:Slider({Title = "Hold Time (ms)", Value = {Min=10, Max=100, Default=30},
    Callback = function(v) Config.AutoBlock.HoldTime = v/100 end})
AutoTab:Slider({
    Title = "Block Cooldown (ms)",
    Desc = "Пауза между блоками — не даёт спамить",
    Value = {Min=200, Max=3000, Default=1200},
    Callback = function(v) Config.AutoBlock.Cooldown = v/1000 end})

AutoTab:Section({Title = "🕳️ Anti Void"})
AutoTab:Toggle({
    Title = "Anti Void",
    Desc = "Телепорт на последнюю безопасную позицию. Не трогает при смерти.",
    Value = false,
    Callback = function(v)
        Config.AntiVoid.Enabled = v
        if v then
            local root = GetRoot(LocalPlayer)
            if root and root.Position.Y > Config.AntiVoid.Threshold + 20 then
                State.LastSafePos = root.Position + Vector3.new(0,5,0)
                State.LastSafeTick = tick()
            end
        end
        Notify(v and "Anti Void ON" or "Anti Void OFF")
    end})
AutoTab:Slider({Title = "Threshold Y", Value = {Min=-500, Max=-50, Default=-150},
    Callback = function(v) Config.AntiVoid.Threshold = v end})

-- ── TAB: ESP ──
local ESPTab = Window:Tab({Title = "👁️ ESP", Icon = "eye"})
ESPTab:Toggle({Title = "ESP", Value = false, Callback = function(v)
    Config.ESP.Enabled = v
    if not v then
        for p in pairs(State.ESPCache) do RemoveESP(p) end
        State.ESPEnabled = false
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) then CreateESP(p) end
        end
        State.ESPEnabled = true
    end
end})
ESPTab:Toggle({Title = "Chams", Value = true, Callback = function(v)
    Config.ESP.ShowChams = v
    for p in pairs(State.ESPCache) do RemoveESP(p) end
    if Config.ESP.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) then CreateESP(p) end
        end
    end
end})
ESPTab:Toggle({Title = "Snapline", Value = false, Callback = function(v)
    Config.ESP.ShowSnapline = v
    for p in pairs(State.ESPCache) do RemoveESP(p) end
    if Config.ESP.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) then CreateESP(p) end
        end
    end
end})
ESPTab:Toggle({Title = "Name", Value = true,
    Callback = function(v) Config.ESP.ShowName = v end})
ESPTab:Toggle({Title = "Distance", Value = true,
    Callback = function(v) Config.ESP.ShowDistance = v end})
ESPTab:Toggle({Title = "Team Check", Value = false,
    Callback = function(v) Config.ESP.TeamCheck = v end})
ESPTab:Slider({Title = "ESP Distance", Value = {Min=50, Max=2000, Default=500},
    Callback = function(v) Config.ESP.MaxDistance = v end})

-- ── TAB: SETTINGS ──
local SetTab = Window:Tab({Title = "⚙️ Settings", Icon = "settings"})
SetTab:Button({Title = "Toggle Camlock", Callback = ToggleCamlock})
SetTab:Button({Title = "Toggle ESP", Callback = function()
    Config.ESP.Enabled = not Config.ESP.Enabled
    if not Config.ESP.Enabled then
        for p in pairs(State.ESPCache) do RemoveESP(p) end
        State.ESPEnabled = false
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) then CreateESP(p) end
        end
        State.ESPEnabled = true
    end
end})

Notify("Kento v5.2 ready ⚔️")
