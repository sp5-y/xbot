--[[ banish.lua ]]--
-- .s <name>   spectate
-- .b [name]   void (same hit as .f, down)
-- .f [name]   air-fling
local env = _G
pcall(function()
    if type(getgenv) == "function" and type(getgenv()) == "table" then
        env = getgenv()
    end
end)
if env.__banish_unload then
    pcall(env.__banish_unload)
end

local Players = game:GetService("Players")
local RunSvc = game:GetService("RunService")
local TCS = game:GetService("TextChatService")
local me = Players.LocalPlayer
local cam = workspace.CurrentCamera
local busy, specPl, running = false, nil, true
local lastCmdAt, lastCmdKey = 0, ""
local conns = {}

local function track(c)
    if c then
        conns[#conns + 1] = c
    end
    return c
end

local function say(t)
    print("[banish] " .. tostring(t))
end

local function hrpOf(p)
    local c = p and p.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

local function alive(p)
    local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function myHrp()
    return hrpOf(me)
end

local function findPl(q)
    if not q or q == "" then return end
    q = q:lower()
    local exactN, exactD, best, bestScore
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me then
            local nl, dl = p.Name:lower(), tostring(p.DisplayName or ""):lower()
            if nl == q then exactN = p end
            if dl == q then exactD = p end
            local i = nl:find(q, 1, true) or dl:find(q, 1, true)
            if i then
                local score = i + math.abs(#nl - #q)
                if not bestScore or score < bestScore then best, bestScore = p, score end
            end
        end
    end
    return exactN or exactD or best
end

local function fromCam()
    cam = workspace.CurrentCamera or cam
    local sub = cam and cam.CameraSubject
    if typeof(sub) ~= "Instance" then return end
    local inst = sub
    pcall(function()
        if inst:IsA("Humanoid") or inst:IsA("BasePart") then
            inst = inst.Parent
        end
    end)
    if typeof(inst) ~= "Instance" then return end
    local p
    pcall(function()
        p = Players:GetPlayerFromCharacter(inst)
    end)
    if p and p ~= me then return p end
end

local function currentTarget()
    if specPl and specPl.Parent and specPl ~= me then return specPl end
    return fromCam()
end

local function spectate(p, silent)
    if not p or p == me then return false end
    specPl = p
    cam = workspace.CurrentCamera or cam
    local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    pcall(function()
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum or hrpOf(p)
        end
    end)
    if not silent then say("spectating " .. p.Name) end
    return true
end

local function camOnMe()
    pcall(function()
        cam = workspace.CurrentCamera or cam
        local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        if cam and hum then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum
        end
    end)
end

local function dropMovers()
    pcall(function()
        local char = me.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BodyAngularVelocity") or d:IsA("BodyVelocity") or d:IsA("BodyPosition") then
                d:Destroy()
            end
        end
    end)
end

local function cleanup(home)
    dropMovers()
    pcall(function()
        local mh = myHrp()
        if mh then
            mh.Anchored = false
            mh.AssemblyLinearVelocity = Vector3.zero
            mh.AssemblyAngularVelocity = Vector3.zero
            mh.Velocity = Vector3.zero
            mh.RotVelocity = Vector3.zero
            if home then mh.CFrame = home end
        end
        local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
        end
    end)
    pcall(function()
        _G.MM_FlingBusy = false
        _G.MM_StandPaused = false
        if _G.MM_ActionEnd then _G.MM_ActionEnd() end
    end)
    busy = false
end

local function unload()
    running = false
    busy = false
    for i = 1, #conns do
        pcall(function()
            conns[i]:Disconnect()
        end)
        conns[i] = nil
    end
    dropMovers()
    pcall(function()
        local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
        end
    end)
    if env.__banish_unload == unload then
        env.__banish_unload = nil
    end
    print("[banish] unloaded")
end
env.__banish_unload = unload

-- Sit on them. No spin, no slam — those fling US into the sky.
local function hit(target, label)
    if busy then return end
    if not target or target == me then
        say("no target — spectate someone or .s <name>")
        return
    end
    if not alive(target) then
        say("target dead")
        return
    end
    if not alive(me) or not myHrp() then
        say("you are dead")
        return
    end
    busy = true
    pcall(function()
        if _G.MM_PauseStand then _G.MM_PauseStand() end
        _G.MM_StandPaused = true
        _G.MM_FlingBusy = true
        _G.MM_FollowGen = (tonumber(_G.MM_FollowGen) or 0) + 1
        _G.MM_StandLoopAlive = false
        if _G.MM_DisableAntiFling then _G.MM_DisableAntiFling() end
        if _G.MM_ActionBegin then _G.MM_ActionBegin() end
    end)
    say(label .. " " .. target.Name)
    task.spawn(function()
        local home = myHrp() and myHrp().CFrame
        dropMovers()
        camOnMe()
        pcall(function()
            local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = true
                hum.AutoRotate = false
            end
        end)
        local guard = track(RunSvc.Stepped:Connect(function()
            pcall(function()
                if not running then return end
                camOnMe()
                dropMovers()
                local mh = myHrp()
                local th = hrpOf(target)
                local char = me.Character
                if not (mh and th and char) then return end
                local at = th.CFrame * CFrame.new(0, 2, 0)
                mh.AssemblyLinearVelocity = Vector3.zero
                mh.AssemblyAngularVelocity = Vector3.zero
                mh.Velocity = Vector3.zero
                mh.RotVelocity = Vector3.zero
                mh.Anchored = true
                pcall(function()
                    char:PivotTo(at)
                end)
                mh.CFrame = at
            end)
        end))
        local t0 = tick()
        while running and tick() - t0 < 6 and alive(me) do
            local th = hrpOf(target)
            if not (th and target.Parent and alive(target)) then break end
            RunSvc.Heartbeat:Wait()
        end
        local mh, th = myHrp(), hrpOf(target)
        local dist = (mh and th) and (mh.Position - th.Position).Magnitude or -1
        say(string.format("lock dist=%.1f myY=%.0f tgtY=%.0f", dist, mh and mh.Position.Y or 0, th and th.Position.Y or 0))
        if guard then pcall(function() guard:Disconnect() end) end
        if not running then return end
        cleanup(home)
        camOnMe()
    end)
end

local function onChat(msg)
    if not running then return end
    msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%.%S+)%s*(.*)$")
    if not cmd then return end
    cmd = cmd:lower()
    rest = (rest or ""):match("^%s*(.-)%s*$") or ""
    local key = cmd .. "\0" .. rest
    local now = tick()
    if key == lastCmdKey and now - lastCmdAt < 0.45 then return end
    lastCmdKey, lastCmdAt = key, now
    if cmd == ".s" or cmd == ".spec" then
        if not spectate(findPl(rest) or currentTarget()) then say("no player") end
        return
    end
    if cmd == ".b" or cmd == ".banish" then
        hit(rest ~= "" and findPl(rest) or currentTarget(), "banish")
        return
    end
    if cmd == ".f" or cmd == ".fling" then
        hit(rest ~= "" and findPl(rest) or currentTarget(), "air-fling")
    end
end

pcall(function()
    track(me.Chatted:Connect(onChat))
end)
pcall(function()
    track(TCS.MessageReceived:Connect(function(m)
        if not running or not m then return end
        local src = m.TextSource
        if src and src.UserId == me.UserId then
            onChat(m.Text)
        end
    end))
end)

task.spawn(function()
    while running do
        task.wait(0.25)
        if not running then break end
        local ok, p = pcall(fromCam)
        if ok and p then specPl = p end
    end
end)

say("ready — .s name, .b void, .f air")
