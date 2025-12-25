-- fixed

local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.run = call("RunService")
svc.vu = call("VirtualUser")

local player = svc.plr.LocalPlayer
local running = false
local candyNames = {common = true, uncommon = true, rare = true, legendary = true, mythic = true}
local candyOrder = {"common", "uncommon", "rare", "legendary", "mythic"}
local totalCollected = 0
local rarityCount = {common = 0, uncommon = 0, rare = 0, legendary = 0, mythic = 0}
local antiAfkEnabled = false
local useTeleport = false

local KyriLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()

local window = KyriLib.new("Candycane Macro", {
    GameName = "CandyFarm"
})

local main = window:tab("Main")
local stats = window:tab("Stats")
local christmas = window:tab("Christmas")

local antiAfkConnection

local function antiRagdoll()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    hum.BreakJointsOnDeath = false
end

player.CharacterAdded:Connect(function()
    task.wait(1)
    antiRagdoll()
end)

antiRagdoll()

local function clearVelocity()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

local totalLabel = stats:label("total: 0")
local countLabels = {}

for _, rarity in ipairs(candyOrder) do
    countLabels[rarity] = stats:label(rarity .. ": 0")
end

local function updateLabels()
    pcall(function()
        totalLabel.Text = "total: " .. totalCollected
        for _, rarity in ipairs(candyOrder) do
            countLabels[rarity].Text = rarity .. ": " .. rarityCount[rarity]
        end
    end)
end

task.spawn(function()
    while task.wait(0.3) do
        updateLabels()
    end
end)

local counted = {}

local function countCandy(candy)
    if not candy or counted[candy] then return end
    counted[candy] = true
    
    local name = candy.Name:lower()
    totalCollected = totalCollected + 1
    if rarityCount[name] then
        rarityCount[name] = rarityCount[name] + 1
    end
    updateLabels()
end

local function teleportTo(target)
    local char = player.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    clearVelocity()
    antiRagdoll()
    hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 2, 0))
    task.wait(0.05)
    clearVelocity()
    
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and candyNames[obj.Name:lower()] then
            if (hrp.Position - obj.Position).Magnitude <= 6 then
                countCandy(obj)
            end
        end
    end
    
    task.wait(0.1)
    return not target.Parent
end

local function walkTo(target)
    local char = player.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    
    local connection
    local reached = false
    
    connection = hum.MoveToFinished:Connect(function()
        reached = true
        if connection then connection:Disconnect() end
    end)
    
    hum:MoveTo(target.Position)
    
    local timeout = 0
    while not reached and target.Parent and timeout < 50 and running do
        timeout = timeout + 1
        task.wait(0.1)
        
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("BasePart") and candyNames[obj.Name:lower()] then
                if (hrp.Position - obj.Position).Magnitude <= 6 then
                    countCandy(obj)
                end
            end
        end
    end
    
    if connection then connection:Disconnect() end
    
    task.wait(0.1)
    
    return not target.Parent
end

local function moveTo(target)
    if useTeleport then
        return teleportTo(target)
    else
        return walkTo(target)
    end
end

local function getSpawnZone()
    if workspace:FindFirstChild("EventWorld") then
        local spawner = workspace.EventWorld:FindFirstChild("CandySpawner")
        if spawner then
            return spawner:FindFirstChild("SpawnZone")
        end
    end
    return nil
end

local function isInZone(pos, zone)
    if not zone then return false end
    local center = zone.Position
    local size = zone.Size
    local offset = pos - center
    return math.abs(offset.X) <= (size.X/2) + 100
        and math.abs(offset.Z) <= (size.Z/2) + 100
        and offset.Y > -50 and offset.Y < 100
end

local function fullScan()
    local zone = getSpawnZone()
    if not zone then return {} end
    
    local found = {}
    
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj:FindFirstChild("TouchInterest") then
            local name = obj.Name:lower()
            if candyNames[name] and isInZone(obj.Position, zone) then
                table.insert(found, obj)
            end
        end
    end
    
    return found
end

local function collectLoop()
    while running do
        local candies = fullScan()
        
        if #candies > 0 then
            for _, candy in ipairs(candies) do
                if not running then break end
                if candy and candy.Parent then
                    moveTo(candy)
                    countCandy(candy)
                end
            end
            task.wait(0.3)
        else
            task.wait(0.5)
        end
    end
end

local points = {
    snowflake = Vector3.new(-446.67, -50.57, -1388.66),
    gift = Vector3.new(-501.04, -50.57, -1409.20),
    gingerbread = Vector3.new(-555.73, -51.10, -1399.74),
    tree = Vector3.new(-595.99, -51.10, -1364.64)
}

local tpSpeed = 0.5
local activeMacro = nil

local function tp(v3)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    clearVelocity()
    antiRagdoll()
    hrp.CFrame = CFrame.new(v3 + Vector3.new(0, 2, 0))
    task.wait(0.05)
    clearVelocity()
    antiRagdoll()
end

local function runMacro(route)
    activeMacro = route
    while activeMacro == route do
        for _, step in ipairs(route) do
            if activeMacro ~= route then return end
            tp(points[step])
            task.wait(tpSpeed)
        end
    end
end

main:label("farm controls")

main:toggle("auto farm", false, function(state)
    running = state
    if state then
        totalCollected = 0
        counted = {}
        for k in pairs(rarityCount) do
            rarityCount[k] = 0
        end
        updateLabels()
        window:notify("Farm", "started", 2)
        task.spawn(collectLoop)
    else
        window:notify("Farm", "stopped - total: " .. totalCollected, 3)
    end
end, "auto_farm")

main:toggle("use teleport", false, function(state)
    useTeleport = state
    if state then
        window:notify("Movement", "teleport enabled", 2)
    else
        window:notify("Movement", "walking enabled", 2)
    end
end, "use_teleport")

main:toggle("anti afk", false, function(state)
    antiAfkEnabled = state
    if state then
        antiAfkConnection = player.Idled:Connect(function()
            svc.vu:CaptureController()
            svc.vu:ClickButton2(Vector2.new())
        end)
        window:notify("Anti AFK", "enabled", 2)
    else
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
        window:notify("Anti AFK", "disabled", 2)
    end
end, "anti_afk")

christmas:label("teleport macros")

christmas:slider("tp speed (lower = faster)", 0.1, 2, tpSpeed, function(v)
    tpSpeed = v
end)

christmas:button("gift snowflake loop", function()
    if activeMacro then
        activeMacro = nil
        window:notify("Macro", "stopped", 2)
    else
        task.spawn(function()
            runMacro({"snowflake", "gift"})
        end)
        window:notify("Macro", "gift snowflake started", 2)
    end
end)

christmas:button("snow gift gingerbread", function()
    if activeMacro then
        activeMacro = nil
        window:notify("Macro", "stopped", 2)
    else
        task.spawn(function()
            runMacro({"snowflake", "gift", "gingerbread"})
        end)
        window:notify("Macro", "3 point started", 2)
    end
end)

christmas:button("full route loop", function()
    if activeMacro then
        activeMacro = nil
        window:notify("Macro", "stopped", 2)
    else
        task.spawn(function()
            runMacro({"snowflake", "gift", "gingerbread", "tree"})
        end)
        window:notify("Macro", "full route started", 2)
    end
end)

christmas:label("click running macro to stop")

window:accent(Color3.fromRGB(255, 100, 100))
