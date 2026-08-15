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

local function shopBusy()
    local b = be()
    local s = b and b:FindFirstChild("Shop")
    return s ~= nil and s.Value == true
end

local function waitForShop(timeout)
    local t0 = tick()
    while shopBusy() and tick() - t0 < (timeout or 3) do
        task.wait(0.1)
    end
    return not shopBusy()
end

local function ko()
    local b = be()
    local k = b and b:FindFirstChild("K.O")
    if k ~= nil and k.Value == true then return true end

    local h = hum()
    if h and h.PlatformStand then return true end

    return false
end

local function find(pattern)
    local g = grm()
    if not g then return nil end

    local gp = g.Position
    if not gp then return nil end

    local best, dist = nil, math.huge

    for i,v in ipairs(shop:GetChildren()) do
        if v.Name:lower():find(pattern, 1, true) then
            local cd = v:FindFirstChildOfClass("ClickDetector")

            if cd then
                local hd = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart") or v:FindFirstChildWhichIsA("BasePart")

                if not hd and v:IsA("BasePart") then
                    hd = v
                end

                local stand = v:FindFirstChild("HumanoidRootPart") or hd

                local hp = hd and hd.Position

                if hp then
                    local d = (hp - gp).Magnitude
                    if d < dist then
                        dist = d
                        best = {cd = cd, hd = hd, stand = stand, d = d}
                    end
                end
            end
        end
    end

    return best
end

local function click(cd, hd)
    if type(fireclickdetector) == "function" then
        return pcall(fireclickdetector, cd)
    end

    if type(mouse1click) ~= "function" then return false end
    if type(isrbxactive) == "function" and not isrbxactive() then return false end

    local x, y, onscreen

    if type(WorldToScreen) == "function" then
        local pt
        pt, onscreen = WorldToScreen(hd.Position)
        x, y = pt.X, pt.Y
    else
        local cam = ws.CurrentCamera
        local ok, pt, os2 = pcall(function()
            return cam:WorldToViewportPoint(hd.Position)
        end)
        if not ok then return false end
        x, y, onscreen = pt.X, pt.Y, os2
    end

    if not onscreen then return false end

    local hid = wsLibrary and not wsLibrary.Unloaded
    if hid then pcall(function() wsLibrary:Minimize() end) end

    local blocked = type(setrobloxinput) == "function"
    if blocked then pcall(setrobloxinput, false) end

    local ok, clicked = pcall(function()
        if type(mousemoveabs) == "function" then
            pcall(mousemoveabs, x, y)
            task.wait(0.35)

            local pt2, onscreen2 = WorldToScreen(hd.Position)
            if onscreen2 then
                pcall(mousemoveabs, pt2.X, pt2.Y)
                task.wait(0.15)
            end
        end

        if type(mouse1press) == "function" and type(mouse1release) == "function" then
            pcall(mouse1press)
            task.wait(0.15)
            return pcall(mouse1release)
        else
            return pcall(mouse1click)
        end
    end)

    if blocked then pcall(setrobloxinput, true) end
    if hid then pcall(function() wsLibrary:Minimize() end) end

    if not ok then return false end
    return clicked
end

local function moveTo(pos)
    local c = chr()
    local g = grm()

    local ok = false

    if type(fireclickdetector) == "function" and c then
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
    if not t then return false end
    if firing then return false end
    firing = true

    local cd, hd = t.cd, t.hd
    local g = grm()

    if not g or not cd or not cd.Parent then
        firing = false
        return false
    end

    if ko() then
        firing = false
        return false
    end

    local old
    local maxdist = cd.MaxActivationDistance or 0

    if t.d > maxdist then
        old = g.CFrame

        local candidates = {}
        local okLook, look = pcall(function() return t.stand.CFrame.LookVector end)
        local okRight, right = pcall(function() return t.stand.CFrame.RightVector end)

        if okLook and look and look.Magnitude > 0 then
            table.insert(candidates, look.Unit * 6)
            table.insert(candidates, look.Unit * -6)
        end
        if okRight and right and right.Magnitude > 0 then
            table.insert(candidates, right.Unit * 6)
            table.insert(candidates, right.Unit * -6)
        end
        table.insert(candidates, Vector3.new(6, 0, 0))
        table.insert(candidates, Vector3.new(-6, 0, 0))
        table.insert(candidates, Vector3.new(0, 0, 6))
        table.insert(candidates, Vector3.new(0, 0, -6))

        local placed = false

        for i,offset in ipairs(candidates) do
            local target = t.stand.Position + offset + Vector3.new(0, 1, 0)

            local faced = pcall(function()
                g.CFrame = CFrame.new(target, hd.Position)
            end)
            if not faced then
                g.Position = target
            end

            task.wait(0.1)

            local ok2, onscreen2 = pcall(function()
                local pt, os2 = WorldToScreen(hd.Position)
                return os2
            end)

            if type(WorldToScreen) ~= "function" or (ok2 and onscreen2) then
                placed = true
                break
            end
        end

        if not placed then
            local target = hd.Position + Vector3.new(6, 1, 0)
            pcall(function()
                g.CFrame = CFrame.new(target, hd.Position)
            end)
        end

        pcall(function() g.AssemblyLinearVelocity = Vector3.zero end)
        task.wait(0.15)
    end

    local ok = click(cd, hd)

    if old then
        task.wait(0.15)
        if g.Parent then
            local restored = pcall(function() g.CFrame = old end)
            if not restored then
                g.Position = old.Position
            end
            pcall(function() g.AssemblyLinearVelocity = Vector3.zero end)
        end
    end

    firing = false
    return ok
end

local function fireExec(t)
    if not t then return false end
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

            if type(fireclickdetector) == "function" then
                local h = hum()
                if h then
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                end
            end
        end
    end

    local ok, result = pcall(function()
        local cd, hd, stand = t.cd, t.hd, t.stand or t.hd
        local g = grm()
        if not g or not cd or not cd.Parent then return false end
        if ko() then return false end

        local h = hum()
        local hpBefore = h and h.Health

        if t.d > cd.MaxActivationDistance then
            old = g.Position
            holding = true

            task.spawn(function()
                while holding and g.Parent do
                    pcall(function() g.AssemblyLinearVelocity = Vector3.zero end)
                    task.wait()
                end
            end)

            moveTo(stand.Position + Vector3.new(3, 0, 0))
            task.wait(0.15)

            local hpNow = h and h.Health
            local damaged = hpBefore and hpNow and hpNow < hpBefore - 0.5

            if damaged or ko() then
                return false
            end

            if not cd.Parent then
                local t2 = find(t.pattern)
                if not t2 then return false end
                cd = t2.cd
                hd = t2.hd
                stand = t2.stand or t2.hd
            end
        end

        local clicked = click(cd, hd)

        if old then
            task.wait(0.15)
        end

        return clicked
    end)

    restore()
    firing = false

    if not ok then return false end
    return result
end

local function fire(t)
    if type(fireclickdetector) == "function" then
        return fireExec(t)
    else
        return fireExternal(t)
    end
end

local function armorValue()
    local b = be()
    local a = b and b:FindFirstChild("Armor")
    return a and a.Value
end

local verifiers = {
    ["full armor"] = { get = armorValue, max = 200 },
}

local function buy(pattern)
    local v = verifiers[pattern]
    local verify = v and v.get
    local before = verify and verify()

    if verify and v.max and before ~= nil and before >= v.max then
        return true
    end

    if type(fireclickdetector) ~= "function" and type(notify) == "function" then
        pcall(notify, "look toward a shop stall now", "rebuy", 3)
    end

    local tries = type(fireclickdetector) == "function" and 8 or 15
    local delay = type(fireclickdetector) == "function" and 0.3 or 0.6

    for i = 1, tries do
        if not waitForShop(3) then
            return false
        end

        local ok = fire(find(pattern))

        waitForShop(3)

        if verify then
            task.wait(0.2)
            local now = verify()
            if now ~= nil and now ~= before then
                return true
            end
        elseif ok then
            return true
        end

        task.wait(delay)
    end

    return false
end

local api = {
    armor = function() return buy("full armor") end,
    stim = function() return buy("stim") end,
}
rawset(genv(), "rebuy", api)

if type(fireclickdetector) ~= "function" then
    pcall(function()
        loadstring(game:HttpGet("https://scripts.wabisabi.mom/wabi-sabi-ui-lib.lua"))()
        local Library = WabiSabi
        wsLibrary = Library

        local Window = Library:CreateWindow({
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

local mode = type(fireclickdetector) == "function" and "exec version" or "external version"
print("ur now running: " .. mode)
if type(notify) == "function" then
    pcall(notify, "ur now running: " .. mode, "Rebuy", 5)
end
