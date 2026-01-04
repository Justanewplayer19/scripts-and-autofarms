if game.PlaceId == 122901288403496 then

local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.rep = call("ReplicatedStorage")
svc.ws = call("Workspace")

local KyriLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()

local window = KyriLib.new("You're Hired!", {
    GameName = "Slap battles"
})

local main = window:tab("Main")

local plr = svc.plr.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

main:toggle("Auto Clean", false, function(state)
    _G.AutoClean = state
    
    task.spawn(function()
        while _G.AutoClean and task.wait() do
            pcall(function()
                for i,c in pairs(svc.ws.Trash.Instances:GetChildren()) do
                    if c.Name == "TrashPile" and (hrp.Position - c:FindFirstChild("trash pile").Position).Magnitude <= 5 then
                        repeat task.wait() until not char:FindFirstChild("Broom")
                        hum:EquipTool(plr.Backpack.Broom)
                        repeat task.wait() until char:FindFirstChild("Broom")
                        wait(0.5)
                        repeat task.wait()
                            svc.rep:WaitForChild("Remotes"):WaitForChild("CleanTrash"):FireServer(c)
                        until not c:FindFirstChild("trash pile")
                        char:FindFirstChild("Broom").Parent = plr.Backpack
                    elseif c.Name == "TrashSpill" and (hrp.Position - c:FindFirstChild("Slime").Position).Magnitude <= 5 then
                        repeat task.wait() until not char:FindFirstChild("Mop")
                        hum:EquipTool(plr.Backpack.Mop)
                        repeat task.wait() until char:FindFirstChild("Mop")
                        wait(0.5)
                        repeat task.wait()
                            svc.rep:WaitForChild("Remotes"):WaitForChild("CleanTrash"):FireServer(c)
                        until not c:FindFirstChild("Slime")
                        char:FindFirstChild("Mop").Parent = plr.Backpack
                    end
                end
            end)
        end
    end)
    
    while _G.AutoClean do
        pcall(function()
            for i,v in pairs(svc.ws.Trash.Instances:GetChildren()) do
                if v.Name == "TrashPile" and not ((hrp.Position - v:FindFirstChild("trash pile").Position).Magnitude <= 5) then
                    hrp.CFrame = v["trash pile"].CFrame * CFrame.new(0,2.5,0)
                elseif v.Name == "TrashSpill" and not ((hrp.Position - v:FindFirstChild("Slime").Position).Magnitude <= 5) then
                    hrp.CFrame = v.Slime.CFrame * CFrame.new(0,2.9,0)
                end
            end
        end)
        task.wait()
    end
end, "auto_clean")

main:toggle("Auto Claim Glove + Scan", false, function(state)
    _G.AutoGlove = state
    
    task.spawn(function()
        while _G.AutoGlove and task.wait() do
            pcall(function()
                for _, g in pairs(svc.ws:GetChildren()) do
                    if g:IsA("Model") then
                        local glove = g:FindFirstChildWhichIsA("MeshPart")
                        if glove and glove.Name:lower():find("glove") then
                            if (hrp.Position - glove.Position).Magnitude <= 20 then
                                svc.rep:WaitForChild("Remotes"):WaitForChild("PickupCheckoutItem"):FireServer(g)
                            end
                        end
                    end
                end
            end)
        end
    end)
    
    while _G.AutoGlove do
        pcall(function()
            for _, s in pairs(svc.ws:GetChildren()) do
                if s:IsA("Model") then
                    local gloves = s:FindFirstChildWhichIsA("MeshPart")
                    if gloves and gloves.Name:lower():find("glove") then
                        hrp.CFrame = CFrame.new(52.7386703, 5.75873089, -41.6181679, -0.999995887, -1.38746992e-09, 0.00287240394, -1.30827926e-09, 1, 2.75713496e-08, -0.00287240394, 2.7567479e-08, -0.99999588)
                    elseif s:IsA("Model") and s.Name:lower():find("heldcheckoutitem") then
                        hrp.CFrame = CFrame.new(52.7386703, 5.75873089, -41.6181679, -0.999995887, -1.38746992e-09, 0.00287240394, -1.30827926e-09, 1, 2.75713496e-08, -0.00287240394, 2.7567479e-08, -0.99999588)
                    end
                end
            end
        end)
        task.wait()
    end
end, "auto_glove")

else
    svc.plr.LocalPlayer:Kick("game not supported")
end
