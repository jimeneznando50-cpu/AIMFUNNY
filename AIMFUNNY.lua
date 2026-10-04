-- language: Lua, file: AIMFUNY.lua, target: Roblox executor
-- dependencias: Drawing API, mousemoverel, getgenv, HttpGet (LinoriaLib)

--// ============================================================
--// SERVICIOS
--// ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()

--// ============================================================
--// TRACKING DE CONEXIONES
--// ============================================================
local connections = {}
local function track(conn)
    table.insert(connections, conn)
    return conn
end

--// ============================================================
--// DRAWING INIT
--// ============================================================
local Drawing_new = Drawing and Drawing.new or function()
    error("Drawing API required — usa un executor con Drawing")
end

--// ============================================================
--// STATE
--// ============================================================
getgenv().AIMFUNY = getgenv().AIMFUNY or {}
local State = getgenv().AIMFUNY

State.Aimbot = {
    Enabled = false, FOV = 120, Distance = 500, ShowFOV = false,
    Smoothness = 0.15, MouseFollow = false, TargetPart = "Head",
}

State.ESP = {
    Enabled = false, Tracers = true, Boxes = true, Names = true,
    Health = true, Distance = true, MaxDist = 1000,
}

--// ============================================================
--// DRAWING OBJECTS
--// ============================================================
local fov_circle = Drawing_new("Circle")
fov_circle.Visible = false
fov_circle.Thickness = 2
fov_circle.Color = Color3.fromRGB(255, 255, 255)
fov_circle.Filled = false
fov_circle.Transparency = 0.7

local esp_cache = {}

--// ============================================================
--// UTILIDADES
--// ============================================================
local function world_to_screen(pos)
    local sp, on_screen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), on_screen
end

local function get_character(player)
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum and root and hum.Health > 0 then
        return char, hum, root
    end
    return nil
end

local function get_target_part(player, part_name)
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild(part_name)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
end

--// ============================================================
--// FOV CIRCLE
--// ============================================================
local function update_fov()
    if State.Aimbot.ShowFOV then
        fov_circle.Visible = true
        fov_circle.Radius = State.Aimbot.FOV
        fov_circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        fov_circle.Visible = false
    end
end

--// ============================================================
--// AIMBOT
--// ============================================================
local function get_closest_target()
    local closest = nil
    local shortest = State.Aimbot.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char, hum, root = get_character(player)
        if not char then continue end

        local part = get_target_part(player, State.Aimbot.TargetPart)
        if not part then continue end

        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist > State.Aimbot.Distance then continue end

        local screen_pos, on_screen = world_to_screen(part.Position)
        if not on_screen then continue end

        local mag = (screen_pos - center).Magnitude
        if mag < shortest then
            shortest = mag
            closest = player
        end
    end
    return closest
end

track(RunService.RenderStepped:Connect(function()
    update_fov()

    if not State.Aimbot.Enabled then return end

    local target = get_closest_target()
    if not target then return end

    local part = get_target_part(target, State.Aimbot.TargetPart)
    if not part then return end

    local target_pos = part.Position

    if State.Aimbot.MouseFollow then
        local mouse_pos = UserInputService:GetMouseLocation()
        local screen_pos, on_screen = world_to_screen(target_pos)
        if on_screen then
            local delta = (screen_pos - mouse_pos) * State.Aimbot.Smoothness
            mousemoverel(delta.X, delta.Y)
        end
    else
        local cam_pos = Camera.CFrame.Position
        local direction = (target_pos - cam_pos).Unit
        Camera.CFrame = CFrame.new(cam_pos, cam_pos + direction)
    end
end))

--// ============================================================
--// ESP
--// ============================================================
local function create_esp(player)
    if esp_cache[player] then return end
    local drawings = {
        box    = Drawing_new("Square"),
        tracer = Drawing_new("Line"),
        name   = Drawing_new("Text"),
        health = Drawing_new("Text"),
        dist   = Drawing_new("Text"),
    }

    drawings.box.Thickness = 1
    drawings.box.Filled = false
    drawings.box.Color = Color3.fromRGB(255, 255, 255)
    drawings.box.Transparency = 0.8

    drawings.tracer.Thickness = 1
    drawings.tracer.Color = Color3.fromRGB(255, 255, 255)
    drawings.tracer.Transparency = 0.7
    drawings.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

    drawings.name.Size = 14
    drawings.name.Center = true
    drawings.name.Outline = true
    drawings.name.Color = Color3.fromRGB(255, 255, 255)

    drawings.health.Size = 12
    drawings.health.Center = true
    drawings.health.Outline = true
    drawings.health.Color = Color3.fromRGB(0, 255, 0)

    drawings.dist.Size = 12
    drawings.dist.Center = true
    drawings.dist.Outline = true
    drawings.dist.Color = Color3.fromRGB(200, 200, 200)

    esp_cache[player] = drawings
end

local function remove_esp(player)
    local d = esp_cache[player]
    if not d then return end
    for _, obj in pairs(d) do
        pcall(function() obj:Remove() end)
    end
    esp_cache[player] = nil
end

track(Players.PlayerAdded:Connect(create_esp))
track(Players.PlayerRemoving:Connect(remove_esp))
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then create_esp(p) end
end

track(RunService.RenderStepped:Connect(function()
    if not State.ESP.Enabled then
        for _, d in pairs(esp_cache) do
            for _, obj in pairs(d) do obj.Visible = false end
        end
        return
    end

    for player, d in pairs(esp_cache) do
        local char, hum, root = get_character(player)
        if not char then
            for _, obj in pairs(d) do obj.Visible = false end
            continue
        end

        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist > State.ESP.MaxDist then
            for _, obj in pairs(d) do obj.Visible = false end
            continue
        end

        local head = char:FindFirstChild("Head")
        if not head then continue end
        local head_pos, on_screen = world_to_screen(head.Position)
        local root_pos = world_to_screen(root.Position)

        if not on_screen then
            for _, obj in pairs(d) do obj.Visible = false end
            continue
        end

        local box_size = Vector2.new(2000 / dist, 3000 / dist)
        d.box.Size = box_size
        d.box.Position = root_pos - box_size / 2
        d.box.Visible = State.ESP.Boxes

        d.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        d.tracer.To = head_pos
        d.tracer.Visible = State.ESP.Tracers

        d.name.Text = player.Name
        d.name.Position = head_pos - Vector2.new(0, 20)
        d.name.Visible = State.ESP.Names

        local hp = math.floor(hum.Health)
        local max_hp = math.floor(hum.MaxHealth)
        d.health.Text = "HP: " .. hp .. "/" .. max_hp
        d.health.Position = head_pos + Vector2.new(0, 5)
        d.health.Color = Color3.fromRGB(255 - (hp / max_hp * 255), hp / max_hp * 255, 0)
        d.health.Visible = State.ESP.Health

        d.dist.Text = math.floor(dist) .. " studs"
        d.dist.Position = head_pos + Vector2.new(0, 20)
        d.dist.Visible = State.ESP.Distance
    end
end))

--// ============================================================
--// GUI (LinoriaLib)
--// ============================================================
local repo = "https://raw.githubusercontent.com/Progoonerfrfr/LinoriaLib/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "AIMFUNY",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Aimbot   = Window:AddTab("Aimbot"),
    ESP      = Window:AddTab("ESP"),
    Settings = Window:AddTab("Settings"),
}

--// AIMBOT TAB
local AimbotGroup = Tabs.Aimbot:AddLeftGroupbox("Aimbot")

AimbotGroup:AddToggle("aim_enabled", {
    Text = "Enable Aimbot", Default = false,
    Callback = function(v) State.Aimbot.Enabled = v end,
})

AimbotGroup:AddSlider("aim_fov", {
    Text = "FOV", Default = 120, Min = 10, Max = 500, Rounding = 0,
    Callback = function(v) State.Aimbot.FOV = v end,
})

AimbotGroup:AddSlider("aim_dist", {
    Text = "Max Distance", Default = 500, Min = 50, Max = 2000, Rounding = 0,
    Callback = function(v) State.Aimbot.Distance = v end,
})

AimbotGroup:AddToggle("aim_show_fov", {
    Text = "Show FOV Circle", Default = false,
    Callback = function(v) State.Aimbot.ShowFOV = v end,
})

AimbotGroup:AddSlider("aim_smooth", {
    Text = "Smoothness", Default = 0.15, Min = 0.01, Max = 1, Rounding = 2,
    Callback = function(v) State.Aimbot.Smoothness = v end,
})

AimbotGroup:AddToggle("aim_mouse_follow", {
    Text = "Mouse Follow (toggle)", Default = false,
    Callback = function(v) State.Aimbot.MouseFollow = v end,
})

AimbotGroup:AddDropdown("aim_part", {
    Text = "Target Part",
    Values = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Default = 1,
    Callback = function(v) State.Aimbot.TargetPart = v end,
})

--// ESP TAB
local ESPGroup = Tabs.ESP:AddLeftGroupbox("ESP")

ESPGroup:AddToggle("esp_enabled", {
    Text = "Enable ESP", Default = false,
    Callback = function(v) State.ESP.Enabled = v end,
})
ESPGroup:AddToggle("esp_tracers", {
    Text = "Tracers", Default = true,
    Callback = function(v) State.ESP.Tracers = v end,
})
ESPGroup:AddToggle("esp_boxes", {
    Text = "Boxes", Default = true,
    Callback = function(v) State.ESP.Boxes = v end,
})
ESPGroup:AddToggle("esp_names", {
    Text = "Names", Default = true,
    Callback = function(v) State.ESP.Names = v end,
})
ESPGroup:AddToggle("esp_health", {
    Text = "Health", Default = true,
    Callback = function(v) State.ESP.Health = v end,
})
ESPGroup:AddToggle("esp_dist", {
    Text = "Distance (studs)", Default = true,
    Callback = function(v) State.ESP.Distance = v end,
})
ESPGroup:AddSlider("esp_max_dist", {
    Text = "Max Render Distance", Default = 1000, Min = 100, Max = 5000, Rounding = 0,
    Callback = function(v) State.ESP.MaxDist = v end,
})

--// SETTINGS TAB
local SettingsGroup = Tabs.Settings:AddLeftGroupbox("Menu")

local function full_unload()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}

    for _, d in pairs(esp_cache) do
        for _, obj in pairs(d) do pcall(function() obj:Remove() end) end
    end
    esp_cache = {}

    pcall(function() fov_circle:Remove() end)
    pcall(function() UserInputService.MouseIconEnabled = true end)
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
    pcall(function() Library:Unload() end)
end

SettingsGroup:AddButton("Unload", function()
    full_unload()
end)

Library:OnUnload(function()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, d in pairs(esp_cache) do
        for _, obj in pairs(d) do pcall(function() obj:Remove() end) end
    end
    pcall(function() fov_circle:Remove() end)
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder("AIMFUNY")
SaveManager:SetFolder("AIMFUNY/Configs")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

Library:Notify("AIMFUNY loaded — aimbot & ESP ready.", 5)

--// ============================================================
--// PATCH — MINIMIZE, X, CURSOR, LIBRARY TOGGLE
--// ============================================================
pcall(function()

    local Plr = Players.LocalPlayer
    local UIS = UserInputService

    --// 1) FRAME PRINCIPAL
    local main_frame
    if Window then
        main_frame = Window.Main or Window.Root or Window.Frame or Window.Holder
    end
    if not main_frame then
        local pg = Plr:FindFirstChildOfClass("PlayerGui")
        if pg then
            local count = 0
            for _, d in ipairs(pg:GetDescendants()) do
                count = count + 1
                if count > 5000 then break end
                if d:IsA("Frame")
                    and d:FindFirstChild("Topbar")
                    and d:FindFirstChildOfClass("TextLabel") then
                    main_frame = d
                    break
                end
            end
        end
    end
    if not main_frame then
        warn("[AIMFUNY] patch: no se encontró el frame principal")
        return
    end

    --// 2) TOPBAR
    local topbar = main_frame:FindFirstChild("Topbar")
        or main_frame:FindFirstChild("TitleBar")
        or main_frame:FindFirstChild("Titlebar")

    if not topbar then
        for _, ch in ipairs(main_frame:GetChildren()) do
            if ch:IsA("Frame") then
                local tl = ch:FindFirstChildOfClass("TextLabel")
                if tl and string.find(string.lower(tl.Text), "aimfuny") then
                    topbar = ch
                    break
                end
            end
        end
    end
    if not topbar then
        warn("[AIMFUNY] patch: no se encontró la topbar")
        return
    end

    --// 3) SCREENGUI QUE CONTIENE EL PANEL
    local lib_screengui = main_frame
    while lib_screengui and lib_screengui.Parent and not lib_screengui:IsA("ScreenGui") do
        lib_screengui = lib_screengui.Parent
    end
    if not lib_screengui or not lib_screengui:IsA("ScreenGui") then
        lib_screengui = nil
    end

    --// 4) FIX DE CÁMARA
    main_frame.Active = false
    topbar.Active = true

    local old_min = topbar:FindFirstChild("AIMFUNY_MinBtn"); if old_min then old_min:Destroy() end
    local old_x   = topbar:FindFirstChild("AIMFUNY_CloseBtn"); if old_x then old_x:Destroy() end

    local function mk_button(name, text, color, x_offset, width)
        local b = Instance.new("TextButton")
        b.Name = name
        b.AnchorPoint = Vector2.new(1, 0)
        b.Size = UDim2.new(0, width or 24, 0, 20)
        b.Position = UDim2.new(1, x_offset, 0, 5)
        b.BackgroundColor3 = color
        b.BackgroundTransparency = 0.1
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(235, 235, 235)
        b.TextSize = 16
        b.Font = Enum.Font.GothamBold
        b.ZIndex = 10
        b.Parent = topbar
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = b
        return b
    end

    local close_btn = mk_button("AIMFUNY_CloseBtn", "X", Color3.fromRGB(120, 30, 30), -6, 24)
    local min_btn   = mk_button("AIMFUNY_MinBtn",   "-", Color3.fromRGB(38, 38, 38),   -34, 24)

    --// 5) CONTENEDOR DEL BOTÓN FLOTANTE
    local gui_parent = lib_screengui and lib_screengui.Parent
        or (gethui and gethui())
        or Plr:FindFirstChildOfClass("PlayerGui")

    if not gui_parent then
        warn("[AIMFUNY] patch: no hay contenedor para el botón flotante")
        return
    end

    local old_float = gui_parent:FindFirstChild("AIMFUNY_Float")
    if old_float then old_float:Destroy() end

    local float_gui = Instance.new("ScreenGui")
    float_gui.Name = "AIMFUNY_Float"
    float_gui.ResetOnSpawn = false
    float_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    float_gui.IgnoreGuiInset = true
    float_gui.DisplayOrder = 2000
    float_gui.Enabled = false
    float_gui.Parent = gui_parent

    local float_btn = Instance.new("TextButton")
    float_btn.Name = "ReopenBtn"
    float_btn.Size = UDim2.new(0, 92, 0, 32)
    float_btn.Position = UDim2.new(0, 20, 0.5, -16)
    float_btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    float_btn.BackgroundTransparency = 0.05
    float_btn.BorderSizePixel = 0
    float_btn.Text = "AIMFUNY"
    float_btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    float_btn.TextSize = 14
    float_btn.Font = Enum.Font.GothamBold
    float_btn.Active = true
    float_btn.Draggable = true
    float_btn.Parent = float_gui

    local fcorner = Instance.new("UICorner")
    fcorner.CornerRadius = UDim.new(0, 6)
    fcorner.Parent = float_btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 1
    stroke.Parent = float_btn

    --// 6) ESTADO
    local original_size = main_frame.Size
    local minimized = false

    local function minimize()
        minimized = true

        -- soltar el estado de UI de Linoria: esto es lo que libera el mouse real
        if Library and Library.Toggled then
            pcall(function() Library:Toggle() end)
        end

        main_frame.Visible = false
        if lib_screengui then lib_screengui.Enabled = false end
        float_gui.Enabled = true

        -- devolver el control del cursor al sistema/juego
        pcall(function() UIS.MouseIconEnabled = true end)
        pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
    end

    local function restore()
        minimized = false

        if lib_screengui then lib_screengui.Enabled = true end
        main_frame.Visible = true
        main_frame.Size = original_size
        float_gui.Enabled = false

        -- reactivar el estado de UI de Linoria si estaba apagado
        if Library and not Library.Toggled then
            pcall(function() Library:Toggle() end)
        end
    end

    local function close_everything()
        minimized = true
        main_frame.Visible = false
        float_gui.Enabled = false

        for _, c in ipairs(connections) do
            pcall(function() c:Disconnect() end)
        end
        connections = {}

        for _, d in pairs(esp_cache) do
            for _, obj in pairs(d) do pcall(function() obj:Remove() end) end
        end
        esp_cache = {}
        pcall(function() fov_circle:Remove() end)

        pcall(function() float_gui:Destroy() end)
        pcall(function() UIS.MouseIconEnabled = true end)
        pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
        pcall(function() Library:Unload() end)
    end

    min_btn.MouseButton1Click:Connect(minimize)
    close_btn.MouseButton1Click:Connect(close_everything)
    float_btn.MouseButton1Click:Connect(restore)

    --// 7) ATAJO RightShift
    track(UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if minimized then restore() else minimize() end
        end
    end))

end)