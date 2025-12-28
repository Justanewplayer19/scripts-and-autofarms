local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.run = call("RunService")
svc.uis = call("UserInputService")
svc.rep = call("ReplicatedStorage")

local KyriLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()

local window = KyriLib.new("MM2", {
    GameName = "MurderMystery2"
})

local main = window:tab("Main", "move")
local combat = window:tab("Combat", "sword")
local visual = window:tab("Visual", "user")
local misc = window:tab("Misc", "settings")

local flying = false
local flySpeed = 50
local bodyVel, bodyGyro
local flyConnection
local isMobile = svc.uis.TouchEnabled and not svc.uis.KeyboardEnabled

local espEnabled = false
local espObjects = {}
local playerRoles = {}
local originalSheriff = nil
local predictedRoles = {}

local gunEspEnabled = false
local gunEspObject = nil
local gunWasPickedUp = false

local autoGunDrop = false
local gunDropFound = false
local lookingForGun = false

local speedEnabled = false
local speedValue = 17

local killingAll = false
local antiFlingEnabled = false
local antiFlingConnection = nil

local antiAfkEnabled = false
local antiAfkConnection = nil

local autoFarmEnabled = false
local coinsCollected = 0
local maxCoins = 40
local farmingCoins = false

local farmStats = {
    allTime = 0,
    thisServer = 0,
    lastServer = 0,
    mostCollected = 0,
    lastSession = 0
}

local statsFile = "mm2_farm_stats.json"

local function searchForGunDrop()
    for _, v in pairs(workspace:GetDescendants()) do
        if v.Name == "GunDrop" and v:IsA("Part") then
            return v
        end
    end
    
    for _, v in pairs(getnilinstances()) do
        if v.Name == "GunDrop" and v:IsA("Part") then
            return v
        end
    end
    
    return nil
end

local function findCoins()
    local coins = {}
    for _, map in pairs(workspace:GetChildren()) do
        local coinContainer = map:FindFirstChild("CoinContainer")
        if coinContainer then
            for _, coin in pairs(coinContainer:GetChildren()) do
                if coin:IsA("Model") or coin:IsA("Part") then
                    table.insert(coins, coin)
                end
            end
        end
    end
    return coins
end

local function loadStats()
    if isfile and readfile and isfile(statsFile) then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(statsFile))
        end)
        if success and data then
            farmStats.allTime = data.allTime or 0
            farmStats.lastServer = data.thisServer or 0
            farmStats.mostCollected = data.mostCollected or 0
        end
    end
end

local function saveStats()
    if writefile then
        local data = {
            allTime = farmStats.allTime,
            thisServer = farmStats.thisServer,
            mostCollected = farmStats.mostCollected
        }
        writefile(statsFile, game:GetService("HttpService"):JSONEncode(data))
    end
end

local function updateStats(amount)
    farmStats.thisServer = farmStats.thisServer + amount
    farmStats.allTime = farmStats.allTime + amount
    farmStats.lastSession = farmStats.lastSession + amount
    
    if farmStats.thisServer > farmStats.mostCollected then
        farmStats.mostCollected = farmStats.thisServer
    end
    
    saveStats()
end

local function tweenToCoin(coin)
    local char = svc.plr.LocalPlayer.Character
    if not char then return false end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    local coinPos = coin:IsA("Model") and coin:GetPivot().Position or coin.Position
    local tw = call("TweenService")
    
    local distance = (root.Position - coinPos).Magnitude
    local speed = 30
    local time = distance / speed
    
    local tween = tw:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = CFrame.new(coinPos)})
    tween:Play()
    tween.Completed:Wait()
    
    wait(0.4)
    return true
end

local function startCoinFarm()
    farmingCoins = true
    coinsCollected = 0
    
    while autoFarmEnabled and farmingCoins do
        if coinsCollected >= maxCoins then
            window:notify("coin farm", "limit reached, resetting", 2)
            svc.plr.LocalPlayer.Character:FindFirstChild("Humanoid").Health = 0
            farmingCoins = false
            break
        end
        
        local coins = findCoins()
        if #coins == 0 then
            window:notify("coin farm", "no coins, waiting for round", 2)
            farmingCoins = false
            break
        end
        
        for _, coin in pairs(coins) do
            if not autoFarmEnabled or coinsCollected >= maxCoins then break end
            
            if coin and coin.Parent then
                local success = tweenToCoin(coin)
                if success then
                    coinsCollected = coinsCollected + 1
                    updateStats(1)
                end
            end
        end
        
        wait(1)
    end
end

local function initRoles()
    local roundStart = svc.rep:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("RoundStart")
    
    roundStart.OnClientEvent:Connect(function(time, roles)
        predictedRoles = {}
        playerRoles = {}
        originalSheriff = nil
        gunDropFound = false
        
        for username, data in pairs(roles) do
            predictedRoles[username] = data.Role
            if data.Role == "Sheriff" then
                originalSheriff = username
            end
        end
        
        window:notify("roles", "predicted", 2)
        
        if espEnabled then
            updateESP()
        end
        
        if autoFarmEnabled and not farmingCoins then
            wait(2)
            spawn(function()
                startCoinFarm()
            end)
        end
    end)
    
    local roundEnd = svc.rep:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("RoundEndFade")
    
    roundEnd.OnClientEvent:Connect(function()
        playerRoles = {}
        predictedRoles = {}
        originalSheriff = nil
        gunDropFound = false
        lookingForGun = false
        gunWasPickedUp = false
    end)
end

local function monitorDeath()
    pcall(function()
        svc.rep:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("Died").OnClientEvent:Connect(function(player)
            if playerRoles[player.Name] == "Sheriff" or player.Name == originalSheriff then
                lookingForGun = true
                window:notify("sheriff died", "looking for gun", 2)
                
                spawn(function()
                    while lookingForGun and autoGunDrop do
                        local gunDrop = searchForGunDrop()
                        if gunDrop and not gunDropFound then
                            gunDropFound = true
                            lookingForGun = false
                            window:notify("gun found", "teleporting", 2)
                            wait(0.5)
                            
                            local char = svc.plr.LocalPlayer.Character
                            if char then
                                local root = char:FindFirstChild("HumanoidRootPart")
                                if root then
                                    local lastPosition = root.CFrame
                                    root.CFrame = gunDrop.CFrame
                                    wait(0.3)
                                    root.CFrame = lastPosition
                                    window:notify("gun drop", "collected", 2)
                                end
                            end
                        end
                        wait(0.5)
                    end
                end)
            end
        end)
    end)
end

local function teleportToGunDrop()
    local char = svc.plr.LocalPlayer.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local lastPosition = root.CFrame
    
    local gunDrop = searchForGunDrop()
    if gunDrop then
        root.CFrame = gunDrop.CFrame
        wait(0.3)
        root.CFrame = lastPosition
        window:notify("gun drop", "collected", 2)
        return true
    else
        window:notify("gun drop", "not found", 2)
        return false
    end
end

local function clearESP()
    for _, obj in pairs(espObjects) do
        if obj then
            obj:Destroy()
        end
    end
    espObjects = {}
end

local function clearGunESP()
    if gunEspObject then
        gunEspObject:Destroy()
        gunEspObject = nil
    end
end

local function updateGunESP()
    if not gunEspEnabled or gunWasPickedUp then return end
    
    clearGunESP()
    
    local gunDrop = searchForGunDrop()
    if gunDrop then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = gunDrop
        highlight.FillColor = Color3.fromRGB(0, 150, 255)
        highlight.OutlineColor = Color3.fromRGB(0, 150, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = gunDrop
        
        gunEspObject = highlight
        
        gunDrop.AncestryChanged:Connect(function()
            if not gunDrop.Parent then
                gunWasPickedUp = true
                clearGunESP()
            end
        end)
    end
end

local function createESP(player, color)
    local char = player.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    if espObjects[player] then
        espObjects[player]:Destroy()
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Adornee = char
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = char
    
    espObjects[player] = highlight
end

local function getPlayerRole(player)
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character
    
    if backpack and backpack:FindFirstChild("Knife") then
        return "murderer"
    end
    
    if char then
        local knife = char:FindFirstChild("Knife")
        if knife then
            return "murderer"
        end
    end
    
    if backpack and backpack:FindFirstChild("Gun") then
        if player.Name == originalSheriff then
            return "sheriff"
        else
            return "hero"
        end
    end
    
    if char then
        local gun = char:FindFirstChild("Gun")
        if gun then
            if player.Name == originalSheriff then
                return "sheriff"
            else
                return "hero"
            end
        end
    end
    
    if espEnabled then
        local role = predictedRoles[player.Name] or playerRoles[player.Name]
        if role then
            return role:lower()
        end
    end
    
    return "innocent"
end

function updateESP()
    if not espEnabled then return end
    
    for _, player in pairs(svc.plr:GetPlayers()) do
        if player ~= svc.plr.LocalPlayer and player.Character then
            local role = getPlayerRole(player)
            local color
            
            if role == "murderer" then
                color = Color3.fromRGB(255, 0, 0)
            elseif role == "sheriff" then
                color = Color3.fromRGB(0, 100, 255)
            elseif role == "hero" then
                color = Color3.fromRGB(255, 255, 0)
            else
                color = Color3.fromRGB(0, 255, 0)
            end
            
            createESP(player, color)
        end
    end
end

local function getMurderer()
    for _, player in pairs(svc.plr:GetPlayers()) do
        if player ~= svc.plr.LocalPlayer then
            local role = getPlayerRole(player)
            if role == "murderer" and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if root and humanoid and humanoid.Health > 0 then
                    return player, root
                end
            end
        end
    end
    return nil, nil
end

local function startFly()
    local char = svc.plr.LocalPlayer.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end
    
    for _, track in pairs(hum:GetPlayingAnimationTracks()) do
        track:Stop()
    end
    
    bodyVel = Instance.new("BodyVelocity")
    bodyVel.Velocity = Vector3.new(0, 0, 0)
    bodyVel.MaxForce = Vector3.new(9e4, 9e4, 9e4)
    bodyVel.Parent = root
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
    bodyGyro.P = 9e4
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root
    
    local cam = workspace.CurrentCamera
    
    flyConnection = svc.run.RenderStepped:Connect(function()
        if not flying then return end
        if not char or not root then return end
        
        for _, track in pairs(hum:GetPlayingAnimationTracks()) do
            track:Stop()
        end
        
        local moveDir = Vector3.new(0, 0, 0)
        
        if isMobile then
            local moveVector = hum.MoveVector
            if moveVector.Magnitude > 0 then
                moveDir = moveDir + (cam.CFrame.LookVector * moveVector.Z * flySpeed)
                moveDir = moveDir + (cam.CFrame.RightVector * moveVector.X * flySpeed)
            end
            
            if hum.Jump then
                moveDir = moveDir + Vector3.new(0, flySpeed, 0)
            end
        else
            if svc.uis:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + (cam.CFrame.LookVector * flySpeed)
            end
            if svc.uis:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - (cam.CFrame.LookVector * flySpeed)
            end
            if svc.uis:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - (cam.CFrame.RightVector * flySpeed)
            end
            if svc.uis:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + (cam.CFrame.RightVector * flySpeed)
            end
            if svc.uis:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, flySpeed, 0)
            end
            if svc.uis:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDir = moveDir - Vector3.new(0, flySpeed, 0)
            end
        end
        
        bodyVel.Velocity = moveDir
        bodyGyro.CFrame = cam.CFrame
    end)
end

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if bodyVel then bodyVel:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    
    local char = svc.plr.LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
            wait()
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end
end

local function applySpeed()
    local char = svc.plr.LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum and speedEnabled then
            hum.WalkSpeed = speedValue
        end
    end
end

local function killAll()
    local char = svc.plr.LocalPlayer.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local knife = char:FindFirstChild("Knife")
    
    if not root or not knife then
        window:notify("kill all", "need knife equipped", 2)
        return
    end
    
    killingAll = true
    local killed = 0
    local alivePlayers = {}
    
    for _, player in pairs(svc.plr:GetPlayers()) do
        if player ~= svc.plr.LocalPlayer and player.Character then
            local targetHum = player.Character:FindFirstChild("Humanoid")
            if targetHum and targetHum.Health > 0 then
                table.insert(alivePlayers, player)
            end
        end
    end
    
    while killingAll and #alivePlayers > 0 do
        for i = #alivePlayers, 1, -1 do
            local player = alivePlayers[i]
            
            if not player or not player.Character then
                table.remove(alivePlayers, i)
            else
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local targetHum = player.Character:FindFirstChild("Humanoid")
                
                if not targetRoot or not targetHum or targetHum.Health <= 0 then
                    table.remove(alivePlayers, i)
                    killed = killed + 1
                else
                    targetRoot.CFrame = root.CFrame
                end
            end
        end
        
        wait(0.1)
    end
    
    killingAll = false
    window:notify("kill all", "finished, killed " .. killed, 2)
end

svc.plr.LocalPlayer.CharacterAdded:Connect(function(char)
    wait(0.5)
    applySpeed()
    
    local hum = char:WaitForChild("Humanoid")
    if speedEnabled then
        hum.WalkSpeed = speedValue
        
        hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if speedEnabled and hum.WalkSpeed ~= speedValue then
                hum.WalkSpeed = speedValue
            end
        end)
    end
end)

main:toggle("fly", false, function(state)
    flying = state
    if state then
        startFly()
        window:notify("fly", "enabled", 2)
    else
        stopFly()
        window:notify("fly", "disabled", 2)
    end
end, "fly")

main:slider("fly speed", 10, 150, 50, function(value)
    flySpeed = value
end, "flyspeed")

main:toggle("speed", false, function(state)
    speedEnabled = state
    if state then
        applySpeed()
        window:notify("speed", "enabled (17)", 2)
    else
        local char = svc.plr.LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum.WalkSpeed = 16
            end
        end
        window:notify("speed", "disabled", 2)
    end
end, "speed")

main:button("get gun drop", function()
    teleportToGunDrop()
end)

main:toggle("auto gun drop", false, function(state)
    autoGunDrop = state
    gunDropFound = false
    
    if state then
        window:notify("auto gun drop", "enabled", 2)
    else
        lookingForGun = false
        window:notify("auto gun drop", "disabled", 2)
    end
end, "autogundrop")

combat:button("kill all", function()
    killAll()
end)

visual:toggle("esp", false, function(state)
    espEnabled = state
    if state then
        spawn(function()
            while espEnabled do
                updateESP()
                wait(0.5)
            end
        end)
        
        window:notify("esp", "enabled", 2)
    else
        clearESP()
        window:notify("esp", "disabled", 2)
    end
end, "esp")

visual:toggle("gun esp", false, function(state)
    gunEspEnabled = state
    if state then
        spawn(function()
            while gunEspEnabled do
                updateGunESP()
                wait(1)
            end
        end)
        
        window:notify("gun esp", "enabled", 2)
    else
        clearGunESP()
        window:notify("gun esp", "disabled", 2)
    end
end, "gunesp")

misc:button("rejoin", function()
    local ts = call("TeleportService")
    ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, svc.plr.LocalPlayer)
end)

misc:toggle("anti fling", false, function(state)
    antiFlingEnabled = state
    
    if state then
        if antiFlingConnection then
            antiFlingConnection:Disconnect()
        end
        
        antiFlingConnection = svc.run.Heartbeat:Connect(function()
            for _, player in pairs(svc.plr:GetPlayers()) do
                if player ~= svc.plr.LocalPlayer and player.Character then
                    for _, v in pairs(player.Character:GetChildren()) do
                        if v:IsA("BasePart") then
                            v.CanCollide = false
                        end
                    end
                end
            end
        end)
        
        window:notify("anti fling", "enabled", 2)
    else
        if antiFlingConnection then
            antiFlingConnection:Disconnect()
            antiFlingConnection = nil
        end
        window:notify("anti fling", "disabled", 2)
    end
end, "antifling")

misc:toggle("anti afk (for autofarm)", false, function(state)
    antiAfkEnabled = state
    
    if state then
        local vu = game:GetService("VirtualUser")
        antiAfkConnection = svc.plr.LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            wait(1)
            vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
        
        window:notify("anti afk", "enabled", 2)
    else
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
        window:notify("anti afk", "disabled", 2)
    end
end, "antiafk")

misc:toggle("auto farm coins", false, function(state)
    autoFarmEnabled = state
    
    if state then
        farmStats.lastSession = 0
        window:notify("coin farm", "enabled (40 per round)", 2)
    else
        farmingCoins = false
        window:notify("coin farm", "disabled", 2)
    end
end, "autofarm")

misc:label("farm stats")

misc:button("view stats", function()
    local statsText = string.format(
        "all time: %d\nthis server: %d\nlast server: %d\nmost collected: %d\nthis session: %d",
        farmStats.allTime,
        farmStats.thisServer,
        farmStats.lastServer,
        farmStats.mostCollected,
        farmStats.lastSession
    )
    window:notify("farm stats", statsText, 5)
end)

misc:button("reset stats", function()
    farmStats = {
        allTime = 0,
        thisServer = 0,
        lastServer = 0,
        mostCollected = 0,
        lastSession = 0
    }
    saveStats()
    window:notify("farm stats", "reset", 2)
end)

svc.plr.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if espEnabled then
            wait(1)
            updateESP()
        end
    end)
end)

for _, player in pairs(svc.plr:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        if espEnabled then
            wait(1)
            updateESP()
        end
    end)
end

initRoles()
monitorDeath()
loadStats()

window:accent(Color3.fromRGB(255, 70, 100))
