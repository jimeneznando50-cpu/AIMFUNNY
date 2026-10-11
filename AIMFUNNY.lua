-- AIMFUNNY.lua | GUI propia (sin LinoriaLib), redimensionable y ligera
-- Requiere: Drawing API, mousemoverel, getgenv

--// ============================================================
--// LIMPIEZA DE EJECUCION ANTERIOR
--// ============================================================
if getgenv().AIMFUNY and getgenv().AIMFUNY.Unload then
    pcall(getgenv().AIMFUNY.Unload)
end

--// ============================================================
--// SERVICIOS
--// ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Stats            = game:GetService("Stats")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

--// ============================================================
--// TEMA
--// ============================================================
local THEME = {
    Accent = Color3.fromRGB(70, 220, 120),
    Bg     = Color3.fromRGB(16, 16, 19),
    Side   = Color3.fromRGB(21, 21, 25),
    Panel  = Color3.fromRGB(26, 26, 31),
    Stroke = Color3.fromRGB(44, 44, 52),
    Text   = Color3.fromRGB(235, 235, 240),
    Sub    = Color3.fromRGB(140, 140, 150),
    Off    = Color3.fromRGB(52, 52, 60),
}

local MIN_W, MIN_H = 460, 300

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
    error("Drawing API required: usa un executor con Drawing")
end

--// ============================================================
--// STATE
--// ============================================================
getgenv().AIMFUNY = {}
local State = getgenv().AIMFUNY

State.Aimbot = {
    Enabled = false, FOV = 120, Distance = 500, ShowFOV = false,
    FOVColor = "White",
    Smoothness = 0.15, MouseFollow = false, TargetPart = "Head",
    IgnoreList = {},
    AimKey = "Always",
    PredictionEnabled = false,
    PredictionAmount = 0.15,
    VisibleCheck = false,
    AutoFire = false,
    AutoFireDelay = 100,
    TriggerBot = false,
    TriggerBotDelay = 50,
    HitboxEnabled = false,
    HitboxSize = 5,
    HitboxPart = "Head",
}

State.Silent = {
    Enabled = false,
    HitChance = 100,
    TargetPart = "Head",
}

State.ESP = {
    Enabled = false, Tracers = true, Boxes = true, Names = true,
    Health = true, Distance = true, MaxDist = 1000,
    HideAllies = false,
    HeadDot = false,
    Skeleton = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    Chams = false,
    ChamsColor = "Green",
    ChamsMode = "Through Walls",
}

State.Player = {
    Walkspeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
    SpeedBoost = false,
    SpeedMultiplier = 2,
}

State.Misc = {
    AntiAFK = false,
    AutoRespawn = false,
    AntiFling = false,
    AutoSaveOnUnload = true,
}

State.Watermark = {
    Enabled = false,
    Text = "AIMFUNNY",
}

State.Menu = {
    Key = "RightShift",
}

--// ============================================================
--// COLOR MAPS
--// ============================================================
local FOV_COLORS = {
    White   = Color3.fromRGB(255, 255, 255),
    Green   = Color3.fromRGB(70, 220, 120),
    Red     = Color3.fromRGB(255, 70, 70),
    Blue    = Color3.fromRGB(80, 150, 255),
    Cyan    = Color3.fromRGB(80, 220, 255),
    Magenta = Color3.fromRGB(255, 80, 220),
    Yellow  = Color3.fromRGB(255, 230, 80),
}

local CHAMS_COLORS = {
    Green   = Color3.fromRGB(70, 220, 120),
    Red     = Color3.fromRGB(255, 70, 70),
    Blue    = Color3.fromRGB(80, 150, 255),
    White   = Color3.fromRGB(255, 255, 255),
    Cyan    = Color3.fromRGB(80, 220, 255),
    Magenta = Color3.fromRGB(255, 80, 220),
    Yellow  = Color3.fromRGB(255, 230, 80),
}

--// ============================================================
--// DRAWING OBJECTS
--// ============================================================
local fov_circle = Drawing_new("Circle")
fov_circle.Visible = false
fov_circle.Thickness = 2
fov_circle.Color = FOV_COLORS.White
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
    if not hum then return nil end
    if hum.Health <= 0 then return nil end

    local root = hum.RootPart
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("LowerTorso")
        or char.PrimaryPart

    if not root then
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then root = p; break end
        end
    end
    if not root then return nil end

    return char, hum, root
end

local function get_target_part(player, part_name)
    local char = player.Character
    if not char then return nil end

    local candidates = { part_name, "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso" }
    for _, name in ipairs(candidates) do
        if name then
            local p = char:FindFirstChild(name)
            if p and p:IsA("BasePart") then return p end
        end
    end

    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then return p end
    end
    return nil
end

--// ============================================================
--// ALLY WHITELIST
--// ============================================================
local ignore_lower = {}
local function rebuild_ignore_lower()
    ignore_lower = {}
    for name in pairs(State.Aimbot.IgnoreList) do
        ignore_lower[string.lower(name)] = true
    end
end
rebuild_ignore_lower()

local function is_ally(player)
    return ignore_lower[string.lower(player.Name)] == true
end

--// ============================================================
--// AIM KEY
--// ============================================================
local AIM_KEY_MAP = {
    ["RMB"]   = { kind = "mouse", code = Enum.UserInputType.MouseButton2 },
    ["LMB"]   = { kind = "mouse", code = Enum.UserInputType.MouseButton1 },
    ["E"]     = { kind = "key",   code = Enum.KeyCode.E },
    ["Q"]     = { kind = "key",   code = Enum.KeyCode.Q },
    ["Shift"] = { kind = "key",   code = Enum.KeyCode.LeftShift },
    ["C"]     = { kind = "key",   code = Enum.KeyCode.C },
}

local function is_aim_key_held()
    local k = State.Aimbot.AimKey
    if k == "Always" then return true end
    local cfg = AIM_KEY_MAP[k]
    if not cfg then return true end
    if cfg.kind == "mouse" then
        return UserInputService:IsMouseButtonPressed(cfg.code)
    end
    return UserInputService:IsKeyDown(cfg.code)
end

--// ============================================================
--// VISIBLE CHECK
--// ============================================================
local RAY_EXCLUDE
pcall(function() RAY_EXCLUDE = Enum.RaycastFilterType.Exclude end)
if not RAY_EXCLUDE then
    RAY_EXCLUDE = Enum.RaycastFilterType.Blacklist
end

local ray_params = RaycastParams.new()
ray_params.FilterType = RAY_EXCLUDE
ray_params.IgnoreWater = true
ray_params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }

local function is_target_visible(target_char, target_part)
    if not State.Aimbot.VisibleCheck then return true end
    ray_params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    local origin = Camera.CFrame.Position
    local dir = target_part.Position - origin
    local result = workspace:Raycast(origin, dir, ray_params)
    if not result then return true end
    return result.Instance:IsDescendantOf(target_char)
end

--// ============================================================
--// VELOCITY
--// ============================================================
local function get_part_velocity(part)
    if not part then return Vector3.zero end
    local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
    if ok and typeof(v) == "Vector3" then return v end
    return part.Velocity or Vector3.zero
end

--// ============================================================
--// AUTO FIRE
--// ============================================================
local VIM
pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)

local last_shot = 0
local function fire_mouse_click(delay_override)
    local now = tick() * 1000
    local min_delay = delay_override or State.Aimbot.AutoFireDelay
    if now - last_shot < min_delay then return end
    last_shot = now

    if mouse1click then
        pcall(mouse1click)
        return
    end
    if mouse1press and mouse1release then
        pcall(mouse1press)
        pcall(function() task.wait(0.01) end)
        pcall(mouse1release)
        return
    end
    if VIM then
        pcall(function()
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    end
end

--// ============================================================
--// SILENT AIM
--// ============================================================
local silent_original = nil
local silent_hooked = false

local get_closest_target_silent = nil

local function install_silent_hook()
    if silent_hooked then return true end
    if not hookmetamethod or not getnamecallmethod then return false end

    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local orig = mt.__namecall
        silent_original = orig
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if State.Silent.Enabled
               and (method == "FireServer" or method == "InvokeServer")
               and self and self.Parent and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local args = { ... }
                for i, arg in ipairs(args) do
                    if typeof(arg) == "CFrame" then
                        local target = get_closest_target_silent and get_closest_target_silent()
                        if target then
                            local part = get_target_part(target, State.Silent.TargetPart)
                            if part then
                                if math.random(1, 100) <= State.Silent.HitChance then
                                    local dir = (part.Position - arg.Position).Unit
                                    args[i] = CFrame.new(arg.Position, arg.Position + dir)
                                end
                            end
                        end
                        return silent_original(self, unpack(args))
                    elseif typeof(arg) == "Vector3" then
                        local target = get_closest_target_silent and get_closest_target_silent()
                        if target then
                            local part = get_target_part(target, State.Silent.TargetPart)
                            if part then
                                if math.random(1, 100) <= State.Silent.HitChance then
                                    local origin = Camera.CFrame.Position
                                    args[i] = (part.Position - origin).Unit
                                end
                            end
                        end
                        return silent_original(self, unpack(args))
                    end
                end
            end
            return silent_original(self, ...)
        end)

        setreadonly(mt, true)
        silent_hooked = true
    end)

    return ok and silent_hooked
end

local function uninstall_silent_hook()
    if not silent_hooked then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = silent_original
        setreadonly(mt, true)
    end)
    silent_hooked = false
end

--// ============================================================
--// HITBOX EXPANDER
--// ============================================================
-- guarda size original por [part] = Vector3 para restaurar
local hitbox_original = {}

local function expand_hitboxes()
    if not State.Aimbot.HitboxEnabled then return end

    local size = State.Aimbot.HitboxSize
    local part_name = State.Aimbot.HitboxPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local part = char:FindFirstChild(part_name)
        if part and part:IsA("BasePart") then
            if not hitbox_original[part] then
                hitbox_original[part] = part.Size
            end
            part.Size = Vector3.new(size, size, size)
            -- para que la hitbox no empuje al jugador ni colisione
            pcall(function()
                part.Massless = true
                part.CanCollide = false
            end)
        end
    end
end

local function reset_hitboxes()
    for part, orig_size in pairs(hitbox_original) do
        pcall(function()
            if part and part.Parent then
                part.Size = orig_size
                part.CanCollide = true
            end
        end)
    end
    hitbox_original = {}
end

-- re-aplicar sobre nuevos characters
track(Players.PlayerAdded:Connect(function(player)
    track(player.CharacterAdded:Connect(function()
        task.wait(1)
        if State.Aimbot.HitboxEnabled then expand_hitboxes() end
    end))
end))

--// ============================================================
--// FOV CIRCLE
--// ============================================================
local function update_fov()
    if State.Aimbot.ShowFOV then
        fov_circle.Visible = true
        fov_circle.Radius = State.Aimbot.FOV
        fov_circle.Color = FOV_COLORS[State.Aimbot.FOVColor] or FOV_COLORS.White
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
        if is_ally(player) then continue end

        local char, hum, root = get_character(player)
        if not char then continue end

        local part = get_target_part(player, State.Aimbot.TargetPart)
        if not part then continue end

        if not is_target_visible(char, part) then continue end

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

get_closest_target_silent = function()
    local closest = nil
    local shortest = State.Aimbot.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if is_ally(player) then continue end
        local char, hum, root = get_character(player)
        if not char then continue end
        local part = get_target_part(player, State.Silent.TargetPart)
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

local function is_crosshair_on_enemy()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local tol = 15
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if is_ally(player) then continue end
        local char, hum, root = get_character(player)
        if not char then continue end
        local part = get_target_part(player, State.Aimbot.TargetPart)
        if not part then continue end
        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist > State.Aimbot.Distance then continue end
        local screen_pos, on_screen = world_to_screen(part.Position)
        if not on_screen then continue end
        if (screen_pos - center).Magnitude <= tol then
            return true
        end
    end
    return false
end

track(RunService.RenderStepped:Connect(function()
    update_fov()

    if not State.Aimbot.Enabled then return end
    if not is_aim_key_held() then return end

    local target = get_closest_target()

    if State.Aimbot.AutoFire and target then
        fire_mouse_click()
    end

    if not target then return end

    local part = get_target_part(target, State.Aimbot.TargetPart)
    if not part then return end

    local target_pos = part.Position
    if State.Aimbot.PredictionEnabled then
        local vel = get_part_velocity(part)
        target_pos = target_pos + vel * State.Aimbot.PredictionAmount
    end

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

track(RunService.RenderStepped:Connect(function()
    if not State.Aimbot.TriggerBot then return end
    if is_crosshair_on_enemy() then
        fire_mouse_click(State.Aimbot.TriggerBotDelay)
    end
end))

-- Hitbox loop (re-aplica cada frame por si el juego resetea Size)
track(RunService.RenderStepped:Connect(function()
    if State.Aimbot.HitboxEnabled then
        expand_hitboxes()
    end
end))

--// ============================================================
--// ESP
--// ============================================================
local SKELETON_BONES_R15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local SKELETON_BONES_R6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"}, {"Left Arm", "Left Hand"},
    {"Torso", "Right Arm"}, {"Right Arm", "Right Hand"},
    {"Torso", "Left Leg"}, {"Left Leg", "Left Foot"},
    {"Torso", "Right Leg"}, {"Right Leg", "Right Foot"},
}

local function create_esp(player)
    if esp_cache[player] then return end
    local drawings = {
        box    = Drawing_new("Square"),
        tracer = Drawing_new("Line"),
        name   = Drawing_new("Text"),
        health = Drawing_new("Text"),
        dist   = Drawing_new("Text"),
        head_dot = Drawing_new("Circle"),
        skeleton = {},
        chams = nil,
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

    drawings.head_dot.Thickness = 2
    drawings.head_dot.Radius = 6
    drawings.head_dot.Filled = false
    drawings.head_dot.Color = Color3.fromRGB(70, 220, 120)
    drawings.head_dot.Transparency = 0.2

    for i = 1, 16 do
        local line = Drawing_new("Line")
        line.Thickness = 1
        line.Color = State.ESP.SkeletonColor
        line.Transparency = 0.4
        line.Visible = false
        drawings.skeleton[i] = line
    end

    pcall(function()
        local h = Instance.new("Highlight")
        h.Name = "AIMFUNNY_Chams"
        h.FillTransparency = 0.5
        h.OutlineTransparency = 0
        h.FillColor = CHAMS_COLORS[State.ESP.ChamsColor] or CHAMS_COLORS.Green
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Enabled = false
        h.Parent = gui
        drawings.chams = h
    end)

    esp_cache[player] = drawings
end

local function remove_esp(player)
    local d = esp_cache[player]
    if not d then return end
    for key, obj in pairs(d) do
        if key == "skeleton" then
            for _, line in ipairs(obj) do pcall(function() line:Remove() end) end
        elseif key == "chams" then
            pcall(function() obj:Destroy() end)
        else
            pcall(function() obj:Remove() end)
        end
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
            for key, obj in pairs(d) do
                if key == "skeleton" then
                    for _, line in ipairs(obj) do line.Visible = false end
                elseif key == "chams" then
                    -- skip
                else
                    obj.Visible = false
                end
            end
        end
        return
    end

    for player, d in pairs(esp_cache) do
        if State.ESP.HideAllies and is_ally(player) then
            for key, obj in pairs(d) do
                if key == "skeleton" then
                    for _, line in ipairs(obj) do line.Visible = false end
                elseif key == "chams" then
                    -- skip
                else
                    obj.Visible = false
                end
            end
            continue
        end

        local char, hum, root = get_character(player)
        if not char then
            for key, obj in pairs(d) do
                if key == "skeleton" then
                    for _, line in ipairs(obj) do line.Visible = false end
                elseif key == "chams" then
                    -- skip
                else
                    obj.Visible = false
                end
            end
            continue
        end

        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist > State.ESP.MaxDist then
            for key, obj in pairs(d) do
                if key == "skeleton" then
                    for _, line in ipairs(obj) do line.Visible = false end
                elseif key == "chams" then
                    -- skip
                else
                    obj.Visible = false
                end
            end
            continue
        end

        local head = get_target_part(player, "Head") or root
        local head_pos, on_screen = world_to_screen(head.Position)
        local root_pos = world_to_screen(root.Position)

        if not on_screen then
            for key, obj in pairs(d) do
                if key == "skeleton" then
                    for _, line in ipairs(obj) do line.Visible = false end
                elseif key == "chams" then
                    -- skip
                else
                    obj.Visible = false
                end
            end
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
        local max_hp = math.max(1, math.floor(hum.MaxHealth))
        d.health.Text = "HP: " .. hp .. "/" .. max_hp
        d.health.Position = head_pos + Vector2.new(0, 5)
        d.health.Color = Color3.fromRGB(255 - (hp / max_hp * 255), hp / max_hp * 255, 0)
        d.health.Visible = State.ESP.Health

        d.dist.Text = math.floor(dist) .. " studs"
        d.dist.Position = head_pos + Vector2.new(0, 20)
        d.dist.Visible = State.ESP.Distance

        d.head_dot.Position = head_pos
        d.head_dot.Visible = State.ESP.HeadDot

        if State.ESP.Skeleton then
            local bones = char:FindFirstChild("UpperTorso") and SKELETON_BONES_R15 or SKELETON_BONES_R6
            local idx = 0
            for _, pair in ipairs(bones) do
                local a = char:FindFirstChild(pair[1])
                local b = char:FindFirstChild(pair[2])
                if a and b then
                    idx += 1
                    local line = d.skeleton[idx]
                    if line then
                        local a_screen, a_on = world_to_screen(a.Position)
                        local b_screen, b_on = world_to_screen(b.Position)
                        if a_on and b_on then
                            line.From = a_screen
                            line.To = b_screen
                            line.Color = State.ESP.SkeletonColor
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    end
                end
            end
            for i = idx + 1, #d.skeleton do
                d.skeleton[i].Visible = false
            end
        else
            for _, line in ipairs(d.skeleton) do line.Visible = false end
        end
    end
end))

-- Chams loop
track(RunService.RenderStepped:Connect(function()
    if not State.ESP.Chams then
        for _, d in pairs(esp_cache) do
            if d.chams then d.chams.Enabled = false end
        end
        return
    end

    local color = CHAMS_COLORS[State.ESP.ChamsColor] or CHAMS_COLORS.Green
    local depth = (State.ESP.ChamsMode == "Through Walls")
        and Enum.HighlightDepthMode.AlwaysOnTop
        or  Enum.HighlightDepthMode.Occluded

    for player, d in pairs(esp_cache) do
        if not d.chams then continue end

        local skip = false
        if State.ESP.HideAllies and is_ally(player) then skip = true end

        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then
            d.chams.Enabled = false
            continue
        end

        if skip then
            d.chams.Enabled = false
            continue
        end

        pcall(function()
            d.chams.Adornee = char
            d.chams.FillColor = color
            d.chams.DepthMode = depth
            d.chams.Enabled = true
        end)
    end
end))

--// ============================================================
--// FLY + NOCLIP + SPEED BOOST
--// ============================================================
local fly_bv = nil

local function stop_fly()
    if fly_bv then
        pcall(function() fly_bv:Destroy() end)
        fly_bv = nil
    end
end

local function start_fly()
    stop_fly()
    local char = LocalPlayer.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if not root then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    fly_bv = bv
end

track(RunService.RenderStepped:Connect(function()
    if State.Player.Fly then
        local char = LocalPlayer.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if root then
            if not fly_bv or fly_bv.Parent ~= root then
                start_fly()
            end
            if fly_bv then
                local move = Vector3.zero
                local look = Camera.CFrame.LookVector
                local right = Camera.CFrame.RightVector
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end
                if move.Magnitude > 0 then
                    fly_bv.Velocity = move.Unit * State.Player.FlySpeed
                else
                    fly_bv.Velocity = Vector3.zero
                end
            end
        end
    else
        if fly_bv then stop_fly() end
    end

    if State.Player.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
    end

    if State.Player.SpeedBoost then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                local target_speed = State.Player.Walkspeed * State.Player.SpeedMultiplier
                if hum.WalkSpeed ~= target_speed then hum.WalkSpeed = target_speed end
            else
                if hum.WalkSpeed ~= State.Player.Walkspeed then hum.WalkSpeed = State.Player.Walkspeed end
            end
        end
    end
end))

track(LocalPlayer.CharacterAdded:Connect(function()
    stop_fly()
end))

--// ============================================================
--// ANTI-AFK + AUTO RESPAWN + ANTI-FLING
--// ============================================================
do
    local vu = game:GetService("VirtualUser")
    track(LocalPlayer.Idled:Connect(function()
        if not State.Misc.AntiAFK then return end
        pcall(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.5)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end))
end

local function hook_auto_respawn(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    track(hum.Died:Connect(function()
        if not State.Misc.AutoRespawn then return end
        task.wait(0.5)
        pcall(function() LocalPlayer:LoadCharacter() end)
    end))
end

if LocalPlayer.Character then
    task.spawn(hook_auto_respawn, LocalPlayer.Character)
end
track(LocalPlayer.CharacterAdded:Connect(hook_auto_respawn))

-- Anti-Fling: escanea partes del character y limpia velocidades anormales
track(RunService.Heartbeat:Connect(function()
    if not State.Misc.AntiFling then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                if p.Velocity.Magnitude > 200 then p.Velocity = Vector3.zero end
                if not p.Massless and p.Name ~= "HumanoidRootPart" then
                    -- solo las partes no root se vuelven massless para romper el fling
                    p.Massless = true
                end
            end)
        end
    end
end))

--// ============================================================
--// WATERMARK
--// ============================================================
local wm_gui = Instance.new("ScreenGui")
wm_gui.Name = "AIMFUNNY_Watermark"
wm_gui.ResetOnSpawn = false
wm_gui.IgnoreGuiInset = true
wm_gui.DisplayOrder = 999
pcall(function() wm_gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)

local wm_frame = Instance.new("Frame")
wm_frame.Size = UDim2.fromOffset(220, 26)
wm_frame.Position = UDim2.new(0, 12, 0, 12)
wm_frame.BackgroundColor3 = THEME.Bg
wm_frame.BackgroundTransparency = 0.15
wm_frame.BorderSizePixel = 0
wm_frame.Visible = false
wm_frame.Active = true
wm_frame.Parent = wm_gui

local wm_corner = Instance.new("UICorner")
wm_corner.CornerRadius = UDim.new(0, 6)
wm_corner.Parent = wm_frame

local wm_stroke = Instance.new("UIStroke")
wm_stroke.Color = THEME.Accent
wm_stroke.Thickness = 1
wm_stroke.Parent = wm_frame

local wm_label = Instance.new("TextLabel")
wm_label.Size = UDim2.new(1, -12, 1, 0)
wm_label.Position = UDim2.new(0, 6, 0, 0)
wm_label.BackgroundTransparency = 1
wm_label.Text = "AIMFUNNY"
wm_label.TextColor3 = THEME.Text
wm_label.TextSize = 12
wm_label.Font = Enum.Font.GothamBold
wm_label.TextXAlignment = Enum.TextXAlignment.Left
wm_label.Parent = wm_frame

local fps_count, fps_last = 0, os.clock()
local fps_value = 0
track(RunService.RenderStepped:Connect(function()
    fps_count += 1
    if os.clock() - fps_last >= 1 then
        fps_value = fps_count
        fps_count = 0
        fps_last = os.clock()
    end

    if State.Watermark.Enabled then
        wm_frame.Visible = true
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        wm_label.Text = string.format("%s  |  %d FPS  |  %dms",
            State.Watermark.Text, fps_value, ping)
    else
        wm_frame.Visible = false
    end
end))

do
    local dragging, drag_start, start_pos = false, nil, nil
    wm_frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            drag_start = i.Position
            start_pos = wm_frame.Position
        end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                         or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - drag_start
            wm_frame.Position = UDim2.new(
                start_pos.X.Scale, start_pos.X.Offset + d.X,
                start_pos.Y.Scale, start_pos.Y.Offset + d.Y
            )
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

--// ============================================================
--// SAVE / LOAD / RESET CONFIG
--// ============================================================
local CONFIG_PATH = "aimfunny_config.json"

local function serialize_value(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts+1] = "[" .. serialize_value(k) .. "]=" .. serialize_value(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

local function save_config()
    if not writefile then return false end
    local snapshot = {
        Aimbot = State.Aimbot,
        Silent = State.Silent,
        ESP = State.ESP,
        Player = State.Player,
        Misc = State.Misc,
        Watermark = State.Watermark,
        Menu = State.Menu,
    }
    snapshot.Aimbot.IgnoreList = State.Aimbot.IgnoreList
    local ok = pcall(function()
        writefile(CONFIG_PATH, serialize_value(snapshot))
    end)
    return ok
end

local function load_config()
    if not readfile or not isfile then return false end
    if not isfile(CONFIG_PATH) then return false end
    local ok, data = pcall(function()
        local raw = readfile(CONFIG_PATH)
        return loadstring("return " .. raw)()
    end)
    if not ok or type(data) ~= "table" then return false end

    for section, values in pairs(data) do
        if State[section] and type(values) == "table" then
            for k, v in pairs(values) do
                if State[section][k] ~= nil then
                    State[section][k] = v
                end
            end
        end
    end
    rebuild_ignore_lower()
    return true
end

-- Reset: limpia config en disco + unload (para reiniciar limpio)
local function reset_config()
    pcall(function()
        if delfile and isfile and isfile(CONFIG_PATH) then
            delfile(CONFIG_PATH)
        end
    end)
    if unload then unload() end
end

--// ============================================================
--// HELPERS DE GUI
--// ============================================================
local order = 0
local function nxt()
    order += 1
    return order
end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function stroke(o, color, thickness)
    return new("UIStroke", {
        Color = color or THEME.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end

local function tw(o, props, t)
    TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function text_label(parent, str, size, color, font)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = str,
        TextSize = size or 13,
        TextColor3 = color or THEME.Text,
        Font = font or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function is_press(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch
end

local function is_move(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch
end

local function make_draggable(handle, target)
    local dragging, drag_start, start_pos, moved = false, nil, nil, false
    handle.InputBegan:Connect(function(i)
        if is_press(i) then
            dragging = true
            moved = false
            drag_start = i.Position
            start_pos = target.Position
        end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and is_move(i) then
            local d = i.Position - drag_start
            if d.Magnitude > 4 then moved = true end
            target.Position = UDim2.new(
                start_pos.X.Scale, start_pos.X.Offset + d.X,
                start_pos.Y.Scale, start_pos.Y.Offset + d.Y
            )
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if is_press(i) then dragging = false end
    end))
    return function() return moved end
end

--// ============================================================
--// VENTANA
--// ============================================================
local gui_parent = (gethui and gethui()) or game:GetService("CoreGui")
local function make_screengui(name, order_value)
    local g = new("ScreenGui", {
        Name = name,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = order_value,
    })
    local ok = pcall(function() g.Parent = gui_parent end)
    if not ok then g.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    return g
end

local gui = make_screengui("AIMFUNNY_GUI", 1000)
local float_gui = make_screengui("AIMFUNNY_Float", 1001)
float_gui.Enabled = true

local main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(580, 380),
    Position = UDim2.new(0.5, -290, 0.5, -190),
    BackgroundColor3 = THEME.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
}, gui)
corner(main, 10)
stroke(main)

local titlebar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = THEME.Side,
    BorderSizePixel = 0,
}, main)

new("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.new(0, 14, 0.5, -4),
    BackgroundColor3 = THEME.Accent,
    BorderSizePixel = 0,
}, titlebar)
corner(titlebar:FindFirstChildOfClass("Frame"), 4)

local title = text_label(titlebar, "AIMFUNNY", 14, THEME.Text, Enum.Font.GothamBold)
title.Position = UDim2.new(0, 30, 0, 0)
title.Size = UDim2.new(0, 120, 1, 0)

local version = text_label(titlebar, "v2.1", 11, THEME.Sub)
version.Position = UDim2.new(0, 104, 0, 1)
version.Size = UDim2.new(0, 40, 1, 0)

new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = THEME.Stroke,
    BorderSizePixel = 0,
}, titlebar)

local function title_button(str, x_offset, hover_color)
    local b = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, x_offset, 0.5, 0),
        Size = UDim2.fromOffset(28, 24),
        BackgroundColor3 = THEME.Side,
        BorderSizePixel = 0,
        Text = str,
        TextColor3 = THEME.Sub,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, titlebar)
    corner(b, 6)
    b.MouseEnter:Connect(function()
        tw(b, { BackgroundColor3 = hover_color, TextColor3 = THEME.Text })
    end)
    b.MouseLeave:Connect(function()
        tw(b, { BackgroundColor3 = THEME.Side, TextColor3 = THEME.Sub })
    end)
    return b
end

local close_btn = title_button("X", -8, Color3.fromRGB(150, 40, 40))
local min_btn   = title_button("-", -40, THEME.Off)

make_draggable(titlebar, main)

local sidebar = new("Frame", {
    Position = UDim2.new(0, 0, 0, 38),
    Size = UDim2.new(0, 128, 1, -38),
    BackgroundColor3 = THEME.Side,
    BorderSizePixel = 0,
}, main)
new("UIPadding", {
    PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, sidebar)
new("UIListLayout", {
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)

new("Frame", {
    Position = UDim2.new(0, 128, 0, 38),
    Size = UDim2.new(0, 1, 1, -38),
    BackgroundColor3 = THEME.Stroke,
    BorderSizePixel = 0,
}, main)

local content = new("Frame", {
    Position = UDim2.new(0, 129, 0, 38),
    Size = UDim2.new(1, -129, 1, -38),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, main)

local grip = new("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 0, 1, 0),
    Size = UDim2.fromOffset(20, 20),
    BackgroundTransparency = 1,
    Active = true,
    ZIndex = 10,
}, main)
for i = 1, 2 do
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 3 + (i - 1) * 4, 0.5, 3 + (i - 1) * 4),
        Size = UDim2.fromOffset(i == 1 and 10 or 5, 1),
        Rotation = -45,
        BackgroundColor3 = THEME.Sub,
        BorderSizePixel = 0,
        ZIndex = 10,
    }, grip)
end

local resizing, rs_start, rs_size = false, nil, nil
grip.InputBegan:Connect(function(i)
    if is_press(i) then
        resizing = true
        rs_start = i.Position
        rs_size = main.AbsoluteSize
    end
end)
track(UserInputService.InputChanged:Connect(function(i)
    if resizing and is_move(i) then
        local d = i.Position - rs_start
        local vp = Camera.ViewportSize
        main.Size = UDim2.fromOffset(
            math.clamp(rs_size.X + d.X, MIN_W, vp.X - 40),
            math.clamp(rs_size.Y + d.Y, MIN_H, vp.Y - 40)
        )
    end
end))
track(UserInputService.InputEnded:Connect(function(i)
    if is_press(i) then resizing = false end
end))

--// ============================================================
--// COMPONENTES
--// ============================================================
local pages, tab_buttons = {}, {}

local function select_tab(name)
    for n, page in pairs(pages) do page.Visible = (n == name) end
    for n, b in pairs(tab_buttons) do
        local active = (n == name)
        tw(b, {
            BackgroundColor3 = active and THEME.Panel or THEME.Side,
            TextColor3 = active and THEME.Text or THEME.Sub,
        })
        tw(b.UIStroke, { Transparency = active and 0 or 1 })
    end
end

local function add_tab(name)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = THEME.Side,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = THEME.Sub,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = nxt(),
    }, sidebar)
    corner(b, 6)
    new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, b)
    local s = stroke(b, THEME.Accent, 1)
    s.Transparency = 1
    b.MouseButton1Click:Connect(function() select_tab(name) end)
    tab_buttons[name] = b

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Off,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, content)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14),
    }, page)
    new("UIListLayout", {
        Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    pages[name] = page
    return page
end

local function add_section(page, title_str)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.Panel,
        BorderSizePixel = 0,
        LayoutOrder = nxt(),
    }, page)
    corner(f, 8)
    stroke(f)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, f)
    new("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    }, f)
    local t = text_label(f, string.upper(title_str), 11, THEME.Sub, Enum.Font.GothamBold)
    t.Size = UDim2.new(1, 0, 0, 16)
    t.LayoutOrder = nxt()
    return f
end

local function add_toggle(sec, text, default, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder = nxt(),
    }, sec)
    local lbl = text_label(row, text, 13, THEME.Text)
    lbl.Size = UDim2.new(1, -50, 1, 0)

    local track_f = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = default and THEME.Accent or THEME.Off,
        BorderSizePixel = 0,
    }, row)
    corner(track_f, 10)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = default and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, track_f)
    corner(knob, 7)

    local state = default
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    }, row)
    btn.MouseButton1Click:Connect(function()
        state = not state
        tw(track_f, { BackgroundColor3 = state and THEME.Accent or THEME.Off })
        tw(knob, { Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
        callback(state)
    end)
end

local function add_slider(sec, text, min, max, default, decimals, callback)
    local mult = 10 ^ decimals
    local function fmt(v)
        if decimals == 0 then return tostring(v) end
        return string.format("%." .. decimals .. "f", v)
    end

    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        LayoutOrder = nxt(),
    }, sec)
    local lbl = text_label(row, text, 13, THEME.Text)
    lbl.Size = UDim2.new(1, -70, 0, 18)

    local box = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(56, 20),
        BackgroundColor3 = THEME.Bg,
        BorderSizePixel = 0,
        Text = fmt(default),
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
    }, row)
    corner(box, 5)
    stroke(box)

    local bar = new("Frame", {
        Position = UDim2.new(0, 0, 0, 31),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = THEME.Off,
        BorderSizePixel = 0,
    }, row)
    corner(bar, 3)
    local rel0 = (default - min) / (max - min)
    local fill = new("Frame", {
        Size = UDim2.new(rel0, 0, 1, 0),
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
    }, bar)
    corner(fill, 3)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(rel0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, bar)
    corner(knob, 6)

    local hit = new("TextButton", {
        Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "",
    }, row)

    local dragging = false
    local function set_from_x(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + (max - min) * rel) * mult + 0.5) / mult
        local r = (v - min) / (max - min)
        fill.Size = UDim2.new(r, 0, 1, 0)
        knob.Position = UDim2.new(r, 0, 0.5, 0)
        box.Text = fmt(v)
        callback(v)
    end

    hit.InputBegan:Connect(function(i)
        if is_press(i) then
            dragging = true
            set_from_x(i.Position.X)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and is_move(i) then set_from_x(i.Position.X) end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if is_press(i) then dragging = false end
    end))
end

local function add_dropdown(sec, text, values, default_index, callback)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nxt(),
    }, sec)
    new("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)

    local lbl = text_label(holder, text, 13, THEME.Text)
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.LayoutOrder = 1

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = THEME.Bg,
        BorderSizePixel = 0,
        Text = values[default_index],
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = 2,
    }, holder)
    corner(head, 6)
    stroke(head)
    new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, head)
    local arrow = text_label(head, "v", 11, THEME.Sub, Enum.Font.GothamBold)
    arrow.AnchorPoint = Vector2.new(1, 0)
    arrow.Position = UDim2.new(1, -4, 0, 0)
    arrow.Size = UDim2.new(0, 16, 1, 0)

    local opts = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.Bg,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 3,
    }, holder)
    corner(opts, 6)
    stroke(opts)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, opts)

    head.MouseButton1Click:Connect(function()
        opts.Visible = not opts.Visible
    end)

    for idx, v in ipairs(values) do
        local o = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = v,
            TextColor3 = THEME.Sub,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            LayoutOrder = idx,
        }, opts)
        new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, o)
        o.MouseEnter:Connect(function() tw(o, { TextColor3 = THEME.Text }) end)
        o.MouseLeave:Connect(function() tw(o, { TextColor3 = THEME.Sub }) end)
        o.MouseButton1Click:Connect(function()
            head.Text = v
            opts.Visible = false
            callback(v)
        end)
    end
end

local function add_button(sec, text, callback)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = THEME.Off,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = THEME.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        LayoutOrder = nxt(),
    }, sec)
    corner(b, 6)
    b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = THEME.Stroke }) end)
    b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = THEME.Off }) end)
    b.MouseButton1Click:Connect(callback)
end

local function add_textbox(sec, placeholder, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        LayoutOrder = nxt(),
    }, sec)

    local box = new("TextBox", {
        Size = UDim2.new(1, -66, 1, 0),
        BackgroundColor3 = THEME.Bg,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = THEME.Sub,
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, row)
    corner(box, 5)
    stroke(box)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)

    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(58, 32),
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
        Text = "Add",
        TextColor3 = Color3.fromRGB(20, 20, 20),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, row)
    corner(btn, 5)

    local function commit()
        local name = box.Text:gsub("^%s*(.-)%s*$", "%1")
        if #name > 0 then
            callback(name)
            box.Text = ""
        end
    end

    btn.MouseButton1Click:Connect(commit)
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then commit() end
    end)
end

local function add_textbox_action(sec, placeholder, btn_text, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        LayoutOrder = nxt(),
    }, sec)

    local box = new("TextBox", {
        Size = UDim2.new(1, -76, 1, 0),
        BackgroundColor3 = THEME.Bg,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = THEME.Sub,
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, row)
    corner(box, 5)
    stroke(box)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)

    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(68, 32),
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
        Text = btn_text,
        TextColor3 = Color3.fromRGB(20, 20, 20),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, row)
    corner(btn, 5)

    btn.MouseButton1Click:Connect(function()
        local name = box.Text:gsub("^%s*(.-)%s*$", "%1")
        if #name > 0 then callback(name) end
    end)
end

--// ============================================================
--// UNLOAD / MINIMIZAR / RESTAURAR
--// ============================================================
local function unload()
    -- NUEVO: auto-save antes de salir
    if State.Misc.AutoSaveOnUnload then
        pcall(save_config)
    end

    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}

    for _, d in pairs(esp_cache) do
        for key, obj in pairs(d) do
            if key == "skeleton" then
                for _, line in ipairs(obj) do pcall(function() line:Remove() end) end
            elseif key == "chams" then
                pcall(function() obj:Destroy() end)
            else
                pcall(function() obj:Remove() end)
            end
        end
    end
    esp_cache = {}
    pcall(function() fov_circle:Remove() end)
    stop_fly()
    reset_hitboxes()
    uninstall_silent_hook()

    pcall(function() gui:Destroy() end)
    pcall(function() float_gui:Destroy() end)
    pcall(function() wm_gui:Destroy() end)
    State.Unload = nil
end
State.Unload = unload

--// ============================================================
--// BOTON FLOTANTE
--// ============================================================
local FS = 48
local float_btn = new("TextButton", {
    Size = UDim2.fromOffset(FS, FS),
    Position = UDim2.new(0, 20, 0.5, 40),
    BackgroundColor3 = THEME.Bg,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
}, float_gui)
corner(float_btn, FS / 2)
stroke(float_btn, THEME.Accent, 2)

local ring = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(28, 28),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, float_btn)
corner(ring, 14)
new("UIStroke", {
    Color = Color3.fromRGB(235, 235, 235),
    Thickness = 2,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, ring)

new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(34, 2),
    BackgroundColor3 = Color3.fromRGB(235, 235, 235),
    BorderSizePixel = 0,
}, float_btn)
new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(2, 34),
    BackgroundColor3 = Color3.fromRGB(235, 235, 235),
    BorderSizePixel = 0,
}, float_btn)

local dot = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = THEME.Accent,
    BorderSizePixel = 0,
}, float_btn)
corner(dot, 3)

for _, cfg in ipairs({
    { UDim2.new(0.5, 0, 0.5, -20), UDim2.fromOffset(4, 8) },
    { UDim2.new(0.5, 0, 0.5, 20),  UDim2.fromOffset(4, 8) },
    { UDim2.new(0.5, -20, 0.5, 0), UDim2.fromOffset(8, 4) },
    { UDim2.new(0.5, 20, 0.5, 0),  UDim2.fromOffset(8, 4) },
}) do
    local m = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = cfg[1],
        Size = cfg[2],
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
    }, float_btn)
    corner(m, 2)
end

local float_moved = make_draggable(float_btn, float_btn)

local minimized = false
local function minimize()
    minimized = true
    main.Visible = false
end
local function restore()
    minimized = false
    main.Visible = true
end

min_btn.MouseButton1Click:Connect(minimize)
close_btn.MouseButton1Click:Connect(unload)
float_btn.MouseButton1Click:Connect(function()
    if not float_moved() then
        if minimized then restore() else minimize() end
    end
end)

local MENU_KEY_MAP = {
    ["RightShift"] = Enum.KeyCode.RightShift,
    ["LeftShift"]  = Enum.KeyCode.LeftShift,
    ["F1"]         = Enum.KeyCode.F1,
    ["F2"]         = Enum.KeyCode.F2,
    ["F3"]         = Enum.KeyCode.F3,
    ["F4"]         = Enum.KeyCode.F4,
    ["P"]          = Enum.KeyCode.P,
    ["Insert"]     = Enum.KeyCode.Insert,
}

track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = MENU_KEY_MAP[State.Menu.Key]
    if key and input.KeyCode == key then
        if minimized then restore() else minimize() end
    end
end))

--// ============================================================
--// PESTANAS
--// ============================================================
local aim_page = add_tab("Aimbot")
local silent_page = add_tab("Silent")
local vis_page = add_tab("Visuals")
local move_page = add_tab("Movement")
local misc_page = add_tab("Misc")
local set_page = add_tab("Settings")

-- Aimbot
local aim = add_section(aim_page, "Aimbot configuration")
add_toggle(aim, "Enable Aimbot", false, function(v) State.Aimbot.Enabled = v end)
add_slider(aim, "FOV", 10, 500, 120, 0, function(v) State.Aimbot.FOV = v end)
add_slider(aim, "Max Distance", 50, 2000, 500, 0, function(v) State.Aimbot.Distance = v end)
add_toggle(aim, "Show FOV Circle", false, function(v) State.Aimbot.ShowFOV = v end)
add_slider(aim, "Smoothness", 0.01, 1, 0.15, 2, function(v) State.Aimbot.Smoothness = v end)
add_toggle(aim, "Mouse Follow", false, function(v) State.Aimbot.MouseFollow = v end)
add_dropdown(aim, "Target Part", { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" }, 1,
    function(v) State.Aimbot.TargetPart = v end)

-- NUEVO: FOV Circle color
local fovc = add_section(aim_page, "FOV Circle")
add_dropdown(fovc, "FOV Circle Color",
    { "White", "Green", "Red", "Blue", "Cyan", "Magenta", "Yellow" }, 1,
    function(v) State.Aimbot.FOVColor = v end)

local ak = add_section(aim_page, "Aim Key")
add_dropdown(ak, "Hold Key", { "Always", "RMB", "LMB", "E", "Q", "Shift", "C" }, 1,
    function(v) State.Aimbot.AimKey = v end)

local pred = add_section(aim_page, "Prediction")
add_toggle(pred, "Enable Prediction", false, function(v) State.Aimbot.PredictionEnabled = v end)
add_slider(pred, "Prediction Amount", 0, 0.5, 0.15, 2, function(v) State.Aimbot.PredictionAmount = v end)

local vis = add_section(aim_page, "Visibility")
add_toggle(vis, "Visible Check", false, function(v) State.Aimbot.VisibleCheck = v end)

local af = add_section(aim_page, "Auto Fire")
add_toggle(af, "Enable Auto Fire", false, function(v) State.Aimbot.AutoFire = v end)
add_slider(af, "Fire Delay (ms)", 10, 500, 100, 0, function(v) State.Aimbot.AutoFireDelay = v end)

local tb = add_section(aim_page, "Trigger Bot")
add_toggle(tb, "Enable Trigger Bot", false, function(v) State.Aimbot.TriggerBot = v end)
add_slider(tb, "Trigger Delay (ms)", 10, 500, 50, 0, function(v) State.Aimbot.TriggerBotDelay = v end)

-- NUEVO: Hitbox Expander
local hb = add_section(aim_page, "Hitbox Expander")
add_toggle(hb, "Enable Hitbox Expander", false, function(v)
    State.Aimbot.HitboxEnabled = v
    if not v then reset_hitboxes() end
end)
add_slider(hb, "Hitbox Size", 1, 20, 5, 1, function(v) State.Aimbot.HitboxSize = v end)
add_dropdown(hb, "Hitbox Part", { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" }, 1,
    function(v)
        reset_hitboxes()
        State.Aimbot.HitboxPart = v
    end)

local wl = add_section(aim_page, "Ally Whitelist")
local wl_hint = text_label(wl, "Nombres a ignorar por el aimbot", 11, THEME.Sub)
wl_hint.Size = UDim2.new(1, 0, 0, 14)
wl_hint.LayoutOrder = nxt()

local wl_display
local function refresh_wl_display()
    if not wl_display then return end
    local names = {}
    for name in pairs(State.Aimbot.IgnoreList) do table.insert(names, name) end
    table.sort(names)
    wl_display.Text = (#names == 0) and "Lista vacia" or table.concat(names, ", ")
end

add_textbox(wl, "Escribe un nombre y Enter", function(name)
    State.Aimbot.IgnoreList[name] = true
    rebuild_ignore_lower()
    refresh_wl_display()
end)

wl_display = text_label(wl, "Lista vacia", 12, THEME.Sub)
wl_display.Size = UDim2.new(1, 0, 0, 0)
wl_display.AutomaticSize = Enum.AutomaticSize.Y
wl_display.TextWrapped = true
wl_display.LayoutOrder = nxt()

add_button(wl, "Limpiar lista", function()
    State.Aimbot.IgnoreList = {}
    rebuild_ignore_lower()
    refresh_wl_display()
end)

-- Silent
local si = add_section(silent_page, "Silent Aim")
add_toggle(si, "Enable Silent Aim", false, function(v)
    State.Silent.Enabled = v
    if v then
        local ok = install_silent_hook()
        if not ok then
            State.Silent.Enabled = false
        end
    else
        uninstall_silent_hook()
    end
end)
add_slider(si, "Hit Chance %", 1, 100, 100, 0, function(v) State.Silent.HitChance = v end)
add_dropdown(si, "Silent Target Part", { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" }, 1,
    function(v) State.Silent.TargetPart = v end)

local si_info = text_label(silent_page, "Nota: si tu executor no soporta hookmetamethod,\nesta funcion no hara nada. El resto sigue funcionando.",
    11, THEME.Sub)
si_info.Size = UDim2.new(1, 0, 0, 30)
si_info.TextWrapped = true
si_info.LayoutOrder = nxt()

-- Visuals
local esp = add_section(vis_page, "ESP functions")
add_toggle(esp, "Enable ESP", false, function(v) State.ESP.Enabled = v end)
add_toggle(esp, "Tracers", true, function(v) State.ESP.Tracers = v end)
add_toggle(esp, "Boxes", true, function(v) State.ESP.Boxes = v end)
add_toggle(esp, "Names", true, function(v) State.ESP.Names = v end)
add_toggle(esp, "Health", true, function(v) State.ESP.Health = v end)
add_toggle(esp, "Distance (studs)", true, function(v) State.ESP.Distance = v end)
add_slider(esp, "Max Render Distance", 100, 5000, 1000, 0, function(v) State.ESP.MaxDist = v end)

local espf = add_section(vis_page, "ESP Filters")
add_toggle(espf, "Hide Allies in ESP", false, function(v) State.ESP.HideAllies = v end)

local espx = add_section(vis_page, "ESP Extras")
add_toggle(espx, "Head Dot", false, function(v) State.ESP.HeadDot = v end)
add_toggle(espx, "Skeleton", false, function(v) State.ESP.Skeleton = v end)

local chams = add_section(vis_page, "Chams")
add_toggle(chams, "Enable Chams", false, function(v) State.ESP.Chams = v end)
add_dropdown(chams, "Chams Color",
    { "Green", "Red", "Blue", "White", "Cyan", "Magenta", "Yellow" }, 1,
    function(v) State.ESP.ChamsColor = v end)
add_dropdown(chams, "Chams Mode", { "Through Walls", "Occluded" }, 1,
    function(v) State.ESP.ChamsMode = v end)

-- Movement
local move = add_section(move_page, "Movement")

local function apply_walkspeed(v)
    State.Player.Walkspeed = v
    if not State.Player.SpeedBoost then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end

local function apply_jumppower(v)
    State.Player.JumpPower = v
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end

add_slider(move, "Walkspeed", 0, 500, 16, 0, apply_walkspeed)
add_slider(move, "JumpPower", 0, 500, 50, 0, apply_jumppower)

track(LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    if State.Player.SpeedBoost then
        hum.WalkSpeed = State.Player.Walkspeed
    end
    hum.UseJumpPower = true
    hum.JumpPower = State.Player.JumpPower
end))

local jmp = add_section(move_page, "Jump")
add_toggle(jmp, "Infinite Jump", false, function(v) State.Player.InfiniteJump = v end)

track(UserInputService.JumpRequest:Connect(function()
    if not State.Player.InfiniteJump then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

local fly = add_section(move_page, "Fly")
add_toggle(fly, "Enable Fly", false, function(v)
    State.Player.Fly = v
    if not v then stop_fly() end
end)
add_slider(fly, "Fly Speed", 10, 300, 50, 0, function(v) State.Player.FlySpeed = v end)

local nc = add_section(move_page, "Collision")
add_toggle(nc, "Noclip", false, function(v)
    State.Player.Noclip = v
    if not v then
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end)
add_toggle(nc, "Speed Boost (hold Shift)", false, function(v) State.Player.SpeedBoost = v end)
add_slider(nc, "Speed Multiplier", 1, 5, 2, 1, function(v) State.Player.SpeedMultiplier = v end)

local tp = add_section(move_page, "Teleport")
add_textbox_action(tp, "Nombre exacto del jugador", "Go", function(name)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and string.lower(plr.Name) == string.lower(name) then
            local my_char = LocalPlayer.Character
            local my_root = my_char and (my_char:FindFirstChild("HumanoidRootPart") or my_char.PrimaryPart)
            local target_char = plr.Character
            local target_root = target_char and (target_char:FindFirstChild("HumanoidRootPart") or target_char.PrimaryPart)
            if my_root and target_root then
                my_root.CFrame = target_root.CFrame + Vector3.new(0, 3, 0)
            end
            return
        end
    end
end)

-- Misc
local misc = add_section(misc_page, "Utility")
add_toggle(misc, "Anti-AFK", false, function(v) State.Misc.AntiAFK = v end)
add_toggle(misc, "Auto Respawn", false, function(v) State.Misc.AutoRespawn = v end)
add_toggle(misc, "Anti-Fling", false, function(v) State.Misc.AntiFling = v end)

local misc_cfg = add_section(misc_page, "Config")
add_toggle(misc_cfg, "Auto-Save on Unload", true, function(v) State.Misc.AutoSaveOnUnload = v end)

-- Settings
local menu = add_section(set_page, "Menu")
add_button(menu, "Unload", unload)

local kb = add_section(set_page, "Keybinds")
add_dropdown(kb, "Menu Toggle Key",
    { "RightShift", "LeftShift", "F1", "F2", "F3", "F4", "P", "Insert" }, 1,
    function(v) State.Menu.Key = v end)

local cfg = add_section(set_page, "Config")
add_button(cfg, "Save Config", function()
    save_config()
end)
add_button(cfg, "Load Config", function()
    load_config()
end)
add_button(cfg, "Reset to Default", function()
    reset_config()
end)

local wms = add_section(set_page, "Watermark")
add_toggle(wms, "Show Watermark", false, function(v) State.Watermark.Enabled = v end)
add_textbox_action(wms, "Texto del watermark", "Set", function(text)
    State.Watermark.Text = text
end)

select_tab("Aimbot")
