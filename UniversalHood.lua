-- this supports matcha, and any other external that has luavm, including executors.
local svc = setmetatable({}, {
    __index = function(t, n)
        local s = game:GetService(n)
        if cloneref then s = cloneref(s) end
        rawset(t, n, s)
        return s
    end
})

local ws = svc.Workspace
local lp = svc.Players.LocalPlayer

local exec = type(fireclickdetector) == "function"

local cfg = {
    standOut = 6,
    standUp = 1,
    execStandOut = 3,

    settle = 0.15,
    aimSettle = 0.35,
    reaimSettle = 0.15,
    pressHold = 0.15,
    spotSettle = 0.1,
    verifyWait = 0.2,

    shopTimeout = 3,

    tries = exec and 8 or 15,
    retryDelay = exec and 0.3 or 0.6,

    armorMax = 200,
}

local function genv()
    if type(getgenv) == "function" then return getgenv() end
    return _G
end

local wsLibrary
local shop = ws:WaitForChild("Ignored"):WaitForChild("Shop")

local function chr()
    return lp.Character
end

local function grm()
    local c = chr()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
    local c = chr()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function be()
    local pf = ws:FindFirstChild("Players")
    pf = pf and pf:FindFirstChild(lp.Name)
    return pf and pf:FindFirstChild("BodyEffects")
end

local function flag(name)
    local b = be()
    return b and b:FindFirstChild(name)
end

local function shopBusy()
    local s = flag("Shop")
    return s ~= nil and s.Value == true
end

local function waitForShop()
    local t0 = tick()
    while shopBusy() and tick() - t0 < cfg.shopTimeout do
        task.wait(0.1)
    end
    return not shopBusy()
end

local function ko()
    local k = flag("K.O")
    if k ~= nil and k.Value == true then return true end

    local h = hum()
    return h ~= nil and h.PlatformStand == true
end

local function armorValue()
    local a = flag("Armor")
    return a and a.Value
end

-- externals differ on whether CFrame writes land, so probe once then remember
local canCFrame = nil

local function place(part, pos, lookAt)
    if canCFrame ~= false then
        local ok = pcall(function()
            part.CFrame = lookAt and CFrame.new(pos, lookAt) or CFrame.new(pos)
        end)
        if ok then
            canCFrame = true
            return
        end
        canCFrame = false
    end

    part.Position = pos
end

local function screenPos(pos)
    if type(WorldToScreen) == "function" then
        local pt, on = WorldToScreen(pos)
        if pt then return pt.X, pt.Y, on end
        return 0, 0, false
    end

    local ok, pt, on = pcall(function()
        return ws.CurrentCamera:WorldToViewportPoint(pos)
    end)
    if not ok or not pt then return 0, 0, false end
    return pt.X, pt.Y, on
end

local function find(pattern)
    local g = grm()
    local gp = g and g.Position
    if not gp then return nil end

    local best, dist = nil, math.huge

    for i,v in ipairs(shop:GetChildren()) do
        if v.Name:lower():find(pattern, 1, true) then
            local cd = v:FindFirstChildOfClass("ClickDetector")

            if cd then
                local hd = v:FindFirstChild("Head")
                    or v:FindFirstChild("HumanoidRootPart")
                    or v:FindFirstChildWhichIsA("BasePart")

                -- IsA lies on some externals, so just test for a usable position
                if not hd then
                    local okPos, pos = pcall(function() return v.Position end)
                    if okPos and pos then hd = v end
                end

                local hp = hd and hd.Position

                if hp then
                    local d = (hp - gp).Magnitude
                    if d < dist then
                        dist = d
                        best = {
                            cd = cd,
                            hd = hd,
                            stand = v:FindFirstChild("HumanoidRootPart") or hd,
                            d = d,
                            pattern = pattern,
                        }
                    end
                end
            end
        end
    end

    return best
end

-- setrobloxinput toggles OUR injected input, not the player's, so it has to
-- be on for any of the mouse calls below to reach the game
local function armInput()
    if type(setrobloxinput) == "function" then
        pcall(setrobloxinput, true)
    end
end

local function click(cd, hd)
    if exec then
        return pcall(fireclickdetector, cd)
    end

    if type(mouse1click) ~= "function" then return false end
    if type(isrbxactive) == "function" and not isrbxactive() then return false end

    local x, y, onscreen = screenPos(hd.Position)
    if not onscreen then return false end

    local hid = wsLibrary and not wsLibrary.Unloaded
    if hid then pcall(function() wsLibrary:Minimize() end) end

    armInput()

    local ok, clicked = pcall(function()
        if type(mousemoveabs) == "function" then
            pcall(mousemoveabs, x, y)
            task.wait(cfg.aimSettle)

            local nx, ny, still = screenPos(hd.Position)
            if still then
                pcall(mousemoveabs, nx, ny)
                task.wait(cfg.reaimSettle)
            end
        end

        if type(mouse1press) == "function" and type(mouse1release) == "function" then
            pcall(mouse1press)
            task.wait(cfg.pressHold)
            return pcall(mouse1release)
        end

        return pcall(mouse1click)
    end)

    if hid then pcall(function() wsLibrary:Minimize() end) end

    if not ok then return false end
    return clicked
end

-- stalls sit in wildly different geometry, so try a few spots and keep
-- whichever one actually leaves the target visible
local function standSpots(t)
    local spots = {}

    local ok, cf = pcall(function() return t.stand.CFrame end)
    if ok and cf then
        spots[#spots+1] = cf.LookVector.Unit * cfg.standOut
        spots[#spots+1] = cf.LookVector.Unit * -cfg.standOut
        spots[#spots+1] = cf.RightVector.Unit * cfg.standOut
        spots[#spots+1] = cf.RightVector.Unit * -cfg.standOut
    end

    spots[#spots+1] = Vector3.new(cfg.standOut, 0, 0)
    spots[#spots+1] = Vector3.new(-cfg.standOut, 0, 0)
    spots[#spots+1] = Vector3.new(0, 0, cfg.standOut)
    spots[#spots+1] = Vector3.new(0, 0, -cfg.standOut)

    return spots
end

local function placeNear(g, t)
    local up = Vector3.new(0, cfg.standUp, 0)

    for i,off in ipairs(standSpots(t)) do
        place(g, t.stand.Position + off + up, t.hd.Position)
        task.wait(cfg.spotSettle)

        local _, _, on = screenPos(t.hd.Position)
        if on or type(WorldToScreen) ~= "function" then
            return true
        end
    end

    place(g, t.hd.Position + Vector3.new(cfg.standOut, cfg.standUp, 0), t.hd.Position)
    return false
end

local function moveTo(pos)
    local c = chr()
    local g = grm()

    local ok = false

    if exec and c then
        ok = pcall(function()
            local pivot = c:GetPivot()
            c:PivotTo(pivot - pivot.Position + pos)
        end)
    end

    if not ok and g then
        g.Position = pos
    end
end

local firing = false

local function fireExternal(t)
    if firing then return false end
    firing = true

    local ok, result = pcall(function()
        local g = grm()
        if not g or not t.cd.Parent then return false end
        if ko() then return false end

        local old
        local maxdist = t.cd.MaxActivationDistance or 0

        if t.d > maxdist then
            old = g.Position
            placeNear(g, t)
            pcall(function() g.AssemblyLinearVelocity = Vector3.zero end)
            task.wait(cfg.settle)
        end

        local clicked = click(t.cd, t.hd)

        if old then
            task.wait(cfg.settle)
            if g.Parent then
                place(g, old)
                pcall(function() g.AssemblyLinearVelocity = Vector3.zero end)
            end
        end

        return clicked
    end)

    firing = false

    if not ok then return false end
    return result
end

local function fireExec(t)
    if firing then return false end
    firing = true

    local old
    local holding = false

    local function restore()
        holding = false
        local g = grm()
        if g and g.Parent and old then
            moveTo(old)
            pcall(function() g.AssemblyLinearVelocity = Vector3.zero end)

            local h = hum()
            if h then
                pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
        end
    end

    local ok, result = pcall(function()
        local cd, hd, stand = t.cd, t.hd, t.stand
        local g = grm()
        if not g or not cd.Parent then return false end
        if ko() then return false end

        local h = hum()
        local hpBefore = h and h.Health

        if t.d > (cd.MaxActivationDistance or 0) then
            old = g.Position
            holding = true

            task.spawn(function()
                while holding and g.Parent do
                    pcall(function() g.AssemblyLinearVelocity = Vector3.zero end)
                    task.wait()
                end
            end)

            moveTo(stand.Position + Vector3.new(cfg.execStandOut, 0, 0))
            task.wait(cfg.settle)

            local hpNow = h and h.Health
            if (hpBefore and hpNow and hpNow < hpBefore - 0.5) or ko() then
                return false
            end

            if not cd.Parent then
                local t2 = find(t.pattern)
                if not t2 then return false end
                cd, hd = t2.cd, t2.hd
            end
        end

        local clicked = click(cd, hd)

        if old then
            task.wait(cfg.settle)
        end

        return clicked
    end)

    restore()
    firing = false

    if not ok then return false end
    return result
end

local function fire(t)
    if not t then return false end
    return exec and fireExec(t) or fireExternal(t)
end

local verifiers = {
    ["full armor"] = { get = armorValue, max = cfg.armorMax },
}

local busy = false

local function buy(pattern)
    if busy then return false end
    busy = true

    local ok, result = pcall(function()
        local v = verifiers[pattern]
        local get = v and v.get
        local before = get and get()

        if get and v.max and before and before >= v.max then
            return true
        end

        if not exec and type(notify) == "function" then
            pcall(notify, "look toward a shop stall now", "rebuy", 3)
        end

        for i = 1, cfg.tries do
            if not waitForShop() then return false end

            local fired = fire(find(pattern))
            waitForShop()

            if get then
                task.wait(cfg.verifyWait)
                local now = get()

                -- only a rise counts; taking damage mid-loop also changes the value
                if now and before and now > before then return true end
                if now and v.max and now >= v.max then return true end
            elseif fired then
                return true
            end

            task.wait(cfg.retryDelay)
        end

        return false
    end)

    busy = false

    if not ok then return false end
    return result
end

local api = {
    armor = function() return buy("full armor") end,
    stim = function() return buy("stim") end,
    isBusy = function() return busy end,
}
rawset(genv(), "rebuy", api)

if not exec then
    pcall(function()
        loadstring(game:HttpGet("https://scripts.wabisabi.mom/wabi-sabi-ui-lib.lua"))()
        wsLibrary = WabiSabi

        local Window = wsLibrary:CreateWindow({
            Title = "rebuy",
            SubTitle = "manual buy",
            Size = Vector2.new(260, 160),
            Resize = false,
        })

        local Tab = Window:AddTab({ Title = "Buy" })

        Tab:AddButton({ Title = "Armor", Callback = function()
            task.spawn(api.armor)
        end })

        Tab:AddButton({ Title = "Stim", Callback = function()
            task.spawn(api.stim)
        end })
    end)
else
    local ui = Instance.new("ScreenGui")
    ui.Name = "rebuyui"
    ui.ResetOnSpawn = false
    ui.DisplayOrder = 20
    ui.Parent = gethui and gethui() or lp:WaitForChild("PlayerGui")

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 140, 0, 76)
    f.Position = UDim2.new(0, 16, 0.5, -38)
    f.BackgroundColor3 = Color3.fromRGB(25, 27, 29)
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    f.Active = true
    f.Parent = ui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = f

    do
        local dragging, dragStart, startPos

        f.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            dragging = true
            dragStart = i.Position
            startPos = f.Position

            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end)

        svc.UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end

            local d = i.Position - dragStart
            f.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end)
    end

    local function makebtn(text, yoff, fn)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 28)
        btn.Position = UDim2.new(0, 8, 0, yoff)
        btn.BackgroundColor3 = Color3.fromRGB(45, 47, 50)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Text = text
        btn.AutoButtonColor = true
        btn.Parent = f

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 6)
        bc.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if busy then return end

            btn.Text = "..."
            local ok = fn()
            btn.Text = ok and (text .. " ✓") or (text .. " ✗")
            task.wait(1)
            btn.Text = text
        end)
    end

    makebtn("Armor", 8, api.armor)
    makebtn("Stim", 40, api.stim)
end

print("ur now running: " .. (exec and "exec version" or "external version"))
if type(notify) == "function" then
    pcall(notify, "ur now running: " .. (exec and "exec version" or "external version"), "Rebuy", 5)
end
