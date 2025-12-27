-- made by kyri / witheredheartz! yes i own kyri lib lol check out my repos!
local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.run = call("RunService")
svc.inp = call("UserInputService")

local player = svc.plr.LocalPlayer
local KyriLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()

local window = KyriLib.new("fake lag", {
    GameName = "FakeLag"
})

local main = window:tab("main")
local settings = window:tab("settings", "settings")

local character
local hrp
local lagActive = false
local lagLoop
local falling = false
local waitTime = 0.05
local delayTime = 0.4

local function stopLag()
    if lagLoop then
        lagLoop:Disconnect()
        lagLoop = nil
    end
    if hrp then
        hrp.Anchored = false
    end
end

local function startLag()
    stopLag()
    
    lagLoop = coroutine.wrap(function()
        while lagActive do
            wait(waitTime)
            if lagActive and character and character.Parent and hrp and hrp.Parent then
                hrp.Anchored = true
                wait(delayTime)
                if hrp and hrp.Parent then
                    hrp.Anchored = false
                end
            end
        end
    end)()
end

local function updateChar(char)
    character = char
    if character then
        hrp = character:WaitForChild("HumanoidRootPart")
        if lagActive then
            startLag()
        end
    end
end

if player.Character then
    updateChar(player.Character)
end

player.CharacterAdded:Connect(updateChar)

main:label("lag control")

main:toggle("enable fake lag", false, function(state)
    lagActive = state
    if state then
        startLag()
        window:notify("fake lag", "enabled", 2)
    else
        stopLag()
        window:notify("fake lag", "disabled", 2)
    end
end, "lag_enabled")

main:keybind("toggle key", "F", false, function()
    local current = window.flags.lag_enabled or false
    window.flags.lag_enabled_set(not current, true)
end, "lag_key")

main:button("falling mode", function()
    if character and character:FindFirstChild("Humanoid") then
        local hum = character.Humanoid
        falling = not falling
        hum.PlatformStand = falling
        if falling then
            hum:Move(Vector3.new(0, -50, 0))
            window:notify("falling", "enabled", 2)
        else
            window:notify("falling", "disabled", 2)
        end
    end
end)

settings:label("timing settings")

settings:input("wait time", "0.05", function(value)
    local num = tonumber(value)
    if num and num > 0 then
        waitTime = num
        window:notify("wait time", num .. "s", 2)
    else
        window:notify("invalid", "must be number > 0", 2)
    end
end, "wait")

settings:input("delay time", "0.4", function(value)
    local num = tonumber(value)
    if num and num > 0 then
        delayTime = num
        window:notify("delay time", num .. "s", 2)
    else
        window:notify("invalid", "must be number > 0", 2)
    end
end, "delay")

window:accent(Color3.fromRGB(138, 116, 249))
window:notify("fake lag", "loaded", 3)
