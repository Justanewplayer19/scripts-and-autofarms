local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.ctx = call("ContextActionService")
svc.http = call("HttpService")
svc.gui = call("GuiService")
svc.core = call("CoreGui")
svc.aes = call("AvatarEditorService")
svc.plr = call("Players")
svc.sg = call("StarterGui")
svc.uis = call("UserInputService")
svc.tele = call("TeleportService")
svc.run = call("RunService")

if _G.EmoteMenuExecutions then
    _G.EmoteMenuExecutions = _G.EmoteMenuExecutions + 1
    if _G.EmoteMenuExecutions >= 3 then
        svc.sg:SetCore("SendNotification", {
            Title = "Rejoining...",
            Text = "Force rejoining to fix issues"
        })
        task.wait(1)
        svc.tele:Teleport(game.PlaceId, svc.plr.LocalPlayer)
        return
    else
        svc.sg:SetCore("SendNotification", {
            Title = "Already Running",
            Text = "Script is already loaded. Execute one more time to force rejoin if broken."
        })
        return
    end
else
    _G.EmoteMenuExecutions = 1
end

local IsStudio = false
local Emotes = {}

local function AddEmote(name, id, price, creator)
    if not (name and id) then
        return
    end
    table.insert(Emotes, {
        ["name"] = name,
        ["id"] = id,
        ["icon"] = "rbxthumb://type=Asset&id=".. id .."&w=150&h=150",
        ["price"] = price or 0,
        ["creator"] = creator or "Roblox",
        ["index"] = #Emotes + 1,
        ["sort"] = {}
    })
end

local CurrentSort = "newestfirst"
local ShowUGC = true
local IsLoading = false
local EmoteSpeed = 1
local SpeedPresets = {
    {key = "Q", speed = -1},
    {key = "E", speed = 1},
    {key = "R", speed = 2},
    {key = "T", speed = 5}
}
local CurrentEmoteTrack = nil
local isEmotePlaying = false
local FavoriteOff = "rbxassetid://10651060677"
local FavoriteOn = "rbxassetid://10651061109"
local FavoritedEmotes = {}

local sfx = {
    click = "rbxassetid://7249904928",
    hover = "rbxassetid://7249903719",
    toggle_on = "rbxassetid://7249904928",
    toggle_off = "rbxassetid://7249903719"
}

local function playSound(id)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = 0.5
    s.Parent = svc.core
    s:Play()
    task.delay(1, function()
        s:Destroy()
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Emotes"
ScreenGui.DisplayOrder = 2
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Enabled = false

local BackFrame = Instance.new("Frame")
BackFrame.Size = UDim2.new(0.9, 0, 0.5, 0)
BackFrame.AnchorPoint = Vector2.new(0.5, 0.5)
BackFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
BackFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
BackFrame.BackgroundTransparency = 1
BackFrame.BorderSizePixel = 0
BackFrame.Active = true
BackFrame.Parent = ScreenGui

local EmoteName = Instance.new("TextLabel")
EmoteName.Name = "EmoteName"
EmoteName.TextScaled = true
EmoteName.AnchorPoint = Vector2.new(0.5, 0.5)
EmoteName.Position = UDim2.new(-0.1, 0, 0.5, 0)
EmoteName.Size = UDim2.new(0.2, 0, 0.2, 0)
EmoteName.SizeConstraint = Enum.SizeConstraint.RelativeYY
EmoteName.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
EmoteName.TextColor3 = Color3.new(1, 1, 1)
EmoteName.BorderSizePixel = 0
EmoteName.Parent = BackFrame

local Corner = Instance.new("UICorner")
Corner.Parent = EmoteName

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0.2, 0, 0.08, 0)
SpeedLabel.SizeConstraint = Enum.SizeConstraint.RelativeYY
SpeedLabel.AnchorPoint = Vector2.new(0.5, 0.5)
SpeedLabel.Position = UDim2.new(-0.1, 0, 0.15, 0)
SpeedLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SpeedLabel.TextScaled = true
SpeedLabel.Text = "Speed: " .. EmoteSpeed
SpeedLabel.TextColor3 = Color3.new(1, 1, 1)
SpeedLabel.BorderSizePixel = 0
Corner:Clone().Parent = SpeedLabel
SpeedLabel.Parent = BackFrame

local SliderBG = Instance.new("Frame")
SliderBG.Size = UDim2.new(0.18, 0, 0.04, 0)
SliderBG.SizeConstraint = Enum.SizeConstraint.RelativeYY
SliderBG.AnchorPoint = Vector2.new(0.5, 0.5)
SliderBG.Position = UDim2.new(-0.1, 0, 0.27, 0)
SliderBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SliderBG.BorderSizePixel = 0
Corner:Clone().Parent = SliderBG
SliderBG.Parent = BackFrame

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.1, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
SliderFill.BorderSizePixel = 0
Corner:Clone().Parent = SliderFill
SliderFill.Parent = SliderBG

local SliderButton = Instance.new("TextButton")
SliderButton.Size = UDim2.new(0.08, 0, 1.5, 0)
SliderButton.Position = UDim2.new(0.1, 0, -0.25, 0)
SliderButton.AnchorPoint = Vector2.new(0.5, 0)
SliderButton.BackgroundColor3 = Color3.new(1, 1, 1)
SliderButton.Text = ""
SliderButton.BorderSizePixel = 0
Corner:Clone().Parent = SliderButton
SliderButton.Parent = SliderBG

local dragging = false
SliderButton.MouseButton1Down:Connect(function()
    dragging = true
end)

svc.uis.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

svc.run.RenderStepped:Connect(function()
    if dragging then
        local mouse = svc.plr.LocalPlayer:GetMouse()
        local relativeX = mouse.X - SliderBG.AbsolutePosition.X
        local percentage = math.clamp(relativeX / SliderBG.AbsoluteSize.X, 0, 1)
        local rawSpeed = (percentage * 20) - 10
        EmoteSpeed = math.floor(rawSpeed * 100) / 100
        SpeedLabel.Text = "Speed: " .. EmoteSpeed
        SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        SliderButton.Position = UDim2.new(percentage, 0, -0.25, 0)
    end
end)

local Loading = Instance.new("TextLabel")
Loading.Name = "InitialLoading"
Loading.AnchorPoint = Vector2.new(0.5, 0.5)
Loading.Text = "Loading..."
Loading.TextColor3 = Color3.new(1, 1, 1)
Loading.BackgroundColor3 = Color3.new(0, 0, 0)
Loading.TextScaled = true
Loading.BackgroundTransparency = 0.5
Loading.Size = UDim2.fromScale(0.2, 0.1)
Loading.Position = UDim2.fromScale(0.5, 0.2)
Loading.Parent = BackFrame
Corner:Clone().Parent = Loading

local Frame = Instance.new("ScrollingFrame")
Frame.Size = UDim2.new(1, 0, 1, 0)
Frame.CanvasSize = UDim2.new(0, 0, 0, 0)
Frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
Frame.ScrollingDirection = Enum.ScrollingDirection.Y
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
Frame.BackgroundTransparency = 1
Frame.ScrollBarThickness = 5
Frame.BorderSizePixel = 0
Frame.MouseLeave:Connect(function()
    EmoteName.Text = "Select an Emote"
end)
Frame.Parent = BackFrame

local Grid = Instance.new("UIGridLayout")
Grid.CellSize = UDim2.new(0.105, 0, 0, 0)
Grid.CellPadding = UDim2.new(0.006, 0, 0.006, 0)
Grid.SortOrder = Enum.SortOrder.LayoutOrder
Grid.Parent = Frame

local KeybindsFrame = Instance.new("Frame")
KeybindsFrame.Size = UDim2.new(0.9, 0, 0.12, 0)
KeybindsFrame.AnchorPoint = Vector2.new(0.5, 0)
KeybindsFrame.Position = UDim2.new(0.5, 0, 1.05, 0)
KeybindsFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
KeybindsFrame.BackgroundTransparency = 1
KeybindsFrame.BorderSizePixel = 0
KeybindsFrame.Parent = BackFrame

local KeybindsLayout = Instance.new("UIGridLayout")
KeybindsLayout.CellSize = UDim2.new(0.24, 0, 0.48, 0)
KeybindsLayout.CellPadding = UDim2.new(0.01, 0, 0.04, 0)
KeybindsLayout.SortOrder = Enum.SortOrder.LayoutOrder
KeybindsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
KeybindsLayout.Parent = KeybindsFrame

local function createKeybind(idx)
    local frame = Instance.new("Frame")
    frame.LayoutOrder = idx
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    Corner:Clone().Parent = frame
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(0.35, 0, 1, 0)
    keyBox.Position = UDim2.new(0, 0, 0, 0)
    keyBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    keyBox.TextColor3 = Color3.new(1, 1, 1)
    keyBox.TextScaled = true
    keyBox.Text = SpeedPresets[idx].key
    keyBox.ClearTextOnFocus = false
    keyBox.BorderSizePixel = 0
    Corner:Clone().Parent = keyBox
    keyBox.Parent = frame
    
    keyBox.FocusLost:Connect(function()
        SpeedPresets[idx].key = keyBox.Text
    end)
    
    local speedBox = Instance.new("TextBox")
    speedBox.Size = UDim2.new(0.63, 0, 1, 0)
    speedBox.Position = UDim2.new(0.37, 0, 0, 0)
    speedBox.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
    speedBox.TextColor3 = Color3.new(1, 1, 1)
    speedBox.TextScaled = true
    speedBox.Text = tostring(SpeedPresets[idx].speed)
    speedBox.ClearTextOnFocus = false
    speedBox.BorderSizePixel = 0
    Corner:Clone().Parent = speedBox
    speedBox.Parent = frame
    
    speedBox.FocusLost:Connect(function()
        local val = tonumber(speedBox.Text)
        if val then
            SpeedPresets[idx].speed = math.clamp(val, 0, 10)
            speedBox.Text = tostring(SpeedPresets[idx].speed)
        else
            speedBox.Text = tostring(SpeedPresets[idx].speed)
        end
    end)
    
    frame.Parent = KeybindsFrame
end

for i=1,4 do
    createKeybind(i)
end

svc.uis.InputBegan:Connect(function(input, gpe)
    if gpe or not ScreenGui.Enabled then return end
    for i,preset in pairs(SpeedPresets) do
        if input.KeyCode == Enum.KeyCode[preset.key:upper()] then
            EmoteSpeed = preset.speed
            local sliderPos = math.clamp((EmoteSpeed + 10) / 20, 0, 1)
            SpeedLabel.Text = "Speed: " .. EmoteSpeed
            SliderFill.Size = UDim2.new(sliderPos, 0, 1, 0)
            SliderButton.Position = UDim2.new(sliderPos, 0, -0.25, 0)
            break
        end
    end
end)

local SortFrame = Instance.new("Frame")
SortFrame.Visible = false
SortFrame.BorderSizePixel = 0
SortFrame.Position = UDim2.new(1, 5, -0.125, 0)
SortFrame.Size = UDim2.new(0.2, 0, 0, 0)
SortFrame.AutomaticSize = Enum.AutomaticSize.Y
SortFrame.BackgroundTransparency = 1
Corner:Clone().Parent = SortFrame
SortFrame.Parent = BackFrame

local SortList = Instance.new("UIListLayout")
SortList.Padding = UDim.new(0.02, 0)
SortList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SortList.VerticalAlignment = Enum.VerticalAlignment.Top
SortList.SortOrder = Enum.SortOrder.LayoutOrder
SortList.Parent = SortFrame

local function SortEmotes()
    for i,Emote in pairs(Emotes) do
        local EmoteButton = Frame:FindFirstChild(tostring(Emote.id))
        if not EmoteButton then
            continue
        end
        local IsFavorited = table.find(FavoritedEmotes, Emote.id)
        EmoteButton.LayoutOrder = Emote.sort[CurrentSort] + ((IsFavorited and 0) or #Emotes)
        local numLabel = EmoteButton:FindFirstChild("number")
        if numLabel then
            numLabel.Text = Emote.sort[CurrentSort]
        end
    end
end

local function createsort(order, text, sort)
    local CreatedSort = Instance.new("TextButton")
    CreatedSort.SizeConstraint = Enum.SizeConstraint.RelativeXX
    CreatedSort.Size = UDim2.new(1, 0, 0.2, 0)
    CreatedSort.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    CreatedSort.LayoutOrder = order
    CreatedSort.TextColor3 = Color3.new(1, 1, 1)
    CreatedSort.Text = text
    CreatedSort.TextScaled = true
    CreatedSort.BorderSizePixel = 0
    Corner:Clone().Parent = CreatedSort
    CreatedSort.Parent = SortFrame
    CreatedSort.MouseButton1Click:Connect(function()
        playSound(sfx.click)
        SortFrame.Visible = false
        CurrentSort = sort
        SortEmotes()
    end)
    CreatedSort.MouseEnter:Connect(function()
        playSound(sfx.hover)
    end)
    return CreatedSort
end

createsort(1, "Newest First", "newestfirst")
createsort(2, "Oldest First", "oldestfirst")
createsort(3, "Alphabetically First", "alphabeticfirst")
createsort(4, "Alphabetically Last", "alphabeticlast")
createsort(5, "Highest Price", "highestprice")
createsort(6, "Lowest Price", "lowestprice")

local SortButton = Instance.new("TextButton")
SortButton.BorderSizePixel = 0
SortButton.AnchorPoint = Vector2.new(0.5, 0.5)
SortButton.Position = UDim2.new(0.925, -5, -0.075, 0)
SortButton.Size = UDim2.new(0.15, 0, 0.1, 0)
SortButton.TextScaled = true
SortButton.TextColor3 = Color3.new(1, 1, 1)
SortButton.BackgroundColor3 = Color3.new(0, 0, 0)
SortButton.BackgroundTransparency = 0.3
SortButton.Text = "Sort"
SortButton.MouseButton1Click:Connect(function()
    playSound(sfx.click)
    SortFrame.Visible = not SortFrame.Visible
end)
SortButton.MouseEnter:Connect(function()
    playSound(sfx.hover)
end)
Corner:Clone().Parent = SortButton
SortButton.Parent = BackFrame

local UGCButton = Instance.new("TextButton")
UGCButton.BorderSizePixel = 0
UGCButton.AnchorPoint = Vector2.new(0.5, 0.5)
UGCButton.Position = UDim2.new(-0.1, 0, 0.75, 0)
UGCButton.Size = UDim2.new(0.2, 0, 0.15, 0)
UGCButton.SizeConstraint = Enum.SizeConstraint.RelativeYY
UGCButton.TextScaled = true
UGCButton.TextColor3 = Color3.new(1, 1, 1)
UGCButton.BackgroundColor3 = Color3.new(0, 0.5, 0)
UGCButton.BackgroundTransparency = 0
UGCButton.Text = "UGC: ON"
Corner:Clone().Parent = UGCButton
UGCButton.Parent = BackFrame

local CloseButton = Instance.new("TextButton")
CloseButton.BorderSizePixel = 0
CloseButton.AnchorPoint = Vector2.new(0.5, 0.5)
CloseButton.Position = UDim2.new(0.075, 0, -0.075, 0)
CloseButton.Size = UDim2.new(0.15, 0, 0.1, 0)
CloseButton.TextScaled = true
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.BackgroundColor3 = Color3.new(0, 0, 0)
CloseButton.BackgroundTransparency = 0.3
CloseButton.Text = "Close"
CloseButton.MouseButton1Click:Connect(function()
    playSound(sfx.click)
    ScreenGui.Enabled = false
end)
CloseButton.MouseEnter:Connect(function()
    playSound(sfx.hover)
end)
Corner:Clone().Parent = CloseButton
CloseButton.Parent = BackFrame

local SearchBar = Instance.new("TextBox")
SearchBar.BorderSizePixel = 0
SearchBar.AnchorPoint = Vector2.new(0.5, 0.5)
SearchBar.Position = UDim2.new(0.5, 0, -0.075, 0)
SearchBar.Size = UDim2.new(0.55, 0, 0.1, 0)
SearchBar.TextScaled = true
SearchBar.PlaceholderText = "Search"
SearchBar.TextColor3 = Color3.new(1, 1, 1)
SearchBar.BackgroundColor3 = Color3.new(0, 0, 0)
SearchBar.BackgroundTransparency = 0.3
SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local text = SearchBar.Text:lower()
    local buttons = Frame:GetChildren()
    if text ~= text:sub(1,50) then
        SearchBar.Text = SearchBar.Text:sub(1,50)
        text = SearchBar.Text:lower()
    end
    if text ~= ""  then
        for i,button in pairs(buttons) do
            if button:IsA("GuiButton") then
                local name = button:GetAttribute("name")
                if name then
                    if name:lower():match(text) then
                        button.Visible = true
                    else
                        button.Visible = false
                    end
                end
            end
        end
    else
        for i,button in pairs(buttons) do
            if button:IsA("GuiButton") then
                button.Visible = true
            end
        end
    end
end)
Corner:Clone().Parent = SearchBar
SearchBar.Parent = BackFrame

local function openemotes(name, state, input)
    if state == Enum.UserInputState.Begin then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end

if IsStudio then
    svc.ctx:BindActionAtPriority("Emote Menu", openemotes, true, 2001, Enum.KeyCode.Comma)
else
    svc.ctx:BindCoreActionAtPriority("Emote Menu", openemotes, true, 2001, Enum.KeyCode.Comma)
end

ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if ScreenGui.Enabled == true then
        EmoteName.Text = "Select an Emote"
        SearchBar.Text = ""
        SortFrame.Visible = false
        svc.gui:SetEmotesMenuOpen(false)
    end
end)

if not IsStudio then
    svc.gui.EmotesMenuOpenChanged:Connect(function(isopen)
        if isopen then
            ScreenGui.Enabled = false
        end
    end)
end

svc.gui.MenuOpened:Connect(function()
    ScreenGui.Enabled = false
end)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = svc.plr.LocalPlayer

if IsStudio then
    ScreenGui.Parent = LocalPlayer.PlayerGui
else
    local SynV3 = syn and DrawingImmediate
    if (not is_sirhurt_closure) and (not SynV3) and (syn and syn.protect_gui) then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = svc.core
    elseif get_hidden_gui or gethui then
        local hiddenUI = get_hidden_gui or gethui
        ScreenGui.Parent = hiddenUI()
    else
        ScreenGui.Parent = svc.core
    end
end

local function SendNotification(title, text)
    if (not IsStudio) and syn and syn.toast_notification then
        syn.toast_notification({
            Type = ToastType.Error,
            Title = title,
            Content = text
        })
    else
        svc.sg:SetCore("SendNotification", {
            Title = title,
            Text = text
        })
    end
end

local function stopCurrentEmote()
    if CurrentEmoteTrack then
        pcall(function()
            CurrentEmoteTrack:AdjustSpeed(1)
        end)
        CurrentEmoteTrack:Stop()
        CurrentEmoteTrack = nil
    end
    isEmotePlaying = false
    
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("AnimationController")
        if h then
            for _, t in pairs(h:GetPlayingAnimationTracks()) do
                pcall(function()
                    t:AdjustSpeed(1)
                end)
            end
        end
    end
end

local function playEmote(humanoid, name, emoteId)
    local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
    if not description then
        description = Instance.new("HumanoidDescription")
        description.Parent = humanoid
    end
    
    pcall(function()
        description:AddEmote(name, emoteId)
    end)
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        local captured = false
        local conn
        conn = animator.AnimationPlayed:Connect(function(t)
            if captured then return end
            
            if t.Priority == Enum.AnimationPriority.Core or t.Priority == Enum.AnimationPriority.Action then
                local aid = t.Animation.AnimationId
                local isWalk = aid:find("180426354") or aid:find("180435571") or 
                               aid:find("180435792") or aid:find("656117878") or 
                               aid:find("656118852") or aid:find("913376220")
                
                if not isWalk then
                    CurrentEmoteTrack = t
                    isEmotePlaying = true
                    captured = true
                    
                    task.wait(0.1)
                    pcall(function()
                        t:AdjustSpeed(EmoteSpeed)
                    end)
                    
                    t.Stopped:Connect(function()
                        isEmotePlaying = false
                        CurrentEmoteTrack = nil
                    end)
                    
                    conn:Disconnect()
                end
            end
        end)
        
        task.delay(2, function()
            if conn then
                conn:Disconnect()
            end
        end)
    end
    
    pcall(function()
        humanoid:PlayEmote(name)
    end)
end

svc.run.Heartbeat:Connect(function()
    if not isEmotePlaying or not CurrentEmoteTrack then return end
    
    if CurrentEmoteTrack.IsPlaying then
        if math.abs(CurrentEmoteTrack.Speed - EmoteSpeed) > 0.01 then
            pcall(function()
                CurrentEmoteTrack:AdjustSpeed(EmoteSpeed)
            end)
        end
    end
end)

local function HumanoidPlayEmote(humanoid, name, id, creator)
    playEmote(humanoid, name, id)
end

local function PlayEmote(name, id, creator)
    local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local Description = Humanoid and Humanoid:FindFirstChildOfClass("HumanoidDescription")
    if not Description then
        return
    end
    if LocalPlayer.Character.Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        local succ, err = pcall(function()
            HumanoidPlayEmote(Humanoid, name, id, creator)
        end)
        if not succ then
            Description:AddEmote(name, id)
            HumanoidPlayEmote(Humanoid, name, id, creator)
        end
    else
        SendNotification("r6? lol", "you gotta be r15 dude")
    end
end

local function WaitForChildOfClass(parent, class)
    local child = parent:FindFirstChildOfClass(class)
    while not child or child.ClassName ~= class do
        child = parent.ChildAdded:Wait()
    end
    return child
end

local function IsFileFunc(...)
    if IsStudio then
        return
    elseif isfile then
        return isfile(...)
    end
end

local function WriteFileFunc(...)
    if IsStudio then
        return
    elseif writefile then
        return writefile(...)
    end
end

local function ReadFileFunc(...)
    if IsStudio then
        return
    elseif readfile then
        return readfile(...)
    end
end

if not IsStudio then
    if IsFileFunc("FavoritedEmotes.txt") then
        if not pcall(function()
            FavoritedEmotes = svc.http:JSONDecode(ReadFileFunc("FavoritedEmotes.txt"))
        end) then
            FavoritedEmotes = {}
        end
    else
        WriteFileFunc("FavoritedEmotes.txt", svc.http:JSONEncode(FavoritedEmotes))
    end
    local UpdatedFavorites = {}
    for i,name in pairs(FavoritedEmotes) do
        if typeof(name) == "string" then
            for i,emote in pairs(Emotes) do
                if emote.name == name then
                    table.insert(UpdatedFavorites, emote.id)
                    break
                end
            end
        end
    end
    if #UpdatedFavorites ~= 0 then
        FavoritedEmotes = UpdatedFavorites
        WriteFileFunc("FavoritedEmotes.txt", svc.http:JSONEncode(FavoritedEmotes))
    end
end

local function CharacterAdded(Character)
    for i,v in pairs(Frame:GetChildren()) do
        if not v:IsA("UIGridLayout") then
            v:Destroy()
        end
    end
    local Humanoid = WaitForChildOfClass(Character, "Humanoid")
    local Description = Humanoid:WaitForChild("HumanoidDescription", 5) or Instance.new("HumanoidDescription", Humanoid)
    local random = Instance.new("TextButton")
    local Ratio = Instance.new("UIAspectRatioConstraint")
    Ratio.AspectType = Enum.AspectType.ScaleWithParentSize
    Ratio.Parent = random
    random.LayoutOrder = 0
    random.TextColor3 = Color3.new(1, 1, 1)
    random.BorderSizePixel = 0
    random.BackgroundTransparency = 0.5
    random.BackgroundColor3 = Color3.new(0, 0, 0)
    random.TextScaled = true
    random.Text = "Random"
    random:SetAttribute("name", "")
    Corner:Clone().Parent = random
    random.MouseButton1Click:Connect(function()
        playSound(sfx.click)
        local randomemote = Emotes[math.random(1, #Emotes)]
        PlayEmote(randomemote.name, randomemote.id, randomemote.creator)
    end)
    random.MouseEnter:Connect(function()
        playSound(sfx.hover)
        EmoteName.Text = "Random"
    end)
    random.Parent = Frame
    for i,Emote in pairs(Emotes) do
        Description:AddEmote(Emote.name, Emote.id)
        local EmoteButton = Instance.new("ImageButton")
        local IsFavorited = table.find(FavoritedEmotes, Emote.id)
        EmoteButton.LayoutOrder = Emote.sort[CurrentSort] + ((IsFavorited and 0) or #Emotes)
        EmoteButton.Name = tostring(Emote.id)
        EmoteButton:SetAttribute("name", Emote.name)
        EmoteButton:SetAttribute("creator", Emote.creator)
        Corner:Clone().Parent = EmoteButton
        EmoteButton.Image = Emote.icon
        EmoteButton.BackgroundTransparency = 0.5
        EmoteButton.BackgroundColor3 = Color3.new(0, 0, 0)
        EmoteButton.BorderSizePixel = 0
        Ratio:Clone().Parent = EmoteButton
        local EmoteNumber = Instance.new("TextLabel")
        EmoteNumber.Name = "number"
        EmoteNumber.TextScaled = true
        EmoteNumber.BackgroundTransparency = 1
        EmoteNumber.TextColor3 = Color3.new(1, 1, 1)
        EmoteNumber.BorderSizePixel = 0
        EmoteNumber.AnchorPoint = Vector2.new(0.5, 0.5)
        EmoteNumber.Size = UDim2.new(0.2, 0, 0.2, 0)
        EmoteNumber.Position = UDim2.new(0.1, 0, 0.9, 0)
        EmoteNumber.Text = tostring(Emote.sort[CurrentSort])
        EmoteNumber.TextXAlignment = Enum.TextXAlignment.Center
        EmoteNumber.TextYAlignment = Enum.TextYAlignment.Center
        local UIStroke = Instance.new("UIStroke")
        UIStroke.Transparency = 0.5
        UIStroke.Parent = EmoteNumber
        EmoteNumber.Parent = EmoteButton
        EmoteButton.Parent = Frame
        EmoteButton.MouseButton1Click:Connect(function()
            playSound(sfx.click)
            PlayEmote(Emote.name, Emote.id, Emote.creator)
        end)
        EmoteButton.MouseEnter:Connect(function()
            playSound(sfx.hover)
            EmoteName.Text = Emote.name
        end)
        local Favorite = Instance.new("ImageButton")
        Favorite.Name = "favorite"
        if table.find(FavoritedEmotes, Emote.id) then
            Favorite.Image = FavoriteOn
        else
            Favorite.Image = FavoriteOff
        end
        Favorite.AnchorPoint = Vector2.new(0.5, 0.5)
        Favorite.Size = UDim2.new(0.2, 0, 0.2, 0)
        Favorite.Position = UDim2.new(0.9, 0, 0.9, 0)
        Favorite.BorderSizePixel = 0
        Favorite.BackgroundTransparency = 1
        Favorite.Parent = EmoteButton
        Favorite.MouseButton1Click:Connect(function()
            local index = table.find(FavoritedEmotes, Emote.id)
            if index then
                playSound(sfx.toggle_off)
                table.remove(FavoritedEmotes, index)
                Favorite.Image = FavoriteOff
                EmoteButton.LayoutOrder = Emote.sort[CurrentSort] + #Emotes
            else
                playSound(sfx.toggle_on)
                table.insert(FavoritedEmotes, Emote.id)
                Favorite.Image = FavoriteOn
                EmoteButton.LayoutOrder = Emote.sort[CurrentSort]
            end
            WriteFileFunc("FavoritedEmotes.txt", svc.http:JSONEncode(FavoritedEmotes))
        end)
    end
    for i=1,9 do
        local EmoteButton = Instance.new("Frame")
        EmoteButton.LayoutOrder = 2147483647
        EmoteButton.Name = "filler"
        EmoteButton.BackgroundTransparency = 1
        EmoteButton.BorderSizePixel = 0
        Ratio:Clone().Parent = EmoteButton
        EmoteButton.Visible = true
        EmoteButton.Parent = Frame
        EmoteButton.MouseEnter:Connect(function()
            EmoteName.Text = "Select an Emote"
        end)
    end
end

local function LoadEmotes()
    if IsLoading then return end
    IsLoading = true
    
    Emotes = {}
    
    for i,v in pairs(Frame:GetChildren()) do
        if not v:IsA("UIGridLayout") then
            v:Destroy()
        end
    end
    
    local existingLoad = BackFrame:FindFirstChild("LoadingLabel")
    if existingLoad then
        existingLoad:Destroy()
    end
    
    local loadingLabel = Instance.new("TextLabel")
    loadingLabel.Name = "LoadingLabel"
    loadingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingLabel.Text = "Loading..."
    loadingLabel.TextColor3 = Color3.new(1, 1, 1)
    loadingLabel.BackgroundColor3 = Color3.new(0, 0, 0)
    loadingLabel.TextScaled = true
    loadingLabel.BackgroundTransparency = 0.5
    loadingLabel.Size = UDim2.fromScale(0.2, 0.1)
    loadingLabel.Position = UDim2.fromScale(0.5, 0.5)
    loadingLabel.ZIndex = 10
    Corner:Clone().Parent = loadingLabel
    loadingLabel.Parent = BackFrame
    
    task.spawn(function()
        local params = CatalogSearchParams.new()
        params.AssetTypes = {Enum.AvatarAssetType.EmoteAnimation}
        params.SortType = Enum.CatalogSortType.RecentlyCreated
        params.SortAggregation = Enum.CatalogSortAggregation.AllTime
        params.IncludeOffSale = true
        if not ShowUGC then
            params.CreatorName = "Roblox"
        end
        params.Limit = 120
        
        local function getCatalogPage()
            local success, catalogPage = pcall(function()
                return svc.aes:SearchCatalog(params)
            end)
            if not success then
                task.wait(5)
                return getCatalogPage()
            end
            return catalogPage
        end
        
        local catalogPage = getCatalogPage()
        local pages = {}
        
        while true do
            local currentPage = catalogPage:GetCurrentPage()
            table.insert(pages, currentPage)
            if catalogPage.IsFinished then
                break
            end
            local function AdvanceToNextPage()
                local success = pcall(function()
                    catalogPage:AdvanceToNextPageAsync()
                end)
                if not success then
                    task.wait(5)
                    return AdvanceToNextPage()
                end
            end
            AdvanceToNextPage()
        end
        
        local totalEmotes = {}
        for _, page in pairs(pages) do
            for _, emote in pairs(page) do
                table.insert(totalEmotes, emote)
            end
        end
        
        for i, Emote in pairs(totalEmotes) do
            AddEmote(Emote.Name, Emote.Id, Emote.Price, Emote.CreatorName)
        end
        
        AddEmote("Arm Wave", 5915773155)
        AddEmote("Head Banging", 5915779725)
        AddEmote("Face Calisthenics", 9830731012)
        
        table.sort(Emotes, function(a, b)
            return a.index < b.index
        end)
        for i,v in pairs(Emotes) do
            v.sort.newestfirst = i
        end
        
        table.sort(Emotes, function(a, b)
            return a.index > b.index
        end)
        for i,v in pairs(Emotes) do
            v.sort.oldestfirst = i
        end
        
        table.sort(Emotes, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
        for i,v in pairs(Emotes) do
            v.sort.alphabeticfirst = i
        end
        
        table.sort(Emotes, function(a, b)
            return a.name:lower() > b.name:lower()
        end)
        for i,v in pairs(Emotes) do
            v.sort.alphabeticlast = i
        end
        
        table.sort(Emotes, function(a, b)
            return a.price < b.price
        end)
        for i,v in pairs(Emotes) do
            v.sort.lowestprice = i
        end
        
        table.sort(Emotes, function(a, b)
            return a.price > b.price
        end)
        for i,v in pairs(Emotes) do
            v.sort.highestprice = i
        end
        
        pcall(function()
            if loadingLabel and loadingLabel.Parent then
                loadingLabel:Destroy()
            end
        end)
        
        if LocalPlayer.Character then
            CharacterAdded(LocalPlayer.Character)
        end
        
        IsLoading = false
    end)
end

UGCButton.MouseButton1Click:Connect(function()
    if IsLoading then return end
    ShowUGC = not ShowUGC
    if ShowUGC then
        playSound(sfx.toggle_on)
        UGCButton.Text = "UGC: ON"
        UGCButton.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        playSound(sfx.toggle_off)
        UGCButton.Text = "UGC: OFF"
        UGCButton.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
    LoadEmotes()
end)
UGCButton.MouseEnter:Connect(function()
    playSound(sfx.hover)
end)

LoadEmotes()

task.wait(0.1)
if Loading and Loading.Parent then
    Loading:Destroy()
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if not IsLoading then
        CharacterAdded(char)
    end
end)
