local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.txt = call("TextChatService")
svc.sg = call("StarterGui")

-------------------------------------------------------------------------------------------------------------------------------

if not game:IsLoaded() then game["Loaded"]:Wait() end

-------------------------------------------------------------------------------------------------------------------------------

local plr = svc.plr["LocalPlayer"]
local char = plr["Character"] or plr["CharacterAdded"]:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

local spinning = false
local frozen = false
local oldjp = 50
local oldws = 16
local r6loaded = false

-------------------------------------------------------------------------------------------------------------------------------

function notify(txt, dur)
    pcall(function()
        svc.sg:SetCore("SendNotification", {
            Title = "Command",
            Text = txt,
            Duration = dur or 3
        })
    end)
end

-------------------------------------------------------------------------------------------------------------------------------

function performflip(character, flipdirection)
    local h = character:WaitForChild("Humanoid")
    local rp = character:WaitForChild("HumanoidRootPart")
    
    h:ChangeState(Enum.HumanoidStateType.Jumping)
    h["Sit"] = true
    
    local lv = rp["CFrame"]["LookVector"]
    local sd = Vector3.new(-lv["Z"], 0, lv["X"])
    
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if torso then
        local bv = Instance.new("BodyAngularVelocity", torso)
        bv["MaxTorque"] = Vector3.new(math.huge, math.huge, math.huge)
        bv["AngularVelocity"] = sd * (flipdirection * 10)
        bv["P"] = 1000
        
        wait(0.4)
        bv:Destroy()
    end
    
    wait(0.2)
    h["Sit"] = false
end

function dospin(target)
    local tchar = char
    
    if target then
        local tplr = svc.plr:FindFirstChild(target)
        if not tplr then
            for _, p in pairs(svc.plr:GetPlayers()) do
                if string.lower(p["Name"]):sub(1, #target) == string.lower(target) then
                    tplr = p
                    break
                end
            end
        end
        if tplr and tplr["Character"] then
            tchar = tplr["Character"]
        else
            notify("Player not found")
            return
        end
    end
    
    if spinning then return end
    spinning = true
    
    local torso = tchar:FindFirstChild("UpperTorso") or tchar:FindFirstChild("Torso")
    if torso then
        local bv = Instance.new("BodyAngularVelocity", torso)
        bv["MaxTorque"] = Vector3.new(0, math.huge, 0)
        bv["AngularVelocity"] = Vector3.new(0, 50, 0)
        bv["P"] = 5000
        
        wait(2)
        bv:Destroy()
    end
    
    spinning = false
    notify("Spun " .. (target or "self"))
end

function dokill()
    hum["Health"] = 0
    notify("Killed")
end

function dofreeze()
    frozen = true
    hum["WalkSpeed"] = 0
    hum["JumpHeight"] = 0
    root["Anchored"] = true
    notify("Frozen")
end

function dounfreeze()
    frozen = false
    hum["WalkSpeed"] = oldws
    hum["JumpHeight"] = 7.2
    root["Anchored"] = false
    notify("Unfrozen")
end

function dofling()
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if torso then
        local bv = Instance.new("BodyVelocity", torso)
        bv["MaxForce"] = Vector3.new(math.huge, math.huge, math.huge)
        bv["Velocity"] = Vector3.new(math.random(-100, 100), 200, math.random(-100, 100))
        
        wait(0.3)
        bv:Destroy()
    end
    notify("Flung")
end

function dospeed(amt)
    local spd = tonumber(amt) or 16
    oldws = spd
    if not frozen then
        hum["WalkSpeed"] = spd
    end
    notify("Speed: " .. spd)
end

function dojump(amt)
    local jp = tonumber(amt) or 7.2
    if not frozen then
        hum["JumpHeight"] = jp
    end
    notify("Jump: " .. jp)
end

function dogod()
    hum["MaxHealth"] = math.huge
    hum["Health"] = math.huge
    notify("God mode on")
end

function doungod()
    hum["MaxHealth"] = 100
    hum["Health"] = 100
    notify("God mode off")
end

function doreset()
    char:BreakJoints()
    notify("Reset")
end

function dosit()
    hum["Sit"] = true
    notify("Sat")
end

function dounsit()
    hum["Sit"] = false
    notify("Unsat")
end

function dofly()
    local bg = Instance.new("BodyGyro", root)
    bg["MaxTorque"] = Vector3.new(9e9, 9e9, 9e9)
    bg["P"] = 9e4
    bg["CFrame"] = root["CFrame"]
    
    local bv = Instance.new("BodyVelocity", root)
    bv["MaxForce"] = Vector3.new(9e9, 9e9, 9e9)
    bv["Velocity"] = Vector3.new(0, 0, 0)
    
    local cam = workspace["CurrentCamera"]
    local flyspd = 50
    
    task.spawn(function()
        while bg and bv and bg["Parent"] do
            local dir = Vector3.new(0, 0, 0)
            local uis = game:GetService("UserInputService")
            
            if uis:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam["CFrame"]["LookVector"] end
            if uis:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam["CFrame"]["LookVector"] end
            if uis:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam["CFrame"]["RightVector"] end
            if uis:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam["CFrame"]["RightVector"] end
            if uis:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if uis:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
            
            bv["Velocity"] = dir * flyspd
            bg["CFrame"] = cam["CFrame"]
            
            wait()
        end
    end)
    
    root["ChildRemoved"]:Connect(function(c)
        if c == bg or c == bv then
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
        end
    end)
    
    notify("Flying")
end

function dounfly()
    for _, v in pairs(root:GetChildren()) do
        if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then
            v:Destroy()
        end
    end
    notify("Unfly")
end

function donoclip()
    task.spawn(function()
        while true do
            if not char or not char["Parent"] then break end
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v["CanCollide"] = false
                end
            end
            wait()
        end
    end)
    notify("Noclip on")
end

function doinvis()
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Decal") then
            v["Transparency"] = 1
        end
        if v:IsA("Accessory") then
            v["Handle"]["Transparency"] = 1
        end
    end
    if char:FindFirstChild("Head") then
        char["Head"]["face"]["Transparency"] = 1
    end
    notify("Invisible")
end

function douninvis()
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v["Name"] ~= "HumanoidRootPart" then
            v["Transparency"] = 0
        elseif v:IsA("Decal") then
            v["Transparency"] = 0
        end
        if v:IsA("Accessory") then
            v["Handle"]["Transparency"] = 0
        end
    end
    if char:FindFirstChild("Head") then
        char["Head"]["face"]["Transparency"] = 0
    end
    notify("Visible")
end

function dobtools()
    local ht = game:GetService("HttpService")
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    
    if req then
        local tools = {
            {4480871687, "Move"},
            {4480870033, "Scale"},
            {4480870155, "Rotate"},
            {4480869324, "Clone"},
            {4480868088, "Weld"},
            {4480869294, "Collisions"},
            {4480869988, "Anchor"},
            {4480870206, "Paint"},
            {4480870268, "Surface"},
            {4480870366, "Material"}
        }
        
        for _, t in pairs(tools) do
            local s, r = pcall(function()
                local rq = req({
                    Url = "https://assetdelivery.roblox.com/v1/asset/?id=" .. t[1],
                    Method = "GET"
                })
                if rq.StatusCode == 200 then
                    local obj = game:GetObjects("rbxassetid://" .. t[1])[1]
                    obj["Parent"] = plr["Backpack"]
                end
            end)
        end
        notify("BTools loaded")
    else
        notify("BTools not supported")
    end
end

function doteleport(x, y, z)
    local nx = tonumber(x) or 0
    local ny = tonumber(y) or 0
    local nz = tonumber(z) or 0
    root["CFrame"] = CFrame.new(nx, ny, nz)
    notify("Teleported")
end

function doexplode()
    local ex = Instance.new("Explosion", workspace)
    ex["Position"] = root["Position"]
    ex["BlastRadius"] = 30
    ex["BlastPressure"] = 500000
    notify("Exploded")
end

function dogravity(amt)
    local grav = tonumber(amt) or 196.2
    workspace["Gravity"] = grav
    notify("Gravity: " .. grav)
end

function dowalkto(x, y, z)
    local nx = tonumber(x) or 0
    local ny = tonumber(y) or 0
    local nz = tonumber(z) or 0
    hum:MoveTo(Vector3.new(nx, ny, nz))
    notify("Walking to position")
end

function dowave()
    if char:FindFirstChild("Animate") then
        local emote = char.Animate:FindFirstChild("PlayEmote")
        if emote then
            emote:Invoke("wave")
        else
            local anim = Instance.new("Animation")
            anim["AnimationId"] = "http://www.roblox.com/asset/?id=507770239"
            local track = hum:LoadAnimation(anim)
            track:Play()
        end
    end
    notify("Waved")
end

function dor6()
    if not r6loaded then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Imagnir/r6_anims_for_r15/main/r6_anims.lua", true))()
        r6loaded = true
        notify("R6 loaded - permanent until rejoin", 5)
    else
        notify("R6 already loaded - rejoin to disable", 5)
    end
end

function docommands()
    print("=== COMMANDS ===")
    print("/spin [player] - Spin yourself or target")
    print("/kill - Kill yourself")
    print("/freeze - Freeze in place")
    print("/unfreeze - Unfreeze")
    print("/backflip - Do a backflip")
    print("/frontflip - Do a frontflip")
    print("/fling - Fling yourself")
    print("/speed [num] - Set walk speed")
    print("/jump [num] - Set jump height")
    print("/god - God mode on")
    print("/ungod - God mode off")
    print("/reset - Reset character")
    print("/sit - Sit down")
    print("/unsit - Stand up")
    print("/fly - Enable fly")
    print("/unfly - Disable fly")
    print("/noclip - Walk through walls")
    print("/invis - Turn invisible")
    print("/uninvis - Turn visible")
    print("/btools - Load building tools")
    print("/tp [x y z] - Teleport")
    print("/explode - Create explosion")
    print("/gravity [num] - Change gravity")
    print("/walkto [x y z] - Walk to position")
    print("/wave - Wave animation")
    print("/r6 - Load R6 animations")
    notify("Commands printed to console (F9)")
end

-------------------------------------------------------------------------------------------------------------------------------

function onchat(msg)
    local lower = string.lower(msg)
    
    if not string.find(lower, "empty") then
        return
    end
    
    local args = string.split(lower, " ")
    local cmd = args[1]
    
    if cmd == "/spin" then
        dospin(args[2])
    elseif cmd == "/kill" then
        dokill()
    elseif cmd == "/freeze" then
        dofreeze()
    elseif cmd == "/unfreeze" then
        dounfreeze()
    elseif cmd == "/backflip" then
        performflip(char, 1)
        notify("Backflipped")
    elseif cmd == "/frontflip" then
        performflip(char, -1)
        notify("Frontflipped")
    elseif cmd == "/fling" then
        dofling()
    elseif cmd == "/speed" then
        dospeed(args[2])
    elseif cmd == "/jump" then
        dojump(args[2])
    elseif cmd == "/god" then
        dogod()
    elseif cmd == "/ungod" then
        doungod()
    elseif cmd == "/reset" then
        doreset()
    elseif cmd == "/sit" then
        dosit()
    elseif cmd == "/unsit" then
        dounsit()
    elseif cmd == "/fly" then
        dofly()
    elseif cmd == "/unfly" then
        dounfly()
    elseif cmd == "/noclip" then
        donoclip()
    elseif cmd == "/invis" then
        doinvis()
    elseif cmd == "/uninvis" then
        douninvis()
    elseif cmd == "/btools" then
        dobtools()
    elseif cmd == "/tp" then
        doteleport(args[2], args[3], args[4])
    elseif cmd == "/explode" then
        doexplode()
    elseif cmd == "/gravity" then
        dogravity(args[2])
    elseif cmd == "/walkto" then
        dowalkto(args[2], args[3], args[4])
    elseif cmd == "/wave" then
        dowave()
    elseif cmd == "/r6" then
        dor6()
    elseif cmd == "/commands" or cmd == "/cmds" then
        docommands()
    end
end

-------------------------------------------------------------------------------------------------------------------------------

if svc.txt["ChatVersion"] == Enum.ChatVersion.TextChatService then
    svc.txt["MessageReceived"]:Connect(function(msg)
        if msg["TextSource"] then
            onchat(msg["Text"])
        end
    end)
else
    svc.plr["PlayerChatted"]:Connect(function(typ, p, m)
        onchat(m)
    end)
end

plr["CharacterAdded"]:Connect(function(c)
    char = c
    hum = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
    frozen = false
    spinning = false
    
    wait(1)
    oldws = hum["WalkSpeed"]
    notify("Commands loaded - Use /commands")
end)

-------------------------------------------------------------------------------------------------------------------------------
