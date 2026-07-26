local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.tw = call("TweenService")
svc.plr = call("Players")
svc.rep = call("ReplicatedStorage")
svc.run = call("RunService")
svc.uis = call("UserInputService")
svc.http = call("HttpService")
svc.vu = call("VirtualUser")

local lp = svc.plr.LocalPlayer
pcall(function() svc.run:Set3dRenderingEnabled(true) end)

if _G.SimpleAFCleanup then
    pcall(_G.SimpleAFCleanup)
end

local rid = {}
_G.SimpleAFRunID = rid
local function isRun()
    return _G.SimpleAFRunID == rid
end

local gui2 = {}

local function buildBg()
    if gui2.bg then return end
    local g = Instance.new('ScreenGui')
    g.Name = 'af' .. math.random(1000, 9999)
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 999
    g.Parent = gethui and gethui() or lp:WaitForChild('PlayerGui')

    local f = Instance.new('Frame')
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
    f.BorderSizePixel = 0
    f.Visible = false
    f.Parent = g

    local lbl = Instance.new('TextLabel')
    lbl.Size = UDim2.new(1, 0, 0, 30)
    lbl.Position = UDim2.new(0, 0, 0.5, -30)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 20
    lbl.TextColor3 = Color3.fromRGB(190, 190, 198)
    lbl.Text = 'AutoFarm running in background'
    lbl.Parent = f

    local sub = Instance.new('TextLabel')
    sub.Size = UDim2.new(1, 0, 0, 24)
    sub.Position = UDim2.new(0, 0, 0.5, 4)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 14
    sub.TextColor3 = Color3.fromRGB(110, 110, 118)
    sub.Text = 'click the game to bring rendering back'
    sub.Parent = f

    local stat = Instance.new('TextLabel')
    stat.Size = UDim2.new(1, 0, 0, 20)
    stat.Position = UDim2.new(0, 0, 0.5, 34)
    stat.BackgroundTransparency = 1
    stat.Font = Enum.Font.Gotham
    stat.TextSize = 14
    stat.TextColor3 = Color3.fromRGB(140, 200, 140)
    stat.Text = 'Coins: -- / -- | Farmed: --'
    stat.Parent = f

    gui2.bg = g
    gui2.bgFrame = f
    gui2.bgStat = stat
end

local focused = true
svc.uis.WindowFocused:Connect(function()
    if not isRun() then return end
    focused = true
    if gui2.bgFrame then gui2.bgFrame.Visible = false end
    pcall(function() svc.run:Set3dRenderingEnabled(true) end)
end)
svc.uis.WindowFocusReleased:Connect(function()
    if not isRun() then return end
    focused = false
    buildBg()
    gui2.bgFrame.Visible = true
    task.wait(0.3)
    if not isRun() or focused then return end
    pcall(function() svc.run:Set3dRenderingEnabled(false) end)
end)

local chr, hum, grm
local ccn, dcn
local ows

local win
local en = true
local shootOn = true
local farmOn = true
local gunOn = true
local hideOn = true
local huntOn = true
local rng = 120
local walkMode = false

local t0 = os.clock()
local fc = 0

local function fmtT()
    local total = math.floor(os.clock() - t0)
    local hrs = math.floor(total / 3600)
    local mins = math.floor((total % 3600) / 60)
    local secs = total % 60
    if hrs > 0 then
        return string.format("%dh %dm %ds", hrs, mins, secs)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    end
    return string.format("%ds", secs)
end

lp.Idled:Connect(function()
    svc.vu:CaptureController()
    svc.vu:ClickButton2(Vector2.new())
end)

local st = 'Lobby'
local role = 'Unknown'
local shf = nil
local mur = nil
local gunDown = false
local fst = 0

local rtu = 0
local rtuPause = 3

local cbt = false

local hideR = 40
local hideT = 0
local hideExR = 65
local hideExT = 1.5

local hiding = false
local dangerT = nil
local safeT = nil

local function setRole(rp)
    if type(rp) ~= 'table' then return end
    shf = nil
    mur = nil
    gunDown = false
    local entry = rp[lp.Name]
    if not entry then
        for i,v in pairs(rp) do
            if type(v) == 'table' and v.UserId == lp.UserId then
                entry = v
                break
            end
        end
    end
    if type(entry) == 'table' then
        role = entry.Role or role
    end
    if win then win:notify('Role', role, 3) end
    for name,v in pairs(rp) do
        if type(v) == 'table' and type(name) == 'string' then
            if v.Role == 'Sheriff' then
                shf = svc.plr:FindFirstChild(name)
            elseif v.Role == 'Murderer' then
                mur = svc.plr:FindFirstChild(name)
            end
        end
    end
end

local lobbyM = 12
local lobC, lobS

local function lobBounds()
    if lobC then return lobC, lobS end
    local cont = workspace:FindFirstChild('Lobby')
    local part = cont and cont:FindFirstChild('Lobby')
    if not part then return nil end
    if part:IsA('BasePart') then
        lobC, lobS = part.Position, part.Size
        return lobC, lobS
    end
    local ok, cf, sz = pcall(function() return part:GetBoundingBox() end)
    if ok then
        lobC, lobS = cf.Position, sz
        return lobC, lobS
    end
    return nil
end

local function inLobbyPos(pos)
    if not pos then return false end
    local c, s = lobBounds()
    if not c then return false end
    local d = pos - c
    local hx = s.X / 2 + lobbyM
    local hz = s.Z / 2 + lobbyM
    return math.abs(d.X) <= hx and math.abs(d.Z) <= hz
end

local function inLobby()
    return grm and inLobbyPos(grm.Position) or false
end

local function hasGun()
    for i,tool in pairs(lp.Backpack:GetChildren()) do
        if tool:IsA('Tool') and tool.Name:lower():find('gun') then
            return true
        end
    end
    local eq = chr and chr:FindFirstChildWhichIsA('Tool')
    if eq and eq.Name:lower():find('gun') then return true end
    return false
end

local function ncOk()
    return en and st == 'Farming' and not inLobby() and not cbt
end

local ncApplied = nil
local ncParts = setmetatable({}, {__mode = 'k'})
local ncConn

local function ncRestore()
    for part in pairs(ncParts) do
        if typeof(part) == 'Instance' and part:IsA('BasePart') and part.Parent then
            part.CanCollide = true
        end
    end
    ncParts = setmetatable({}, {__mode = 'k'})
end

local function setNoclip(enabled)
    if not chr then return end
    if ncApplied == enabled then return end
    ncApplied = enabled
    if ncConn then
        ncConn:Disconnect()
        ncConn = nil
    end
    if enabled then
        ncConn = svc.run.Stepped:Connect(function()
            if ncApplied ~= true or not chr then return end
            for i,part in ipairs(chr:GetDescendants()) do
                if part:IsA('BasePart') and part.CanCollide == true then
                    part.CanCollide = false
                    ncParts[part] = true
                end
            end
        end)
    else
        ncRestore()
    end
end

local espOn = true
local tags = {}
local over = false
local lastHero = nil

local function rmTag(plr)
    local tag = tags[plr]
    if tag then
        pcall(function() tag:Destroy() end)
        tags[plr] = nil
    end
end

local espCol = {
    Sheriff = Color3.fromRGB(80, 170, 255),
    Murderer = Color3.fromRGB(255, 70, 70),
    Hero = Color3.fromRGB(255, 210, 60),
}

local function espRole(plr)
    local c = plr.Character
    if not c then return nil end
    if plr == shf then
        if over then return 'Sheriff' end
        local h = c:FindFirstChildOfClass('Humanoid')
        local g = c:FindFirstChild('HumanoidRootPart')
        if h and h.Health > 0 and not (g and inLobbyPos(g.Position)) then
            return 'Sheriff'
        end
        return nil
    end
    if plr == mur then return 'Murderer' end
    if over then
        if plr == lastHero then return 'Hero' end
        return nil
    end
    if gunDown then
        local eq = c:FindFirstChildWhichIsA('Tool')
        if eq and eq.Name:lower():find('gun') then
            lastHero = plr
            return 'Hero'
        end
    end
    return nil
end

local function doEsp()
    for i,plr in ipairs(svc.plr:GetPlayers()) do
        local role1 = espOn and espRole(plr) or nil
        local c = plr.Character
        local head = c and c:FindFirstChild('Head')
        if role1 and head then
            local tag = tags[plr]
            if not tag or tag.Parent ~= head then
                rmTag(plr)
                tag = Instance.new('BillboardGui')
                tag.Name = 'af' .. math.random(1000, 9999)
                tag.Adornee = head
                tag.Size = UDim2.new(0, 140, 0, 24)
                tag.StudsOffset = Vector3.new(0, 2.2, 0)
                tag.AlwaysOnTop = true
                local lbl = Instance.new('TextLabel')
                lbl.Name = 'l'
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 16
                lbl.TextStrokeTransparency = 0
                lbl.Parent = tag
                tag.Parent = head
                tags[plr] = tag
            end
            local lbl = tag:FindFirstChild('l')
            if lbl then
                lbl.Text = (over and 'Last ' or '') .. role1 .. (plr == lp and ' (You)' or '')
                lbl.TextColor3 = espCol[role1]
            end
        else
            rmTag(plr)
        end
    end
end

svc.plr.PlayerRemoving:Connect(function(plr)
    if not isRun() then return end
    rmTag(plr)
end)

local espErr = false
svc.run.Heartbeat:Connect(function()
    if not isRun() then return end
    if os.clock() < rtu then return end
    if os.clock() % 0.2 < 0.05 then
        local ok, err = pcall(doEsp)
        if not ok and not espErr then
            espErr = true
            warn(tostring(err))
        end
    end
end)

local function worn(obj)
    for i,plr in ipairs(svc.plr:GetPlayers()) do
        local c = plr.Character
        if c and obj:IsDescendantOf(c) then return true end
    end
    return false
end

local function isAcc(name)
    name = name:lower()
    return name:find('belt') ~= nil or name:find('holster') ~= nil
end

local function findDrop()
    for i,child in ipairs(workspace:GetChildren()) do
        local d = child:FindFirstChild('GunDrop')
        if d and d:IsA('BasePart') then return d end
    end
    return nil
end

local function findGun()
    local d = findDrop()
    if d and not worn(d) then return d end
    local best
    local bd = math.huge
    for i,obj in pairs(workspace:GetDescendants()) do
        if obj:IsA('Attachment') and (obj.Name:find('GunRaycastAttachment') or obj.Name:find('GunShoulderAttachment')) then
            local root = obj.Parent
            while root and not root:IsA('BasePart') do
                root = root.Parent
            end
            if root and not worn(root) and not isAcc(root.Name) then
                local dist = (root.Position - grm.Position).Magnitude
                if dist < bd then bd = dist; best = root end
            end
        elseif obj:IsA('Model') and obj.Name:lower():find('gun') and not isAcc(obj.Name) and not worn(obj) then
            local part = obj:FindFirstChildWhichIsA('BasePart', true)
            if part then
                local dist = (part.Position - grm.Position).Magnitude
                if dist < bd then bd = dist; best = part end
            end
        elseif obj:IsA('BasePart') and obj.Name:lower():find('gun') and not isAcc(obj.Name) and not worn(obj) then
            local dist = (obj.Position - grm.Position).Magnitude
            if dist < bd then bd = dist; best = obj end
        end
    end
    return best
end

local coins = 0
local coinCap = 40

local function getCoins()
    return coins
end

local function srvPart(part)
    if not part then return nil end
    if part.Name == 'Coin_Server' and part:IsA('BasePart') then return part end
    if part.Name == 'CoinVisual' and part:IsA('BasePart') then
        local parent = part.Parent
        if parent then
            local sp = parent:FindFirstChild('Coin_Server')
            if sp and sp:IsA('BasePart') then return sp end
        end
    end
    return nil
end

local cCache, cCacheT = nil, 0
local function findCoins()
    if cCache and os.clock() - cCacheT < 0.15 then return cCache end
    local out = {}
    local seen = {}
    for i,obj in pairs(workspace:GetDescendants()) do
        if obj:IsA('BasePart') and (obj.Name == 'Coin_Server' or obj.Name == 'CoinVisual') then
            local sp = srvPart(obj)
            if sp and not seen[sp] then
                seen[sp] = true
                out[#out + 1] = sp
            end
        end
    end
    if #out == 0 and type(getnilinstances) == 'function' then
        for i,obj in pairs(getnilinstances()) do
            if obj.ClassName == 'Part' and (obj.Name == 'Coin_Server' or obj.Name == 'CoinVisual') then
                local sp = srvPart(obj)
                if sp and not seen[sp] then
                    seen[sp] = true
                    out[#out + 1] = sp
                end
            end
        end
    end
    cCache = out
    cCacheT = os.clock()
    return out
end

local function los(origin, tp, tc)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {chr}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(origin, tp - origin, rp)
    if not result then return true end
    return result.Instance:IsDescendantOf(tc)
end

local function murDanger()
    if not mur then return false end
    local mc = mur.Character
    if not mc then return false end
    local h = mc:FindFirstChildOfClass('Humanoid')
    local g = mc:FindFirstChild('HumanoidRootPart')
    if not h or not g or h.Health <= 0 then return false end
    if (g.Position - grm.Position).Magnitude > hideR then return false end
    return los(grm.Position + Vector3.new(0, 1.5, 0), g.Position, mc)
end

local function tweenTo(cf, dur, cancel)
    local info = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tw = svc.tw:Create(grm, info, {CFrame = cf})
    tw:Play()
    local el = 0
    while tw.PlaybackState == Enum.PlaybackState.Playing do
        if st ~= 'Farming' or (cancel and cancel()) then
            tw:Cancel()
            return false
        end
        task.wait(0.05)
        el = el + 0.05
        if el > dur + 1 then break end
    end
    return true
end

local function walkTo(tp, dur, cancel)
    if not hum or not grm then return false end
    hum:MoveTo(tp)
    local el = 0
    while el <= dur + 1.5 do
        if st ~= 'Farming' or (cancel and cancel()) then
            hum:MoveTo(grm.Position)
            return false
        end
        if (grm.Position - tp).Magnitude <= 3 then return true end
        wait(0.05)
        el = el + 0.05
    end
    return (grm.Position - tp).Magnitude <= 6
end

local function safeBelow(part)
    local pos = part.Position
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {chr}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local r = workspace:Raycast(pos, Vector3.new(0, -50, 0), rp)
    local gY = r and r.Position.Y or (pos.Y - 50)
    local minY = gY + 2
    local ty = pos.Y - part.Size.Y / 2 - 0.8
    if ty < minY then ty = minY end
    if ty < grm.Position.Y - 40 then ty = grm.Position.Y - 40 end
    return Vector3.new(pos.X, ty, pos.Z)
end

local function farmCoin(part)
    if not part or not part.Parent then return false, false end
    if ncOk() then setNoclip(true) end
    hum.WalkSpeed = 12
    local dist = (part.Position - grm.Position).Magnitude
    local dur = math.max(dist / 12, 0.2)
    local gone = function()
        return not part.Parent or (role ~= 'Murderer' and murDanger())
    end
    local sp = safeBelow(part)
    local reached
    if walkMode then
        reached = walkTo(sp, dur, gone)
    else
        reached = tweenTo(CFrame.new(sp), dur, gone)
    end
    if not reached then
        local d = not part.Parent
        return d, d
    end
    task.wait(0.05)
    return true, not part.Parent
end

local function standY(pos)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {chr}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local r = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), rp)
    if r then return r.Position.Y + 3 end
    return grm.Position.Y
end

local function grabGun(part)
    if not part or not part.Parent then return false end
    if ncOk() then setNoclip(true) end
    hum.WalkSpeed = 12
    local gp = part.Position
    local sy = standY(gp)
    local ap = Vector3.new(gp.X, sy, gp.Z)
    local td = ap - grm.Position
    local fd = Vector3.new(td.X, 0, td.Z)
    if fd.Magnitude < 0.1 then fd = grm.CFrame.LookVector end
    local appr = CFrame.lookAt(ap, ap + fd)
    if not part.Parent then return false end
    pcall(function() grm.CFrame = appr end)
    local rcf = grm.CFrame
    local gcf = CFrame.lookAt(ap, ap + fd)
    local t = os.clock()
    while part.Parent and not hasGun() and os.clock() - t < 0.3 do
        if st ~= 'Farming' then
            pcall(function() grm.CFrame = rcf end)
            return hasGun()
        end
        pcall(function() grm.CFrame = gcf end)
        task.wait()
    end
    pcall(function() grm.CFrame = rcf end)
    if grm then pcall(function() grm.AssemblyLinearVelocity = Vector3.zero end) end
    return hasGun()
end

local function eqGun()
    local t = chr:FindFirstChild('Gun') or lp.Backpack:FindFirstChild('Gun')
    if t and t.Parent ~= chr then hum:EquipTool(t) end
end

local function eqWep()
    if chr:FindFirstChildWhichIsA('Tool') then return end
    local t = lp.Backpack:FindFirstChild('Knife') or lp.Backpack:FindFirstChildWhichIsA('Tool')
    if t then hum:EquipTool(t) end
end

local function nearest()
    local nb, nd = nil, math.huge
    for i,plr in ipairs(svc.plr:GetPlayers()) do
        if plr ~= lp then
            local c = plr.Character
            local h = c and c:FindFirstChildOfClass('Humanoid')
            local g = c and c:FindFirstChild('HumanoidRootPart')
            if h and g and h.Health > 0 then
                local dist = (g.Position - grm.Position).Magnitude
                if dist < nd then nb = plr; nd = dist end
            end
        end
    end
    return nb, nd
end

local tgtMargin = 8
local tgtRecheck = 1.5
local curTgt = nil
local curTgtT = 0

local function pickTgt()
    local cc = curTgt and curTgt.Character
    local ch = cc and cc:FindFirstChildOfClass('Humanoid')
    local cg = cc and cc:FindFirstChild('HumanoidRootPart')
    local valid = ch and cg and ch.Health > 0
    local cd = valid and (cg.Position - grm.Position).Magnitude or math.huge
    if valid and os.clock() - curTgtT < tgtRecheck then return curTgt end
    local nb, nd = nearest()
    if not nb then curTgt = nil; return nil end
    if not valid or nb == curTgt or nd < cd - tgtMargin then
        curTgt = nb
        curTgtT = os.clock()
    end
    return curTgt
end

local mm = {
    deadEndFolder = 'SimpleAF_DeadEnds',
    deathFolder = 'SimpleAF_Deaths',
    goodFolder = 'SimpleAF_Good',
    mergeR = 10,
    penaltyR = 12,
    deathR = 20,
    goodR = 12,
    goodBonus = 1.6,
    deadEnds = {},
    deaths = {},
    good = {},
    mapId = nil,
    deadEndPath = nil,
    deathPath = nil,
    goodPath = nil,
}

local function hasFs()
    return type(writefile) == 'function' and type(readfile) == 'function' and type(isfile) == 'function'
end

local function looksMap(child)
    if child.Name == 'Lobby' then return false end
    if not (child:IsA('Model') or child:IsA('Folder')) then return false end
    return child:FindFirstChild('Spawns') ~= nil or child:FindFirstChild('CoinAreas') ~= nil
end

local function mapId()
    local d = findDrop()
    if d and d.Parent then return d.Parent.Name end
    for i,child in ipairs(workspace:GetChildren()) do
        if looksMap(child) then return child.Name end
    end
    return 'UnknownMap'
end

local function loadJson(path)
    local eok, ex = pcall(isfile, path)
    if eok and ex then
        local rok, data = pcall(readfile, path)
        if rok and data and #data > 0 then
            local dok, dec = pcall(function() return svc.http:JSONDecode(data) end)
            if dok and type(dec) == 'table' then return dec end
        end
    end
    return {}
end

local allTime = {coins = 0, seconds = 0, sessions = 0, deaths = 0, path = 'SimpleAF_AllTime.json'}

function allTime.save()
    if not hasFs() then return end
    allTime.seconds = allTime.baseSeconds + (os.clock() - t0)
    local clean = {coins = allTime.coins, seconds = allTime.seconds, sessions = allTime.sessions, deaths = allTime.deaths}
    pcall(function() writefile(allTime.path, svc.http:JSONEncode(clean)) end)
end

function allTime.load()
    local data = loadJson(allTime.path)
    allTime.coins = type(data.coins) == 'number' and data.coins or 0
    allTime.seconds = type(data.seconds) == 'number' and data.seconds or 0
    allTime.sessions = type(data.sessions) == 'number' and data.sessions or 0
    allTime.deaths = type(data.deaths) == 'number' and data.deaths or 0
    allTime.baseSeconds = allTime.seconds
    allTime.sessions = allTime.sessions + 1
    allTime.save()
end

function allTime.fmt()
    local total = math.floor(allTime.baseSeconds + (os.clock() - t0))
    local hrs = math.floor(total / 3600)
    local mins = math.floor((total % 3600) / 60)
    if hrs > 0 then return string.format('%dh %dm', hrs, mins) end
    return string.format('%dm', mins)
end

local function loadMM(id)
    mm.deadEnds = {}
    mm.deaths = {}
    mm.good = {}
    mm.mapId = id
    mm.deadEndPath = nil
    mm.deathPath = nil
    mm.goodPath = nil
    if not hasFs() then return end
    pcall(function()
        if type(makefolder) == 'function' and type(isfolder) == 'function' then
            if not isfolder(mm.deadEndFolder) then makefolder(mm.deadEndFolder) end
            if not isfolder(mm.deathFolder) then makefolder(mm.deathFolder) end
            if not isfolder(mm.goodFolder) then makefolder(mm.goodFolder) end
        end
    end)
    mm.deadEndPath = mm.deadEndFolder .. '/' .. id .. '.json'
    mm.deathPath = mm.deathFolder .. '/' .. id .. '.json'
    mm.goodPath = mm.goodFolder .. '/' .. id .. '.json'
    mm.deadEnds = loadJson(mm.deadEndPath)
    mm.deaths = loadJson(mm.deathPath)
    mm.good = loadJson(mm.goodPath)
end

local function saveDE()
    if not hasFs() or not mm.deadEndPath then return end
    pcall(function() writefile(mm.deadEndPath, svc.http:JSONEncode(mm.deadEnds)) end)
end

local function rememDE(pos)
    for i,s in ipairs(mm.deadEnds) do
        local dx, dy, dz = pos.X - s.x, pos.Y - s.y, pos.Z - s.z
        if (dx * dx + dy * dy + dz * dz) < (mm.mergeR * mm.mergeR) then return end
    end
    table.insert(mm.deadEnds, {x = pos.X, y = pos.Y, z = pos.Z})
    saveDE()
    if win then win:notify('AutoFarm', 'Learned a dead end (' .. #mm.deadEnds .. ' known)', 3) end
end

local function saveDth()
    if not hasFs() or not mm.deathPath then return end
    pcall(function() writefile(mm.deathPath, svc.http:JSONEncode(mm.deaths)) end)
end

local function rememDth(pos)
    for i,s in ipairs(mm.deaths) do
        local dx, dy, dz = pos.X - s.x, pos.Y - s.y, pos.Z - s.z
        if (dx * dx + dy * dy + dz * dz) < (mm.mergeR * mm.mergeR) then return end
    end
    table.insert(mm.deaths, {x = pos.X, y = pos.Y, z = pos.Z})
    saveDth()
    if win then win:notify('AutoFarm', 'Remembered a death spot (' .. #mm.deaths .. ' known)', 3) end
end

local function saveGood()
    if not hasFs() or not mm.goodPath then return end
    pcall(function() writefile(mm.goodPath, svc.http:JSONEncode(mm.good)) end)
end

local function rememGood(pos)
    for i,s in ipairs(mm.good) do
        local dx, dy, dz = pos.X - s.x, pos.Y - s.y, pos.Z - s.z
        if (dx * dx + dy * dy + dz * dz) < (mm.mergeR * mm.mergeR) then return end
    end
    table.insert(mm.good, {x = pos.X, y = pos.Y, z = pos.Z})
    saveGood()
    if win then win:notify('AutoFarm', 'Learned a good escape spot (' .. #mm.good .. ' known)', 3) end
end

local function distGood(pos)
    local best = math.huge
    for i,s in ipairs(mm.good) do
        local dx, dy, dz = pos.X - s.x, pos.Y - s.y, pos.Z - s.z
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)
        if d < best then best = d end
    end
    return best
end

local function nearDth(pos)
    for i,s in ipairs(mm.deaths) do
        local dx, dy, dz = pos.X - s.x, pos.Y - s.y, pos.Z - s.z
        if (dx * dx + dy * dy + dz * dz) < (mm.deathR * mm.deathR) then return true end
    end
    return false
end

local function ensureMM()
    local id = mapId()
    if id ~= mm.mapId then loadMM(id) end
end

local function distDE(pos)
    local best = math.huge
    for i,s in ipairs(mm.deadEnds) do
        local dx, dy, dz = pos.X - s.x, pos.Y - s.y, pos.Z - s.z
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)
        if d < best then best = d end
    end
    return best
end

local angs = {0, 35, -35, 70, -70, 110, -110, 150, -150}

local function clearDir(baseDir, maxDist, avoidPos)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {chr}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local origin = grm.Position
    local bestDir, bestScore = baseDir, -1
    for i,a in ipairs(angs) do
        local dir = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(a)):VectorToWorldSpace(baseDir)
        local hit = workspace:Raycast(origin, dir * maxDist, rp)
        local cd = hit and hit.Distance or maxDist
        local endpoint = origin + dir * cd
        local nearDE = distDE(endpoint) < mm.penaltyR
        if cd >= maxDist - 1 and not nearDE then
            local far = origin + dir * maxDist
            local g = workspace:Raycast(far, Vector3.new(0, -15, 0), rp)
            if g then return dir, cd end
        end
        local score = nearDE and cd * 0.3 or cd
        if avoidPos and distGood(endpoint) < mm.goodR and (endpoint - avoidPos).Magnitude > hideR then
            score = score * mm.goodBonus
        end
        if score > bestScore then bestScore = score; bestDir = dir end
    end
    return bestDir, bestScore
end

local angs360 = {0, 20, -20, 40, -40, 60, -60, 80, -80, 100, -100, 120, -120, 140, -140, 160, -160, 180}

local function clearDir360(fromPos, maxDist, avoidPos)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {chr}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local bestDir, bestScore = Vector3.new(1, 0, 0), -1
    for i,a in ipairs(angs360) do
        local dir = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(a)):VectorToWorldSpace(Vector3.new(1, 0, 0))
        local hit = workspace:Raycast(fromPos, dir * maxDist, rp)
        local cd = hit and hit.Distance or maxDist
        local endpoint = fromPos + dir * cd
        local score = cd
        if distDE(endpoint) < mm.penaltyR then score = cd * 0.3 end
        if avoidPos and distGood(endpoint) < mm.goodR and (endpoint - avoidPos).Magnitude > hideR then
            score = score * mm.goodBonus
        end
        if score > bestScore then bestScore = score; bestDir = dir end
    end
    return bestDir, bestScore
end

local stabR = 6
local throwR = 60

local function knife()
    return chr:FindFirstChild('Knife') or lp.Backpack:FindFirstChild('Knife')
end

local stabT = 0
local function doStab()
    if os.clock() - stabT < 0.5 then return end
    local k = knife()
    local ev = k and k:FindFirstChild('Events')
    local r = ev and ev:FindFirstChild('KnifeStabbed')
    if not r then return end
    stabT = os.clock()
    pcall(function() k:Activate() end)
    pcall(function() r:FireServer() end)
end

local throwT = 0
local function doThrow(tc, tp)
    if os.clock() - throwT < 1 then return end
    local k = knife()
    local ev = k and k:FindFirstChild('Events')
    local r = ev and ev:FindFirstChild('KnifeThrown')
    if not r then return end
    local origin = grm.Position + Vector3.new(0, 1.5, 0)
    if not los(origin, tp, tc) then return end
    throwT = os.clock()
    local ocf = CFrame.lookAt(origin, tp)
    local hcf = CFrame.new(tp)
    pcall(function() r:FireServer(ocf, hcf) end)
end

local chaseStep = 15

local function chaseMove(tg)
    local td = tg.Position - grm.Position
    local flat = Vector3.new(td.X, 0, td.Z)
    if flat.Magnitude < 0.1 then return end
    local dir = clearDir(flat.Unit, chaseStep)
    local step = math.min(flat.Magnitude, chaseStep)
    local mp = grm.Position + dir * step
    hum:MoveTo(Vector3.new(mp.X, grm.Position.Y, mp.Z))
    if math.random() < 0.1 then hum.Jump = true end
end

local zigAmp = 6
local function zigMove(tg)
    local td = tg.Position - grm.Position
    local flat = Vector3.new(td.X, 0, td.Z)
    if flat.Magnitude < 0.1 then return end
    local fwd = clearDir(flat.Unit, chaseStep)
    local rt = fwd:Cross(Vector3.new(0, 1, 0))
    local zig = rt * math.sin(os.clock() * 6) * zigAmp
    local mp = grm.Position + fwd * 10 + zig
    hum:MoveTo(Vector3.new(mp.X, grm.Position.Y, mp.Z))
    if math.random() < 0.15 then hum.Jump = true end
end

local function murGone()
    if not mur then return true end
    local mc = mur.Character
    if not mc then return true end
    local h = mc:FindFirstChildOfClass('Humanoid')
    local g = mc:FindFirstChild('HumanoidRootPart')
    if not h or not g or h.Health <= 0 then return true end
    return (g.Position - grm.Position).Magnitude > hideExR
end

local retSpd = 24
local retDist = 20
local retStickyT = 1.2
local retDir, retDirT = nil, 0
local retDot = -0.85

local armEnter = 12
local armExit = 20
local armRet = false
local armRetDir, armRetDirT = nil, 0
local armApDir, armApDirT = nil, 0
local cornerT = 6

local manualActive = false

local function manualHeld()
    if svc.uis:GetFocusedTextBox() then return false end
    return svc.uis:IsKeyDown(Enum.KeyCode.W) or svc.uis:IsKeyDown(Enum.KeyCode.A) or svc.uis:IsKeyDown(Enum.KeyCode.S) or svc.uis:IsKeyDown(Enum.KeyCode.D)
end

local function endManual()
    if not manualActive then return end
    manualActive = false
    if grm then rememGood(grm.Position) end
end

local function retreat()
    if not mur or not grm or not hum then return end
    ensureMM()
    if manualHeld() then
        if not manualActive then
            manualActive = true
            rememDE(grm.Position)
        end
        return
    end
    endManual()
    local mc = mur.Character
    local tg = mc and mc:FindFirstChild('HumanoidRootPart')
    if not tg then return end
    hum.WalkSpeed = retSpd
    local away = grm.Position - tg.Position
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
    away = away.Unit
    local dir
    if retDir and os.clock() - retDirT < retStickyT and retDir:Dot(away) > retDot then
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {chr}
        rp.FilterType = Enum.RaycastFilterType.Blacklist
        if not workspace:Raycast(grm.Position, retDir * retDist, rp) then dir = retDir end
    end
    if not dir then
        local cd
        dir, cd = clearDir(away, retDist, tg.Position)
        if cd < cornerT then
            rememDE(grm.Position)
            local wd, wc = clearDir360(grm.Position, retDist, tg.Position)
            if wc > cd then dir, cd = wd, wc end
            hum.Jump = true
        end
        retDir = dir
        retDirT = os.clock()
    end
    local ap = grm.Position + dir * retDist
    hum:MoveTo(Vector3.new(ap.X, grm.Position.Y, ap.Z))
end

local function goHide()
    hiding = true
    if win then win:notify('Hiding', 'Murderer nearby -- keeping distance', 3) end
end

local function unHide()
    hiding = false
    dangerT = nil
    safeT = nil
    retDir = nil
    if win then win:notify('Hiding', 'Clear -- resuming farming', 2) end
end

local aimMinY = -1.5
local aimMaxY = 2.8
local aimJit = 0.6

local function aimPoint(tg)
    local base = tg.Position
    local vok, vel = pcall(function() return tg.AssemblyLinearVelocity end)
    if vok and vel then
        local pok, ping = pcall(function() return lp:GetNetworkPing() end)
        local lead = (pok and ping or 0.1) / 2
        base = base + vel * lead
    end
    local hOff = aimMinY + math.random() * (aimMaxY - aimMinY)
    local ang = math.random() * math.pi * 2
    local jit = math.random() * aimJit
    local ho = Vector3.new(math.cos(ang) * jit, 0, math.sin(ang) * jit)
    return base + Vector3.new(0, hOff, 0) + ho
end

local shotT = 0
local function doShoot(ignoreLos)
    if not shootOn then return end
    if not mur then return end
    local mc = mur.Character
    if not mc then return end
    local mh = mc:FindFirstChildOfClass('Humanoid')
    local mg = mc:FindFirstChild('HumanoidRootPart')
    if not mh or not mg or mh.Health <= 0 then return end
    local origin = grm.Position + Vector3.new(0, 1.5, 0)
    local actual = mg.Position
    if (actual - origin).Magnitude > rng then return end
    if not ignoreLos and not los(origin, actual, mc) then return end
    if os.clock() - shotT < 0.6 then return end
    shotT = os.clock()
    eqGun()
    local gt = chr:FindFirstChild('Gun')
    local sr = gt and gt:FindFirstChild('Shoot')
    if not sr then return end
    local tp = aimPoint(mg)
    local ocf = CFrame.lookAt(origin, tp)
    local hcf = CFrame.new(tp)
    pcall(function() sr:FireServer(ocf, hcf) end)
end

svc.uis.InputBegan:Connect(function(k, gp)
    if not isRun() then return end
    if gp then return end
    if k.UserInputType ~= Enum.UserInputType.MouseButton1 and k.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if not chr or not grm then return end
    pcall(doShoot, true)
end)

local gunCd = 4
local gunCdT = 0

local function needGun()
    if role == 'Sheriff' then return false end
    if hasGun() then return false end
    return gunDown
end

local recent = setmetatable({}, {__mode = 'k'})
local recentCd = 2
local counted = setmetatable({}, {__mode = 'k'})
local failCd = 10
local gDepth = 75

local function reach(part)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {chr}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local r = workspace:Raycast(part.Position, Vector3.new(0, -gDepth, 0), rp)
    return r ~= nil
end

local stuckT = 3
local stuckSince = nil

local function farmNear()
    local parts = findCoins()
    if #parts == 0 then
        stuckSince = nil
        task.wait(1)
        return
    end
    local now = os.clock()
    local closest, cd = nil, math.huge
    for i,part in ipairs(parts) do
        local bl = recent[part]
        if not (bl and now - bl < recentCd) then
            if reach(part) then
                local dist = (part.Position - grm.Position).Magnitude
                if dist < cd then closest = part; cd = dist end
            end
        end
    end
    if not closest then
        stuckSince = stuckSince or now
        if not walkMode and now - stuckSince >= stuckT then
            for i,part in ipairs(parts) do
                local bl = recent[part]
                if not (bl and now - bl < recentCd) then
                    local dist = (part.Position - grm.Position).Magnitude
                    if dist < cd then closest = part; cd = dist end
                end
            end
        end
    else
        stuckSince = nil
    end
    if closest then
        recent[closest] = now
        local reached, destroyed = farmCoin(closest)
        if reached and not counted[closest] then
            counted[closest] = true
            fc = fc + 1
            coins = coins + 1
            allTime.coins = allTime.coins + 1
            if allTime.coins % 10 == 0 then allTime.save() end
        end
        if not destroyed then
            recent[closest] = now + (failCd - recentCd)
        end
    else
        task.wait(0.2)
    end
end

local function idleSpd()
    if hum and ows and hum.WalkSpeed ~= ows then
        pcall(function() hum.WalkSpeed = ows end)
    end
end

local function doHide()
    if not (hideOn and role ~= 'Murderer' and not hasGun()) then return false end
    if hiding then
        cbt = true
        if murGone() then
            safeT = safeT or os.clock()
            if os.clock() - safeT >= hideExT then
                unHide()
            else
                retreat()
            end
        else
            safeT = nil
            retreat()
        end
        task.wait(0.2)
        return true
    elseif murDanger() then
        dangerT = dangerT or os.clock()
        if os.clock() - dangerT >= hideT then
            goHide()
            cbt = true
            retreat()
            task.wait(0.2)
            return true
        end
    else
        dangerT = nil
    end
    return false
end

local capDone = false

local function shfBreak()
    if murDanger() then return true end
    if not mur or not nearDth(grm.Position) then return false end
    local mc = mur.Character
    local mh = mc and mc:FindFirstChildOfClass('Humanoid')
    local mg = mc and mc:FindFirstChild('HumanoidRootPart')
    if not (mh and mg and mh.Health > 0) then return false end
    return (mg.Position - grm.Position).Magnitude <= hideR * 1.5
end

local function tick()
    cbt = false
    if not manualHeld() then endManual() end
    if inLobby() then
        idleSpd()
        task.wait(0.5)
        return
    end

    if role == 'Murderer' then
        if not huntOn then
            idleSpd()
            task.wait(0.3)
            return
        end
        cbt = true
        eqWep()
        hum.WalkSpeed = 16
        local tg = pickTgt()
        if tg then
            local tc = tg.Character
            local tgm = tc and tc:FindFirstChild('HumanoidRootPart')
            if tgm then
                local dist = (tgm.Position - grm.Position).Magnitude
                local hasWep = tc:FindFirstChildWhichIsA('Tool') ~= nil
                local threat = tg == shf and hasWep
                if threat then
                    zigMove(tgm)
                else
                    chaseMove(tgm)
                end
                if dist <= stabR then
                    local prev = stabT
                    doStab()
                    if stabT == prev then doThrow(tc, tgm.Position) end
                elseif dist <= throwR then
                    doThrow(tc, tgm.Position)
                end
            end
        end
        task.wait(0.15)
        return
    end

    if gunOn and role ~= 'Sheriff' and needGun() then
        if os.clock() < gunCdT then
            if farmOn then
                farmNear()
            elseif not doHide() then
                idleSpd()
                task.wait(0.2)
            end
            return
        end
        local gp = findGun()
        if gp then
            if not grabGun(gp) then gunCdT = os.clock() + gunCd end
        elseif farmOn then
            farmNear()
        elseif not doHide() then
            idleSpd()
            task.wait(0.2)
        end
        return
    end

    if doHide() then return end

    if role == 'Sheriff' then
        ensureMM()
        if not capDone and getCoins() >= coinCap then capDone = true end
        if farmOn and not capDone and not shfBreak() then
            farmNear()
            return
        end
    end

    if hasGun() then
        if not shootOn then
            idleSpd()
            task.wait(0.3)
            return
        end
        cbt = true
        eqGun()
        hum.WalkSpeed = 21
        local mc = mur and mur.Character
        local mh = mc and mc:FindFirstChildOfClass('Humanoid')
        local mg = mc and mc:FindFirstChild('HumanoidRootPart')
        if mh and mg and mh.Health > 0 then
            local td = mg.Position - grm.Position
            local flat = Vector3.new(td.X, 0, td.Z)
            local dist = td.Magnitude
            if armRet then
                if dist > armExit then armRet = false end
            elseif dist < armEnter then
                armRet = true
            end
            if armRet and flat.Magnitude > 0.1 and manualHeld() then
                if not manualActive then
                    manualActive = true
                    ensureMM()
                    rememDE(grm.Position)
                end
            elseif armRet and flat.Magnitude > 0.1 then
                local away = -flat.Unit
                local dir
                if armRetDir and os.clock() - armRetDirT < retStickyT and armRetDir:Dot(away) > retDot then
                    local rp = RaycastParams.new()
                    rp.FilterDescendantsInstances = {chr}
                    rp.FilterType = Enum.RaycastFilterType.Blacklist
                    if not workspace:Raycast(grm.Position, armRetDir * 20, rp) then dir = armRetDir end
                end
                if not dir then
                    dir = clearDir(away, 20, mg.Position)
                    armRetDir = dir
                    armRetDirT = os.clock()
                end
                local ap = grm.Position + dir * 20
                hum:MoveTo(Vector3.new(ap.X, grm.Position.Y, ap.Z))
            elseif not armRet and dist <= rng and not los(grm.Position + Vector3.new(0, 1.5, 0), mg.Position, mc) and flat.Magnitude > 0.1 then
                local appr = flat.Unit
                local dir
                if armApDir and os.clock() - armApDirT < retStickyT and armApDir:Dot(appr) > retDot then
                    local rp = RaycastParams.new()
                    rp.FilterDescendantsInstances = {chr}
                    rp.FilterType = Enum.RaycastFilterType.Blacklist
                    if not workspace:Raycast(grm.Position, armApDir * 15, rp) then dir = armApDir end
                end
                if not dir then
                    dir = clearDir(appr, 15)
                    armApDir = dir
                    armApDirT = os.clock()
                end
                local ap = grm.Position + dir * math.min(flat.Magnitude, 15)
                hum:MoveTo(Vector3.new(ap.X, grm.Position.Y, ap.Z))
            end
        end
        doShoot()
        task.wait(0.2)
        return
    end

    if getCoins() >= coinCap then
        idleSpd()
        task.wait(0.5)
        return
    end

    if farmOn then
        farmNear()
    else
        idleSpd()
        task.wait(0.3)
    end
end

local hop = {on = true, min = 4, checkInt = 45, active = false, ts = nil}

function hop.go()
    if hop.active then return end
    hop.active = true
    if not hop.ts then hop.ts = call('TeleportService') end
    if win then win:notify('AutoFarm', 'Low player count -- server hopping', 3) end
    pcall(function()
        hop.ts.TeleportInitFailed:Connect(function(plr, result, msg)
            if plr ~= lp then return end
            task.wait(3)
            pcall(function() hop.ts:Teleport(game.PlaceId, lp) end)
        end)
    end)
    pcall(function() hop.ts:Teleport(game.PlaceId, lp) end)
end

task.spawn(function()
    while isRun() do
        wait(hop.checkInt)
        if hop.on and not hop.active and st == 'Farming' and #svc.plr:GetPlayers() < hop.min then
            hop.go()
        end
    end
end)

local function loop()
    while isRun() do
        if not en or st ~= 'Farming' then
            if hum and ows and hum.WalkSpeed ~= ows then
                pcall(function() hum.WalkSpeed = ows end)
            end
            task.wait(0.5)
        else
            local ok, err = pcall(tick)
            if not ok then
                warn(tostring(err))
                task.wait(0.3)
            else
                task.wait()
            end
        end
    end
end

local descConn
local function watchDesc(c)
    if descConn then descConn:Disconnect() end
    descConn = c.DescendantAdded:Connect(function(d)
        if not d:IsA('BasePart') then return end
        if d.CanCollide == false then return end
        if d:FindFirstAncestorWhichIsA('Tool') then
            d.CanCollide = false
            pcall(function() d.AssemblyLinearVelocity = Vector3.zero end)
            if grm then pcall(function() grm.AssemblyLinearVelocity = Vector3.zero end) end
            return
        end
        if ncApplied == true then
            d.CanCollide = false
            ncParts[d] = true
            pcall(function() d.AssemblyLinearVelocity = Vector3.zero end)
            if grm then pcall(function() grm.AssemblyLinearVelocity = Vector3.zero end) end
        end
    end)
end

svc.run.Heartbeat:Connect(function()
    if not isRun() then return end
    setNoclip(ncOk())
end)

local avMargin = 25
local avUp = 100
local avInt = 0.1
local avT = 0
local avConn = svc.run.Stepped:Connect(function()
    if not isRun() then return end
    if not grm then return end
    if os.clock() - avT < avInt then return end
    avT = os.clock()
    if grm.Position.Y <= workspace.FallenPartsDestroyHeight + avMargin then
        pcall(function()
            local v = grm.AssemblyLinearVelocity
            grm.AssemblyLinearVelocity = Vector3.new(v.X, avUp, v.Z)
        end)
    end
end)

local function fixColl()
    if grm then
        pcall(function() grm.CFrame = grm.CFrame + Vector3.new(0, 4, 0) end)
    end
    setNoclip(false)
    hiding = false
    dangerT = nil
    safeT = nil
    retDir = nil
end

local hpConn, attrConn

local function died()
    if st == 'Dead' then return end
    pcall(function()
        if grm and mur then
            ensureMM()
            local mc = mur.Character
            local mg = mc and mc:FindFirstChild('HumanoidRootPart')
            if mg and (mg.Position - grm.Position).Magnitude < 40 then
                rememDth(grm.Position)
            end
        end
    end)
    allTime.deaths = allTime.deaths + 1
    allTime.save()
    st = 'Dead'
    fixColl()
    if win then win:notify('Dead', 'Waiting for the next round', 3) end
end

local function onChar(c)
    if not isRun() then return end
    chr = c
    grm = c:WaitForChild('HumanoidRootPart')
    hum = c:WaitForChild('Humanoid')
    ncApplied = nil
    hiding = false
    dangerT = nil
    safeT = nil
    retDir = nil
    ows = hum.WalkSpeed
    watchDesc(c)

    if dcn then dcn:Disconnect() end
    dcn = hum.Died:Connect(died)

    if hpConn then hpConn:Disconnect() end
    hpConn = hum.HealthChanged:Connect(function(h)
        if h <= 0 then died() end
    end)

    if attrConn then attrConn:Disconnect() end
    attrConn = c:GetAttributeChangedSignal('Dead'):Connect(function()
        if c:GetAttribute('Dead') then died() end
    end)

    if st == 'Dead' or st == 'Lobby' then st = 'Lobby' end
end

local function hookRemotes()
    local ok, gp = pcall(function()
        return svc.rep:WaitForChild('Remotes', 5):WaitForChild('Gameplay', 5)
    end)
    if not ok or not gp then return end

    local rs = gp:FindFirstChild('RoundStart')
    if rs and rs:IsA('RemoteEvent') then
        rs.OnClientEvent:Connect(function(_, rp)
            if not isRun() then return end
            pcall(setRole, rp)
            fst = 0
            over = false
            lastHero = nil
            coins = 0
            coinCap = 40
            rtu = os.clock() + rtuPause
            hiding = false
            dangerT = nil
            safeT = nil
            retDir = nil
            gunCdT = 0
            curTgt = nil
            curTgtT = 0
            capDone = false
            counted = setmetatable({}, {__mode = 'k'})
            recent = setmetatable({}, {__mode = 'k'})
            if st ~= 'Dead' then st = 'Lobby' end
        end)
    end

    local cs = gp:FindFirstChild('CoinsStarted')
    if cs and cs:IsA('RemoteEvent') then
        cs.OnClientEvent:Connect(function(payload)
            if not isRun() then return end
            if type(payload) == 'table' and type(payload.Coin) == 'table' then
                if type(payload.Coin.CollectedAmount) == 'number' and payload.Coin.CollectedAmount > coins then
                    coins = payload.Coin.CollectedAmount
                end
                if type(payload.Coin.CollectionLimit) == 'number' then
                    coinCap = payload.Coin.CollectionLimit
                end
            end
            if st ~= 'Dead' and hum and hum.Health > 0 and not inLobby() then
                st = 'Farming'
                fst = os.clock()
            end
        end)
    end

    local cc = gp:FindFirstChild('CoinCollected')
    if cc and cc:IsA('RemoteEvent') then
        cc.OnClientEvent:Connect(function(bag, amt, cap)
            if not isRun() then return end
            if bag == 'Coin' and type(amt) == 'number' then
                coins = amt
                if type(cap) == 'number' then coinCap = cap end
            end
        end)
    end

    local function lastHeroCatch()
        for i,plr in ipairs(svc.plr:GetPlayers()) do
            if plr ~= shf then
                local c = plr.Character
                local eq = c and c:FindFirstChildWhichIsA('Tool')
                if eq and eq.Name:lower():find('gun') then
                    lastHero = plr
                    return
                end
            end
        end
    end

    local ref = gp:FindFirstChild('RoundEndFade')
    if ref and ref:IsA('RemoteEvent') then
        ref.OnClientEvent:Connect(function()
            if not isRun() then return end
            st = 'Lobby'
            fixColl()
            lastHeroCatch()
            over = true
        end)
    end

    local vs = gp:FindFirstChild('VictoryScreen')
    if vs and vs:IsA('RemoteEvent') then
        vs.OnClientEvent:Connect(function(won, role1, reason)
            if not isRun() then return end
            st = 'Lobby'
            fixColl()
            lastHeroCatch()
            over = true
            if win then win:notify(won and 'Victory' or 'Round Over', tostring(reason or ''), 3) end
        end)
    end

    local sdc
    local function watchShf()
        if not shf then return end
        local c = shf.Character
        if not c then return end
        local h = c:FindFirstChildOfClass('Humanoid')
        if not h then return end
        if sdc then sdc:Disconnect() end
        sdc = h.Died:Once(function()
            if role ~= 'Sheriff' then
                gunDown = true
                if win then win:notify('Sheriff Down', 'Gun is up for grabs', 3) end
            end
        end)
    end

    local shfErr = false
    task.spawn(function()
        while isRun() do
            wait(1)
            if not (os.clock() < rtu) then
                local ok1, err = pcall(function()
                    watchShf()
                    if shf and not gunDown and role ~= 'Sheriff' and fst > 0 and os.clock() - fst > 5 then
                        local c = shf.Character
                        local g = c and c:FindFirstChild('HumanoidRootPart')
                        if g and inLobbyPos(g.Position) then
                            gunDown = true
                            if win then win:notify('Sheriff Down', 'Gun is up for grabs', 3) end
                        end
                    end
                end)
                if not ok1 and not shfErr then
                    shfErr = true
                    warn(tostring(err))
                end
            end
        end
    end)
end

chr = lp.Character or lp.CharacterAdded:Wait()
onChar(chr)
ccn = lp.CharacterAdded:Connect(onChar)
allTime.load()

local uok, kyri = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua'))()
end)

if uok and kyri then
    win = kyri.new('MM2', {
        GameName = 'Murder Mystery 2',
        AutoLoad = 'default'
    })
end

if win then
    local t1 = win:tab('AutoFarm', 'sword')

    t1:section('master')
    t1:toggle('Enabled', true, function(v) en = v end, 'enabled')
    t1:keybind('Toggle Enabled', 'Q', false, function()
        en = not en
        win:notify('AutoFarm', en and 'Enabled' or 'Disabled', 2)
    end, 'toggle_key')

    t1:section('features')
    t1:toggle('Auto Farm Coins', true, function(v) farmOn = v end, 'autocoinfarm')
    t1:toggle('Auto Grab Dropped Gun', true, function(v) gunOn = v end, 'autogunpickup')
    t1:toggle('Auto Hide From Murderer', true, function(v) hideOn = v end, 'antimurdererhide')
    t1:toggle('Auto Hunt (as Murderer)', true, function(v) huntOn = v end, 'automurdererhunt')

    t1:section('movement')
    t1:dropdown('Coin Movement Style', {'Tween', 'Walk'}, 'Tween', function(sel)
        walkMode = (sel == 'Walk')
    end, 'movementstyle')
    t1:label('Tween = smooth slide. Walk = real humanoid walking paced by WalkSpeed.')

    t1:section('training')
    t1:keybind('Mark Bad Spot (Here)', 'B', false, function()
        if not grm then return end
        ensureMM()
        rememDE(grm.Position)
    end, 'markbad')
    t1:keybind('Mark Good Escape (Here)', 'N', false, function()
        if not grm then return end
        ensureMM()
        rememGood(grm.Position)
    end, 'markgood')
    t1:label('Stand where it messed up and press B to flag it, or run to the spot you wanted it to use and press N. Both save per-map and apply next time.')

    t1:section('server')
    t1:toggle('Auto Server Hop (low pop)', true, function(v) hop.on = v end, 'autohop')
    t1:slider('Min Players', 1, 10, 4, function(v) hop.min = v end, 'minplayers')
    t1:label('Checks every 45s while farming -- teleports out and keeps retrying until it lands on a fuller server.')

    local t2 = win:tab('MM2 - Soft Aim', 'target')

    t2:section('soft aim')
    t2:toggle('Soft Aim (Auto Shoot)', true, function(v) shootOn = v end, 'autoshoot')
    t2:slider('Shot Range', 20, 200, 120, function(v) rng = v end, 'range')
    t2:keybind('Auto Shoot Key', 'V', false, function()
        if not chr or not grm then return end
        pcall(doShoot, true)
    end, 'autoshootkey')
    t2:label('Click, press the keybind, or use the mobile + button to fire the assisted shot.')

    local t3 = win:tab('Visuals', 'eye')
    t3:section('esp')
    t3:toggle('ESP (Sheriff/Murderer/Hero)', true, function(v) espOn = v end, 'esp')

    local t4 = win:tab('Stats', 'chart')

    t4:section('live status')
    local roleLbl = t4:label('Role: --')
    local stLbl = t4:label('State: --')
    local coinLbl = t4:label('Coins: --')
    local armLbl = t4:label('Armed: --')

    t4:section('round')
    local shfLbl = t4:label('Sheriff: --')
    local murLbl = t4:label('Murderer: --')
    local hideLbl = t4:label('Hiding: --')

    t4:section('session')
    local upLbl = t4:label('Uptime: --')
    local fcLbl = t4:label('Coins farmed (session): --')

    t4:button('Show Stats', function()
        win:notify('Stats', string.format('Running %s | %d coins farmed', fmtT(), fc), 4)
    end)

    t4:section('all-time')
    allTime.uiCoin = t4:label('Total coins farmed: --')
    allTime.uiTime = t4:label('Total time played: --')
    allTime.uiDeath = t4:label('Total deaths: --')
    allTime.uiSess = t4:label('Sessions run: --')
    t4:button('Reset All-Time Stats', function()
        allTime.coins = 0
        allTime.baseSeconds = 0
        allTime.sessions = 1
        allTime.deaths = 0
        t0 = os.clock()
        allTime.save()
        if win then win:notify('AutoFarm', 'All-time stats reset', 2) end
    end)

    t4:section('learning')
    mm.uiDE = t4:label('Known dead ends (this map): --')
    t4:button('Forget Dead Ends (this map)', function()
        mm.deadEnds = {}
        saveDE()
        if win then win:notify('AutoFarm', 'Cleared dead-end memory', 2) end
    end)
    mm.uiDeath = t4:label('Known death spots (this map): --')
    t4:button('Forget Death Spots (this map)', function()
        mm.deaths = {}
        saveDth()
        if win then win:notify('AutoFarm', 'Cleared death memory', 2) end
    end)
    mm.uiGood = t4:label('Known good escapes (this map): --')
    t4:button('Forget Good Escapes (this map)', function()
        mm.good = {}
        saveGood()
        if win then win:notify('AutoFarm', 'Cleared good-escape memory', 2) end
    end)

    t4:section('actions')
    t4:button('Rejoin Server', function()
        local ts = call('TeleportService')
        local ok = pcall(function()
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
        end)
        if not ok then
            pcall(function() ts:Teleport(game.PlaceId, lp) end)
        end
    end)

    task.spawn(function()
        while isRun() do
            local ok = pcall(function()
                roleLbl:set('Role: ' .. role)
                stLbl:set('State: ' .. st)
                coinLbl:set(string.format('Coins: %d / %d', getCoins(), coinCap))
                armLbl:set('Armed: ' .. (hasGun() and 'Yes' or 'No'))

                local st1 = 'Sheriff: --'
                if shf then
                    local sc = shf.Character
                    local sh = sc and sc:FindFirstChildOfClass('Humanoid')
                    local alive = sh and sh.Health > 0
                    if gunDown then
                        st1 = string.format('Sheriff: %s (down, gun dropped)', shf.Name)
                    elseif alive then
                        st1 = string.format('Sheriff: %s (alive)', shf.Name)
                    else
                        st1 = string.format('Sheriff: %s (down)', shf.Name)
                    end
                end
                shfLbl:set(st1)

                local mt = 'Murderer: --'
                if mur then
                    local mc = mur.Character
                    local mh = mc and mc:FindFirstChildOfClass('Humanoid')
                    local alive = mh and mh.Health > 0
                    mt = string.format('Murderer: %s (%s)', mur.Name, alive and 'alive' or 'down')
                end
                murLbl:set(mt)

                himm.uiDE:set('Hiding: ' .. (hiding and 'Yes' or 'No'))
                upLbl:set('Uptime: ' .. fmtT())
                fcLbl:set('Coins farmed (session): ' .. fc)
                mm.uiDE:set('Known dead ends (this map): ' .. #mm.deadEnds)
                mm.uiDeath:set('Known death spots (this map): ' .. #mm.deaths)
                mm.uiGood:set('Known good escapes (this map): ' .. #mm.good)
                allTime.uiCoin:set('Total coins farmed: ' .. allTime.coins)
                allTime.uiTime:set('Total time played: ' .. allTime.fmt())
                allTime.uiDeath:set('Total deaths: ' .. allTime.deaths)
                allTime.uiSess:set('Sessions run: ' .. allTime.sessions)
            end)
            wait(0.5)
        end
    end)
else
    warn('KyriLib failed to load')
end

if svc.uis.TouchEnabled and not svc.uis.KeyboardEnabled then
    local mGui = Instance.new('ScreenGui')
    mGui.Name = 'af' .. math.random(1000, 9999)
    mGui.ResetOnSpawn = false
    mGui.IgnoreGuiInset = true
    mGui.Parent = gethui and gethui() or lp:WaitForChild('PlayerGui')
    gui2.mobile = mGui

    local btn = Instance.new('TextButton')
    btn.Name = 'b'
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, -20, 0.5, 0)
    btn.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
    btn.BackgroundTransparency = 0.2
    btn.BorderSizePixel = 0
    btn.Text = '+'
    btn.TextSize = 36
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Parent = mGui

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    btn.Activated:Connect(function()
        if not isRun() then return end
        if not chr or not grm then return end
        pcall(doShoot, true)
    end)
end

task.spawn(function()
    while isRun() do
        wait(300)
        if win and isRun() then
            win:notify('Stats', string.format('Running %s | %d coins farmed', fmtT(), fc), 4)
        end
        allTime.save()
    end
end)

task.spawn(function()
    while isRun() do
        if gui2.bgStat then
            gui2.bgStat.Text = string.format('Coins: %d / %d | Session: %d | All-time: %d (%s)', getCoins(), coinCap, fc, allTime.coins, allTime.fmt())
        end
        wait(1)
    end
end)

_G.SimpleAFCleanup = function()
    en = false
    st = 'Lobby'
    pcall(allTime.save)
    pcall(function() if ccn then ccn:Disconnect() end end)
    pcall(function() if dcn then dcn:Disconnect() end end)
    pcall(function() if hpConn then hpConn:Disconnect() end end)
    pcall(function() if attrConn then attrConn:Disconnect() end end)
    pcall(function() if descConn then descConn:Disconnect() end end)
    pcall(function() if avConn then avConn:Disconnect() end end)
    for i,tag in pairs(tags) do
        pcall(function() tag:Destroy() end)
    end
    pcall(function() if gui2.mobile then gui2.mobile:Destroy() end end)
    pcall(function() if gui2.bg then gui2.bg:Destroy() end end)
    pcall(function() svc.run:Set3dRenderingEnabled(true) end)
    pcall(fixColl)
    if hum and ows then
        pcall(function() hum.WalkSpeed = ows end)
    end
    if win then pcall(function() win:destroy() end) end
end

hookRemotes()
loop()
