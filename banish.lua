--[[ banish.lua ]]--
-- panel buttons or .s / .b / .f
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
local CoreGui = game:GetService("CoreGui")
local me = Players.LocalPlayer
local cam = workspace.CurrentCamera
local busy, specPl, running = false, nil, true
local lastCmdAt, lastCmdKey = 0, ""
local conns = {}
local statusLbl, targetLbl, nameBox

local function track(c)
    if c then
        conns[#conns + 1] = c
    end
    return c
end

local function say(t)
    t = tostring(t)
    print("[banish] " .. t)
    if statusLbl then
        statusLbl.Text = t
    end
end

local function setTargetLabel()
    if not targetLbl then return end
    if specPl and specPl.Parent then
        targetLbl.Text = "Target: " .. specPl.Name
    else
        targetLbl.Text = "Target: none"
    end
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
    setTargetLabel()
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
            if d:IsA("BodyAngularVelocity") or d:IsA("BodyVelocity") or d:IsA("BodyPosition")
                or d:IsA("BodyThrust") or d:IsA("BodyForce") then
                d:Destroy()
            end
        end
    end)
end

local function cleanup(home)
    dropMovers()
    pcall(function()
        local char = me.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = true
                    p.Massless = false
                    pcall(function()
                        p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
                    end)
                end
            end
        end
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
        env.MM_FlingBusy = false
        env.MM_StandPaused = false
        if env.MM_ActionEnd then env.MM_ActionEnd() end
    end)
    busy = false
end

local gui
local function uiParent()
    local ok, h
    if type(gethui) == "function" then
        ok, h = pcall(gethui)
        if ok and typeof(h) == "Instance" then return h end
    end
    if type(get_hidden_ui) == "function" then
        ok, h = pcall(get_hidden_ui)
        if ok and typeof(h) == "Instance" then return h end
    end
    local pg = me:FindFirstChildOfClass("PlayerGui")
    if not pg then
        pcall(function()
            pg = me:WaitForChild("PlayerGui", 3)
        end)
    end
    if pg then return pg end
    return CoreGui
end

local function parentGui(g)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(g)
        end
    end)
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        g.DisplayOrder = 100000
    end)
    g.Enabled = true
    g.Parent = uiParent()
    if not g.Parent then
        g.Parent = CoreGui
    end
    print("[banish] panel parent=" .. tostring(g.Parent))
end

local function killGui()
    pcall(function()
        if gui then gui:Destroy() end
        for _, name in ipairs({"BanishPanel", "BanishLoader"}) do
            local old = CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
            local pg = me:FindFirstChildOfClass("PlayerGui")
            if pg then
                old = pg:FindFirstChild(name)
                if old then old:Destroy() end
            end
            if type(gethui) == "function" then
                local ok, h = pcall(gethui)
                if ok and h then
                    old = h:FindFirstChild(name)
                    if old then old:Destroy() end
                end
            end
        end
    end)
    gui, statusLbl, targetLbl, nameBox = nil, nil, nil, nil
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
    killGui()
    if env.__banish_unload == unload then
        env.__banish_unload = nil
    end
    print("[banish] unloaded")
end
env.__banish_unload = unload

local function hit(target, label)
    if busy then
        say("busy")
        return
    end
    if not target or target == me then
        say("no target — type a name or spectate")
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
    specPl = target
    setTargetLabel()
    local oldNoclip = env.MM_StandNoclip
    pcall(function()
        if env.MM_PauseStand then env.MM_PauseStand() end
        env.MM_StandPaused = true
        env.MM_FlingBusy = true
        env.MM_FollowGen = (tonumber(env.MM_FollowGen) or 0) + 1
        env.MM_StandLoopAlive = false
        env.MM_StandNoclip = function() end
        if env.MM_DisableAntiFling then env.MM_DisableAntiFling() end
        if env.MM_ActionBegin then env.MM_ActionBegin() end
    end)
    say(label .. " " .. target.Name)
    task.spawn(function()
        local home = myHrp() and myHrp().CFrame
        local killY = -500
        pcall(function()
            local h = workspace.FallenPartsDestroyHeight
            if typeof(h) == "number" and h == h then killY = h end
        end)
        -- Air: FE sideways thrust + spin (they go up).
        -- Banish: no spin/thrust. Stay on their XZ, never ride Y up, stomp down.
        dropMovers()
        camOnMe()
        local heavy = PhysicalProperties.new(100, 0.3, 0.5)
        local down = label == "banish"
        local thrust, bav, sink, clip, hold, draw
        pcall(function()
            local mh = myHrp()
            local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = true
                hum.AutoRotate = false
            end
            if not mh then return end
            mh.Anchored = false
            if down then
                sink = Instance.new("BodyVelocity")
                sink.MaxForce = Vector3.new(0, 1e9, 0)
                sink.P = 1e5
                sink.Velocity = Vector3.new(0, -900, 0)
                sink.Parent = mh
            else
                thrust = Instance.new("BodyThrust")
                thrust.Force = Vector3.new(500, 0, 500)
                thrust.Location = mh.Position
                thrust.Parent = mh
                bav = Instance.new("BodyAngularVelocity")
                bav.MaxTorque = Vector3.new(0, math.huge, 0)
                bav.P = math.huge
                bav.AngularVelocity = Vector3.new(0, 99999, 0)
                bav.Parent = mh
            end
        end)
        local startY = 0
        pcall(function()
            local th0 = hrpOf(target)
            startY = th0 and th0.Position.Y or 0
        end)
        local ceilY = startY
        local function stick()
            if not running then return end
            local char = me.Character
            local mh = myHrp()
            local th = hrpOf(target)
            if not (char and mh and th) then return end
            local pos = th.Position
            local yVel = 0
            if down then
                if th.Position.Y < ceilY then
                    ceilY = th.Position.Y
                end
                pos = Vector3.new(th.Position.X, math.min(th.Position.Y, ceilY), th.Position.Z)
                yVel = -900
            end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    local core = p.Name == "HumanoidRootPart" or p.Name == "Torso" or p.Name == "UpperTorso"
                    p.CanCollide = down and core
                    p.Massless = false
                    pcall(function()
                        p.CustomPhysicalProperties = heavy
                    end)
                end
            end
            mh.Anchored = false
            mh.CFrame = CFrame.new(pos) * (mh.CFrame - mh.CFrame.Position)
            local v = Vector3.new(0, yVel, 0)
            mh.AssemblyLinearVelocity = v
            mh.Velocity = v
            if sink and sink.Parent then
                sink.Velocity = v
            end
            if thrust and thrust.Parent then
                thrust.Force = Vector3.new(500, 0, 500)
                thrust.Location = mh.Position
            end
        end
        clip = track(RunSvc.Stepped:Connect(function()
            pcall(stick)
        end))
        hold = track(RunSvc.Heartbeat:Connect(function()
            pcall(stick)
        end))
        draw = track(RunSvc.RenderStepped:Connect(function()
            pcall(stick)
        end))
        local t0 = tick()
        local maxT = down and 8 or 5
        local logged = false
        while running and tick() - t0 < maxT and alive(me) do
            if not target.Parent or not alive(target) then break end
            local th = hrpOf(target)
            local mh = myHrp()
            if not th then break end
            if not logged and mh then
                logged = true
                say(string.format("touch %s myY=%.0f tgtY=%.0f", target.Name, mh.Position.Y, th.Position.Y))
            end
            if bav then
                bav.AngularVelocity = Vector3.new(0, 99999, 0)
            end
            if down and (th.Position.Y <= killY + 80 or th.Position.Y < 40) then break end
            if not down and (th.Position.Y > startY + 2 or th.AssemblyLinearVelocity.Magnitude > 45) then
                if tick() - t0 > 2.2 then break end
            end
            task.wait(0.2)
            if bav then bav.AngularVelocity = Vector3.zero end
            task.wait(0.1)
        end
        local thf = hrpOf(target)
        local y = thf and math.floor(thf.Position.Y + 0.5) or 0
        local win
        if label == "banish" then
            win = (not alive(target)) or (thf and (thf.Position.Y <= killY + 80 or thf.Position.Y < 40)) or not target.Parent
            say((win and "voided " or "miss ") .. target.Name .. " y=" .. tostring(y))
        else
            win = thf and thf.Position.Y > startY + 2
            say((win and "flung " or "miss ") .. target.Name .. " y=" .. tostring(y))
        end
        if thrust then pcall(function() thrust:Destroy() end) end
        if bav then pcall(function() bav:Destroy() end) end
        if sink then pcall(function() sink:Destroy() end) end
        if clip then pcall(function() clip:Disconnect() end) end
        if hold then pcall(function() hold:Disconnect() end) end
        if draw then pcall(function() draw:Disconnect() end) end
        pcall(function()
            env.MM_StandNoclip = oldNoclip
        end)
        if not running then return end
        cleanup(home)
        spectate(target, true)
    end)
end

local function typedTarget()
    local q = nameBox and nameBox.Text or ""
    q = (q:match("^%s*(.-)%s*$") or "")
    if q ~= "" then return findPl(q) end
    return currentTarget()
end

local function mkBtn(parent, text, x, color, fn)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 88, 0, 28)
    b.Position = UDim2.new(0, x, 1, -36)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Text = text
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(fn)
    return b
end

local function makePanel()
    killGui()
    gui = Instance.new("ScreenGui")
    gui.Name = "BanishPanel"
    parentGui(gui)
    local box = Instance.new("Frame", gui)
    box.Size = UDim2.new(0, 420, 0, 168)
    box.Position = UDim2.new(0.5, -210, 0, 80)
    box.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    local title = Instance.new("TextLabel", box)
    title.Size = UDim2.new(1, -20, 0, 22)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(180, 125, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Banish"
    targetLbl = Instance.new("TextLabel", box)
    targetLbl.Size = UDim2.new(1, -20, 0, 16)
    targetLbl.Position = UDim2.new(0, 10, 0, 30)
    targetLbl.BackgroundTransparency = 1
    targetLbl.Font = Enum.Font.Gotham
    targetLbl.TextSize = 12
    targetLbl.TextColor3 = Color3.fromRGB(180, 180, 195)
    targetLbl.TextXAlignment = Enum.TextXAlignment.Left
    targetLbl.Text = "Target: none"
    statusLbl = Instance.new("TextLabel", box)
    statusLbl.Size = UDim2.new(1, -20, 0, 36)
    statusLbl.Position = UDim2.new(0, 10, 0, 48)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 13
    statusLbl.TextWrapped = true
    statusLbl.TextColor3 = Color3.fromRGB(235, 235, 245)
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextYAlignment = Enum.TextYAlignment.Top
    statusLbl.Text = "Ready"
    nameBox = Instance.new("TextBox", box)
    nameBox.Size = UDim2.new(1, -20, 0, 28)
    nameBox.Position = UDim2.new(0, 10, 0, 88)
    nameBox.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    nameBox.BorderSizePixel = 0
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 13
    nameBox.TextColor3 = Color3.fromRGB(235, 235, 245)
    nameBox.PlaceholderText = "player name"
    nameBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)
    nameBox.Text = ""
    nameBox.ClearTextOnFocus = false
    Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)
    mkBtn(box, "Spectate", 10, Color3.fromRGB(70, 70, 90), function()
        if not spectate(typedTarget()) then say("no player") end
    end)
    mkBtn(box, "Banish", 108, Color3.fromRGB(140, 60, 200), function()
        hit(typedTarget(), "banish")
    end)
    mkBtn(box, "Fling", 206, Color3.fromRGB(50, 110, 190), function()
        hit(typedTarget(), "air-fling")
    end)
    mkBtn(box, "Close", 322, Color3.fromRGB(70, 50, 50), function()
        unload()
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
        if ok and p then
            specPl = p
            setTargetLabel()
        end
    end
end)

makePanel()
say("ready — use the panel or .s / .b / .f")
