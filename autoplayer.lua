local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.run = call("RunService")
svc.uis = call("UserInputService")
svc.vu = call("VirtualUser")

local id = game.PlaceId
local MMM, RAT, FF = 7205641391, 9571630408, 6447798030

if id ~= MMM and id ~= RAT and id ~= FF then
    return warn("autoplay: this game is not supported")
end

local ffsrc = [==[
local svc = {}
local gs = cloneref or function(o) return o end
local function call(n)
    return gs(game:GetService(n))
end

svc.plr = call("Players")
svc.run = call("RunService")
svc.uis = call("UserInputService")
svc.vu = call("VirtualUser")

local lp = svc.plr.LocalPlayer
local host = gethui and gethui() or lp:WaitForChild("PlayerGui")

local reg = host:FindFirstChild("ffctl")
if reg then
    local k = reg:FindFirstChild("kill")
    if k then pcall(function() k:Fire() end) end
    task.wait()
    reg:Destroy()
end

reg = Instance.new("Folder")
reg.Name = "ffctl"
local kill = Instance.new("BindableEvent")
kill.Name = "kill"
kill.Parent = reg
reg.Parent = host

local vsrg, env
for i,v in pairs(getgc(true)) do
    if type(v) == "table" then
        pcall(function()
            local g = rawget(v, "GameHandler")
            if type(g) == "table" and rawget(g, "Games") ~= nil then vsrg = v end
            if rawget(v, "VSRG") ~= nil and rawget(v, "SettingsHandler") ~= nil and rawget(v, "Configs") ~= nil then env = v end
        end)
    end
end
if not (vsrg and env) then
    reg:Destroy()
    return warn("autoplay: could not read this game, try again once a song has started")
end

local gh = vsrg.GameHandler
local vc = env.Configs.VSRG
local ign = vc.IgnoredNoteTypes
local death = vc.DeathNoteTypes

local cfg
do
    local raw = {
        on = false,
        tkey = "End",
        lead = 0,
        offms = 0,
        target = "Sick",
        bias = "Early",
        jitter = 0,
        tapms = 25,
        liftms = 0,
        hold = true,
        catchup = true,
        hitdeath = false,
        blockmiss = false,
        antiidle = true,
        misschance = 0,
        breakevery = 0,
        lanes = {}
    }
    for i = 1, 5 do raw.lanes[i] = true end

    cfg = setmetatable({}, {
        __index = function(_, k)
            if raw[k] == nil then
                warn("autoplay: there is no setting called "..tostring(k))
            end
            return raw[k]
        end,
        __newindex = function(_, k, v)
            if raw[k] == nil then
                warn("autoplay: there is no setting called "..tostring(k))
                return
            end
            raw[k] = v
        end,
        __iter = function()
            return next, raw
        end,
        __metatable = "locked"
    })
end

local jms = {
    Sick = 0,
    Good = 72,
    Ok = 122,
    Bad = 172,
    Random = 0
}

local hold = {}
local seen = 0
local lastNow = 0
local lastFld
local alive = true
local conns = {}
local tog, teardown, kb

local function songtime(gm, ck)
    local tps = gm.TimePositionSample
    local base = tps and tps.Position or gm.TimePosition
    if not base then return nil end
    if tps and type(tps.Clock) == "number" then
        return base + math.clamp(ck - tps.Clock, -0.25, 0.25) * (gm.AdjustedPlayback or 1)
    end
    return base
end

local function press(f, i, down)
    pcall(function() f:HitLane(i, down, os.clock()) end)
end

local function letgo()
    local f = gh.Field
    for i,v in pairs(hold) do
        hold[i] = nil
        if f then press(f, i, false) end
    end
end

local function setOn(v)
    cfg.on = v and true or false
    if not cfg.on then letgo() end
    pcall(function() tog:set(cfg.on) end)
    return cfg.on
end

local function hotkey()
    local n = cfg.tkey
    if kb then
        local ok, g = pcall(function() return kb:get() end)
        if ok and type(g) == "string" then n = g end
    end
    local ok, e = pcall(function() return Enum.KeyCode[n] end)
    return ok and e or nil
end

local function aim()
    local t = cfg.target
    if t == "Random" then
        local l = { "Sick", "Good", "Ok" }
        t = l[math.random(1, #l)]
    end

    local e = jms[t] or 0
    if cfg.bias == "Early" then
        e = -e
    elseif cfg.bias == "Both" and math.random() < 0.5 then
        e = -e
    end

    if cfg.jitter > 0 then
        e = e + (math.random() - 0.5) * 2 * cfg.jitter
    end

    return math.clamp(e, -195, 195)
end

local function usable(n)
    if n.Hit or n.Sync or n.apskip then return false end
    local ty = n.NoteData and n.NoteData.Type
    if not ty then return true end
    if table.find(death, ty) then return cfg.hitdeath end
    return table.find(ign, ty) == nil
end

conns[1] = svc.run.Heartbeat:Connect(function()
    if not cfg.on then return end

    local f = gh.Field
    local gm = gh.Playing and gh.Games[gh.Playing]
    if not (f and gm and f.Lanes) or gm.Ending then return end

    local ck = os.clock()
    local t = songtime(gm, ck)
    if not t then return end

    if f ~= lastFld or t < lastNow - 0.5 then
        table.clear(hold)
        lastFld = f
    end
    lastNow = t

    for li,lane in pairs(f.Lanes) do
        local h = hold[li]
        if h then
            if t >= h then
                hold[li] = nil
                press(f, li, false)
            end
        elseif cfg.lanes[li] ~= false then
            local n
            for i1,v in pairs(lane.Notes) do
                if usable(v) and (not n or v.Time < n.Time) then n = v end
            end

            if n then
                if n.apaim == nil then
                    seen = seen + 1
                    n.apaim = aim() + cfg.offms

                    if cfg.misschance > 0 and math.random(1, 100) <= cfg.misschance then
                        n.apskip = true
                    elseif cfg.breakevery > 0 and seen % cfg.breakevery == 0 then
                        n.apskip = true
                    end
                end

                local d = (t - n.Time) * 1000
                local want = n.apaim - cfg.lead
                local late = cfg.catchup and d > 0 and d <= 190

                if not n.apskip and (d >= want or late) then
                    press(f, li, true)

                    if cfg.hold and n.Length and n.Length > 0 then
                        hold[li] = n.Time + n.Length + cfg.liftms / 1000
                    else
                        local l = li
                        task.delay(cfg.tapms / 1000, function() press(f, l, false) end)
                    end
                end
            end
        end

        if cfg.blockmiss then
            for i1,v in pairs(lane.Notes) do
                if not (v.Hit or v.Sync) and (v.Time + (v.Length or 0) - t) < -0.19 then
                    v.Hit = true
                end
            end
        end
    end
end)

local tally = {}
local judged, accsum, combo, bestcombo = 0, 0, 0, 0
local lastGame

conns[2] = env.EventAction:Bind("ScoreCalculated"):Connect(function(f, n, sc, val, ms, acc)
    if f ~= gh.Field or not sc then return end
    tally[sc.Name] = (tally[sc.Name] or 0) + 1
    judged = judged + 1
    accsum = accsum + (acc or 0)

    if sc.Name == "Miss" then
        combo = 0
    else
        combo = combo + 1
        if combo > bestcombo then bestcombo = combo end
    end
end)

conns[3] = svc.uis.InputBegan:Connect(function(k)
    if svc.uis:GetFocusedTextBox() then return end
    if k.KeyCode == hotkey() then
        setOn(not cfg.on)
    end
end)

conns[5] = lp.Idled:Connect(function()
    if not cfg.antiidle then return end
    pcall(function()
        svc.vu:CaptureController()
        svc.vu:ClickButton2(Vector2.new())
    end)
end)

local kyri
do
    local src = game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua")
    local at = src:find("Enum.KeyCode.RightControl", 1, true)
    if at then
        local gate = "if gpe then return end"
        local pre = src:sub(1, at)
        local g = pre:match(".*()if gpe then return end")
        if g then
            src = src:sub(1, g - 1).."if false then return end"..src:sub(g + #gate)
        end
        src = src:gsub("Enum%.KeyCode%.RightControl", "Enum.KeyCode.Backquote")
    end
    kyri = loadstring(src)()
end

local w = kyri.new("ff autoplay", {
    GameName = "FunkyFriday",
    AutoLoad = "default",
    Mode = "island",
    Splash = false,
    Theme = {
        accent = Color3.fromRGB(190, 140, 255)
    }
})
if not w then return end

local main = w:tab("Main", "zap")
local tm = w:tab("Timing", "timer")
local prot = w:tab("Protect", "shield")
local hum = w:tab("Human", "user")
local lane = w:tab("Lanes", "columns-3")
local info = w:tab("Stats", "bar-chart-2")

do
    main:section("autoplay")
    tog = main:toggle("enabled", false, function(s)
        cfg.on = s
        if not s then letgo() end
    end, "ff_on")

    kb = main:keybind("toggle key", cfg.tkey, false, function() end, "ff_key")

    main:label("press backtick to hide this panel")

    main:section("feel")
    main:slider("hit early by (ms)", 0, 60, cfg.lead, function(v) cfg.lead = v end, "ff_lead", 1)
    main:slider("offset (ms)", -80, 80, cfg.offms, function(v) cfg.offms = v end, "ff_off", 1)
    main:slider("how long to hold a tap (ms)", 10, 150, cfg.tapms, function(v) cfg.tapms = v end, "ff_tap", 5)
end

do
    tm:section("judgement")
    tm:dropdown("aim for", { "Sick", "Good", "Ok", "Bad", "Random" }, cfg.target, function(v)
        cfg.target = v
    end, "ff_target")
    tm:dropdown("hit side", { "Early", "Late", "Both" }, cfg.bias, function(v)
        cfg.bias = v
    end, "ff_bias")
    tm:slider("timing jitter (ms)", 0, 80, cfg.jitter, function(v) cfg.jitter = v end, "ff_jit", 1)

    tm:section("sustains")
    tm:toggle("hold tails", cfg.hold, function(s) cfg.hold = s end, "ff_hold")
    tm:slider("release long notes early or late (ms)", -100, 100, cfg.liftms, function(v) cfg.liftms = v end, "ff_lift", 5)

    tm:paragraph("how close you need to be", "sick is within 50ms of the note, good within 100, ok within 150 and bad within 200. anything later than that is a miss. aiming for sick keeps you right on top of every note.")
end

do
    prot:section("notes")
    prot:toggle("catch late notes", cfg.catchup, function(s) cfg.catchup = s end, "ff_catch")
    prot:toggle("hit death notes", cfg.hitdeath, function(s) cfg.hitdeath = s end, "ff_death")
    prot:paragraph("about those notes", "some songs mix in skull and poison notes. hitting a skull wipes your health instantly and poison takes a big chunk out of it, while a normal note only gives a little back. letting them slide past costs you nothing at all, so leave this off unless you really want them hit. space bar notes are always left alone.")

    prot:section("scoring")
    prot:toggle("block misses", cfg.blockmiss, function(s) cfg.blockmiss = s end, "ff_bmiss")
    prot:paragraph("what this does", "a note only counts as missed once it has gone past and disappeared. with this on, notes you did not get are quietly marked as done first, so they stop costing you health. it does not hand you any points for them, and the server still works your real score out from the notes you actually hit.")

    prot:section("afk")
    prot:toggle("anti idle", cfg.antiidle, function(s) cfg.antiidle = s end, "ff_idle")
    prot:paragraph("staying connected", "autoplay never moves your mouse or presses a real key, so roblox decides you are away and disconnects you after about twenty minutes no matter how many notes you are hitting. this gives the game a tiny nudge whenever that timer starts, so you stay in. it works fine with roblox in the background.")
end

do
    hum:section("mistakes")
    hum:slider("miss chance (%)", 0, 25, cfg.misschance, function(v) cfg.misschance = v end, "ff_miss", 1)
    hum:slider("drop every n notes (0 = never)", 0, 200, cfg.breakevery, function(v) cfg.breakevery = v end, "ff_break", 1)
    hum:paragraph("tip", "try aiming for good with jitter around 30 and a miss chance of one or two percent. a whole song of nothing but flawless timing is the easiest thing there is to spot.")
end

do
    lane:section("lanes")
    for i = 1, 5 do
        local n = i
        lane:toggle("lane "..i, true, function(s) cfg.lanes[n] = s end, "ff_lane_"..i)
    end
    lane:label("lane 5 only shows up on 5 key songs")
end

local l1, l2, l3, l4, lj, bar
do
    info:section("live")
    l1 = info:label("score 0")
    l2 = info:label("accuracy 0%")
    l3 = info:label("combo 0")
    l4 = info:label("misses 0")
    bar = info:progressbar("accuracy", 100)
    lj = info:paragraph("judgements", "sick 0  good 0  ok 0  bad 0  miss 0")

    info:section("panel")
    info:button("reset position", function()
        pcall(function() w:resetpos() end)
    end)
    info:button("unload", function()
        teardown()
    end)
end

local tick = 0
conns[4] = svc.run.Heartbeat:Connect(function(dt)
    tick = tick + dt
    if tick < 0.1 then return end
    tick = 0

    if gh.Playing ~= lastGame then
        lastGame = gh.Playing
        table.clear(tally)
        judged, accsum, combo, bestcombo = 0, 0, 0, 0
    end

    local f = gh.Field
    local gm = gh.Playing and gh.Games[gh.Playing]
    local acc = judged > 0 and accsum / judged or 0
    local md = gm and gm.Metadata and gm.Metadata.Stats and f and gm.Metadata.Stats[f.Position]

    pcall(function()
        l1:set(("score %d%s"):format(f and f.CurrentScore or 0, md and md.MaxScore and ("  of %d"):format(md.MaxScore) or ""))
        l2:set(("accuracy %.2f%%"):format(acc))
        l3:set(("combo %d  best %d"):format(combo, bestcombo))
        l4:set(("misses %d  notes %d"):format(tally.Miss or 0, judged))
        bar:set(math.clamp(acc, 0, 100))
        lj:set(("sick %d  good %d  ok %d  bad %d  miss %d"):format(tally.Sick or 0, tally.Good or 0, tally.Ok or 0, tally.Bad or 0, tally.Miss or 0))
    end)

    if w.isl then
        pcall(function()
            w.isl:set({ subtitle = cfg.on and ("on  %.1f%%"):format(acc) or "off" })
        end)
    end
end)

teardown = function()
    if not alive then return end
    alive = false
    cfg.on = false
    letgo()

    for i,v in pairs(conns) do pcall(function() v:Disconnect() end) end

    pcall(function() w:destroy() end)
    pcall(function() reg:Destroy() end)
end

kill.Event:Connect(teardown)
reg.AncestryChanged:Connect(function()
    if not reg:IsDescendantOf(game) then teardown() end
end)
]==]

if id == FF then
    if not (getactors and run_on_actor) then
        return warn("autoplay: your executor cannot run this game, it needs actor support")
    end

    local act
    for i,v in pairs(getactors()) do
        if v:IsDescendantOf(svc.plr.LocalPlayer) then act = v end
    end
    act = act or getactors()[1]
    if not act then return warn("autoplay: could not hook into this game, try rejoining") end

    return run_on_actor(act, ffsrc)
end

local lp = svc.plr.LocalPlayer
local host = gethui and gethui() or lp:WaitForChild("PlayerGui")

local reg = host:FindFirstChild("apctl")
if reg then
    local k = reg:FindFirstChild("kill")
    if k then pcall(function() k:Fire() end) end
    task.wait()
    reg:Destroy()
end

reg = Instance.new("Folder")
reg.Name = "apctl"
local kill = Instance.new("BindableEvent")
kill.Name = "kill"
kill.Parent = reg
reg.Parent = host

local alive = true
local conns = {}
local shut = {}
local cfg, tog, teardown, letgo, w, kb

local function mkcfg(raw)
    return setmetatable({}, {
        __index = function(_, k)
            if raw[k] == nil then
                warn("autoplay: there is no setting called "..tostring(k))
            end
            return raw[k]
        end,
        __newindex = function(_, k, v)
            if raw[k] == nil then
                warn("autoplay: there is no setting called "..tostring(k))
                return
            end
            raw[k] = v
        end,
        __iter = function()
            return next, raw
        end,
        __metatable = "locked"
    })
end

local function setOn(v)
    cfg.on = v and true or false
    if not cfg.on and letgo then letgo() end
    pcall(function() tog:set(cfg.on) end)
    return cfg.on
end

local function hotkey()
    local n = cfg.tkey
    if kb then
        local ok, g = pcall(function() return kb:get() end)
        if ok and type(g) == "string" then n = g end
    end
    local ok, e = pcall(function() return Enum.KeyCode[n] end)
    return ok and e or nil
end

local kyri
do
    local src = game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua")
    local at = src:find("Enum.KeyCode.RightControl", 1, true)
    if at then
        local gate = "if gpe then return end"
        local pre = src:sub(1, at)
        local g = pre:match(".*()if gpe then return end")
        if g then
            src = src:sub(1, g - 1).."if false then return end"..src:sub(g + #gate)
        end
        src = src:gsub("Enum%.KeyCode%.RightControl", "Enum.KeyCode.Backquote")
    end
    kyri = loadstring(src)()
end

if id == MMM then
    svc.vim = call("VirtualInputManager")
    svc.cas = call("ContextActionService")
    svc.rep = call("ReplicatedStorage")

    local ng = require(lp.PlayerScripts.Start.Menu.Freeplay.NoteGame)

    local cls, notes, opt, st, stats, jd, sa, oldstats
    local hooked = false
    local animbase, lastside
    local jname = {}
    local poperr

    local function resolve()
        if cls and notes and opt and st and stats and jd and sa then return true end

        if not cls then
            for i,v in pairs(ng) do
                if typeof(v) == "function" then
                    for i1,v1 in pairs(getupvalues(v)) do
                        if type(v1) == "table" and rawget(v1, "_GetClosestNote") then cls = v1 break end
                    end
                end
                if cls then break end
            end
        end
        if not cls then return false end

        for i,v in pairs(getupvalues(cls._GetEarlistNoteOfAll)) do
            if type(v) == "table" then
                if rawget(v, "NoteSpeed") then opt = v else notes = v end
            end
        end
        for i,v in pairs(getupvalues(cls._CantHitNotes)) do
            if type(v) == "table" then st = v end
        end
        for i,v in pairs(getupvalues(cls._ArrowReleased)) do
            if type(v) == "table" then stats = v end
        end
        for i,v in pairs(getupvalues(cls._GetClosestNote)) do
            if type(v) == "table" and rawget(v, "Sick") and rawget(v, "Miss_Note") then jd = v end
        end
        for i,v in pairs(getupvalues(cls._ArrowPressed)) do
            if type(v) == "table" and rawget(v, "ReleaseAnimation") and rawget(v, "ConfirmAnimation") then sa = v end
        end
        if not (notes and opt and st and stats and jd) then return false end

        if not hooked then
            hooked = true
            oldstats = rawget(cls, "_ap_orig_UpdateStats")
            if not oldstats then
                oldstats = cls._UpdateStats
                cls._ap_orig_UpdateStats = oldstats
            end

            for k,v in pairs(jd) do jname[v] = k end

            local function ismiss(x)
                return type(x) == "table" and rawget(x, "AccuracyRating") == nil
            end

            local function isghost(x)
                return ismiss(x) and (rawget(x, "Score") or 0) < 0
            end

            local function refresh()
                for i,v in pairs(getupvalues(cls._GetClosestNote)) do
                    if type(v) == "table" and rawget(v, "Sick") and rawget(v, "Miss_Note") then jd = v end
                end
                for i,v in pairs(getupvalues(cls._ArrowReleased)) do
                    if type(v) == "table" and rawget(v, "Judgements") ~= nil then stats = v end
                end
                jname = {}
                for k,v in pairs(jd) do jname[v] = k end
            end

            local function tally(add, drop)
                local t = stats and stats.Judgements
                if type(t) ~= "table" then return end
                if drop and t[drop] and t[drop] > 0 then t[drop] = t[drop] - 1 end
                if add then t[add] = (t[add] or 0) + 1 end
            end

            local base = oldstats
            cls._UpdateStats = function(self, j, ...)
                if jname[j] == nil then refresh() end

                local miss = j == jd.Miss_Note or j == jd.Miss_Hit or ismiss(j)

                local ghost = j == jd.Miss_Hit or isghost(j)

                if ghost and cfg.ghostdrop then
                    return
                end

                if not ghost and miss and cfg.missfix then
                    local to = jd[cfg.missas]
                    if to then
                        local m0 = stats.Misses
                        local c0 = stats.Combo
                        local r = base(self, to, to.AccuracyRating or 1, ...)

                        if m0 and stats.Misses and stats.Misses > m0 then
                            stats.Misses = m0
                        end
                        if c0 and stats.Combo and stats.Combo <= c0 then
                            stats.Combo = c0 + 1
                            if (stats.BestCombo or 0) < stats.Combo then stats.BestCombo = stats.Combo end
                        end

                        tally(cfg.missas)

                        if cfg.misspop and animbase then
                            local okp, ep = pcall(function() animbase(self, to, lastside) end)
                            if not okp then poperr = tostring(ep) end
                        end

                        return r
                    end
                end

                local renamed
                if not miss and not ghost and cfg.force then
                    local to = jd[cfg.forceas]
                    if to and to ~= j then
                        renamed = jname[j]
                        j = to
                    end
                end

                if miss and cfg.blockmiss then
                    return
                end

                if miss and cfg.combofix then
                    local c, m = stats.Combo, stats.Misses
                    local r = base(self, j, ...)
                    stats.Combo, stats.Misses = c, m
                    return r
                end

                local out = base(self, j, ...)
                if renamed then tally(cfg.forceas, renamed) end
                return out
            end

            local oldanim = rawget(cls, "_ap_orig_AnimateAccuracy")
            if not oldanim then
                oldanim = cls._AnimateAccuracy
                cls._ap_orig_AnimateAccuracy = oldanim
            end
            animbase = oldanim

            cls._AnimateAccuracy = function(self, j, side, ...)
                if side ~= nil then lastside = side end
                if jname[j] == nil then refresh() end

                local ghost = j == jd.Miss_Hit or isghost(j)
                if ghost and cfg.ghostdrop then return end

                if not ismiss(j) and not ghost and cfg.force then
                    local to = jd[cfg.forceas]
                    if to then j = to end
                end

                return animbase(self, j, side, ...)
            end

            shut[#shut + 1] = function()
                cls._UpdateStats = base
                cls._AnimateAccuracy = oldanim
            end
        end

        return true
    end

    local dirs = { "Left", "Down", "Up", "Right", "Left2", "Down2", "Up2", "Right2", "Space" }

    local raw = {
        on = false,
        tkey = "End",
        lead = 0.5,
        offms = 0,
        target = "Perfect",
        bias = "Early",
        jitter = 0,
        tapms = 20,
        hold = true,
        retap = 0,
        direct = true,
        antiidle = true,
        catchup = true,
        retry = true,
        retryms = 45,
        ghostguard = true,
        blockmiss = false,
        combofix = false,
        force = false,
        forceas = "Sick",
        missfix = false,
        missas = "Sick",
        ghostdrop = false,
        misspop = true,
        dodge = true,
        skipdeath = true,
        autotype = true,
        dodgeat = 4,
        hplock = false,
        hpval = 0.5,
        misschance = 0,
        breakevery = 0,
        lanes = {}
    }
    for i,v in pairs(dirs) do raw.lanes[v] = true end
    cfg = mkcfg(raw)

    local jpos = {
        Perfect = 0,
        Sick = 0.03,
        Good = 0.079,
        Ok = 0.116,
        Bad = 0.15
    }

    local head = {}
    local prev = {}
    local shot = {}
    local held = {}
    local tshot = {}
    local seen = 0

    local function key(d)
        if not (st and opt) then return nil end
        local n = st.MaxArrows or 4
        if n == 4 then return opt[d.."Key"] end
        local t = opt.ExtraKeySettings and opt.ExtraKeySettings[tostring(n)]
        return t and t[d.."Key"] or opt[d.."Key"]
    end

    local acont, aside
    local function arrows()
        if acont and acont.Parent then return acont end
        if not notes then return nil end
        acont, aside = nil, nil

        for d,l in pairs(notes) do
            local f = l[1] and l[1][1]
            local nf = f and f.Parent
            local sd = nf and nf.Parent and nf.Parent.Parent
            local c = sd and sd:FindFirstChild("MainArrowContainer")
            if c and c:FindFirstChild(d) then
                acont, aside = c, sd.Name
                return acont
            end
        end
    end

    local pressed = {}

    local function vimsend(d, down)
        local k = key(d)
        if not k then return end
        pcall(function()
            svc.vim:SendKeyEvent(down, Enum.KeyCode[k], false, game)
        end)
    end

    local function dsend(d, down)
        local c = arrows()
        if not c then return false end
        local a = c:FindFirstChild(d)
        if not a then return false end

        if not down then
            local r = pressed[d]
            if not r then return true end
            pressed[d] = nil
            r.Direction = aside
            local ok = pcall(function() cls:_ArrowReleased(a, r) end)
            if not ok then return false end
            pcall(function() sa:ReleaseAnimation(a) end)
            local chr = cls:_GetOurCharacter()
            if chr then pcall(function() cls:_AnimateCharacter(a, 3, chr, not (r.apDead or r.apHit)) end) end
            return true
        end

        if pressed[d] then dsend(d, false) end

        local chr = cls:_GetOurCharacter()
        local ok, r, hit, loop, dead, noanim = pcall(function()
            return cls:_ArrowPressed(a, chr)
        end)
        if not (ok and r) then return false end

        pressed[d] = r
        r.apHit, r.apDead = hit, dead
        if chr and not noanim then
            pcall(function() cls:_AnimateCharacter(a, 1, chr, not (dead or hit)) end)
        end
        pcall(function()
            if hit then sa:ConfirmAnimation(a, false, loop) else sa:PressAnimation(a) end
        end)
        return true
    end

    local function send(d, down)
        if cfg.direct and sa then
            if dsend(d, down) then return end
        end
        vimsend(d, down)
    end

    local function release(d)
        if held[d] then
            held[d] = nil
            send(d, false)
        end
    end

    letgo = function()
        for i,v in pairs(held) do release(i) end
        for i,v in pairs(pressed) do send(i, false) end
        table.clear(pressed)
        table.clear(head)
        table.clear(prev)
        table.clear(shot)
        table.clear(tshot)
    end

    local function spd()
        if not cls then return 1 end
        local ok, v = pcall(function() return cls:_GetNoteSpeed() end)
        return ok and v or 1
    end

    local function window()
        return jd and jd.Bad.Distance * spd() or 0
    end

    local function offset(mv, dt)
        local s = spd()
        local ups = dt > 0 and mv / dt or 0
        local o = cfg.lead * mv + cfg.offms / 1000 * ups

        local t = cfg.target
        if t == "Random" then
            local l = { "Sick", "Good", "Ok" }
            t = l[math.random(1, #l)]
        end

        local j = (jpos[t] or 0) * s
        if cfg.bias == "Late" then
            j = -j
        elseif cfg.bias == "Both" and math.random() < 0.5 then
            j = -j
        end
        o = o + j

        if cfg.jitter > 0 then
            o = o + (math.random() - 0.5) * 2 * (cfg.jitter / 1000 * ups)
        end

        local wd = window()
        if cfg.ghostguard then
            if o > wd then o = wd end
            if o < -wd then o = -wd end
        end

        return o
    end

    local agui, mctitle, mctab, mcmodat, mcgen = nil, nil, nil, 0, 0
    local danger

    local function arrowgui()
        if agui and agui.Parent then return agui end
        agui = nil
        for i,v in pairs(lp.PlayerGui:GetDescendants()) do
            if v.Name == "ArrowGui" and v:IsA("GuiObject") then agui = v break end
        end
        return agui
    end

    local function songname()
        local g = arrowgui()
        local ti = g and g:FindFirstChild("Title", true)
        if not ti or not ti.Text then return nil end
        local t = ti.Text:gsub("<[^>]->", ""):gsub("%[[^%]]*%]", ""):gsub("%s+", " ")
        return (t:gsub("^%s+", ""):gsub("%s+$", "")):lower()
    end

    local function modchart()
        local now = os.clock()
        if now - mcmodat > 2 then
            mcmodat = now
            local title = songname()
            if title ~= mctitle then
                mctitle, mctab, danger = title, nil, nil
                mcgen = mcgen + 1
            end
        end
        if mctab then return mctab end
        if not mctitle then return nil end

        local mc = svc.rep:FindFirstChild("Modules")
        mc = mc and mc:FindFirstChild("ModCharts")
        if not mc then return nil end

        local best, bestlen
        for i,v in pairs(mc:GetDescendants()) do
            if v:IsA("ModuleScript") and v.Name:sub(1, 1) ~= "_" and v.Name ~= "API" and v.Name ~= "MechanicInfo" then
                local nm = v.Name:gsub("_", " "):gsub("%(New%)", ""):gsub("%(new%)", "")
                nm = (nm:gsub("^%s+", ""):gsub("%s+$", "")):lower()
                if #nm >= 4 and mctitle:find(nm, 1, true) and (not bestlen or #nm > bestlen) then
                    best, bestlen = v, #nm
                end
            end
        end
        if not best then return nil end

        local ok, t = pcall(function() return require(best) end)
        if ok and type(t) == "table" then mctab = t end
        return mctab
    end

    local function dangerset()
        if danger then return danger end
        local t = modchart()
        if not t then return nil end
        danger = {}
        local cn = rawget(t, "_CustomNoteConfig")
        if type(cn) == "table" and type(cn.IsDangerous) == "table" and type(cn.ArrowSkinData) == "table" then
            for skin,bad in pairs(cn.IsDangerous) do
                local sd = bad and cn.ArrowSkinData[skin]
                if type(sd) == "table" then
                    for dir,frames in pairs(sd) do
                        if type(frames) == "table" then
                            for i,fr in pairs(frames) do
                                if type(fr) == "table" and type(fr.Image) == "string" then
                                    danger[fr.Image] = true
                                end
                            end
                        end
                    end
                end
            end
        end
        return danger
    end

    local dnote = setmetatable({}, { __mode = "k" })
    local wrapped

    local function wrapnotes()
        local t = modchart()
        if not t then return end
        local cn = rawget(t, "_CustomNoteConfig")
        if type(cn) ~= "table" or type(cn.IsDangerous) ~= "table" then return end
        if wrapped == cn then return end
        wrapped = cn

        local base = rawget(cn, "_ap_orig_CustomizeNote") or cn.CustomizeNote
        if typeof(base) ~= "function" then return end
        cn._ap_orig_CustomizeNote = base

        cn.CustomizeNote = function(...)
            local args = table.pack(...)
            pcall(function()
                local frame, skin
                for i = 1, args.n do
                    local v = args[i]
                    if not frame and typeof(v) == "Instance" and v:IsA("GuiObject") then frame = v end
                    if not skin and type(v) == "string" and cn.IsDangerous[v] ~= nil then skin = v end
                end
                if frame and skin then dnote[frame] = cn.IsDangerous[skin] == true end
            end)
            return base(...)
        end
    end

    local function deadly(f)
        if not cfg.skipdeath then return false end
        wrapnotes()
        if dnote[f] ~= nil then return dnote[f] end
        local d = dangerset()
        if not d or not next(d) then return false end
        local ok, img = pcall(function() return f.Image end)
        return ok and type(img) == "string" and d[img] == true
    end

    local function fire(d, e)
        shot[d] = true
        tshot[d] = os.clock()
        local lng = e[2]

        task.spawn(function()
            release(d)
            send(d, true)
            held[d] = true

            if lng and cfg.hold then
                if cfg.retap > 0 then
                    while lng.Parent and lng.Visible do
                        task.wait(cfg.retap / 1000)
                        if not (lng.Parent and lng.Visible) then break end
                        send(d, false)
                        task.wait()
                        send(d, true)
                    end
                else
                    while lng.Parent and lng.Visible do task.wait() end
                end
                release(d)
            else
                task.delay(cfg.tapms / 1000, function() release(d) end)
            end
        end)
    end

    conns[1] = svc.run.RenderStepped:Connect(function(dt)
        if not cfg.on then return end
        if not resolve() then return end
        if cls:_CantHitNotes() then return end

        local ds = opt.DownScroll
        local tgt = ds and 1 or 0
        local wd = window()

        for d,l in pairs(notes) do
            local e = l[1]
            local f = e and e[1]

            if not f then
                head[d], prev[d], shot[d] = nil, nil, nil
            elseif cfg.lanes[d] ~= false then
                if head[d] ~= f then
                    head[d] = f
                    prev[d] = nil
                    shot[d] = nil
                    seen = seen + 1

                    if deadly(f) then
                        shot[d] = true
                    elseif cfg.misschance > 0 and math.random(1, 100) <= cfg.misschance then
                        shot[d] = true
                    elseif cfg.breakevery > 0 and seen % cfg.breakevery == 0 then
                        shot[d] = true
                    end
                end

                local p = f.Position.Y.Scale
                local mv = prev[d] and math.abs(p - prev[d]) or 0
                prev[d] = p
                local diff = ds and (tgt - p) or (p - tgt)

                if not shot[d] then
                    if mv > 0 and diff <= offset(mv, dt) then
                        fire(d, e)
                    elseif cfg.catchup and diff < 0 and -diff <= wd then
                        fire(d, e)
                    end
                elseif cfg.retry and tshot[d] and os.clock() - tshot[d] >= cfg.retryms / 1000 then
                    if diff <= 0 and -diff <= wd then
                        fire(d, e)
                    else
                        tshot[d] = nil
                    end
                end
            end
        end
    end)

    local pend, pkey, parm, plast = nil, nil, true, 0
    local pseen, pscan = 0, 0
    local mech, mechat, mechgen = nil, 0, -1
    local ptries, pabs = 0, nil

    local function mechlive(m)
        local sf = rawget(m, "SawFrame")
        if typeof(sf) ~= "Instance" or not sf.Parent then return false end
        for i,v in pairs(sf:GetDescendants()) do
            if v:IsA("ImageLabel") then return true end
        end
        return false
    end

    local function mechok(m)
        return type(m) == "table"
    end

    local function findmech()
        if mechok(mech) and mechgen == mcgen then return mech end
        if os.clock() - mechat < 2 then return nil end
        mechat = os.clock()
        mech = nil

        local t = modchart()
        if not t then return nil end

        local seen = {}
        local function crawl(f, depth)
            if mech or depth > 6 or type(f) ~= "function" or seen[f] then return end
            seen[f] = true
            local oku, us = pcall(function() return getupvalues(f) end)
            if oku and us then
                for k,v in pairs(us) do
                    if type(v) == "table" and (rawget(v, "CanDodge") ~= nil or rawget(v, "SawFrame") ~= nil
                        or rawget(v, "LastDodge") ~= nil or rawget(v, "WarningImage") ~= nil) then
                        mech = v
                        return
                    end
                    if type(v) == "function" then crawl(v, depth + 1) end
                end
            end
            local okp, ps = pcall(function() return debug.getprotos(f) end)
            if okp and ps then for i,v in pairs(ps) do crawl(v, depth + 1) end end
        end
        for k,v in pairs(t) do if typeof(v) == "function" then crawl(v, 0) end end

        if mech then
            mechgen = mcgen
        end
        return mech
    end

    local function dodgekey()
        if pkey then return pkey end
        local ok, all = pcall(function() return svc.cas:GetAllBoundActionInfo() end)
        if ok and type(all) == "table" then
            for nm,info in pairs(all) do
                if tostring(nm):sub(1, 6) == "Event-" then
                    for i,t in pairs(info.inputTypes or {}) do
                        if typeof(t) == "EnumItem" and t.EnumType == Enum.KeyCode then
                            pkey = t
                            return pkey
                        end
                    end
                end
            end
        end
        if pseen > 0 and os.clock() - pseen > 1.5 then
            pkey = Enum.KeyCode.Space
            return pkey
        end
        return nil
    end

    local function tap(k)
        if not k then return end
        plast = os.clock()
        svc.vim:SendKeyEvent(true, k, false, game)
        task.delay(0.03, function()
            pcall(function() svc.vim:SendKeyEvent(false, k, false, game) end)
        end)
    end

    local gmap, gsheet, gbank, ggen = nil, nil, nil, -1

    local function letterscan(t)
        local did, map, sheets, bank = {}, {}, {}, nil
        local function isl(v)
            if type(v) ~= "table" then return false end
            local n = 0
            for k in pairs(v) do if type(k) == "string" and #k == 1 then n = n + 1 end end
            return n > 20
        end
        local function isb(v)
            if type(v) ~= "table" or #v < 20 then return false end
            for i,k in pairs(v) do if type(k) ~= "string" or #k < 2 then return false end end
            return true
        end
        local function crawl(f, d)
            if d > 8 or type(f) ~= "function" or did[f] then return end
            did[f] = true
            local oku, us = pcall(function() return getupvalues(f) end)
            if oku and us then
                for k,v in pairs(us) do
                    if isl(v) then
                        for k1,fs in pairs(v) do
                            if type(k1) == "string" and #k1 == 1 and type(fs) == "table" then
                                for i2,fr in pairs(fs) do
                                    if type(fr) == "table" and fr.Image and fr.ImageRectOffset then
                                        sheets[fr.Image] = true
                                        map[fr.Image .. "@" .. tostring(fr.ImageRectOffset)] = k1
                                    end
                                end
                            end
                        end
                    elseif not bank and isb(v) then
                        bank = v
                    end
                    if type(v) == "function" then crawl(v, d + 1) end
                end
            end
            local okp, ps = pcall(function() return debug.getprotos(f) end)
            if okp and ps then for i,v in pairs(ps) do crawl(v, d + 1) end end
        end
        for k,v in pairs(t) do if typeof(v) == "function" then crawl(v, 0) end end
        return map, sheets, bank
    end

    local function glyphdata()
        if ggen == mcgen then return gmap end
        ggen = mcgen
        gmap, gsheet, gbank = nil, nil, nil

        local t = modchart()
        if type(t) == "table" then
            local a, b, c = letterscan(t)
            if next(a) then gmap, gsheet, gbank = a, b, c end
        end
        if not gmap and mctitle and mctitle:find("monochrome", 1, true) then
            local mc = svc.rep:FindFirstChild("Modules")
            mc = mc and mc:FindFirstChild("ModCharts")
            for i,v in pairs(mc and mc:GetDescendants() or {}) do
                if v:IsA("ModuleScript") and v.Name:lower():find("monochrome") then
                    local ok, m = pcall(function() return require(v) end)
                    if ok and type(m) == "table" then
                        local a, b, c = letterscan(m)
                        if next(a) then gmap, gsheet, gbank = a, b, c break end
                    end
                end
            end
        end
        return gmap
    end

    local keymap = { [" "] = Enum.KeyCode.Space, ["!"] = Enum.KeyCode.One, ["?"] = Enum.KeyCode.Slash }

    local function readword()
        if not gmap or not gsheet then return nil end
        local g = {}
        for i,v in pairs(lp.PlayerGui:GetDescendants()) do
            if v:IsA("ImageLabel") and gsheet[v.Image] and v.Visible then
                local l = gmap[v.Image .. "@" .. tostring(v.ImageRectOffset)]
                local ap = v.AbsolutePosition
                if l and l ~= " " and ap.Y > 0 then
                    g[#g + 1] = { l = l, x = ap.X, y = ap.Y, w = v.AbsoluteSize.X }
                end
            end
        end
        if #g < 3 then return nil end
        table.sort(g, function(a, b)
            if math.abs(a.y - b.y) > 24 then return a.y < b.y end
            return a.x < b.x
        end)

        local raw, gap = "", ""
        for i,v in pairs(g) do
            local pv = g[i - 1]
            if pv and v.x - (pv.x + pv.w) > pv.w * 0.6 then gap = gap .. " " end
            raw = raw .. v.l
            gap = gap .. v.l
        end

        if type(gbank) == "table" then
            for i,ph in pairs(gbank) do
                if type(ph) == "string" and (ph:gsub(" ", "")) == raw then return ph end
            end
        end
        return gap
    end

    local function typeout(w)
        for i = 1, #w do
            local c = w:sub(i, i)
            local k = keymap[c] or Enum.KeyCode[c]
            if k then
                svc.vim:SendKeyEvent(true, k, false, game)
                svc.vim:SendKeyEvent(false, k, false, game)
            end
            svc.run.RenderStepped:Wait()
        end
    end

    do
        local busy, done, scan = false, nil, 0
        task.spawn(function()
            while alive do
                task.wait(0.05)
                if not cfg.autotype or busy then continue end
                pcall(function()
                    if not arrowgui() then done = nil return end
                    local now = os.clock()
                    if now - scan < 0.05 then return end
                    scan = now
                    if not glyphdata() then return end

                    local w = readword()
                    if not w then done = nil return end
                    if w == done then return end
                    done = w
                    busy = true
                    task.spawn(function()
                        pcall(typeout, w)
                        busy = false
                    end)
                end)
            end
        end)
    end

    local dodgeerr

    task.spawn(function()
        while alive do
            svc.run.RenderStepped:Wait()
            if not cfg.dodge then
                pkey, pseen, mech = nil, 0, nil
                continue
            end

            local okd, ed = pcall(function()
            local now = os.clock()

            local m = arrowgui() and findmech() or nil
            if m then
                if pseen == 0 then pseen = now end
                if not rawget(m, "CanDodge") or not mechlive(m) then ptries = 0 end
                if rawget(m, "CanDodge") == true and mechlive(m) and not rawget(m, "Dodged") and ptries < 3 and now - plast > 0.22 then
                    ptries = ptries + 1
                    tap(dodgekey())
                end
            end

            if now - pscan > 0.1 then
                pscan = now
                local g = arrowgui()
                pend = nil
                if g then
                    local f = g:FindFirstChild("Pendulum", true)
                    if f and f:IsA("GuiObject") then pend = f end
                end
            end

            if pend and pend.Parent then
                if pseen == 0 then pseen = now end
                local r = pend.Rotation
                local a = math.abs(r)
                if a > 18 then parm = true end
                local k = dodgekey()
                if parm and k and a <= cfg.dodgeat and now - plast > 0.2 then
                    if a <= 1 or (pabs and a > pabs) then
                        parm = false
                        tap(k)
                    end
                end
                pabs = a
            end

            if not pend and not m then pseen, pkey = 0, nil end
            end)

            if not okd and tostring(ed) ~= dodgeerr then
                dodgeerr = tostring(ed)
                warn("autoplay: auto dodge stopped working, try reloading")
            end
        end
    end)

    task.spawn(function()
        while alive do
            if cfg.hplock and st and st.HealthBar then
                pcall(function() st.HealthBar:SetRatio(cfg.hpval) end)
            end
            task.wait(0.05)
        end
    end)

    w = kyri.new("mmm autoplay", {
        GameName = "MondayMorningMisery",
        AutoLoad = "default",
        Mode = "island",
        Splash = false,
        Theme = {
            accent = Color3.fromRGB(120, 200, 255)
        }
    })
    if not w then return end

    local main = w:tab("Main", "zap")
    local tm = w:tab("Timing", "timer")
    local prot = w:tab("Protect", "shield")
    local hum = w:tab("Human", "user")
    local lane = w:tab("Lanes", "columns-3")
    local info = w:tab("Stats", "bar-chart-2")
    local own = w:tab("Yourself", "hand")
    local upd = w:tab("Updates", "bell")

    do
        main:section("autoplay")
        tog = main:toggle("enabled", false, function(s)
            cfg.on = s
            if not s then letgo() end
        end, "ap_on")

        kb = main:keybind("toggle key", cfg.tkey, false, function() end, "ap_key")

        main:label("press backtick to hide this panel")

        main:section("feel")
        main:slider("hit early by (frames)", 0, 2, cfg.lead, function(v) cfg.lead = v end, "ap_lead", 0.05)
        main:slider("offset (ms)", -80, 80, cfg.offms, function(v) cfg.offms = v end, "ap_off", 1)
        main:slider("how long to hold a tap (ms)", 5, 120, cfg.tapms, function(v) cfg.tapms = v end, "ap_tap", 1)
    end

    do
        tm:section("judgement")
        tm:dropdown("aim for", { "Perfect", "Sick", "Good", "Ok", "Bad", "Random" }, cfg.target, function(v)
            cfg.target = v
        end, "ap_target")
        tm:dropdown("hit side", { "Early", "Late", "Both" }, cfg.bias, function(v)
            cfg.bias = v
        end, "ap_bias")
        tm:slider("timing jitter (ms)", 0, 60, cfg.jitter, function(v) cfg.jitter = v end, "ap_jit", 1)

        tm:section("long notes")
        tm:toggle("hold tails", cfg.hold, function(s) cfg.hold = s end, "ap_hold")
        tm:slider("retap long notes (ms, 0 = just hold)", 0, 200, cfg.retap, function(v) cfg.retap = v end, "ap_retap", 5)

        tm:label("sick is tightest, then good, ok, bad. aim for sick")
    end

    do
        prot:section("miss recovery")
        prot:toggle("catch late notes", cfg.catchup, function(s) cfg.catchup = s end, "ap_catch")
        prot:toggle("retry unhit notes", cfg.retry, function(s) cfg.retry = s end, "ap_retry")
        prot:slider("retry after (ms)", 15, 150, cfg.retryms, function(v) cfg.retryms = v end, "ap_retryms", 5)
        prot:toggle("ghost tap guard", cfg.ghostguard, function(s) cfg.ghostguard = s end, "ap_ghost")

        prot:section("input")
        prot:toggle("direct input (works tabbed out)", cfg.direct, function(s) cfg.direct = s end, "ap_direct")
        prot:toggle("anti idle", cfg.antiidle, function(s) cfg.antiidle = s end, "ap_idle")

        prot:toggle("auto dodge", cfg.dodge, function(s) cfg.dodge = s end, "ap_dodge")
        prot:toggle("skip death notes", cfg.skipdeath, function(s) cfg.skipdeath = s end, "ap_skipdeath")
        prot:toggle("type for me", cfg.autotype, function(s) cfg.autotype = s end, "ap_autotype")
        prot:slider("dodge window (degrees)", 1, 9, cfg.dodgeat, function(v) cfg.dodgeat = v end, "ap_dodgeat", 1)
        prot:label("leave direct on, it keeps playing while you are tabbed out")

        prot:section("stat blocking")
        prot:toggle("block misses", cfg.blockmiss, function(s) cfg.blockmiss = s end, "ap_bmiss")
        prot:toggle("keep combo on miss", cfg.combofix, function(s) cfg.combofix = s end, "ap_cfix")
        prot:label("block drops the miss, keep combo lets it count but saves your combo")

        own:section("what your hits count as")
        own:toggle("rate every hit myself", cfg.force, function(s) cfg.force = s end, "ap_force")
        own:dropdown("count my hits as", { "Sick", "Good", "Ok", "Bad" }, cfg.forceas, function(v) cfg.forceas = v end, "ap_forceas")

        own:section("misses")
        own:toggle("turn misses into a hit", cfg.missfix, function(s) cfg.missfix = s end, "ap_missfix")
        own:dropdown("count misses as", { "Sick", "Good", "Ok", "Bad" }, cfg.missas, function(v) cfg.missas = v end, "ap_missas")

        own:toggle("pop the rating up on a turned miss", cfg.misspop, function(s) cfg.misspop = s end, "ap_misspop")
        own:label("shows the rating on screen like a real hit")

        own:section("ghost taps")
        own:toggle("ignore taps on an empty lane", cfg.ghostdrop, function(s) cfg.ghostdrop = s end, "ap_ghost")
        own:label("empty taps never earn score, this only drops the 50 point penalty")

        own:label("play with autoplay off, your notes just get written down as what you picked")

        prot:section("health bar")
        prot:toggle("lock bar", cfg.hplock, function(s) cfg.hplock = s end, "ap_hplock")
        prot:slider("locked at", 0, 1, cfg.hpval, function(v) cfg.hpval = v end, "ap_hpval", 0.05)
        prot:label("the bar only shows who is ahead, so this just changes what you see")
    end

    do
        upd:section("22 november")
        upd:paragraph("songs with mechanics get played for you",
            "charts with an exclamation mark next to them can kill you. the saw in termination and the swinging pendulum in safety lullaby, left unchecked and lost cause are now dodged for you. it reads the dodge key out of the game itself, so there is nothing to set up.")
        upd:paragraph("notes that kill you are left alone",
            "expurgation and hellclown mix in notes that kill you if you hit them. those get skipped now. death toll's custom notes are harmless so they still get played.")
        upd:paragraph("monochrome v1 gets typed for you",
            "the typing bit in monochrome v1 is read off the screen and typed back in about a tenth of a second, spaces included. the window gets shorter the further into the song you are, so it types the whole thing at once instead of letter by letter.")
        upd:paragraph("every song is covered now",
            "the invisible notes in musical memory and the moving lanes in missingno get played normally, and cheating and unfairness are only marked unfair for being hard, nothing in them can kill you.")

        upd:section("earlier")
        upd:paragraph("rate your own notes",
            "the Yourself tab lets you play with autoplay off and still choose what each note counts as, and turn notes you never touched into hits.")

        upd:label("both new settings live in the Protect tab and are already on")
    end

    do
        hum:section("mistakes")
        hum:slider("miss chance (%)", 0, 25, cfg.misschance, function(v) cfg.misschance = v end, "ap_miss", 1)
        hum:slider("drop every n notes (0 = never)", 0, 200, cfg.breakevery, function(v) cfg.breakevery = v end, "ap_break", 1)
        hum:label("good with jitter 25 and 2% misses reads like a real run")
    end

    resolve()

    do
        lane:section("lanes")
        for i,v in pairs(dirs) do
            lane:toggle(v:lower(), true, function(s) cfg.lanes[v] = s end, "ap_lane_"..v)
        end
    end

    task.delay(1.5, function()
        local ok = pcall(function()
            w:notify("mmm autoplay", "new: mechanic songs get dodged for you, see the Updates tab", 7, "bell")
        end)
        if not ok then pcall(kyri.toast, "mmm autoplay updated, see the Updates tab") end
    end)

    local lblscore, lblacc, lblmiss, lblcombo, lbljudge, bar
    do
        info:section("live")
        lblscore = info:label("score 0")
        lblacc = info:label("accuracy 0%")
        lblmiss = info:label("misses 0")
        lblcombo = info:label("combo 0")
        bar = info:progressbar("accuracy", 100)
        lbljudge = info:paragraph("judgements", "sick 0  good 0  ok 0  bad 0")

        info:section("panel")
        info:button("reset position", function()
            pcall(function() w:resetpos() end)
        end)
        info:button("unload", function()
            teardown()
        end)
    end

    local tick = 0
    conns[2] = svc.run.Heartbeat:Connect(function(dt)
        tick = tick + dt
        if tick < 0.1 then return end
        tick = 0

        if not stats then
            if not resolve() then return end
        end

        local sc = stats.Score or 0
        local ac = stats.Accuracy or 0
        local ms = stats.Misses or 0
        local cb = stats.Combo or 0
        local j = stats.Judgements or {}

        pcall(function()
            lblscore:set("score "..tostring(ng.FormatScore and ng:FormatScore(sc) or math.floor(sc)))
            lblacc:set(("accuracy %.2f%%"):format(ac))
            lblmiss:set(("misses %d"):format(ms))
            lblcombo:set(("combo %d  best %d"):format(cb, stats.BestCombo or 0))
            bar:set(math.clamp(ac, 0, 100))
            lbljudge:set(("sick %d  good %d  ok %d  bad %d"):format(j.Sick or 0, j.Good or 0, j.Ok or 0, j.Bad or 0))
        end)

        if w.isl then
            pcall(function()
                w.isl:set({ subtitle = cfg.on and ("on  %.1f%%"):format(ac) or "off" })
            end)
        end
    end)
elseif id == RAT then
    svc.rep = call("ReplicatedStorage")
    svc.snd = call("SoundService")

    local util = require(svc.rep.UtilityModule)
    local lmod = require(svc.rep.GUI.LoadingModule)
    local gm = require(svc.rep.Game.GameModule)
    local pm = require(svc.rep.Game.PlayerModule)

    local gtrig = getfenv(gm.IsActive).trigger
    if not gtrig then
        reg:Destroy()
        return warn("autoplay: could not hook into this game, try rejoining")
    end

    local sides
    local sidx

    local function side()
        for i,v in pairs(getupvalues(gtrig)) do
            if type(v) == "number" then sidx = v end
        end

        if not (sides and sidx and sides[sidx] and sides[sidx].Strums) then
            for i,v in pairs(getupvalues(pm.Trigger)) do
                if type(v) == "table" and type(v[1]) == "table" and v[1].Strums then sides = v end
            end
        end

        return sides and sides[sidx or 1]
    end

    local raw = {
        on = false,
        notab = true,
        tkey = "End",
        lead = 8,
        offms = 0,
        target = "Perfect",
        bias = "Early",
        jitter = 0,
        tapms = 25,
        liftms = 0,
        hold = true,
        skiphurt = true,
        hitspecial = true,
        catchup = true,
        blockmiss = false,
        nostumble = false,
        nofail = false,
        antiidle = true,
        hplock = false,
        hp = 1.5,
        misschance = 0,
        breakevery = 0,
        lanes = {}
    }
    for i = 1, 9 do raw.lanes[i] = true end
    cfg = mkcfg(raw)

    local jms = {
        Perfect = 0,
        Sick = 35,
        Good = 68,
        Bad = 112,
        Random = 0
    }

    local tabgui, tabconn

    local tabflag
    do
        local ups = getupvalues(gm.initHud)
        for i,v in pairs(ups) do
            local a, b = ups[i + 1], ups[i + 2]
            if type(v) == "boolean" and typeof(a) == "Instance" and typeof(b) == "Instance" then
                if a.Name == "Pregame" and b.Name == "TabIn" then tabflag = i end
            end
        end
    end

    local function killtab()
        if tabflag then
            pcall(setupvalue, gm.initHud, tabflag, false)
        end
        local s = svc.snd:FindFirstChild("TabIn")
        if s and s.IsPlaying then s:Stop() end
        pcall(function() lmod:HideScreen("TabInBozo") end)
        if tabgui and tabgui.Enabled then tabgui.Enabled = false end
    end

    local function hooktab(g)
        if not (g and g:IsA("ScreenGui")) then return end
        tabgui = g
        if tabconn then tabconn:Disconnect() end
        tabconn = g:GetPropertyChangedSignal("Enabled"):Connect(function()
            if g.Enabled and cfg.notab then g.Enabled = false end
        end)
        if g.Enabled then g.Enabled = false end
    end

    local hold = {}
    local seen = 0
    local lastNow = 0

    local function press(i, down)
        local s = side()
        if not s then return end
        pcall(function()
            if pm:GetGamemode() == "Guitar" then
                pm:Trigger(sidx, i, down)
                if down then pm:Trigger(sidx, 0, true) end
            else
                pm:Trigger(sidx, i, down)
            end
        end)
    end

    letgo = function()
        for i,v in pairs(hold) do
            hold[i] = nil
            press(i, false)
        end
    end

    local function aim()
        local t = cfg.target
        if t == "Random" then
            local l = { "Perfect", "Sick", "Good" }
            t = l[math.random(1, #l)]
        end

        local e = jms[t] or 0
        if cfg.bias == "Early" then
            e = -e
        elseif cfg.bias == "Both" and math.random() < 0.5 then
            e = -e
        end

        if cfg.jitter > 0 then
            e = e + (math.random() - 0.5) * 2 * cfg.jitter
        end

        return math.clamp(e, -170, 170)
    end

    local function skippable(n)
        local ok, t = pcall(function() return util:GetMintType(n) end)
        if not ok then return false end
        if t >= 2 and cfg.skiphurt then return true end
        if t == 0 and not cfg.hitspecial then return true end
        return false
    end

    conns[1] = svc.run.Heartbeat:Connect(function(dt)
        if not cfg.on then return end
        if not gm:IsActive() then return end
        if not gm:GetPlayerStrum() then return end

        local s = side()
        if not (s and s.Strums) or s.BlockPlay then return end

        local now = gm:GetSongTime()
        local half = dt * 500

        if now < lastNow - 500 then
            for i,v in pairs(hold) do hold[i] = nil end
        end
        lastNow = now

        for i,v in ipairs(s.Strums) do
            local h = hold[i]
            if h then
                if now >= h then
                    hold[i] = nil
                    press(i, false)
                end
            elseif cfg.lanes[i] ~= false then
                local n
                for i1 = 1, 4 do
                    local c = v.Notes and v.Notes[i1]
                    if not c then break end
                    if not (c.apdone or c.apskip or c.removed) then n = c break end
                end

                if n then
                    local d = now - n.t

                    if n.apskip == nil then
                        seen = seen + 1
                        n.apskip = skippable(n) or d > 90

                        if not n.apskip then
                            if cfg.misschance > 0 and math.random(1, 100) <= cfg.misschance then
                                n.apskip = true
                            elseif cfg.breakevery > 0 and seen % cfg.breakevery == 0 then
                                n.apskip = true
                            end
                        end

                        n.apaim = aim() + cfg.offms
                    end

                    if not n.apskip then
                        local want = n.apaim - cfg.lead - half
                        local late = cfg.catchup and d > 0 and d <= 170

                        if d >= want or late then
                            n.apdone = true
                            press(i, true)

                            if cfg.hold and n.len and n.len > 0 then
                                hold[i] = n.t + n.len + cfg.liftms
                            else
                                local l = i
                                task.delay(cfg.tapms / 1000, function() press(l, false) end)
                            end
                        end
                    end
                end
            end
        end

        if cfg.hplock and s.Score then
            s.Score.Health = cfg.hp
        end
    end)

    local orig = rawget(util, "_ap_orig")
    if not orig then
        orig = {
            ScoreMiss = util.ScoreMiss,
            AddMiss = util.AddMiss,
            ScoreStumble = util.ScoreStumble,
            CheckForDeath = util.CheckForDeath
        }
        util._ap_orig = orig
    end

    util.ScoreMiss = function(self, sc, t)
        if cfg.blockmiss then return end
        return orig.ScoreMiss(self, sc, t)
    end
    util.AddMiss = function(self, sc)
        if cfg.blockmiss then return end
        return orig.AddMiss(self, sc)
    end
    util.ScoreStumble = function(self, sc, t)
        if cfg.nostumble then return end
        return orig.ScoreStumble(self, sc, t)
    end
    util.CheckForDeath = function(self, sc, a)
        if cfg.nofail then
            local t = a or sc
            if type(t) == "table" then
                t.Failed = false
                if t.Health and t.Health <= 0.1 then t.Health = 0.5 end
            end
            return false
        end
        return orig.CheckForDeath(self, sc, a)
    end

    shut[#shut + 1] = function()
        util.ScoreMiss = orig.ScoreMiss
        util.AddMiss = orig.AddMiss
        util.ScoreStumble = orig.ScoreStumble
        util.CheckForDeath = orig.CheckForDeath
        if tabconn then tabconn:Disconnect() end
    end

    w = kyri.new("rat autoplay", {
        GameName = "RapAbilityTest",
        AutoLoad = "default",
        Mode = "island",
        Splash = false,
        Theme = {
            accent = Color3.fromRGB(255, 190, 90)
        }
    })
    if not w then return end

    local main = w:tab("Main", "zap")
    local tm = w:tab("Timing", "timer")
    local prot = w:tab("Protect", "shield")
    local hum = w:tab("Human", "user")
    local lane = w:tab("Lanes", "columns-3")
    local info = w:tab("Stats", "bar-chart-2")

    do
        main:section("autoplay")
        tog = main:toggle("enabled", false, function(s)
            cfg.on = s
            if not s then letgo() end
        end, "rat_on")

        kb = main:keybind("toggle key", cfg.tkey, false, function() end, "rat_key")

        main:label("press backtick to hide this panel")

        main:section("feel")
        main:slider("hit early by (ms)", 0, 60, cfg.lead, function(v) cfg.lead = v end, "rat_lead", 1)
        main:slider("offset (ms)", -80, 80, cfg.offms, function(v) cfg.offms = v end, "rat_off", 1)
        main:slider("how long to hold a tap (ms)", 10, 150, cfg.tapms, function(v) cfg.tapms = v end, "rat_tap", 5)
    end

    do
        tm:section("judgement")
        tm:dropdown("aim for", { "Perfect", "Sick", "Good", "Bad", "Random" }, cfg.target, function(v)
            cfg.target = v
        end, "rat_target")
        tm:dropdown("hit side", { "Early", "Late", "Both" }, cfg.bias, function(v)
            cfg.bias = v
        end, "rat_bias")
        tm:slider("timing jitter (ms)", 0, 80, cfg.jitter, function(v) cfg.jitter = v end, "rat_jit", 1)

        tm:section("sustains")
        tm:toggle("hold tails", cfg.hold, function(s) cfg.hold = s end, "rat_hold")
        tm:slider("release long notes early or late (ms)", -100, 100, cfg.liftms, function(v) cfg.liftms = v end, "rat_lift", 5)

        tm:paragraph("how close you need to be", "perfect is within 25ms of the note, then sick 45, good 90, bad 135 and trash 180. anything later than that is a miss.")
    end

    do
        prot:section("notes")
        prot:toggle("skip hurt notes", cfg.skiphurt, function(s) cfg.skiphurt = s end, "rat_hurt")
        prot:toggle("hit special notes", cfg.hitspecial, function(s) cfg.hitspecial = s end, "rat_spec")
        prot:toggle("catch late notes", cfg.catchup, function(s) cfg.catchup = s end, "rat_catch")
        prot:paragraph("about hurt notes", "hurt notes damage you when you hit them. the milder ones take a slice of your health and the worse ones can knock you out of the song completely. ignoring them is always the right play, so leave skip on unless you have a reason not to.")

        prot:section("annoyances")
        prot:toggle("no tab-out screen", cfg.notab, function(s)
            cfg.notab = s
            if s then
                hooktab(lp.PlayerGui:FindFirstChild("TabbedOut"))
                killtab()
            end
        end, "rat_notab")
        prot:paragraph("what this does", "this game nags you twice for looking away. during a song it holds the loading for ten seconds behind a tab back in screen, and outside a song a picture pops up any time the window loses focus. with this on you get neither, no screen, no sound and no waiting around.")
        prot:toggle("anti idle", cfg.antiidle, function(s) cfg.antiidle = s end, "rat_idle")
        prot:paragraph("staying connected", "hitting notes this way does not count as touching your keyboard, so roblox still disconnects you for being away after about twenty minutes. this nudges the game quietly so you stay in, and it works with roblox in the background.")

        prot:section("scoring")
        prot:toggle("block misses", cfg.blockmiss, function(s) cfg.blockmiss = s end, "rat_bmiss")
        prot:toggle("block stumbles", cfg.nostumble, function(s) cfg.nostumble = s end, "rat_bstum")
        prot:toggle("hide fail (your screen only)", cfg.nofail, function(s) cfg.nofail = s end, "rat_nofail")
        prot:toggle("lock health (your screen only)", cfg.hplock, function(s) cfg.hplock = s end, "rat_hplock")
        prot:slider("health at", 0, 2, cfg.hp, function(v) cfg.hp = v end, "rat_hp", 0.1)
        prot:paragraph("read this first", "these four only change what you see on your own screen. the server works your health and your fail out from the notes you actually hit, so it can still fail you and fling you no matter how these are set. all they do is hide the fail sound, the animation, the popup and the FAIL rating. hitting the notes is the only thing that really stops a fail.")
    end

    do
        hum:section("mistakes")
        hum:slider("miss chance (%)", 0, 25, cfg.misschance, function(v) cfg.misschance = v end, "rat_miss", 1)
        hum:slider("drop every n notes (0 = never)", 0, 200, cfg.breakevery, function(v) cfg.breakevery = v end, "rat_break", 1)
        hum:paragraph("tip", "aim for sick with jitter around 30 and a couple of percent misses. a solid wall of perfects is the obvious giveaway.")
    end

    do
        lane:section("lanes")
        for i = 1, 9 do
            local n = i
            lane:toggle("lane "..i, true, function(s) cfg.lanes[n] = s end, "rat_lane_"..i)
        end
        lane:label("lanes past 4 only matter on songs that use them")
    end

    local l1, l2, l3, l4, l5, lj, bar
    do
        info:section("live")
        l1 = info:label("score 0")
        l2 = info:label("accuracy 0%")
        l3 = info:label("combo 0")
        l4 = info:label("misses 0")
        l5 = info:label("health 0")
        bar = info:progressbar("accuracy", 100)
        lj = info:paragraph("judgements", "perfect 0  sick 0  good 0  bad 0")

        info:section("panel")
        info:button("reset position", function()
            pcall(function() w:resetpos() end)
        end)
        info:button("unload", function()
            teardown()
        end)
    end

    if cfg.notab then hooktab(lp.PlayerGui:FindFirstChild("TabbedOut")) end

    conns[#conns + 1] = lp.PlayerGui.ChildAdded:Connect(function(c)
        if c.Name == "TabbedOut" then
            task.wait()
            hooktab(c)
        end
    end)

    task.spawn(function()
        while alive do
            if cfg.notab then killtab() end
            task.wait(0.25)
        end
    end)

    local tick = 0
    conns[#conns + 1] = svc.run.Heartbeat:Connect(function(dt)
        tick = tick + dt
        if tick < 0.1 then return end
        tick = 0

        local s = side()
        local sc = s and s.Score
        if not sc then return end

        pcall(function()
            l1:set("score "..tostring(sc.Score or 0))
            l2:set(("accuracy %.2f%%"):format(sc.Accuracy or 0))
            l3:set(("combo %d  best %d"):format(sc.Combo or 0, sc.BestCombo or 0))
            l4:set(("misses %d  stumbles %d"):format(sc.TotalMisses or sc.Misses or 0, sc.Stumbles or 0))
            l5:set(("health %.2f%s"):format(sc.Health or 0, sc.Failed and "  FAILED" or ""))
            bar:set(math.clamp(sc.Accuracy or 0, 0, 100))
            lj:set(("perfect %d  sick %d  good %d  bad %d  trash %d  mines %d"):format(sc.Perfects or 0, sc.Sicks or 0, sc.Goods or 0, sc.Bads or 0, sc.Trashes or 0, sc.Mines or 0))
        end)

        if w.isl then
            pcall(function()
                w.isl:set({ subtitle = cfg.on and ("on  %.1f%%"):format(sc.Accuracy or 0) or "off" })
            end)
        end
    end)
end

conns[#conns + 1] = svc.uis.InputBegan:Connect(function(k)
    if svc.uis:GetFocusedTextBox() then return end
    if k.KeyCode == hotkey() then
        setOn(not cfg.on)
    end
end)

conns[#conns + 1] = lp.Idled:Connect(function()
    if not cfg.antiidle then return end
    pcall(function()
        svc.vu:CaptureController()
        svc.vu:ClickButton2(Vector2.new())
    end)
end)

teardown = function()
    if not alive then return end
    alive = false
    cfg.on = false
    if letgo then letgo() end

    for i,v in pairs(conns) do pcall(function() v:Disconnect() end) end
    for i,v in pairs(shut) do pcall(v) end

    pcall(function() w:destroy() end)
    pcall(function() reg:Destroy() end)
end

kill.Event:Connect(teardown)
reg.AncestryChanged:Connect(function()
    if not reg:IsDescendantOf(game) then teardown() end
end)
