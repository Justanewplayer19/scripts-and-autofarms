local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")

local KyriLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()

local window = KyriLib.new("CAC", {
    GameName = "CatalogAvatarCreator",
    Theme = {
        accent = Color3.fromRGB(100, 150, 255)
    }
})

local main = window:tab("Main", "user")

main:button("ALL emotes (including UGC)", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"))()
    window:notify("emotes", "loaded", 2)
end)
