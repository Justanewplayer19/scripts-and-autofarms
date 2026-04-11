local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.run = call("RunService")
svc.uis = call("UserInputService")

local KyriLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()
local window = KyriLib.new("JJS Util", { GameName = "JJS" })

local main = window:tab("Main", "move")
local lockTab = window:tab("Lock On", "user")
local settings = window:tab("Settings", "settings")

local lp = svc.plr.LocalPlayer
local cam = workspace.CurrentCamera

local speedOn = false
local speedVal = 16
local lockOn = false
local target = nil
local maxDist = 200
local aimPart = "Head"
local smooth = true
local lockBB = nil

local function getChar() return lp.Character end
local function root(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function hum(c) return c and c:FindFirstChildOfClass("Humanoid") end

local function applyDecal(c)
    if not c then return end
    local hrp = root(c)
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "JJSLock"
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 0, 0)
    bb.Size = UDim2.new(0, 80, 0, 120)
    bb.Parent = hrp
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(1, 0, 1, 0)
    img.BackgroundTransparency = 1
    img.Image = "rbxassetid://263401222"
    img.Parent = bb
    lockBB = bb
end

local function removeDecal(c)
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p.Name == "JJSLock" then p:Destroy() end
    end
    lockBB = nil
end

local function delock()
    removeDecal(target)
    target = nil
end

local function forceSpeed()
    if not speedOn then return end
    local h = hum(getChar())
    if h then h.WalkSpeed = speedVal end
end

local function nameFromChar(c)
    for _, p in ipairs(svc.plr:GetPlayers()) do
        if p.Character == c then return p.Name end
    end
    return c.Name
end

local function mouseTarget()
    local cx = cam.ViewportSize.X / 2
    local cy = cam.ViewportSize.Y / 2
    local myChar = getChar()
    local best, bestDist = nil, math.huge

    local function checkChar(c)
        if c == myChar then return end
        local r = root(c)
        if not r then return end
        local screenPos, onScreen = cam:WorldToScreenPoint(r.Position)
        if onScreen then
            local dx = screenPos.X - cx
            local dy = screenPos.Y - cy
            local d = math.sqrt(dx*dx + dy*dy)
            if d < bestDist then
                bestDist = d
                best = c
            end
        end
    end

    local folder = workspace:FindFirstChild("Characters")
    if folder then
        for _, c in ipairs(folder:GetChildren()) do
            checkChar(c)
        end
    end

    -- fallback: check Players characters
    if not best then
        for _, p in ipairs(svc.plr:GetPlayers()) do
            if p ~= lp and p.Character then
                checkChar(p.Character)
            end
        end
    end

    return best
end

local function hookHum(char)
    task.spawn(function()
        local h = hum(char)
        if not h then return end
        h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if speedOn and h.WalkSpeed ~= speedVal then
                h.WalkSpeed = speedVal
            end
        end)
    end)
end

hookHum(getChar())
lp.CharacterAdded:Connect(function(c) hookHum(c) end)

svc.plr.PlayerRemoving:Connect(function(p)
    if p.Character and p.Character == target then delock() end
end)

local charFolder = workspace:FindFirstChild("Characters")
if charFolder then
    charFolder.ChildRemoved:Connect(function(c)
        if c == target then delock() end
    end)
end

-- Main tab
main:section("movement")

main:paragraph("walkspeed info", "Adjust your walkspeed to move faster. Use the toggle or keybind to enable/disable.")

main:toggle("Walkspeed", false, function(v)
    speedOn = v
    if not v then
        local h = hum(getChar())
        if h then h.WalkSpeed = 16 end
    end
end, "speed_on")

main:slider("Speed", 16, 500, 16, function(v)
    speedVal = v
end, "speed_val")

main:keybind("Speed Toggle", "LeftAlt", false, function()
    speedOn = not speedOn
    if not speedOn then
        local h = hum(getChar())
        if h then h.WalkSpeed = 16 end
    end
    window:notify("Speed", speedOn and "enabled" or "disabled", 1)
end, "speed_keybind")

svc.run.Stepped:Connect(function() forceSpeed() end)
svc.run.Heartbeat:Connect(function() forceSpeed() end)
svc.run.RenderStepped:Connect(function() forceSpeed() end)

-- Lock On tab
lockTab:section("aimlock")

lockTab:paragraph("lock on info", "Lock onto targets with mouse button 3. Choose aim part and distance.")

lockTab:toggle("Lock On", false, function(v)
    lockOn = v
    if not v then delock() end
end, "lock_on")

lockTab:toggle("Smoothing", true, function(v)
    smooth = v
end, "lock_smooth")

lockTab:dropdown("Aim Part", {"Head","HumanoidRootPart","Torso","Right Arm","Left Arm","Right Leg","Left Leg"}, "Head", function(v)
    aimPart = v
end)

lockTab:slider("Max Distance", 50, 500, 200, function(v)
    maxDist = v
end, "lock_dist")

-- Settings tab
settings:section("appearance")

settings:colorpicker("accent color", Color3.fromRGB(138, 116, 249), function(color)
    window:accent(color)
end, "accent_color")

svc.uis.InputBegan:Connect(function(inp, gpe)
    if gpe or not lockOn then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton3 then
        if target then
            delock()
        else
            local t = mouseTarget()
            if t then
                target = t
                applyDecal(t)
                window:notify("Locked", nameFromChar(t), 2)
            end
        end
    end
end)

svc.run:BindToRenderStep("jjs_lock", Enum.RenderPriority.Last.Value, function()
    if not lockOn or not target then return end
    if not target.Parent then delock() return end

    local r = root(target)
    local h = hum(target)
    if not r or not h or h.Health <= 0 then delock() return end

    local myRoot = root(getChar())
    if not myRoot then return end

    if (r.Position - myRoot.Position).Magnitude > maxDist then
        delock() return
    end

    if lockBB and lockBB.Parent then
        local dist = math.max((cam.CFrame.Position - r.Position).Magnitude, 1)
        local pps = cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView) / 2)) / dist
        lockBB.Size = UDim2.new(0, math.floor(7 * pps), 0, math.floor(8 * pps))
    end

    local part = target:FindFirstChild(aimPart) or r
    local aimPos = part.Position
    local dist = (aimPos - cam.CFrame.Position).Magnitude
    local lerpFactor = math.clamp(0.15 + (1 / math.max(dist, 1)) * 3, 0.15, 1)

    pcall(function()
        if smooth then
            local curr = cam.CFrame.LookVector
            local want = (aimPos - cam.CFrame.Position).Unit
            local lerped = curr:Lerp(want, lerpFactor)
            cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + lerped)
        else
            cam.CFrame = CFrame.new(cam.CFrame.Position, aimPos)
        end
    end)
end)

window:accent(Color3.fromRGB(138, 116, 249))
window:notify("JJS Util", "loaded", 3)
