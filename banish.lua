--[[ banish.lua — local test ]]--
-- .s <name>  spectate
-- .b         drag into void (ride them down until dead)
-- .f         air-fling
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
local busy = false
local specPl = nil
local lastCmdAt, lastCmdKey = 0, ""
local running = true
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
    local r = hrpOf(p)
    pcall(function()
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum or r
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

local savedFPDH
local function protectVoid(on)
    pcall(function()
        if on then
            if type(savedFPDH) ~= "number" then
                savedFPDH = workspace.FallenPartsDestroyHeight
            end
            workspace.FallenPartsDestroyHeight = -1e6
        elseif type(savedFPDH) == "number" then
            workspace.FallenPartsDestroyHeight = savedFPDH
        end
    end)
end

local function snapHome(home)
    local mh = myHrp()
    if not mh then return end
    pcall(function()
        mh.Anchored = false
        mh.AssemblyLinearVelocity = Vector3.zero
        mh.AssemblyAngularVelocity = Vector3.zero
        mh.Velocity = Vector3.zero
        mh.RotVelocity = Vector3.zero
        if home then mh.CFrame = home end
    end)
end

local function cleanup(home)
    pcall(function()
        snapHome(home)
        local char = me.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = true
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
                p.Velocity = Vector3.zero
                p.RotVelocity = Vector3.zero
            end
        end
        snapHome(home)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end
        local anim = char:FindFirstChild("Animate")
        if anim then anim.Disabled = false end
    end)
    dropMovers()
    protectVoid(false)
    if _G.MM_ActionEnd then pcall(_G.MM_ActionEnd) end
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
        local char = me.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
        local anim = char:FindFirstChild("Animate")
        if anim then anim.Disabled = false end
    end)
    protectVoid(false)
    if env.__banish_unload == unload then
        env.__banish_unload = nil
    end
    print("[banish] unloaded")
end
env.__banish_unload = unload

local function feetY(root, hum)
    if not root then return 0 end
    local hip = 2
    pcall(function()
        if hum and hum.RigType == Enum.HumanoidRigType.R6 then
            hip = 3 - root.Size.Y / 2
        elseif hum then
            hip = hum.HipHeight
        end
    end)
    return root.Position.Y - hip - root.Size.Y / 2
end

local function collideAll()
    local char = me.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = true
            p.CanTouch = true
            p.Massless = false
            pcall(function() p.CollisionGroup = "Default" end)
        end
    end
end

-- Stay glued to their CFrame. Velocity is only a hit; we never ride it
-- into the void (that resets us, not them).
local function banish(target)
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
    if _G.MM_DisableAntiFling then pcall(_G.MM_DisableAntiFling) end
    if _G.MM_ActionBegin then pcall(_G.MM_ActionBegin) end
    say("banish " .. target.Name)
    task.spawn(function()
        local home = myHrp() and myHrp().CFrame
        local killY = -500
        pcall(function()
            local h = workspace.FallenPartsDestroyHeight
            if typeof(h) == "number" and h == h then killY = h end
        end)
        protectVoid(true)
        camOnMe()
        local spin = Vector3.new(9e4, 9e4, 9e4)
        local up = Vector3.new(0, 4200, 0)
        local bav, guard, hold
        local abort = false
        local ok, err = pcall(function()
            local th0
            for _ = 1, 12 do
                th0 = hrpOf(target)
                if th0 then break end
                RunSvc.Heartbeat:Wait()
            end
            if not th0 then
                say("no hrp")
                return
            end
            local startY = th0.Position.Y
            local hum0 = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
            if hum0 then
                pcall(function()
                    hum0.PlatformStand = true
                    hum0.AutoRotate = false
                    hum0.BreakJointsOnDeath = false
                    hum0:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    hum0:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    hum0:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                end)
            end
            pcall(function()
                local mh = myHrp()
                if not mh then return end
                bav = Instance.new("BodyAngularVelocity")
                bav.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
                bav.P = 1e9
                bav.AngularVelocity = Vector3.new(0, 9e4, 9e4)
                bav.Parent = mh
            end)
            local phase = "pop"
            local t0 = tick()
            local function loose(th, thum)
                if not th then return false end
                if th.Position.Y > startY + 1.1 then return true end
                if th.Position.Y < startY - 3 then return true end
                local tv = th.AssemblyLinearVelocity
                if tv.Magnitude < 1 then tv = th.Velocity end
                if tv.Y > 18 or tv.Y < -22 then return true end
                if thum then
                    if thum.FloorMaterial == Enum.Material.Air then return true end
                    local st = thum:GetState()
                    if st == Enum.HumanoidStateType.Freefall
                        or st == Enum.HumanoidStateType.Flying
                        or st == Enum.HumanoidStateType.Physics
                        or st == Enum.HumanoidStateType.FallingDown
                        or st == Enum.HumanoidStateType.Ragdoll then
                        return true
                    end
                end
                return false
            end
            local function stick(th)
                local mh = myHrp()
                if not (mh and th) then return mh end
                mh.Anchored = false
                mh.CFrame = th.CFrame
                return mh
            end
            local function punch(lin)
                local char = me.Character
                if not char then return end
                for _, n in ipairs({"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}) do
                    local p = char:FindFirstChild(n)
                    if p and p:IsA("BasePart") then
                        p.CanCollide = true
                        p.Anchored = false
                        p.Massless = false
                        p.AssemblyLinearVelocity = lin
                        p.Velocity = lin
                        p.AssemblyAngularVelocity = spin
                        p.RotVelocity = spin
                    end
                end
            end
            local function unsafe(mh, th)
                if not mh then return true end
                if mh.Position.Y < 80 then return true end
                if th and (mh.Position - th.Position).Magnitude > 40 then return true end
                return false
            end
            guard = track(RunSvc.Stepped:Connect(function(_, dt)
                pcall(function()
                    if not running or abort then return end
                    dt = math.clamp(tonumber(dt) or 0.016, 0.008, 0.05)
                    local th = hrpOf(target)
                    local mh = stick(th)
                    if not (mh and th) then return end
                    if unsafe(mh, th) then
                        stick(th)
                        if unsafe(mh, th) then
                            abort = true
                            snapHome(home)
                            say("aborted — kept us, not the void")
                        end
                        return
                    end
                    local thum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                    if phase == "pop" and loose(th, thum) then
                        phase = "sink"
                        say(string.format("sink t=%.2f tgtY=%.0f", tick() - t0, th.Position.Y))
                    elseif phase == "sink" then
                        local tv = th.AssemblyLinearVelocity
                        if tv.Magnitude < 1 then tv = th.Velocity end
                        local glued = th.Position.Y > startY - 1.2 and math.abs(tv.Y) < 8
                        if thum and thum.FloorMaterial == Enum.Material.Air then
                            glued = false
                        end
                        if glued and not loose(th, thum) then
                            phase = "pop"
                        end
                    end
                    -- Cap so one physics step cannot throw US through the map.
                    local down = Vector3.new(0, -math.min(1800, 28 / dt), 0)
                    punch(phase == "sink" and down or up)
                    stick(th)
                end)
            end))
            hold = track(RunSvc.Heartbeat:Connect(function()
                pcall(function()
                    if not running or abort then return end
                    local th = hrpOf(target)
                    local mh = stick(th)
                    if mh and unsafe(mh, th) then
                        stick(th)
                        if unsafe(mh, th) then
                            abort = true
                            snapHome(home)
                        end
                    end
                end)
            end))
            while running and not abort and tick() - t0 < 10 and alive(me) do
                if not target.Parent or not alive(target) then break end
                local th = hrpOf(target)
                if not th or th.Position.Y <= killY + 80 or th.Position.Y < 40 then break end
                RunSvc.Heartbeat:Wait()
            end
            local thf = hrpOf(target)
            local y = thf and math.floor(thf.Position.Y + 0.5) or 0
            local win = (not alive(target)) or (thf and (thf.Position.Y <= killY + 80 or thf.Position.Y < 40)) or not target.Parent
            say((win and "voided " or "miss ") .. target.Name .. " y=" .. tostring(y))
        end)
        if not ok then say("error " .. tostring(err)) end
        if bav then pcall(function() bav:Destroy() end) end
        if guard then pcall(function() guard:Disconnect() end) end
        if hold then pcall(function() hold:Disconnect() end) end
        snapHome(home)
        if not running then
            protectVoid(false)
            return
        end
        cleanup(home)
        spectate(target, true)
    end)
end

local function airFling(target)
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
    if _G.MM_DisableAntiFling then pcall(_G.MM_DisableAntiFling) end
    if _G.MM_ActionBegin then pcall(_G.MM_ActionBegin) end
    say("air-fling " .. target.Name)
    task.spawn(function()
        local home = myHrp() and myHrp().CFrame
        protectVoid(true)
        camOnMe()
        local spin = Vector3.new(9e4, 9e4, 9e4)
        local bav, guard, hold
        pcall(function()
            local mh = myHrp()
            if not mh then return end
            bav = Instance.new("BodyAngularVelocity")
            bav.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            bav.P = 1e9
            bav.AngularVelocity = Vector3.new(0, 9e4, 9e4)
            bav.Parent = mh
        end)
        local startY = 0
        local function stick(th)
            local mh = myHrp()
            if mh and th then
                mh.Anchored = false
                mh.CFrame = th.CFrame
            end
            return mh
        end
        guard = track(RunSvc.Stepped:Connect(function()
            pcall(function()
                if not running then return end
                local th = hrpOf(target)
                local mh = stick(th)
                if not (mh and th) then return end
                local char = me.Character
                for _, n in ipairs({"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}) do
                    local p = char and char:FindFirstChild(n)
                    if p and p:IsA("BasePart") then
                        p.CanCollide = true
                        p.Anchored = false
                        p.CFrame = n == "HumanoidRootPart" and th.CFrame or p.CFrame
                        p.AssemblyLinearVelocity = Vector3.new(0, 4200, 0)
                        p.Velocity = Vector3.new(0, 4200, 0)
                        p.AssemblyAngularVelocity = spin
                        p.RotVelocity = spin
                    end
                end
                stick(th)
            end)
        end))
        hold = track(RunSvc.Heartbeat:Connect(function()
            pcall(function()
                if not running then return end
                stick(hrpOf(target))
            end)
        end))
        local t0 = tick()
        pcall(function()
            local th0 = hrpOf(target)
            startY = th0 and th0.Position.Y or 0
            local hum0 = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
            if hum0 then
                hum0.PlatformStand = true
                hum0.AutoRotate = false
            end
            while running and tick() - t0 < 5 and alive(me) do
                local th = hrpOf(target)
                if th and (th.Position.Y > startY + 2 or th.AssemblyLinearVelocity.Magnitude > 45) then
                    if tick() - t0 > 2.2 then break end
                end
                RunSvc.Heartbeat:Wait()
            end
        end)
        local thf = hrpOf(target)
        local y = thf and math.floor(thf.Position.Y + 0.5) or 0
        say(((thf and thf.Position.Y > startY + 2) and "flung " or "miss ") .. target.Name .. " y=" .. tostring(y))
        if bav then pcall(function() bav:Destroy() end) end
        if guard then pcall(function() guard:Disconnect() end) end
        if hold then pcall(function() hold:Disconnect() end) end
        snapHome(home)
        if not running then
            protectVoid(false)
            return
        end
        cleanup(home)
        spectate(target, true)
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
        local p = findPl(rest) or currentTarget()
        if not spectate(p) then say("no player") end
        return
    end
    if cmd == ".b" or cmd == ".banish" then
        banish(rest ~= "" and findPl(rest) or currentTarget())
        return
    end
    if cmd == ".f" or cmd == ".fling" then
        airFling(rest ~= "" and findPl(rest) or currentTarget())
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

say("ready — .s name, .b void, .f air-fling (re-inject unloads)")
