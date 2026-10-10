--[[ Xeno V1.05 XBOT_BUILD 20261010x ]]--
local GRAPHICS = true
local TARGET_FPS = 50
local Players = game:GetService("Players")
local cref = cloneref or function(x) return x end
local TCS = cref(game:GetService("TextChatService"))
local function rawTCS()
    return game:GetService("TextChatService")
end
local Tween = game:GetService("TweenService")
local RunSvc = game:GetService("RunService")
local RS = cref(game:GetService("ReplicatedStorage"))
local Http = cref(game:GetService("HttpService"))
local Stats = cref(game:GetService("Stats"))
local StarterGui = cref(game:GetService("StarterGui"))
local TeleportSvc = cref(game:GetService("TeleportService"))
local isLegacy = TCS and TCS.ChatVersion == Enum.ChatVersion.LegacyChatService
local me = Players.LocalPlayer
if not me then
    for _ = 1, 40 do
        task.wait(0.05)
        me = Players.LocalPlayer
        if me then break end
    end
end
local cam = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
local UIS = cref(game:GetService("UserInputService"))
local DEFAULT_FOV, WIDE_FOV = 70, 100
local SPAWN_CFRAME = CFrame.new(14.3513288, 505.044952, -58.2513657, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local toggleGun = false
local toggleShoot = false
local toggleAlerts = false
local toggleReveal = true
local toggleResetOnOwnerDeath = true
local toggleDrop = false
local gunTargetId = nil
local gunDelivered = false
local shootTargetId = nil
local shootDone = false
local hopBusy = false
local PING_MIN_MS, PING_MAX_MS = 50, 90
local G = _G
pcall(function()
    if type(getgenv) == "function" then
        G = getgenv() or G
    end
end)
if type(G) ~= "table" then G = {} end
G.MM_UnderSpawn = SPAWN_CFRAME * CFrame.new(0, -34, 0)
G.MM_ShootActive = false
G.MM_BootReady = false
G.MM_ForceHide = false
G.MM_HoldMove = false
G.MM_HoldStand = false
pcall(function()
    RunSvc:Set3dRenderingEnabled(true)
    if setfpscap then setfpscap(TARGET_FPS) end
    settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
end)
local XENO_OWNER_USERNAME = tostring(G.xeno_roblox or _G.xeno_roblox or xeno_roblox or ""):match("^%s*(.-)%s*$") or ""
local XENO_OWNER_DISCORD = tostring(G.xeno_discord or _G.xeno_discord or xeno_discord or ""):match("^%s*(.-)%s*$") or ""
local ANNOUNCEMENT_MESSAGE = tostring(G.announcement_message or _G.announcement_message or ""):match("^%s*(.-)%s*$") or ""
local ACTIVE_OWNER_USERNAME = XENO_OWNER_USERNAME
local bridgeOwnerConnected = false
G.MM_HopState = G.MM_HopState or {pingSearchActive = false}
local hopState = G.MM_HopState
_G.MM_StabBusy = _G.MM_StabBusy or false
_G.MM_GunBusy = _G.MM_GunBusy or false
_G.MM_ShootBusy = _G.MM_ShootBusy or false
_G.MM_OwnerDiedPendingReset = _G.MM_OwnerDiedPendingReset or false
_G.MM_StabBusyUntil = _G.MM_StabBusyUntil or 0
local OWNER_MURD_GUN_MSG = "Gun unavailable"
local OWNER_MURD_STASH_COOLDOWN = 3
G.MM_OwnerPremium = true

--[[ Session ]]--
local oldSession = G.MM_Session or _G.MM_Session
if type(oldSession) == "table" then
    oldSession.active = false
    oldSession.ownerId = nil
end
local oldCleanup = G.MM_Cleanup or _G.MM_Cleanup
if type(oldCleanup) == "function" then pcall(oldCleanup) end
if game.CoreGui:FindFirstChild("MM") then game.CoreGui.MM:Destroy() end
local gui
local session = {active = true, ownerId = nil, connections = {}}
local function trackConnection(conn)
    if conn then table.insert(session.connections, conn) end
    return conn
end
local function cleanupSession()
    if not session.active and session.cleaned then return end
    session.active = false
    session.cleaned = true
    session.ownerId = nil
    for _, conn in ipairs(session.connections) do
        pcall(function() conn:Disconnect() end)
    end
    session.connections = {}
    _G.MM_StabBusy = false
    _G.MM_GunBusy = false
    _G.MM_ShootBusy = false
    _G.MM_OwnerDiedPendingReset = false
    G.MM_RoleSentThisRound = false
    G.MM_RoleSentKey = nil
    G.MM_MurderOnlySent = false
    G.MM_RoleQBusy = false
    G.MM_Resetting = false
    if G.MM_AntiFlingShutdown then pcall(G.MM_AntiFlingShutdown) end
    if gui and gui.Parent then pcall(function() gui:Destroy() end) end
end
G.MM_Session = session
G.MM_Cleanup = cleanupSession
_G.MM_Session = session
_G.MM_Cleanup = cleanupSession
do
    if G.MM_OwnerReleased or not G.MM_OwnerAdopted then
        session.ownerId = nil
        if G.MM_OwnerReleased then
            G.MM_PendingOwnerId = nil
        end
    else
        local pending = tonumber(G.MM_PendingOwnerId)
        if pending and pending > 0 then
            session.ownerId = pending
        end
    end
end
pcall(function()
    if not cam then cam = workspace.CurrentCamera end
    if cam then cam.FieldOfView = DEFAULT_FOV end
    local h = me and me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if cam and h then cam.CameraSubject = h end
end)

--[[ Render / FPS — keep 3D on so leftover farm-mode loops cannot blank the screen ]]--
task.spawn(function()
    local VU = game:GetService("VirtualUser")
    pcall(function()
        trackConnection(Players.LocalPlayer.Idled:Connect(function()
            if not session.active then return end
            VU:CaptureController()
            VU:ClickButton2(Vector2.new(math.random(10, 50), math.random(10, 50)))
        end))
    end)
    while session.active do
        pcall(function()
            RunSvc:Set3dRenderingEnabled(true)
            if setfpscap then setfpscap(TARGET_FPS) end
        end)
        task.wait(0.5)
    end
end)

--[[ GUI ]]--
do
    local parent = nil
    pcall(function()
        if gethui then parent = gethui() end
    end)
    if not parent then
        pcall(function() parent = game:GetService("CoreGui") end)
    end
    if not parent then
        pcall(function() parent = me:WaitForChild("PlayerGui", 3) end)
    end
    gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn = "MM", false
    gui.Parent = parent
end
local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 140, 0, 180), UDim2.new(1, -150, 0, 10)
f.BackgroundColor3, f.Visible = Color3.fromRGB(20, 20, 20), false
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
local img = Instance.new("ImageLabel", f)
img.Size, img.Position, img.BackgroundTransparency = UDim2.new(1, -10, 1, -40), UDim2.new(0, 5, 0, 5), 1
local lbl = Instance.new("TextLabel", f)
lbl.Size, lbl.Position, lbl.BackgroundTransparency = UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 1, -32), 1
lbl.TextColor3, lbl.Font, lbl.TextScaled = Color3.new(1, 0, 0), Enum.Font.GothamBold, true

--[[ Log GUI ]]--
local log
do
    local TextService = game:GetService("TextService")
    local expanded = false
    local rows = {}
    local root = Instance.new("Frame", gui)
    root.Name = "MMLog"
    root.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
    root.BackgroundTransparency = 0.12
    root.BorderSizePixel = 0
    root.ZIndex = 80
    root.Active = true
    Instance.new("UICorner", root).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", root)
    stroke.Color = Color3.fromRGB(70, 110, 70)
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    local header = Instance.new("TextButton", root)
    header.BackgroundColor3 = Color3.fromRGB(20, 28, 20)
    header.BackgroundTransparency = 0.05
    header.BorderSizePixel = 0
    header.Font = Enum.Font.GothamBold
    header.TextSize = 13
    header.TextColor3 = Color3.fromRGB(190, 235, 190)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.AutoButtonColor = true
    header.ZIndex = 81
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
    local minBtn = Instance.new("TextButton", root)
    minBtn.BackgroundColor3 = Color3.fromRGB(28, 40, 28)
    minBtn.BackgroundTransparency = 0.05
    minBtn.BorderSizePixel = 0
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 12
    minBtn.TextColor3 = Color3.fromRGB(210, 235, 210)
    minBtn.AutoButtonColor = true
    minBtn.ZIndex = 82
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)
    local scroll = Instance.new("ScrollingFrame", root)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    scroll.ScrollBarImageColor3 = Color3.fromRGB(130, 190, 130)
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = 81
    scroll.Active = true
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 12)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 8)
    local list = Instance.new("UIListLayout", scroll)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 3)
    local function applyLayout()
        if expanded then
            root.Size = UDim2.new(0.86, 0, 0.86, 0)
            root.Position = UDim2.new(0.07, 0, 0.07, 0)
            header.Size = UDim2.new(1, -72, 0, 28)
            header.Position = UDim2.new(0, 0, 0, 0)
            header.Text = "  logs"
            minBtn.Size = UDim2.new(0, 68, 0, 28)
            minBtn.Position = UDim2.new(1, -68, 0, 0)
            minBtn.Text = "min"
            minBtn.Visible = true
            scroll.Position = UDim2.new(0, 0, 0, 30)
            scroll.Size = UDim2.new(1, 0, 1, -30)
        else
            root.Size = UDim2.new(0, 360, 0, 176)
            root.Position = UDim2.new(0, 10, 1, -186)
            header.Size = UDim2.new(1, 0, 0, 24)
            header.Position = UDim2.new(0, 0, 0, 0)
            header.Text = "  logs  (click to expand)"
            minBtn.Visible = false
            scroll.Position = UDim2.new(0, 0, 0, 24)
            scroll.Size = UDim2.new(1, 0, 1, -24)
        end
    end
    local function relayoutLabels()
        local width = math.max(80, scroll.AbsoluteSize.X - 22)
        for _, row in ipairs(rows) do
            local ok, sz = pcall(function()
                return TextService:GetTextSize(row.Text, 14, Enum.Font.Code, Vector2.new(width, 20000))
            end)
            local h = 18
            if ok and sz then h = math.max(18, math.ceil(sz.Y) + 4) end
            row.Size = UDim2.new(1, -4, 0, h)
        end
        local y = list.AbsoluteContentSize.Y + 10
        scroll.CanvasSize = UDim2.new(0, 0, 0, y)
        scroll.CanvasPosition = Vector2.new(0, math.max(0, y - scroll.AbsoluteSize.Y))
    end
    applyLayout()
    header.MouseButton1Click:Connect(function()
        expanded = not expanded
        applyLayout()
        task.defer(relayoutLabels)
    end)
    minBtn.MouseButton1Click:Connect(function()
        expanded = false
        applyLayout()
        task.defer(relayoutLabels)
    end)
    log = function(msg)
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.Code
        t.TextSize = 14
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextYAlignment = Enum.TextYAlignment.Top
        t.TextColor3 = Color3.fromRGB(180, 230, 180)
        t.TextWrapped = true
        t.TextTruncate = Enum.TextTruncate.None
        t.Text = "[" .. os.date("%X") .. "] " .. tostring(msg)
        t.LayoutOrder = #rows + 1
        t.ZIndex = 82
        t.Parent = scroll
        table.insert(rows, t)
        while #rows > 200 do
            local old = table.remove(rows, 1)
            if old then old:Destroy() end
        end
        task.defer(relayoutLabels)
    end
    scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        task.defer(relayoutLabels)
    end)
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 10)
    end)
end

--[[ Finders ]]--
G.MM_GunNames = G.MM_GunNames or {"Gun", "Revolver", "SheriffGun", "Laser", "Luger", "Blaster"}
G.MM_KnifeNames = G.MM_KnifeNames or {"Knife"}
local function hasItem(parent, names)
    for _, c in ipairs(parent and parent:GetChildren() or {}) do
        if table.find(names, c.Name) and (c:IsA("Tool") or c:IsA("HopperBin")) then
            return true
        end
    end
end
local function playerHas(p, names)
    if not p then return end
    if hasItem(p.Character, names) or hasItem(p:FindFirstChildOfClass("Backpack"), names) then
        return true
    end
    if p == me then
        return hasItem(me:FindFirstChild("MM_HiddenTools"), names) == true
    end
end
local function findHolder(names)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me and playerHas(p, names) then return p end
    end
end
local function botHasGun() return playerHas(me, G.MM_GunNames) end
local function botHasKnife() return playerHas(me, G.MM_KnifeNames) end
G.MM_MarkIgnoreDrop = function(pos, secs)
    secs = tonumber(secs) or 10
    G.MM_BlockGunGrab = true
    G.MM_SkipGunUntil = tick() + secs
    if pos then
        G.MM_IgnoreDropPos = pos
        G.MM_IgnoreDropUntil = tick() + secs
    end
end
local function findDroppedGun()
    local function leftover(part)
        if not part then return true end
        if part.Position.Y < -40 then return true end
        local untilT = tonumber(G.MM_IgnoreDropUntil) or 0
        local ip = G.MM_IgnoreDropPos
        if ip and tick() < untilT and (part.Position - ip).Magnitude < 32 then
            return true
        end
        return false
    end
    local function usable(part)
        if not part or not part.Parent then return end
        if leftover(part) then return end
        return part
    end
    local function asPart(obj)
        if not obj then return end
        if obj:IsA("BasePart") then return usable(obj) end
        if obj:IsA("Model") then
            return usable(obj.PrimaryPart or obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart"))
        end
        if obj:IsA("Tool") then
            return usable(obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart"))
        end
    end
    local direct = workspace:FindFirstChild("GunDrop") or workspace:FindFirstChild("DroppedGun")
    local part = asPart(direct)
    if part then return part end
    local nested = workspace:FindFirstChild("GunDrop", true) or workspace:FindFirstChild("DroppedGun", true)
    part = asPart(nested)
    if part then return part end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Tool") and (table.find(G.MM_GunNames, o.Name) or o.Name == "GunDrop")
           and not Players:GetPlayerFromCharacter(o.Parent) then
            local h = usable(o:FindFirstChild("Handle") or o:FindFirstChildWhichIsA("BasePart"))
            if h then return h end
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") and (o.Name == "GunDrop" or o.Name == "DroppedGun") then
            local h = usable(o)
            if h then return h end
        end
    end
end

-- MM2 GetPlayerData: Role, Dead, Killed. Killed = stabbed/shot. Dead without Killed = reset.
G.MM_PlayerData = {}
G.MM_HasKilledField = false
G.MM_RoundLive = false
G.MM_RoleSentThisRound = false
G.MM_MurderOnlySent = false
G.MM_LastRoleCallout = nil
G.MM_LastRoleCalloutAt = 0
G.MM_RoleQ = {}
G.MM_RoleQBusy = false
G.MM_RoleSending = nil
G.MM_OnPlayerKilled = nil
;(function()
    local function parseKilled(info)
        local k = info.Killed
        if k == nil then k = info.killed end
        if k == true or k == 1 then return true, nil end
        if k == false or k == 0 or k == nil then return false, nil end
        if type(k) == "string" then
            local low = k:lower()
            if low == "" or low == "false" or low == "none" or low == "nil" then return false, nil end
            if low == "true" then return true, nil end
            return true, k
        end
        return false, nil
    end
    local function parseInfo(info, old)
        if type(info) == "string" then
            return {Role = info, Dead = false, Killed = false, Killer = nil}
        end
        if type(info) ~= "table" then return end
        if info.Killed ~= nil or info.killed ~= nil then
            G.MM_HasKilledField = true
        end
        local killed, killer = parseKilled(info)
        if not killer then
            local kb = info.Killer or info.KilledBy or info.killedBy
            if type(kb) == "string" and kb ~= "" then killer = kb end
        end
        local dead = info.Dead == true or info.dead == true
        local role = info.Role or info.role or info.CurrentRole or info.Class
        if type(role) == "table" then
            role = role.Name or role.Role or role.role
        end
        if (not role or role == "Unknown") and old and old.Role and old.Role ~= "Unknown" then
            if dead or killed or old.Dead or old.Killed then
                role = old.Role
            end
        end
        return {Role = role, Dead = dead, Killed = killed, Killer = killer}
    end
    local function ingest(data)
        if type(data) ~= "table" then return end
        local n = 0
        local sawRole = false
        for name, info in pairs(data) do
            n = n + 1
            local old = G.MM_PlayerData[name]
            local rec = parseInfo(info, old)
            if rec then
                if rec.Role == "Murderer" or rec.Role == "Sheriff" or rec.Role == "Hero" then
                    sawRole = true
                end
                G.MM_PlayerData[name] = rec
                local pl
                if type(info) == "table" then
                    local iuid = info.UserId or info.userId or info.UserID
                    if iuid then
                        pl = Players:GetPlayerByUserId(tonumber(iuid))
                    end
                    if not pl and typeof(info.Player) == "Instance" and info.Player:IsA("Player") then
                        pl = info.Player
                    end
                    local pname = info.Name or info.name or info.Username or info.PlayerName
                    if not pl and type(info.Player) == "string" then
                        pname = pname or info.Player
                    end
                    if not pl and pname then
                        pl = Players:FindFirstChild(tostring(pname))
                    end
                end
                if not pl then
                    local uid = tonumber(name)
                    if uid then
                        pl = Players:GetPlayerByUserId(uid)
                    else
                        pl = Players:FindFirstChild(tostring(name))
                        if not pl then
                            for _, cand in ipairs(Players:GetPlayers()) do
                                if tostring(cand.DisplayName) == tostring(name) then
                                    pl = cand
                                    break
                                end
                            end
                        end
                    end
                end
                if pl then
                    G.MM_PlayerData[pl.Name] = rec
                    G.MM_PlayerData[tostring(pl.UserId)] = rec
                end
                if old and not old.Killed and rec.Killed then
                    local cb = G.MM_OnPlayerKilled
                    if cb then pcall(cb, name, rec) end
                end
            end
        end
        if n == 0 then return end
        local playerCount = #Players:GetPlayers()
        if sawRole then
            if not G.MM_RoundLive then
                G.MM_RoundPulse = tick()
            end
            G.MM_RoundLive = true
        elseif n >= math.max(2, playerCount - 1) then
            G.MM_RoundLive = false
            for _, rec in pairs(G.MM_PlayerData) do
                rec.Killed = false
                rec.Dead = false
            end
        end
    end
    local function isRemoteEvent(inst)
        if typeof(inst) ~= "Instance" then return false end
        local cn = inst.ClassName
        return cn == "RemoteEvent" or cn == "UnreliableRemoteEvent"
    end
    local function findRemote(name, className)
        local direct = RS:FindFirstChild(name)
        if direct and direct.ClassName == className then return direct end
        local rem = RS:FindFirstChild("Remotes")
        if rem then
            local nested = rem:FindFirstChild(name, true)
            if nested and nested.ClassName == className then return nested end
        end
    end
    local function connectClient(ev, fn)
        if not isRemoteEvent(ev) then return end
        local ok, conn = pcall(function()
            return ev.OnClientEvent:Connect(fn)
        end)
        if ok then trackConnection(conn) end
    end
    -- Do not search for "Fade". MM2 GUI Frames use that name.
    local function pulseRound()
        G.MM_RoundPulse = tick()
    end
    local function ingestChanged(a, b)
        if type(a) == "table" then
            ingest(a)
        elseif type(a) == "string" then
            ingest({[a] = b})
        end
    end
    pcall(function()
        connectClient(findRemote("PlayerDataChanged", "RemoteEvent"), ingestChanged)
        connectClient(findRemote("UpdatePlayerData", "RemoteEvent"), ingest)
    end)
    pcall(function()
        connectClient(findRemote("RoleSelect", "RemoteEvent"), function(role)
            local rec = G.MM_PlayerData[me.Name] or {Dead = false, Killed = false}
            rec.Role = role or rec.Role
            G.MM_PlayerData[me.Name] = rec
            if rec.Role == "Murderer" or rec.Role == "Sheriff" or rec.Role == "Hero" then
                G.MM_RoundLive = true
            end
            pulseRound()
        end)
        connectClient(findRemote("RoundStart", "RemoteEvent"), pulseRound)
        connectClient(findRemote("ShowRoleSelect", "RemoteEvent"), pulseRound)
        connectClient(findRemote("ShowRoleSelectNew", "RemoteEvent"), pulseRound)
    end)
    pcall(function()
        local rem = RS:FindFirstChild("Remotes")
        local gp = rem and rem:FindFirstChild("Gameplay")
        local re = gp and gp:FindFirstChild("RoundEndFade")
        if not isRemoteEvent(re) then
            re = findRemote("RoundEndFade", "RemoteEvent")
        end
        connectClient(re, function()
            G.MM_PlayerData = {}
            G.MM_RoundLive = false
            G.MM_SuppressGunDrop = nil
            G.MM_RoleSentThisRound = false
            G.MM_MurderOnlySent = false
            G.MM_RoleSentKey = nil
        end)
    end)
    local function recOf(p)
        if not p then return end
        return G.MM_PlayerData[p.Name] or G.MM_PlayerData[tostring(p.UserId)] or G.MM_PlayerData[p.DisplayName]
    end
    local function roleIs(rec, want)
        if not rec or type(rec.Role) ~= "string" then return false end
        return rec.Role:lower() == tostring(want):lower()
    end
    local function matchRole(want, allowDead)
        for _, p in ipairs(Players:GetPlayers()) do
            local rec = recOf(p)
            if roleIs(rec, want) and (allowDead or not rec.Dead) then
                return p
            end
        end
        for key, rec in pairs(G.MM_PlayerData) do
            if roleIs(rec, want) and (allowDead or not rec.Dead) then
                local uid = tonumber(key)
                local p = uid and Players:GetPlayerByUserId(uid) or Players:FindFirstChild(tostring(key))
                if p then return p end
            end
        end
    end
    G.MM_FindRole = function(want)
        local hit = matchRole(want, false) or matchRole(want, true)
        if hit then return hit end
        if want == "Murderer" then
            if botHasKnife() then return me end
            return findHolder({"Knife"})
        end
        if want == "Sheriff" or want == "Hero" then
            local h = findHolder(G.MM_GunNames)
            if not h then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= me and p.Character then
                        for _, d in ipairs(p.Character:GetChildren()) do
                            if table.find(G.MM_GunNames, d.Name) and d:IsA("Tool") then
                                h = p
                                break
                            end
                        end
                    end
                    if h then break end
                end
            end
            if h then
                local rec = recOf(h)
                if roleIs(rec, want) then return h end
                if not rec then return h end
                if want == "Sheriff" and rec.Role ~= "Hero" then return h end
                if want == "Hero" and rec.Role == "Hero" then return h end
            end
            if botHasGun() then
                local rec = recOf(me)
                if roleIs(rec, want) then return me end
                if not h and want == "Sheriff" and (not rec or rec.Role ~= "Hero") then
                    return me
                end
            end
        end
    end
    G.MM_RoleOf = function(p)
        if not p then return end
        local rec = recOf(p)
        if rec and rec.Role and rec.Role ~= "Unknown" then return rec.Role end
        if playerHas(p, G.MM_KnifeNames) then return "Murderer" end
        if playerHas(p, G.MM_GunNames) then
            return "Sheriff"
        end
    end
    G.MM_HasRoundRoles = function()
        if G.MM_RoundLive then return true end
        return G.MM_FindRole("Murderer") ~= nil
    end
    task.spawn(function()
        while session.active do
            pcall(function()
                local rem = RS:FindFirstChild("Remotes")
                local gp = rem and rem:FindFirstChild("Gameplay")
                local cur = gp and gp:FindFirstChild("GetCurrentPlayerData")
                local data
                if cur and cur.ClassName == "RemoteFunction" then
                    data = cur:InvokeServer()
                end
                local n = 0
                if type(data) == "table" then
                    for _ in pairs(data) do n = n + 1 end
                end
                if n == 0 then
                    local rf = findRemote("GetPlayerData", "RemoteFunction")
                    if rf then data = rf:InvokeServer() end
                end
                if type(data) == "table" then
                    n = 0
                    for _ in pairs(data) do n = n + 1 end
                end
                if n == 0 then
                    local bf = RS:FindFirstChild("GetPlayerData_REMOTE")
                    if bf and bf.ClassName == "BindableFunction" then
                        data = bf:Invoke()
                    end
                end
                ingest(data)
            end)
            task.wait(0.55)
        end
    end)
end)()

local function findPlayer(q)
    if not q or q == "" then return end
    q = q:lower()
    local best, bestScore
    for _, p in ipairs(Players:GetPlayers()) do
        local n, d = p.Name:lower(), p.DisplayName:lower()
        local i = n:find(q, 1, true) or d:find(q, 1, true)
        if i then
            local score = i + math.abs(#n - #q)
            if not bestScore or score < bestScore then best, bestScore = p, score end
        end
    end
    return best
end
local function findOwner()
    if not G.MM_OwnerAdopted or not session.ownerId then return end
    local o = Players:GetPlayerByUserId(session.ownerId)
    if o and o ~= me then return o end
end
local scheduleOwnerOnboarding
local function configuredOwnerMatches(p)
    if not p or ACTIVE_OWNER_USERNAME == "" then return false end
    local q = ACTIVE_OWNER_USERNAME:lower()
    return p.Name:lower() == q or tostring(p.DisplayName or ""):lower() == q
end
local function findConfiguredOwner()
    if ACTIVE_OWNER_USERNAME == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me and configuredOwnerMatches(p) then
            return p
        end
    end
    return nil
end
local function syncConfiguredOwner()
    return findOwner()
end

local function authorizeCommand(p)
    return p and p ~= me and G.MM_OwnerAdopted and session.ownerId and p.UserId == session.ownerId
end

function G.MM_CurrentToggleConfig()
    return {
        automatic_gun = toggleGun,
        automatic_shoot = toggleShoot,
        reveal = toggleReveal,
        alerts = toggleAlerts,
        automatic_reset = toggleResetOnOwnerDeath,
        automatic_drop = toggleDrop,
    }
end

function G.MM_ApplyToggleConfig(cfg)
    if type(cfg) ~= "table" then return end
    if cfg.automatic_gun ~= nil then
        toggleGun = cfg.automatic_gun == true
        if not toggleGun then gunTargetId, gunDelivered = nil, false end
    end
    if cfg.automatic_shoot ~= nil then
        toggleShoot = cfg.automatic_shoot == true
        if not toggleShoot then shootTargetId, shootDone = nil, false end
    end
    if cfg.reveal ~= nil then toggleReveal = cfg.reveal == true end
    if cfg.alerts ~= nil then toggleAlerts = cfg.alerts == true end
    if cfg.automatic_reset ~= nil then
        toggleResetOnOwnerDeath = cfg.automatic_reset == true
        if not toggleResetOnOwnerDeath then _G.MM_OwnerDiedPendingReset = false end
    end
    if cfg.automatic_drop ~= nil then toggleDrop = cfg.automatic_drop == true end
end

G.MM_OwnerPrefs = G.MM_OwnerPrefs or {}
G.MM_TipLines = {
    "❓ Tip: Whisper commands so the lobby doesn't see them",
    "❓ Tip: !help reveal  ·  !help gun  ·  !help hide",
    "❓ Tip: Add loop after !fling to keep going (!fling ... loop)",
    "❓ Tip: Use !reveal (player) to reveal the round roles to someone",
    "❓ Tip: Use !hide to keep the bot hidden",
    "❓ Tip: !reset respawns the bot if it's stuck",
    "❓ Tip: !gun <name> delivers the dropped gun",
    "❓ Tip: !stab sheriff or !stab all when the bot is Murderer",
    "❓ Tip: !help (cmd) explains one command, !help list all",
    "❓ Tip: !togglegun <name> auto-delivers gun every time it drops",
    "❓ Tip: !adopt claims the bot, !unadopt lets someone else take it",
    "❓ Tip: !chat <msg> makes the bot talk in public",
}
G.MM_ApplyOwnerDefaults = function()
    toggleGun, toggleShoot, toggleAlerts = false, false, false
    toggleReveal = true
    toggleResetOnOwnerDeath, toggleDrop = true, false
    gunTargetId, gunDelivered = nil, false
    shootTargetId, shootDone = nil, false
    G.MM_ForceHide = false
    G.MM_SummonFocusId = nil
    G.MM_ResetUserSet = false
    _G.MM_OwnerDiedPendingReset = false
    G.MM_TipSent = {}
    G.MM_TipRounds = 0
end
G.MM_SaveOwnerPrefs = function(uid)
    uid = tonumber(uid)
    if not uid then return end
    G.MM_OwnerPrefs[tostring(uid)] = {
        toggles = G.MM_CurrentToggleConfig(),
        forceHide = G.MM_ForceHide == true,
        summonFocusId = G.MM_SummonFocusId,
        tipsSent = G.MM_TipSent or {},
        tipRounds = tonumber(G.MM_TipRounds) or 0,
        gunTargetId = gunTargetId,
        shootTargetId = shootTargetId,
        resetUserSet = G.MM_ResetUserSet == true,
    }
end
G.MM_LoadOwnerPrefs = function(uid)
    uid = tonumber(uid)
    G.MM_ApplyOwnerDefaults()
    G.MM_TipOwnerId = uid
    if not uid then return end
    local rec = G.MM_OwnerPrefs[tostring(uid)]
    if type(rec) ~= "table" then return end
    G.MM_ApplyToggleConfig(rec.toggles)
    if rec.resetUserSet == true then
        G.MM_ResetUserSet = true
    else
        toggleResetOnOwnerDeath = true
        G.MM_ResetUserSet = false
    end
    G.MM_ForceHide = rec.forceHide == true
    G.MM_SummonFocusId = tonumber(rec.summonFocusId)
    G.MM_TipSent = type(rec.tipsSent) == "table" and rec.tipsSent or {}
    G.MM_TipRounds = tonumber(rec.tipRounds) or 0
    if rec.gunTargetId then gunTargetId = rec.gunTargetId end
    if rec.shootTargetId then shootTargetId = rec.shootTargetId end
end
G.MM_NoteRoundForTips = function()
    local uid = session.ownerId
    if not uid then return end
    if G.MM_TipOwnerId ~= uid then
        G.MM_LoadOwnerPrefs(uid)
    end
    local lines = G.MM_TipLines
    local sent = G.MM_TipSent or {}
    local left = {}
    for i = 1, #lines do
        if not sent[i] and not sent[tostring(i)] then
            table.insert(left, i)
        end
    end
    if #left == 0 then return end
    G.MM_TipRounds = (tonumber(G.MM_TipRounds) or 0) + 1
    if (G.MM_TipRounds % 3) ~= 0 then
        G.MM_SaveOwnerPrefs(uid)
        return
    end
    local pick = left[math.random(1, #left)]
    local text = lines[pick]
    G.MM_SaveOwnerPrefs(uid)
    task.spawn(function()
        task.wait(6.2)
        if session.ownerId ~= uid then return end
        local o = Players:GetPlayerByUserId(uid)
        if not o then return end
        if whisperOk(text, o) then
            sent[pick] = true
            G.MM_TipSent = sent
            G.MM_SaveOwnerPrefs(uid)
        end
    end)
end
G.MM_SendAdoptAd = function()
    if session.ownerId then return end
    local line = "No owner — !adopt to claim this bot"
    log("adopt advert")
    sendChat(line)
end
G.MM_NoteRoundForAdoptAd = function()
    if session.ownerId then
        G.MM_AdoptAdRounds = 0
        return
    end
    G.MM_AdoptAdRounds = (tonumber(G.MM_AdoptAdRounds) or 0) + 1
    if (G.MM_AdoptAdRounds % 3) == 0 then
        G.MM_SendAdoptAd()
    end
end
if session.ownerId then
    G.MM_LoadOwnerPrefs(session.ownerId)
end

function G.MM_CurrentOwnerInfo()
    local owner = findOwner()
    if not owner then return nil end
    return {
        user_id = owner.UserId,
        username = owner.Name,
        display_name = owner.DisplayName,
    }
end
local function shortName(p) return p.Name:sub(1, 4) .. "..." end

local function bridgePlayerLabel(p)
    if not p then return "?" end
    local dn = p.DisplayName
    if type(dn) == "string" and dn ~= "" then return dn end
    return p.Name
end

local function isOwnerPlayer(p)
    return p and G.MM_OwnerAdopted and session.ownerId and p.UserId == session.ownerId
end
local function adoptedOwnerPlayer()
    if not G.MM_OwnerAdopted or not session.ownerId then return end
    local o = Players:GetPlayerByUserId(session.ownerId)
    if o and o ~= me then return o end
end
local function ownerIsConfirmedDead(own)
    own = own or adoptedOwnerPlayer()
    if not own or own == me then return false end
    if not isOwnerPlayer(own) then return false end
    local rec = G.MM_PlayerData[own.Name] or G.MM_PlayerData[tostring(own.UserId)]
    if rec and (rec.Dead == true or rec.Killed == true) then return true end
    local hum = own.Character and own.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return true end
    return false
end

local function bridgeTargetLabel(p)
    if not p then return "?" end
    if isOwnerPlayer(p) then return "you" end
    return bridgePlayerLabel(p)
end

local function commandTargetLabel(p)
    if not p then return "?" end
    if isOwnerPlayer(p) then return "you" end
    return shortName(p)
end
local function matchedPlayerLabel(p, query)
    if not p then return "?" end
    local name = tostring(p.Name or "")
    local dn = tostring(p.DisplayName or "")
    local label = name
    if dn ~= "" and dn:lower() ~= name:lower() then
        label = dn .. " (@" .. name .. ")"
    end
    local q = (tostring(query or ""):match("^%s*(.-)%s*$") or ""):lower()
    if q ~= "" and q ~= name:lower() and q ~= dn:lower() then
        label = label .. '  (matched "' .. tostring(query) .. '")'
    end
    return label
end
local function restOfChatArgs(args)
    if not args or #args < 2 then return "" end
    return (table.concat(args, " ", 2)):match("^%s*(.-)%s*$") or ""
end
local function splitChatArgs(msg)
    if type(msg) ~= "string" then return {""} end
    if string.split then return string.split(msg, " ") end
    local out = {}
    for w in msg:gmatch("%S+") do table.insert(out, w) end
    if #out == 0 then out[1] = msg end
    return out
end
-- Like findPlayer but never the bot; prefers exact username/display match (matches bot.lua intent for combat targets).
local function findOtherPlayer(q)
    if not q or q == "" then return end
    q = tostring(q):lower()
    local exactN, exactD, best, bestScore
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= me then
            local nl, dl = pl.Name:lower(), tostring(pl.DisplayName or ""):lower()
            if nl == q then exactN = pl end
            if dl == q then exactD = pl end
            local i = nl:find(q, 1, true) or dl:find(q, 1, true)
            if i then
                local score = i + math.abs(#nl - #q)
                if not bestScore or score < bestScore then best, bestScore = pl, score end
            end
        end
    end
    return exactN or exactD or best
end
local function getHeldTool(p, names)
    for _, container in ipairs({p.Character, p:FindFirstChildOfClass("Backpack")}) do
        for _, c in ipairs(container and container:GetChildren() or {}) do
            if c:IsA("Tool") and table.find(names, c.Name) then
                return c
            end
        end
    end
end
--[[ Chat / Whisper ]]--
local function wakeChat()
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) end)
    pcall(function() StarterGui:SetCore("ChatActive", true) end)
end
wakeChat()

local function channelSend(chan, msg)
    if not chan then return false end
    local ok, result = pcall(function()
        return chan:SendAsync(msg)
    end)
    if not ok or result == false then return false end
    -- Xeno/SendAsync often returns nil/true with no Status object — that still sent.
    if result == true or result == nil then return true end
    local st
    pcall(function() st = result.Status end)
    if st == nil then return true end
    local t0 = tick()
    while st == Enum.TextChatMessageStatus.Sending and tick() - t0 < 1.2 do
        task.wait(0.05)
        pcall(function() st = result.Status end)
    end
    if st == Enum.TextChatMessageStatus.Floodchecked then
        task.wait(1.6)
        ok, result = pcall(function()
            return chan:SendAsync(msg)
        end)
        if not ok or result == false then return false end
        if result == true or result == nil then return true end
        st = nil
        pcall(function() st = result.Status end)
        t0 = tick()
        while st == Enum.TextChatMessageStatus.Sending and tick() - t0 < 1.2 do
            task.wait(0.05)
            pcall(function() st = result.Status end)
        end
    end
    if st == Enum.TextChatMessageStatus.Success then return true end
    if st == Enum.TextChatMessageStatus.InvalidPrivacySettings then return false end
    if st == Enum.TextChatMessageStatus.InvalidTextChannelPermissions then return false end
    if st == Enum.TextChatMessageStatus.MessageTooLong then return false end
    -- Sending/Unknown after wait: do not claim success or /w fallback never runs.
    return false
end

local function sendLegacyPublic(msg)
    local events = RS:FindFirstChild("DefaultChatSystemChatEvents")
    local say = events and events:FindFirstChild("SayMessageRequest")
    if not say then return false end
    return pcall(function()
        say:FireServer(msg, "All")
    end)
end

local function getGeneralChannel()
    local tcs = rawTCS()
    local channels = tcs:FindFirstChild("TextChannels") or tcs:WaitForChild("TextChannels", 8)
    if not channels then return end
    return channels:FindFirstChild("RBXGeneral") or channels:WaitForChild("RBXGeneral", 8)
end

local function sendChat(msg)
    msg = tostring(msg or ""):match("^%s*(.-)%s*$") or ""
    if msg == "" then return false end
    wakeChat()
    local ch = getGeneralChannel()
    if channelSend(ch, msg) then return true end
    local bar
    pcall(function()
        bar = TCS:FindFirstChildOfClass("ChatInputBarConfiguration") or TCS:FindFirstChild("ChatInputBarConfiguration")
    end)
    local target = bar and bar.TargetTextChannel
    if target and target ~= ch and channelSend(target, msg) then return true end
    local folders = TCS:FindFirstChild("TextChannels")
    if folders then
        for _, c in ipairs(folders:GetChildren()) do
            if c:IsA("TextChannel") and c ~= ch and c.Name:find("General", 1, true) then
                if channelSend(c, msg) then return true end
            end
        end
    end
    if sendLegacyPublic(msg) then return true end
    return false
end

local function whisperChannelNameFor(uid)
    local a, b = tonumber(me.UserId), tonumber(uid)
    if not a or not b then return end
    if a > b then a, b = b, a end
    return ("RBXWhisper:%d_%d"):format(a, b)
end

G.MM_WhisperChan = G.MM_WhisperChan or {}

local function rememberWhisperChannel(uid, ch)
    uid = tonumber(uid)
    if not uid or not ch then return end
    local ok = pcall(function()
        return ch:IsA("TextChannel")
    end)
    if ok and ch.Parent then
        G.MM_WhisperChan[tostring(uid)] = ch
    end
end

local function textChannelFolders()
    local seen, out = {}, {}
    local raw = rawTCS()
    for _, tcs in ipairs({ raw, TCS }) do
        if tcs then
            local folder = tcs:FindFirstChild("TextChannels")
            if folder and not seen[folder] then
                seen[folder] = true
                table.insert(out, folder)
            end
        end
    end
    return out
end

local function findWhisperChannel(uid)
    uid = tostring(uid)
    local cached = G.MM_WhisperChan[uid]
    if cached and cached.Parent then return cached end
    local want = whisperChannelNameFor(uid)
    for _, channels in ipairs(textChannelFolders()) do
        if want then
            local exact = channels:FindFirstChild(want)
            if exact and exact:IsA("TextChannel") then
                G.MM_WhisperChan[uid] = exact
                return exact
            end
        end
        for _, ch in ipairs(channels:GetChildren()) do
            if ch:IsA("TextChannel") and tostring(ch.Name):find("RBXWhisper", 1, true)
               and tostring(ch.Name):find(uid, 1, true) then
                G.MM_WhisperChan[uid] = ch
                return ch
            end
        end
    end
end

local function sendOnWhisperChannel(ch, m)
    if not ch then return false end
    local ok = pcall(function()
        ch:SendAsync(m)
    end)
    return ok == true
end

local function deliverWhisper(o, m)
    m = tostring(m or "")
    if m == "" or not o or o == me then return false end
    wakeChat()
    local ch = findWhisperChannel(o.UserId)
    if sendOnWhisperChannel(ch, m) then return true end
    -- Do not /w DisplayName or /w on general. That prints "User ... doesn't exist".
    if isLegacy then
        local events = RS:FindFirstChild("DefaultChatSystemChatEvents")
        local say = events and events:FindFirstChild("SayMessageRequest")
        if say then
            return pcall(function()
                say:FireServer("/w " .. o.Name .. " " .. m, "All")
            end)
        end
    end
    return false
end

local function resolveWhisperTarget(target)
    local isInst = false
    if typeof then
        isInst = typeof(target) == "Instance"
    elseif type(target) == "userdata" then
        isInst = pcall(function() return target:IsA("Player") end)
    end
    if isInst and target:IsA("Player") then
        if target == me then return nil end
        return target
    end
    return findOwner()
end

local whisperQ, whisperBusy = {}, false
local function whisperNow(m, o, ownerOnly)
    m = tostring(m or "")
    if m == "" or not o or o == me then return false end
    if ownerOnly then
        local cur = findOwner()
        if not cur or cur.UserId ~= o.UserId then
            return false
        end
    end
    local ok, result = pcall(function()
        return deliverWhisper(o, m)
    end)
    if ok and result == true then
        for line in string.gmatch(m, "[^\n]+") do
            log("-> " .. o.Name .. ": " .. line)
        end
        return true
    end
    task.wait(0.45)
    ok, result = pcall(function()
        return deliverWhisper(o, m)
    end)
    if ok and result == true then
        for line in string.gmatch(m, "[^\n]+") do
            log("-> " .. o.Name .. ": " .. line)
        end
        return true
    end
    log("whisper failed: " .. m:gsub("\n", " / "))
    return false
end
local function pumpWhisperQ()
    if whisperBusy then return end
    whisperBusy = true
    task.spawn(function()
        while session.active do
            local job = table.remove(whisperQ, 1)
            if not job then break end
            if job.wait then
                task.wait(job.wait)
                job.done = true
            else
                local ok = whisperNow(job.m, job.t, job.ownerOnly)
                if not ok and type(job.alt) == "table" then
                    ok = false
                    for _, line in ipairs(job.alt) do
                        if whisperNow(line, job.t, job.ownerOnly) then ok = true end
                        task.wait(0.85)
                    end
                else
                    task.wait(0.85)
                end
                job.ok = ok == true
                job.done = true
            end
        end
        whisperBusy = false
        if whisperQ[1] then pumpWhisperQ() end
    end)
end
local function enqueueWhisper(m, target, waitDone)
    local explicit = false
    if typeof then
        explicit = typeof(target) == "Instance" and target:IsA("Player")
    elseif type(target) == "userdata" then
        explicit = pcall(function() return target:IsA("Player") end) and target:IsA("Player")
    end
    local o = resolveWhisperTarget(target)
    if not o or o == me then
        if not waitDone then log("whisper: no owner") end
        return false
    end
    local job = { m = tostring(m), t = o, done = false, ok = false, ownerOnly = not explicit }
    table.insert(whisperQ, job)
    pumpWhisperQ()
    if not waitDone then return true end
    local t0 = tick()
    while session.active and not job.done and tick() - t0 < 10 do
        task.wait(0.05)
    end
    return job.ok == true
end
local function flushWhisperQueue()
    for i = #whisperQ, 1, -1 do
        whisperQ[i] = nil
    end
end
local function clearAdoptedOwner(reason)
    if session.ownerId then
        pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end)
    end
    session.ownerId = nil
    G.MM_PendingOwnerId = nil
    G.MM_OwnerAdopted = false
    G.MM_OwnerReleased = true
    gunTargetId, gunDelivered = nil, false
    _G.MM_OwnerDiedPendingReset = false
    pcall(function() G.MM_ApplyOwnerDefaults() end)
    G.MM_AdoptAdRounds = 0
    flushWhisperQueue()
    if reason then log("owner cleared: " .. tostring(reason)) end
end
local function whisper(m, target)
    return enqueueWhisper(m, target, false)
end
local function whisperOk(m, target)
    return enqueueWhisper(m, target, true)
end
local function sendRoleLines(mLabel, sLabel, usePublic, target)
    local mLine = "Murder: " .. tostring(mLabel)
    local sLine = "Sheriff: " .. tostring(sLabel)
    if usePublic then
        task.spawn(function()
            sendChat(mLine)
            task.wait(0.85)
            sendChat(sLine)
        end)
        return true
    end
    local o = resolveWhisperTarget(target)
    if not o or o == me then
        log("reveal: no owner")
        return false
    end
    local ownerOnly = target == nil
    table.insert(whisperQ, { m = mLine, t = o, ownerOnly = ownerOnly })
    table.insert(whisperQ, { m = sLine, t = o, ownerOnly = ownerOnly })
    pumpWhisperQ()
    return true
end
local function channelLooksPrivate(name)
    name = tostring(name or "")
    if name == "" then return true end
    if name:find("RBXWhisper", 1, true) then return true end
    if name:sub(1, 3) == "To " then return true end
    return false
end

local hiddenChatEvent = nil
local function getHiddenChatEvent()
    if hiddenChatEvent and hiddenChatEvent.Parent then return hiddenChatEvent end
    local ok, events = pcall(function()
        return RS:WaitForChild("DefaultChatSystemChatEvents", 10)
    end)
    if not ok or not events then return end
    ok, hiddenChatEvent = pcall(function()
        return events:WaitForChild("OnMessageDoneFiltering", 10)
    end)
    if ok then return hiddenChatEvent end
end
task.spawn(getHiddenChatEvent)
local recentCommandKeys = {}
local function cleanChatText(msg)
    return tostring(msg or ""):gsub("[\n\r]", ""):gsub("\t", " "):gsub("[ ]+", " ")
end
local function extractCommandText(msg)
    msg = cleanChatText(msg)
    if msg == "" then return "" end
    msg = msg:gsub("^/w%s+%S+%s+", "")
    msg = msg:gsub("^/whisper%s+%S+%s+", "")
    msg = msg:gsub("^To%s+[^:]+:%s*", "")
    msg = msg:match("^%s*(.-)%s*$") or msg
    if msg:sub(1, 1) ~= "!" then return "" end
    return msg
end
local function isSelfPlayer(p)
    return p == me or (p and me and p.UserId == me.UserId)
end
local function seenCommandRecently(p, msg)
    msg = cleanChatText(msg):lower()
    if msg == "" then return true end
    if msg:sub(1, 1) ~= "!" then return false end
    local key = tostring(p.UserId) .. "\0" .. msg
    local now = tick()
    local last = recentCommandKeys[key]
    recentCommandKeys[key] = now
    if last and now - last < 15 then return true end
    task.delay(20, function()
        if recentCommandKeys[key] == now then
            recentCommandKeys[key] = nil
        end
    end)
    return false
end
local function showHiddenChat(p, msg)
    local text = "{SPY} [" .. (p.DisplayName or p.Name) .. "]: " .. msg
    log(text)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = text,
            Color = Color3.fromRGB(0, 255, 255),
            Font = Enum.Font.SourceSansBold,
            TextSize = 18,
        })
    end)
end

local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return body end
    local requestFn = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if not requestFn then return end
    ok, body = pcall(function()
        return requestFn({Url = url, Method = "GET"})
    end)
    if not ok or not body then return end
    return body.Body or body.body or body
end

local function httpJson(method, url, payload)
    local body = payload and Http:JSONEncode(payload) or nil
    local headers = {["Content-Type"] = "application/json"}
    local bridgeKey = (getgenv and getgenv().XENO_BRIDGE_KEY) or ""
    if bridgeKey ~= "" then headers["X-Xeno-Key"] = bridgeKey end
    local requestFn = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if requestFn then
        local ok, res = pcall(function()
            return requestFn({
                Url = url,
                Method = method,
                Headers = headers,
                Body = body,
            })
        end)
        if ok and res then
            local raw = res.Body or res.body or res
            if type(raw) == "string" and raw ~= "" then return raw end
        end
    end
    if method == "GET" and not body then
        return httpGet(url)
    end
end

local hopServer, getPingMs, queueRegionSpreadOnTeleport
do
local function queuePingSearchOnTeleport()
    local queueFn = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not queueFn then return end
    pcall(function()
        queueFn([[
pcall(function()
    local g = getgenv and getgenv() or _G
    g.MM_HopState = g.MM_HopState or {}
    g.MM_HopState.pingSearchActive = true
end)
]])
    end)
end

function queueRegionSpreadOnTeleport()
    local queueFn = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not queueFn then return end
    pcall(function()
        queueFn([[
pcall(function()
    local g = getgenv and getgenv() or _G
    g.MM_RegionSpreadCheck = true
end)
]])
    end)
end

local function queueOwnerPersistOnTeleport(ownerId)
    if not ownerId then return end
    local queueFn = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not queueFn then return end
    pcall(function()
        queueFn(([[
pcall(function()
    local g = getgenv and getgenv() or _G
    g.MM_PendingOwnerId = %d
    g.MM_OwnerAdopted = true
    g.MM_OwnerReleased = false
end)
]]):format(math.floor(ownerId)))
    end)
end

G.MM_HopSeenServers = G.MM_HopSeenServers or {}
G.MM_HopSeenHour = G.MM_HopSeenHour or os.date("!*t").hour

local function hopSeenResetIfNeeded()
    local h = tonumber(os.date("!*t").hour) or 0
    if tonumber(G.MM_HopSeenHour) ~= h then
        G.MM_HopSeenServers = {}
        G.MM_HopSeenHour = h
    end
end

local function hopIsSeen(serverId)
    hopSeenResetIfNeeded()
    local sid = tostring(serverId)
    for _, existing in ipairs(G.MM_HopSeenServers) do
        if tostring(existing) == sid then return true end
    end
    return false
end

local function hopMarkSeen(serverId)
    hopSeenResetIfNeeded()
    local sid = tostring(serverId)
    if hopIsSeen(sid) then return end
    table.insert(G.MM_HopSeenServers, sid)
end

function getPingMs()
    local ok, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    end)
    if ok and value then
        local n = tonumber(tostring(value):match("(%d+%.?%d*)"))
        if n then return n end
    end
    ok, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok then
        value = tonumber(value)
        if value then
            if value > 0 and value < 10 then return value * 1000 end
            return value
        end
    end
end

local function findHopServer()
    hopSeenResetIfNeeded()
    hopMarkSeen(game.JobId)
    local cursor, fallback = nil, nil
    local jobId = tostring(game.JobId)
    for _ = 1, 12 do
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        if cursor and cursor ~= "" then
            url = url .. "&cursor=" .. Http:UrlEncode(cursor)
        end
        local raw = httpGet(url)
        if not raw then break end
        local ok, page = pcall(function() return Http:JSONDecode(raw) end)
        if not ok or type(page) ~= "table" then break end
        for _, server in ipairs(page.data or {}) do
            local sid = server.id and tostring(server.id) or ""
            if sid ~= "" and sid ~= jobId and not hopIsSeen(sid) then
            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0
                if maxPlayers > playing then
                    if playing > 2 then
                        return sid
                    end
                    if not fallback then fallback = sid end
                end
            end
        end
        cursor = page.nextPageCursor
        if not cursor or cursor == "null" or cursor == nil then break end
    end
    return fallback
end

local function resolveHopServerId(targetServerId)
    if targetServerId and tostring(targetServerId) ~= "" then
        return tostring(targetServerId)
    end
    local serverId
    for _ = 1, 8 do
        serverId = findHopServer()
        if serverId then break end
        task.wait(0.4)
    end
    return serverId
end

function hopServer(reason, continuePingSearch, targetServerId)
    if hopBusy then return false end
    hopBusy = true
    stopFollow()
    if continuePingSearch then
        hopState.pingSearchActive = true
        queuePingSearchOnTeleport()
    else
        if session.ownerId and G.MM_OwnerAdopted then
            G.MM_PendingOwnerId = session.ownerId
            queueOwnerPersistOnTeleport(session.ownerId)
        end
        queueRegionSpreadOnTeleport()
    end
    log("server hop: " .. tostring(reason or "requested"))
    G.MM_ServerLocationJob = nil
    G.MM_ServerLocationCache = nil
    local serverId = resolveHopServerId(targetServerId)
    if not serverId then
        log("server hop: no server found")
        hopBusy = false
        return false
    end
    log("server hop: teleporting to " .. tostring(serverId))
    local ok = pcall(function()
        TeleportSvc:TeleportToPlaceInstance(game.PlaceId, serverId, me)
    end)
    if not ok then
        log("server hop failed")
        hopMarkSeen(serverId)
        hopBusy = false
        return false
    end
    hopMarkSeen(serverId)
    return true
end
end

--[[ Movement ]]--
local hrp, restoreStandBody, stopFollow, isFollowing, isSummoned, startFollowLoop, startSummonLoop, playBotEmote, commandTakesMove
do
local function unitAlive(p)
    local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
function hrp() return me.Character and me.Character:FindFirstChild("HumanoidRootPart") end
function restoreStandBody()
    local char = me.Character
    if not char then return end
    local track = G.MM_StandTrack
    if track then
        pcall(function() track:Stop(0.15) end)
        pcall(function() track:Destroy() end)
        G.MM_StandTrack = nil
    end
    G.MM_EmoteUntil = 0
    G.MM_StandEmoteOk = false
    pcall(function()
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Motor6D") then
                d.Transform = CFrame.new()
            end
        end
    end)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
                if tostring(tr.Name):find("MM_Stand", 1, true) then
                    tr:Stop(0.1)
                end
            end
            hum.PlatformStand = false
            hum.AutoRotate = true
            if hum.WalkSpeed < 1 then hum.WalkSpeed = 16 end
            if hum.JumpPower < 1 then hum.JumpPower = 50 end
            pcall(function() hum.EvaluateStateMachine = true end)
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
                hum.BreakJointsOnDeath = true
            end)
            if G.MM_StandGodConn then
                pcall(function() G.MM_StandGodConn:Disconnect() end)
                G.MM_StandGodConn = nil
            end
            if G.MM_StandDiedConn then
                pcall(function() G.MM_StandDiedConn:Disconnect() end)
                G.MM_StandDiedConn = nil
            end
            if G.MM_StandStateConn then
                pcall(function() G.MM_StandStateConn:Disconnect() end)
                G.MM_StandStateConn = nil
            end
            if G.MM_StandAnimConn then
                pcall(function() G.MM_StandAnimConn:Disconnect() end)
                G.MM_StandAnimConn = nil
            end
        end)
    end
    local saved = G.MM_AnimateFallSaved
    G.MM_AnimateFallSaved = nil
    if type(saved) == "table" then
        for _, e in ipairs(saved) do
            if e.inst and e.inst.Parent then
                pcall(function() e.inst.AnimationId = e.id end)
            end
        end
    end
    local anim = char:FindFirstChild("Animate")
    if anim then pcall(function() anim.Disabled = false end) end
    local hl = char:FindFirstChild("MM_StandAura")
    if hl then pcall(function() hl:Destroy() end) end
    local h = char:FindFirstChild("HumanoidRootPart")
    if h then
        for _, n in ipairs({"MM_StandHold", "MM_StandGyro", "MM_StandVel", "MM_StandAP", "MM_StandAO", "MM_StandAtt"}) do
            local o = h:FindFirstChild(n)
            if o then pcall(function() o:Destroy() end) end
        end
        pcall(function()
            h.Anchored = false
            h.CanCollide = true
        end)
    end
    pcall(function()
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 0
                if p.Name == "HumanoidRootPart" or p.Name == "Head" or p.Name == "Torso" or p.Name == "UpperTorso" then
                    p.CanCollide = true
                    p.CanTouch = true
                    p.CanQuery = true
                end
            elseif p:IsA("Decal") or p:IsA("Texture") then
                if p:GetAttribute("MM_Hid") then
                    p.Transparency = 0
                    p:SetAttribute("MM_Hid", nil)
                end
            end
        end
    end)
    local stash = me:FindFirstChild("MM_HiddenTools")
    if stash then
        local bag = me:FindFirstChildOfClass("Backpack")
        for _, t in ipairs(stash:GetChildren()) do
            pcall(function()
                t.Parent = bag or me
            end)
        end
        pcall(function() stash:Destroy() end)
    end
end

function stopFollow()
    local wasSummon = G.MM_SummonUserId ~= nil or G.MM_Hiding == true or G.MM_Parking == true
    G.MM_FollowUserId = nil
    G.MM_SummonUserId = nil
    G.MM_Hiding = false
    G.MM_Parking = false
    G.MM_StandLoopAlive = false
    G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
    if wasSummon then restoreStandBody() end
end
function commandTakesMove()
    G.MM_HoldMove = true
    G.MM_HoldStand = false
    G.MM_ForceHide = false
    G.MM_SummonFocusId = nil
    stopFollow()
end
G.MM_PauseStand = function()
    G.MM_StandPaused = true
    G.MM_Hiding = false
    G.MM_Parking = false
    G.MM_StandLoopAlive = false
    G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
    pcall(restoreStandBody)
end
G.MM_ResumeStand = function()
    G.MM_StandPaused = false
    if G.MM_EnsureAutoStand then task.defer(G.MM_EnsureAutoStand) end
end
local function standBusy()
    return G.MM_StandPaused or G.MM_FlingBusy or _G.MM_GunBusy or _G.MM_ShootBusy or _G.MM_StabBusy
end
function isFollowing()
    return G.MM_FollowUserId ~= nil or G.MM_SummonUserId ~= nil or G.MM_Hiding == true
end
function isSummoned()
    return G.MM_SummonUserId ~= nil
end
local function followSnap(p)
    local h = hrp()
    local t = p and p.Character and (p.Character:FindFirstChild("HumanoidRootPart") or p.Character.PrimaryPart)
    if not (h and t) then return false end
    pcall(function()
        h.Anchored = false
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
        h.CFrame = t.CFrame * CFrame.new(0, 0.1, 3)
        h.AssemblyLinearVelocity = Vector3.zero
    end)
    return true
end
function startFollowLoop()
    G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
    local gen = G.MM_FollowGen
    task.spawn(function()
        while session.active and gen == G.MM_FollowGen and G.MM_FollowUserId do
            local target = Players:GetPlayerByUserId(G.MM_FollowUserId)
            if not target then
                stopFollow()
                break
            end
            local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                followSnap(target)
            end
            task.wait(0.08)
        end
    end)
end

local function muteAnimateFalls(char)
    if not char or G.MM_AnimateFallSaved then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    local saved = {}
    for _, child in ipairs(animate:GetChildren()) do
        local n = child.Name:lower()
        if n:find("fall", 1, true) or n == "jump" or n == "jumpl"
            or n == "walk" or n == "run" or n == "swim" or n == "climb" then
            for _, a in ipairs(child:GetDescendants()) do
                if a:IsA("Animation") then
                    table.insert(saved, {inst = a, id = a.AnimationId})
                    pcall(function() a.AnimationId = "" end)
                end
            end
        end
    end
    G.MM_AnimateFallSaved = saved
end

local function standGroundHumanoid(hum, forceState)
    if not hum then return end
    pcall(function()
        hum.PlatformStand = false
        hum.AutoRotate = false
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        pcall(function() hum.JumpHeight = 0 end)
        pcall(function() hum.EvaluateStateMachine = false end)
        local block = {
            Enum.HumanoidStateType.Freefall,
            Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Jumping,
            Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.GettingUp,
            Enum.HumanoidStateType.Landed,
            Enum.HumanoidStateType.Swimming,
            Enum.HumanoidStateType.Climbing,
            Enum.HumanoidStateType.Flying,
            Enum.HumanoidStateType.Seated,
            Enum.HumanoidStateType.Physics,
            Enum.HumanoidStateType.Dead,
        }
        for i = 1, #block do
            pcall(function() hum:SetStateEnabled(block[i], false) end)
        end
        pcall(function()
            local np = Enum.HumanoidStateType.RunningNoPhysics
            if np then
                hum:SetStateEnabled(np, true)
                if forceState then hum:ChangeState(np) end
            end
        end)
    end)
end

local function stopFallTracks(hum)
    if not hum then return end
    pcall(function()
        for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
            local n = tostring(tr.Name):lower()
            local aid = ""
            pcall(function()
                aid = tostring(tr.Animation and tr.Animation.AnimationId or ""):lower()
            end)
            if n:find("fall", 1, true) or n:find("jump", 1, true) or n:find("walk", 1, true)
                or n:find("run", 1, true) or n:find("swim", 1, true) or n:find("climb", 1, true)
                or aid:find("fall", 1, true) then
                tr:Stop(0)
            end
        end
    end)
end

G.MM_StandNoclip = function(char)
    if not char then return end
    pcall(function()
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
                p.CanTouch = false
                p.CanQuery = false
            end
        end
    end)
end

G.MM_AuraPlaying = function(hum)
    if G.MM_StandTrack and G.MM_StandTrack.IsPlaying then return true end
    if not hum then return false end
    local found = false
    pcall(function()
        for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
            local n = tostring(tr.Name):lower()
            local aid = ""
            pcall(function()
                aid = tostring(tr.Animation and tr.Animation.AnimationId or ""):lower()
            end)
            local isAura = n:find("mm_stand", 1, true) or n:find("angelic", 1, true)
                or n:find("endless", 1, true) or n:find("aura", 1, true)
                or aid:find("124474822519936", 1, true)
            if not isAura then
                local pri
                pcall(function() pri = tr.Priority end)
                if (pri == Enum.AnimationPriority.Action4 or pri == Enum.AnimationPriority.Action)
                    and not (n:find("walk", 1, true) or n:find("run", 1, true)
                        or n:find("fall", 1, true) or n:find("jump", 1, true)
                        or n:find("idle", 1, true) or n:find("tool", 1, true)) then
                    isAura = true
                end
            end
            if isAura then
                found = true
                G.MM_StandTrack = tr
                pcall(function()
                    tr.Looped = true
                    tr.Priority = Enum.AnimationPriority.Action4
                end)
                return
            end
        end
    end)
    return found
end

local function applyStandMotors(char, now)
    if not char then return end
    local pulse = math.sin(now * 3.15) * 0.12
    local flex = math.sin(now * 1.7) * 0.08
    local map = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Motor6D") and d.Part1 then
            map[d.Part1.Name] = d
        end
    end
    local function pose(name, cf)
        local m = map[name]
        if m then m.Transform = cf end
    end
    pose("RightUpperArm", CFrame.Angles(math.rad(-18 + flex * 10), math.rad(22), math.rad(102 + pulse * 16)))
    pose("RightLowerArm", CFrame.Angles(math.rad(-42), math.rad(8), math.rad(-12)))
    pose("RightHand", CFrame.Angles(0, 0, math.rad(-18)))
    pose("LeftUpperArm", CFrame.Angles(math.rad(18), math.rad(-12), math.rad(-78 - pulse * 10)))
    pose("LeftLowerArm", CFrame.Angles(math.rad(-62), 0, math.rad(10)))
    pose("UpperTorso", CFrame.Angles(math.rad(-14), math.rad(-20), math.rad(8)))
    pose("LowerTorso", CFrame.Angles(math.rad(4), math.rad(-6), 0))
    pose("Head", CFrame.Angles(math.rad(-10), math.rad(24), math.rad(4)))
    pose("RightUpperLeg", CFrame.Angles(math.rad(12 + flex * 6), 0, math.rad(8)))
    pose("RightLowerLeg", CFrame.Angles(math.rad(-18), 0, 0))
    pose("LeftUpperLeg", CFrame.Angles(math.rad(14), 0, math.rad(-8)))
    pose("LeftLowerLeg", CFrame.Angles(math.rad(-16), 0, 0))
    pose("Right Arm", CFrame.Angles(math.rad(-28), math.rad(18), math.rad(105 + pulse * 14)))
    pose("Left Arm", CFrame.Angles(math.rad(12), math.rad(-6), math.rad(-82)))
    pose("Torso", CFrame.Angles(math.rad(-10), math.rad(-16), math.rad(6)))
    pose("Right Leg", CFrame.Angles(math.rad(8), 0, math.rad(6)))
    pose("Left Leg", CFrame.Angles(math.rad(10), 0, math.rad(-6)))
end

local function auraEmoteTargets(hum)
    local names, ids, seen = {"Endless Angelic Aura"}, {"124474822519936"}, {}
    local function addName(n)
        n = tostring(n or "")
        if n == "" or seen[n] then return end
        seen[n] = true
        table.insert(names, 1, n)
    end
    local function addId(id)
        id = tostring(id or ""):gsub("%D", "")
        if id ~= "" then table.insert(ids, id) end
    end
    local function takeEmotes(emotes)
        if type(emotes) ~= "table" then return end
        for emoteName, list in pairs(emotes) do
            local id = type(list) == "table" and list[1] or list
            local n = tostring(emoteName):lower()
            if n:find("angelic", 1, true) or n:find("endless", 1, true) or tostring(id) == "124474822519936" then
                addName(emoteName)
                addId(id)
            end
        end
    end
    pcall(function()
        local desc = hum:GetAppliedDescription() or me:GetAppliedDescription()
        if desc then takeEmotes(desc:GetEmotes()) end
    end)
    pcall(function() takeEmotes(hum:GetEmotes()) end)
    pcall(function()
        for _, slot in ipairs(hum:GetEquippedEmotes() or {}) do
            if type(slot) == "table" and slot.Name then
                local n = tostring(slot.Name):lower()
                if n:find("angelic", 1, true) or n:find("endless", 1, true) then
                    addName(slot.Name)
                end
            elseif type(slot) == "string" then
                local n = slot:lower()
                if n:find("angelic", 1, true) or n:find("endless", 1, true) then
                    addName(slot)
                end
            end
        end
    end)
    return names, ids
end

local function invokeAnimateEmote(char, emoteName)
    local animate = char and char:FindFirstChild("Animate")
    if not animate then return false end
    local ok = false
    pcall(function()
        local pf = animate:FindFirstChild("PlayEmote") or animate:FindFirstChild("playEmote")
        if pf and pf:IsA("BindableFunction") then
            local ret = pf:Invoke(emoteName)
            ok = ret ~= false
        elseif pf and pf:IsA("BindableEvent") then
            pf:Fire(emoteName)
            ok = true
        end
    end)
    return ok
end

local function tryStandAnimation(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    standGroundHumanoid(hum, not G.MM_StandEmoteOk)
    muteAnimateFalls(char)
    stopFallTracks(hum)
    if G.MM_AuraPlaying and G.MM_AuraPlaying(hum) then
        G.MM_StandEmoteOk = true
        return
    end
    local names, ids = auraEmoteTargets(hum)
    for _, emoteName in ipairs(names) do
        local named = false
        pcall(function()
            named = hum:PlayEmote(emoteName) == true
        end)
        if invokeAnimateEmote(char, emoteName) then
            named = true
        end
        if named then
            G.MM_EmoteUntil = tick() + 1e8
            G.MM_StandEmoteOk = true
            G.MM_StandEmoteName = emoteName
            stopFallTracks(hum)
            pcall(function()
                if G.MM_AuraPlaying then G.MM_AuraPlaying(hum) end
                local tr = G.MM_StandTrack
                if tr then
                    tr.Stopped:Connect(function()
                        if G.MM_SummonUserId then G.MM_StandEmoteOk = false end
                    end)
                end
            end)
            return
        end
    end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    local function playId(id)
        id = tostring(id or "")
        if id:find("%D") then
            -- keep rbxassetid://
        else
            id = "rbxassetid://" .. id
        end
        local anim = Instance.new("Animation")
        anim.Name = "MM_StandClip"
        anim.AnimationId = id
        local track
        local ok = pcall(function()
            track = animator:LoadAnimation(anim)
        end)
        if not ok or not track then
            anim:Destroy()
            return false
        end
        track.Looped = true
        track.Priority = Enum.AnimationPriority.Action4
        local played = pcall(function() track:Play(0.2, 1, 1) end)
        if played and track.IsPlaying then
            G.MM_StandTrack = track
            return true
        end
        pcall(function() track:Stop() end)
        anim:Destroy()
        return false
    end
    for _, id in ipairs(ids) do
        if playId(id) then
            G.MM_EmoteUntil = tick() + 1e8
            G.MM_StandEmoteOk = true
            return
        end
    end
end

local function weaponNameLooks(n)
    n = tostring(n or ""):lower()
    return n:find("knife", 1, true) or n:find("gun", 1, true) or n:find("revolver", 1, true)
        or n:find("luger", 1, true) or n:find("holster", 1, true) or n:find("sheath", 1, true)
        or n:find("blade", 1, true) or n:find("weapon", 1, true) or n:find("gundrop", 1, true)
end

local function hideClientVisual(inst)
    if not inst then return end
    pcall(function()
        if inst:IsA("BasePart") then
            inst.LocalTransparencyModifier = 1
            inst.Transparency = 1
            inst.CanCollide = false
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            inst.Transparency = 1
            inst:SetAttribute("MM_Hid", true)
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Fire") or inst:IsA("Smoke") then
            inst.Enabled = false
        elseif inst:IsA("Weld") or inst:IsA("WeldConstraint") or inst:IsA("Motor6D") then
            if weaponNameLooks(inst.Name) then
                inst.Enabled = false
            end
        end
    end)
end

local function hideWeaponTree(root)
    if not root then return end
    hideClientVisual(root)
    for _, d in ipairs(root:GetDescendants()) do
        hideClientVisual(d)
    end
    pcall(function()
        if root:IsA("Accessory") or (root:IsA("Model") and not root:IsA("Tool")) then
            root:Destroy()
        end
    end)
end

local function applyStandGod(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum.BreakJointsOnDeath = false
        hum.Health = hum.MaxHealth
    end)
    if G.MM_StandGodConn then
        pcall(function() G.MM_StandGodConn:Disconnect() end)
    end
    G.MM_StandGodConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not G.MM_SummonUserId or G.MM_StandPaused or G.MM_Resetting then return end
        if hum.Parent and hum.Health < hum.MaxHealth then
            pcall(function() hum.Health = hum.MaxHealth end)
        end
    end)
    trackConnection(G.MM_StandGodConn)
    if G.MM_StandDiedConn then
        pcall(function() G.MM_StandDiedConn:Disconnect() end)
    end
    G.MM_StandDiedConn = hum.Died:Connect(function()
        if not G.MM_SummonUserId or G.MM_StandPaused or G.MM_Resetting then return end
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.Health = hum.MaxHealth
            standGroundHumanoid(hum, true)
            G.MM_StandEmoteOk = false
            tryStandAnimation(char)
        end)
    end)
    trackConnection(G.MM_StandDiedConn)
end

local function hideBackWeapons(char, first)
    if not char then return end
    local stash = me:FindFirstChild("MM_HiddenTools")
    if not stash then
        stash = Instance.new("Folder")
        stash.Name = "MM_HiddenTools"
        stash.Parent = me
    end
    local bag = me:FindFirstChildOfClass("Backpack")
    if first then
        local hum = char:FindFirstChildOfClass("Humanoid")
        pcall(function()
            if hum then hum:UnequipTools() end
        end)
    end
    for _, bagRef in ipairs({ char, bag }) do
        if bagRef then
            for _, t in ipairs(bagRef:GetChildren()) do
                if t:IsA("Tool") then
                    hideWeaponTree(t)
                    pcall(function() t.Parent = stash end)
                end
            end
        end
    end
    local keep = {
        HumanoidRootPart = true, Torso = true, UpperTorso = true, LowerTorso = true,
        Head = true, Humanoid = true, Animate = true, MM_StandAura = true,
    }
    for _, d in ipairs(char:GetDescendants()) do
        if keep[d.Name] or d:IsA("Humanoid") or d:IsA("Highlight") then
            -- skip body
        else
            local n = d.Name
            local parentN = d.Parent and d.Parent.Name
            if weaponNameLooks(n) or weaponNameLooks(parentN) or d:IsA("Tool") then
                if d:IsA("Tool") or d:IsA("Accessory") or d:IsA("Model") then
                    hideWeaponTree(d)
                    pcall(function() d.Parent = stash end)
                else
                    hideClientVisual(d)
                    if d:IsA("BasePart") then
                        hideWeaponTree(d)
                    end
                end
            end
        end
    end
end

local function prepareStandBody(char)
    if not char then return end
    G.MM_AnimateFallSaved = nil
    local hum = char:FindFirstChildOfClass("Humanoid")
    standGroundHumanoid(hum, true)
    muteAnimateFalls(char)
    stopFallTracks(hum)
    hideBackWeapons(char, true)
    pcall(function()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
    applyStandGod(char)
    if G.MM_StandNoclip then G.MM_StandNoclip(char) end
    if G.MM_StandStateConn then
        pcall(function() G.MM_StandStateConn:Disconnect() end)
        G.MM_StandStateConn = nil
    end
    if G.MM_StandAnimConn then
        pcall(function() G.MM_StandAnimConn:Disconnect() end)
        G.MM_StandAnimConn = nil
    end
    if hum then
        G.MM_StandStateConn = hum.StateChanged:Connect(function()
            if not G.MM_SummonUserId or G.MM_StandPaused or G.MM_Resetting then return end
            standGroundHumanoid(hum)
            if G.MM_StandNoclip then G.MM_StandNoclip(char) end
            if not (G.MM_AuraPlaying and G.MM_AuraPlaying(hum)) then
                G.MM_StandEmoteOk = false
            end
        end)
        trackConnection(G.MM_StandStateConn)
        G.MM_StandAnimConn = hum.AnimationPlayed:Connect(function(tr)
            if not G.MM_SummonUserId or G.MM_StandPaused or G.MM_Resetting then return end
            local n = tostring(tr.Name):lower()
            if n:find("walk", 1, true) or n:find("run", 1, true) or n:find("fall", 1, true)
                or n:find("jump", 1, true) or n:find("swim", 1, true) or n:find("climb", 1, true) then
                pcall(function() tr:Stop(0) end)
                return
            end
            if G.MM_AuraPlaying then G.MM_AuraPlaying(hum) end
            if G.MM_StandTrack == tr then
                pcall(function()
                    tr.Stopped:Connect(function()
                        if G.MM_SummonUserId then G.MM_StandEmoteOk = false end
                    end)
                end)
            end
        end)
        trackConnection(G.MM_StandAnimConn)
    end
    tryStandAnimation(char)
    if not char:FindFirstChild("MM_StandAura") then
        pcall(function()
            local hl = Instance.new("Highlight")
            hl.Name = "MM_StandAura"
            hl.FillColor = Color3.fromRGB(170, 70, 255)
            hl.OutlineColor = Color3.fromRGB(255, 230, 255)
            hl.FillTransparency = 0.62
            hl.OutlineTransparency = 0.15
            hl.DepthMode = Enum.HighlightDepthMode.Occluded
            hl.Parent = char
        end)
    end
end

local function standHoverCFrame(ownerRoot, bornAt)
    local now = tick()
    local bob = math.sin(now * 1.55) * 0.12
    local rise = 1
    if bornAt then
        rise = math.clamp((now - bornAt) / 0.35, 0, 1)
    end
    return ownerRoot.CFrame
        * CFrame.new(3.35, 2.85 + bob + (1 - rise) * -2.2, 1.05)
        * CFrame.Angles(0, math.rad(16), 0)
end

local function summonSnap(p, bornAt, dt)
    local h = hrp()
    local t = p and p.Character and (p.Character:FindFirstChild("HumanoidRootPart") or p.Character.PrimaryPart)
    if not (h and t) then return false end
    local goal = standHoverCFrame(t, bornAt)
    local prev = G.MM_StandSmoothCF
    local use = goal
    if typeof(prev) == "CFrame" then
        local dist = (goal.Position - prev.Position).Magnitude
        if dist < 40 and not (bornAt and tick() - bornAt < 0.38) then
            local k = 13
            if dist > 8 then k = 18 elseif dist < 1.2 then k = 9 end
            local a = 1 - math.exp(-k * math.clamp(tonumber(dt) or 0.016, 1 / 240, 0.08))
            use = prev:Lerp(goal, a)
        end
    end
    G.MM_StandSmoothCF = use
    pcall(function()
        h.Anchored = false
        h.CFrame = use
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
        pcall(function()
            h.Velocity = Vector3.zero
            h.RotVelocity = Vector3.zero
        end)
    end)
    return true
end

function startSummonLoop(userId)
    G.MM_FollowUserId = nil
    G.MM_SummonUserId = userId
    G.MM_Hiding = false
    G.MM_StandLoopAlive = true
    G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
    local gen = G.MM_FollowGen
    local bornAt = tick()
    G.MM_StandEmoteOk = false
    G.MM_StandSmoothCF = nil
    prepareStandBody(me.Character)
    local lastChar
    local lastHide = 0
    local lastEmote = 0
    local lastGround = 0
    local hideConn
    local conn
    local physConn
    local function bindHide(char)
        if hideConn then
            pcall(function() hideConn:Disconnect() end)
            hideConn = nil
        end
        if not char then return end
        hideConn = char.DescendantAdded:Connect(function(d)
            if gen ~= G.MM_FollowGen then return end
            if d:IsA("Tool") or weaponNameLooks(d.Name) or weaponNameLooks(d.Parent and d.Parent.Name) then
                hideBackWeapons(char)
            end
        end)
        trackConnection(hideConn)
    end
    bindHide(me.Character)
    local function dropStandConns()
        if conn then
            pcall(function() conn:Disconnect() end)
            conn = nil
        end
        if physConn then
            pcall(function() physConn:Disconnect() end)
            physConn = nil
        end
        if hideConn then
            pcall(function() hideConn:Disconnect() end)
            hideConn = nil
        end
        if gen == G.MM_FollowGen then G.MM_StandLoopAlive = false end
    end
    local function hoverOnce(dt)
        if not session.active or gen ~= G.MM_FollowGen or not G.MM_SummonUserId then
            dropStandConns()
            return
        end
        local target = Players:GetPlayerByUserId(G.MM_SummonUserId)
        if not target then
            stopFollow()
            return
        end
        local char = me.Character
        if char and char ~= lastChar then
            lastChar = char
            G.MM_StandEmoteOk = false
            G.MM_StandSmoothCF = nil
            prepareStandBody(char)
            bindHide(char)
            lastEmote = 0
        end
        if G.MM_StandNoclip then G.MM_StandNoclip(char) end
        summonSnap(target, bornAt, dt)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if tick() - lastGround > 0.45 then
            lastGround = tick()
            stopFallTracks(hum)
            standGroundHumanoid(hum)
        end
        if tick() - lastHide > 0.35 then
            lastHide = tick()
            hideBackWeapons(char)
        end
        local playing = G.MM_AuraPlaying and G.MM_AuraPlaying(hum)
        if playing then
            G.MM_StandEmoteOk = true
        elseif G.MM_StandEmoteOk and tick() - lastEmote < 1.1 then
            -- PlayEmote just fired; wait for the track to show
        else
            G.MM_StandEmoteOk = false
            if tick() - lastEmote > 0.8 then
                lastEmote = tick()
                tryStandAnimation(char)
            end
        end
    end
    conn = RunSvc.Stepped:Connect(function(_, dt)
        hoverOnce(dt)
    end)
    physConn = RunSvc.Heartbeat:Connect(function()
        if not session.active or gen ~= G.MM_FollowGen or not G.MM_SummonUserId then
            dropStandConns()
            return
        end
        local h = hrp()
        local cf = G.MM_StandSmoothCF
        if h and typeof(cf) == "CFrame" then
            pcall(function()
                h.CFrame = cf
                h.AssemblyLinearVelocity = Vector3.zero
                h.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        if G.MM_StandNoclip then G.MM_StandNoclip(me.Character) end
    end)
    trackConnection(conn)
    trackConnection(physConn)
end

local function ownerInMap(owner)
    local t = owner and owner.Character and (owner.Character:FindFirstChild("HumanoidRootPart") or owner.Character.PrimaryPart)
    if t then return t.Position.Y < 430 end
    return G.MM_RoundLive == true
end

local function wantStandFollow(owner)
    if not owner then return false end
    if not unitAlive(owner) then return true end
    return not ownerInMap(owner)
end

local function startHideLoop()
    if G.MM_HoldMove or G.MM_HoldStand or standBusy() then return end
    G.MM_FollowUserId = nil
    G.MM_SummonUserId = nil
    G.MM_Hiding = true
    G.MM_StandLoopAlive = true
    G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
    local gen = G.MM_FollowGen
    restoreStandBody()
    local conn
    conn = RunSvc.Stepped:Connect(function()
        if G.MM_HoldMove or G.MM_HoldStand or standBusy() or not session.active or gen ~= G.MM_FollowGen or not G.MM_Hiding then
            G.MM_Hiding = false
            if conn then
                pcall(function() conn:Disconnect() end)
                conn = nil
            end
            if gen == G.MM_FollowGen then G.MM_StandLoopAlive = false end
            return
        end
        local h = hrp()
        local park = G.MM_UnderSpawn
        if not (h and park) then return end
        pcall(function()
            h.Anchored = false
            h.CFrame = park
            h.AssemblyLinearVelocity = Vector3.zero
            h.AssemblyAngularVelocity = Vector3.zero
            local char = me.Character
            if char then
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end)
    trackConnection(conn)
    log("stand: hiding under spawn")
end
G.MM_StartHideLoop = startHideLoop

local function startSpawnParkLoop()
    G.MM_FollowUserId = nil
    G.MM_SummonUserId = nil
    G.MM_Hiding = false
    G.MM_Parking = true
    G.MM_StandLoopAlive = true
    G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
    local gen = G.MM_FollowGen
    restoreStandBody()
    local lastEmote = 0
    local conn
    conn = RunSvc.Stepped:Connect(function()
        if not session.active or gen ~= G.MM_FollowGen or not G.MM_Parking or session.ownerId then
            if conn then
                pcall(function() conn:Disconnect() end)
                conn = nil
            end
            if gen == G.MM_FollowGen then G.MM_StandLoopAlive = false end
            return
        end
        local h = hrp()
        if not (h and SPAWN_CFRAME) then return end
        pcall(function()
            h.Anchored = false
            h.CFrame = SPAWN_CFRAME
            h.AssemblyLinearVelocity = Vector3.zero
            h.AssemblyAngularVelocity = Vector3.zero
        end)
        if playBotEmote and tick() - lastEmote > 8 then
            lastEmote = tick()
            pcall(function() playBotEmote("124474822519936") end)
        end
    end)
    trackConnection(conn)
    task.defer(function()
        if playBotEmote then pcall(function() playBotEmote("124474822519936") end) end
    end)
    log("stand: parking at spawn")
end

G.MM_EnsureAutoStand = function()
    if not G.MM_BootReady or not session.active or G.MM_Resetting then return end
    pcall(function()
        if G.MM_HoldMove or standBusy() then return end
        if G.MM_FollowUserId then return end
        if not unitAlive(me) then return end
        local function keepSummon(uid)
            uid = tonumber(uid)
            if not uid then return false end
            if G.MM_SummonUserId == uid and G.MM_StandLoopAlive then return true end
            local pl = Players:GetPlayerByUserId(uid)
            if not pl or pl == me then return false end
            log("stand: follow " .. pl.Name)
            startSummonLoop(uid)
            return true
        end
        if G.MM_HoldStand then
            if keepSummon(G.MM_SummonFocusId or G.MM_SummonUserId) then return end
            local owner = findOwner()
            if owner and keepSummon(owner.UserId) then return end
            return
        end
        local justAdopted = G.MM_AdoptAt and (tick() - tonumber(G.MM_AdoptAt) < 12)
        if justAdopted then
            local owner = findOwner()
            if owner and keepSummon(owner.UserId) then return end
        end
        local roundOn = G.MM_RoundLive == true
            or (G.MM_HasRoundRoles and G.MM_HasRoundRoles() == true)
        if G.MM_ForceHide or (roundOn and not justAdopted) then
            if not (G.MM_Hiding and G.MM_StandLoopAlive) then
                startHideLoop()
            end
            return
        end
        local owner = findOwner()
        if owner and owner ~= me and wantStandFollow(owner) then
            keepSummon(owner.UserId)
            return
        end
        if G.MM_Hiding and G.MM_StandLoopAlive then return end
        startHideLoop()
    end)
end
task.spawn(function()
    for _, d in ipairs({0.2, 0.7, 1.6, 3.2}) do
        task.wait(d)
        if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
    end
end)
pcall(function()
    trackConnection(Players.PlayerAdded:Connect(function(p)
        task.delay(0.15, function()
            if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
        end)
        pcall(function()
            trackConnection(p.CharacterAdded:Connect(function()
                task.delay(0.2, function()
                    if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
                end)
            end))
        end)
    end))
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            trackConnection(p.CharacterAdded:Connect(function()
                task.delay(0.2, function()
                    if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
                end)
            end))
        end)
    end
end)

local function playAnimAsset(hum, assetId, looped)
    assetId = tostring(assetId or ""):gsub("%D", "")
    if assetId == "" then return false end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    local anim = Instance.new("Animation")
    anim.Name = "MM_EmoteClip"
    anim.AnimationId = "rbxassetid://" .. assetId
    local track
    local ok = pcall(function()
        track = animator:LoadAnimation(anim)
    end)
    if not ok or not track then
        anim:Destroy()
        return false
    end
    track.Looped = looped == true
    track.Priority = Enum.AnimationPriority.Action4
    local played = pcall(function()
        track:Play(0.2, 1, 1)
    end)
    if played and track.IsPlaying then
        if G.MM_StandTrack then
            pcall(function() G.MM_StandTrack:Stop(0.1) end)
        end
        G.MM_StandTrack = track
        return true
    end
    pcall(function() track:Stop() end)
    anim:Destroy()
    return false
end

local function equippedEmoteMatch(hum, query)
    query = tostring(query or ""):lower()
    local desc
    pcall(function() desc = hum:GetAppliedDescription() end)
    if not desc then
        pcall(function() desc = me:GetAppliedDescription() end)
    end
    if not desc then return end
    local emotes
    pcall(function() emotes = desc:GetEmotes() end)
    if type(emotes) ~= "table" then return end
    local digits = query:gsub("%D", "")
    for emoteName, ids in pairs(emotes) do
        local id = type(ids) == "table" and ids[1] or ids
        local n = tostring(emoteName):lower()
        if n == query or n:find(query, 1, true) or (digits ~= "" and tostring(id) == digits) then
            return emoteName, id
        end
    end
end

function playBotEmote(name)
    name = tostring(name or ""):gsub("^/e%s+", ""):gsub("^rbxassetid://", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return false, "wave | dance | laugh | 124474822519936 | Endless Angelic Aura"
    end
    local char = me.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false, "No character" end
    local q = name:lower()
    local exact, assetId = equippedEmoteMatch(hum, q)
    if q:match("^%d+$") then
        assetId = assetId or q
    end
    G.MM_EmoteUntil = tick() + 12
    local played = false
    if exact then
        pcall(function()
            if hum:PlayEmote(exact) then played = true end
        end)
        if not played then
            pcall(function()
                if hum.PlayEmoteAsync then
                    hum:PlayEmoteAsync(exact)
                    played = true
                end
            end)
        end
    end
    if not played then
        pcall(function()
            if hum:PlayEmote(name) then played = true end
        end)
    end
    if not played and assetId and playAnimAsset(hum, assetId, true) then
        played = true
    end
    if not played and q:match("^%d+$") and playAnimAsset(hum, q, true) then
        played = true
    end
    pcall(function()
        local animate = char:FindFirstChild("Animate")
        local pf = animate and animate:FindFirstChild("PlayEmote")
        if pf and pf:IsA("BindableFunction") then
            pf:Invoke(exact or name)
        end
    end)
    if played then
        return true, exact or name
    end
    return false, exact or name
end
end
local GUN_MOTION_SAMPLE_SEC = 0.1
do
local GUN_DROP_PREDICT_SEC = 0.28
local GUN_RESET_LATENCY_SEC = 0.12
local GUN_PICKUP_FORWARD = 0.7
local gunPredState = {}
local function gunDropLead(root, hum, boost, observedVelocity, targetId, dt)
    if not root then return Vector3.zero end
    boost = boost or 1
    dt = dt or GUN_MOTION_SAMPLE_SEC

    local sid = targetId or 0
    local state = gunPredState[sid] or {smooth = Vector3.zero, last = Vector3.zero}
    gunPredState[sid] = state

    local v = root.AssemblyLinearVelocity
    if v.Magnitude < 1e-3 then v = root.Velocity end
    local vh = Vector3.new(v.X, 0, v.Z)
    local observed = observedVelocity and Vector3.new(observedVelocity.X, 0, observedVelocity.Z) or Vector3.zero
    if observed.Magnitude > 0.75 then
        vh = vh * 0.2 + observed * 0.8
    elseif vh.Magnitude < 2 then
        vh = Vector3.zero
    end
    if hum then
        local md = hum.MoveDirection
        if md.Magnitude > 0.05 then
            local moveVel = Vector3.new(md.X, 0, md.Z).Unit * math.max(10, math.min(hum.WalkSpeed, 20))
            vh = vh.Magnitude < 0.5 and moveVel or (vh * 0.65 + moveVel * 0.35)
        end
    end
    state.smooth = state.smooth * 0.55 + vh * 0.45
    local blended = state.smooth
    local spd = blended.Magnitude

    if spd <= 2.25 then
        local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        if facing.Magnitude > 0.05 then
            return facing.Unit * GUN_PICKUP_FORWARD
        end
        return Vector3.zero
    end

    local dir = blended.Unit
    local accel = (blended - state.last) / math.max(dt, 0.03)
    local ah = Vector3.new(accel.X, 0, accel.Z)
    local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    if look.Magnitude > 0.05 then
        dir = (dir * 0.75 + look.Unit * 0.25).Unit
    end
    local curve = 0
    if state.last.Magnitude > 0.75 then
        curve = math.clamp((1 - state.last.Unit:Dot(dir)) * 0.5, 0, 0.5)
    end
    local lookahead = (GUN_DROP_PREDICT_SEC + GUN_RESET_LATENCY_SEC) * (1 - curve)
    local lead = (spd * lookahead + GUN_PICKUP_FORWARD) * boost
    if ah.Magnitude > 1 then
        lead = lead + math.clamp(ah.Magnitude * 0.02, 0, 0.9)
    end
    lead = math.clamp(lead, 1.2, 7.5)
    state.last = blended
    return dir * lead
end
G.MM_gunDropLead = gunDropLead
end
-- Fling-only: stronger lookahead for ~15fps cap (velocity + Humanoid move intent).
local FLING_PREDICT_SEC = 0.22
local function flingApproachLead(root, hum)
    if not root then return Vector3.zero end
    local v = root.AssemblyLinearVelocity
    if v.Magnitude < 1e-3 then v = root.Velocity end
    if hum then
        local md = hum.MoveDirection
        if md.Magnitude > 0.05 then
            local hv = md * hum.WalkSpeed
            local vh = Vector3.new(v.X, 0, v.Z)
            local hm = Vector3.new(hv.X, 0, hv.Z)
            if hm.Magnitude > vh.Magnitude then
                v = hv
            elseif hm.Magnitude > 0.4 then
                v = vh + hm * 0.65
            end
        end
    end
    local vh = Vector3.new(v.X, 0, v.Z)
    local spd = vh.Magnitude
    if spd <= 0.08 then return Vector3.zero end
    local ahead = spd * FLING_PREDICT_SEC
    local snap = math.min(spd * 0.22, 7)
    return vh.Unit * math.min(snap + ahead, 18)
end

local revealAnnouncePending = false
local roleAnnounceUnlockAt = 0

local function isAlive(p)
    local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function tweenTo(cf, dur)
    local h = hrp(); if not h then return end
    local tw = Tween:Create(h, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
    tw:Play(); tw.Completed:Wait()
end
local function zeroVel(h)
    if not h then return end
    pcall(function() h.AssemblyLinearVelocity = Vector3.zero end)
    pcall(function() h.AssemblyAngularVelocity = Vector3.zero end)
    h.Velocity = Vector3.zero
    h.RotVelocity = Vector3.zero
end

-- MM2 gun is server-owned. Client CFrame of GunDrop does not pick it up.
;(function()
    local function fireTouch(a, b)
        if not (a and b) then return end
        local fti = rawget(G, "firetouchinterest") or rawget(_G, "firetouchinterest")
        if type(fti) ~= "function" then return end
        pcall(fti, a, b, 0)
        pcall(fti, a, b, 1)
        pcall(fti, b, a, 0)
        pcall(fti, b, a, 1)
    end
    local function firePrompt(inst)
        local fpp = rawget(G, "fireproximityprompt") or rawget(_G, "fireproximityprompt")
        if type(fpp) ~= "function" or not inst then return end
        if inst:IsA("ProximityPrompt") then
            pcall(fpp, inst)
            return
        end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("ProximityPrompt") then pcall(fpp, d) end
        end
    end
    local function sheriffFromData()
        local hero = G.MM_FindRole and G.MM_FindRole("Hero")
        if hero then return hero, "Hero" end
        local sher = G.MM_FindRole and G.MM_FindRole("Sheriff")
        if sher then return sher, "Sheriff" end
    end
    G.MM_GunWhere = function()
        if botHasGun() then return "Bot already has the gun" end
        local drop = findDroppedGun()
        if drop then
            local p = drop.Position
            return string.format("GunDrop at %.0f, %.0f, %.0f — grabbing", p.X, p.Y, p.Z)
        end
        local sher = findHolder(G.MM_GunNames)
        if sher then
            return "Gun is still on " .. shortName(sher) .. " — it only drops when they die"
        end
        local fromData, role = sheriffFromData()
        if fromData then
            return "Gun is on " .. shortName(fromData) .. " (" .. tostring(role):lower() .. ") — wait for drop"
        end
        return "No GunDrop in workspace — sheriff hasn't dropped it"
    end
    G.MM_GrabDroppedGun = function(timeout, force)
        if botHasGun() then return true end
        if not force and G.MM_BlockGunGrab then return false end
        timeout = timeout or 3.2
        G.MM_Hiding = false
        G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
        G.MM_StandLoopAlive = false
        pcall(restoreStandBody)
        local h = hrp()
        if not (h and isAlive(me)) then return false end
        local t0 = tick()
        local logged = false
        while session.active and tick() - t0 < timeout do
            if not isAlive(me) then return false end
            if not force and G.MM_BlockGunGrab then return false end
            if not force and tick() < (tonumber(G.MM_SkipGunUntil) or 0) then return false end
            if botHasGun() then return true end
            local drop = findDroppedGun()
            if not drop then
                task.wait(0.08)
            else
                if not logged then
                    logged = true
                    log(string.format("gun: grabbing GunDrop at %.0f, %.0f, %.0f", drop.Position.X, drop.Position.Y, drop.Position.Z))
                end
                h = hrp()
                if not h then return botHasGun() end
                pcall(function()
                    h.Anchored = false
                    h.CFrame = drop.CFrame + Vector3.new(0, 2.2, 0)
                    zeroVel(h)
                end)
                fireTouch(h, drop)
                firePrompt(drop)
                pcall(function()
                    local root = drop
                    while root.Parent and root.Parent ~= workspace do
                        root = root.Parent
                        firePrompt(root)
                    end
                end)
                task.wait(0.04)
            end
        end
        return botHasGun()
    end

    -- MM2 has no GiveGun / DropGun remote. GunDrop is server-spawned on sheriff/hero death.
    -- If GunDrop already exists, firetouch the TARGET onto it (no bot death).
    -- If the bot is holding the gun, only death creates GunDrop. CanBeDropped is almost always locked.
    task.spawn(function()
        local hits = {}
        pcall(function()
            for _, d in ipairs(RS:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    local n = d.Name:lower()
                    if n:find("gun", 1, true) or n:find("drop", 1, true) or n:find("give", 1, true)
                       or n:find("weapon", 1, true) then
                        table.insert(hits, d.ClassName .. " " .. d:GetFullName())
                    end
                end
            end
        end)
        if #hits > 0 then
            log("mm2 remotes: " .. table.concat(hits, " | "))
        else
            log("mm2 remotes: no Give/Drop/Gun remotes — death or GunDrop touch only")
        end
    end)

    local function touchCharacter(char, drop)
        if not (char and drop) then return end
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then fireTouch(p, drop) end
        end
        firePrompt(drop)
    end

    G.MM_DeliverDrop = function(target, timeout)
        timeout = timeout or 2.6
        if not isAlive(target) then return false end
        local t0 = tick()
        while session.active and tick() - t0 < timeout do
            if playerHas(target, G.MM_GunNames) then return true end
            if botHasGun() then return false end
            local drop = findDroppedGun()
            if not drop then return playerHas(target, G.MM_GunNames) end
            local th = target.Character and (target.Character:FindFirstChild("HumanoidRootPart") or target.Character.PrimaryPart)
            if th then
                pcall(function()
                    drop.CFrame = th.CFrame * CFrame.new(0, 1.4, 0)
                    drop.AssemblyLinearVelocity = Vector3.zero
                end)
            end
            touchCharacter(target.Character, drop)
            task.wait(0.05)
        end
        return playerHas(target, G.MM_GunNames)
    end

    local function pressBackspace()
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
            task.wait()
            vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
        end)
        pcall(function()
            local kp = rawget(G, "keypress") or rawget(_G, "keypress")
            local kr = rawget(G, "keyrelease") or rawget(_G, "keyrelease")
            if type(kp) == "function" then
                kp(0x08)
                task.wait()
                if type(kr) == "function" then kr(0x08) end
            end
        end)
    end

    local function setCanBeDropped(gun)
        pcall(function() gun.CanBeDropped = true end)
        pcall(function()
            if sethiddenproperty then sethiddenproperty(gun, "CanBeDropped", true) end
        end)
        pcall(function()
            if setscriptable then
                setscriptable(gun, "CanBeDropped", true)
                gun.CanBeDropped = true
            end
        end)
    end

    local function fireGunDropRemotes(gun)
        for _, d in ipairs(gun:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local n = d.Name:lower()
                if n:find("drop", 1, true) or n:find("throw", 1, true) or n:find("unequip", 1, true) then
                    log("gun: tool remote " .. d.ClassName .. " " .. d:GetFullName())
                    if d:IsA("RemoteEvent") then
                        pcall(function() d:FireServer() end)
                    else
                        pcall(function() d:InvokeServer() end)
                    end
                end
            end
        end
    end

    -- Engine drop only works while equipped. Backpack Unequip does not drop.
    -- Server CanBeDropped is almost always false; client set is local unless the engine accepts it.
    G.MM_ForceDropGun = function()
        local gun = getHeldTool(me, G.MM_GunNames)
        if not gun then return false end
        local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
        if gun.Parent ~= me.Character then
            pcall(function() hum:EquipTool(gun) end)
            task.wait(0.06)
            gun = getHeldTool(me, G.MM_GunNames)
            if not gun then return false end
        end
        log("gun: force-drop start CanBeDropped=" .. tostring(gun.CanBeDropped) .. " parent=" .. tostring(gun.Parent and gun.Parent.Name))
        fireGunDropRemotes(gun)
        setCanBeDropped(gun)
        if gun.Parent ~= me.Character then
            pcall(function() hum:EquipTool(gun) end)
            task.wait(0.04)
        end
        pressBackspace()
        task.wait(0.05)
        gun = getHeldTool(me, G.MM_GunNames)
        if gun then
            setCanBeDropped(gun)
            pcall(function() gun.Parent = workspace end)
        end
        local t0 = tick()
        while tick() - t0 < 0.6 do
            if findDroppedGun() then
                log("gun: force-drop created GunDrop")
                return true
            end
            if not botHasGun() then
                for _, o in ipairs(workspace:GetChildren()) do
                    if o:IsA("Tool") and table.find(G.MM_GunNames, o.Name) then
                        log("gun: force-drop left Tool in workspace")
                        return true
                    end
                end
            end
            task.wait(0.05)
        end
        if botHasGun() then
            log("gun: server rejected backpack drop (CanBeDropped locked)")
            return false
        end
        return findDroppedGun() ~= nil
    end
    G.MM_TryClientDrop = G.MM_ForceDropGun

    G.MM_DieInPlace = function()
        pcall(restoreStandBody)
        local char = me.Character
        if not char then return end
        local h = char:FindFirstChild("HumanoidRootPart")
        if G.MM_MarkIgnoreDrop then
            G.MM_MarkIgnoreDrop(h and h.Position, 8)
        else
            G.MM_BlockGunGrab = true
            G.MM_SkipGunUntil = tick() + 8
        end
        if h then
            pcall(function() h.Anchored = false end)
            zeroVel(h)
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                hum.BreakJointsOnDeath = true
                hum.Health = 0
            end)
            pcall(function() hum:TakeDamage(hum.MaxHealth * 2) end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
        end
        pcall(function() char:BreakJoints() end)
    end
end)()

--[[ Anti Fling ]]--
do
local antiFlingState = {enabled = false, conns = {}, lastSafe = nil, busyDepth = 0}
local function disconnectAntiFling()
    for _, c in ipairs(antiFlingState.conns) do
        pcall(function() c:Disconnect() end)
    end
    antiFlingState.conns = {}
end
local function bindAntiFlingForCharacter(char)
    disconnectAntiFling()
    if not antiFlingState.enabled or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end
    antiFlingState.lastSafe = root.CFrame
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = false
        end
    end
    for _, seatName in ipairs({"Seat1", "Seat2"}) do
        local seat = char:FindFirstChild(seatName)
        if seat then pcall(function() seat:Destroy() end) end
    end
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
    table.insert(antiFlingState.conns, RunSvc.Heartbeat:Connect(function()
        if not char.Parent then return end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = false
            end
        end
    end))
    table.insert(antiFlingState.conns, RunSvc.Heartbeat:Connect(function()
        if root.Position.Y < -100 or root.Position.Y > 400 then
            if antiFlingState.lastSafe then
                root.CFrame = antiFlingState.lastSafe
            end
        end
    end))
    table.insert(antiFlingState.conns, RunSvc.Heartbeat:Connect(function()
        if root.Velocity.Magnitude < 50 and root.RotVelocity.Magnitude < 50 then
            antiFlingState.lastSafe = root.CFrame
        end
    end))
    table.insert(antiFlingState.conns, RunSvc.Stepped:Connect(function()
        if root.Velocity.Magnitude > 50 then
            root.Velocity = Vector3.zero
        end
        if root.RotVelocity.Magnitude > 50 then
            root.RotVelocity = Vector3.zero
        end
    end))
end
local function enableAntiFling()
    if antiFlingState.enabled then return end
    antiFlingState.enabled = true
    if me.Character then bindAntiFlingForCharacter(me.Character) end
end
local function disableAntiFling()
    if not antiFlingState.enabled then return end
    antiFlingState.enabled = false
    disconnectAntiFling()
    local char = me.Character
    if char then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
        end
    end
end
local function actionBegin()
    antiFlingState.busyDepth = antiFlingState.busyDepth + 1
    if antiFlingState.busyDepth == 1 then
        disableAntiFling()
    end
end
local function actionEnd()
    antiFlingState.busyDepth = math.max(0, antiFlingState.busyDepth - 1)
    if antiFlingState.busyDepth == 0 then
        enableAntiFling()
    end
end
G.MM_ActionBegin = actionBegin
G.MM_ActionEnd = actionEnd
G.MM_AntiFlingShutdown = function()
    antiFlingState.busyDepth = 0
    disableAntiFling()
    disconnectAntiFling()
end
trackConnection(me.CharacterAdded:Connect(function(char)
    task.wait(0.15)
    if antiFlingState.enabled then
        bindAntiFlingForCharacter(char)
    end
end))
task.spawn(function()
    task.wait(0.2)
    if session.active then enableAntiFling() end
end)
end

local function stowKnife()
    if not botHasKnife() then return end
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:UnequipTools() end)
    end
    local knife = getHeldTool(me, {"Knife"})
    if knife and knife.Parent == me.Character then
        pcall(function() knife.Parent = me.Backpack end)
    end
end
function G.MM_StabBusyActive()
    if _G.MM_StabBusy and tick() <= tonumber(_G.MM_StabBusyUntil or 0) then
        return true
    end
    _G.MM_StabBusy = false
    _G.MM_StabBusyUntil = 0
    return false
end
function G.MM_BeginStabBusy(seconds)
    G.MM_ActionBegin()
    _G.MM_StabBusy = true
    _G.MM_StabBusyUntil = tick() + (seconds or 53)
end
function G.MM_EndStabBusy()
    _G.MM_StabBusy = false
    _G.MM_StabBusyUntil = 0
    G.MM_ActionEnd()
end
local function tpTo(p)
    if not _G.MM_StabBusy and me.Character and me.Character:FindFirstChild("Knife") then
        stowKnife()
    end
    local h, t = hrp(), p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if h and t then
        zeroVel(h)
        h.CFrame = t.CFrame + Vector3.new(0, 0, 3)
        zeroVel(h)
    end
end
local function tpHome()
    if isFollowing() then return end
    local h = hrp()
    if h and SPAWN_CFRAME then
        pcall(function() h.Anchored = false end)
        zeroVel(h)
        h.CFrame = SPAWN_CFRAME
        zeroVel(h)
    end
end
local function goSpawnWhenReady()
    task.spawn(function()
        for _ = 1, 24 do
            if not session.active then return end
            if G.MM_StandPaused or G.MM_FlingBusy then
                task.wait(0.12)
            else
                if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
                if isFollowing() then return end
                local owner = findOwner()
                if owner and owner ~= me then
                    task.wait(0.12)
                else
                    if hrp() then tpHome() end
                    return
                end
            end
        end
    end)
end
local function homeBurst()
    task.spawn(function()
        for _ = 1, 16 do
            if not session.active then return end
            if isFollowing() then return end
            if G.MM_StandPaused or G.MM_FlingBusy then return end
            local owner = findOwner()
            if owner and owner ~= me then
                if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
                return
            end
            if hrp() then tpHome() end
            task.wait(0.12)
        end
    end)
end
G.MM_HomeBurst = homeBurst
if me.Character then goSpawnWhenReady() end
trackConnection(me.CharacterAdded:Connect(function()
    G.MM_StandLoopAlive = false
    goSpawnWhenReady()
    task.spawn(function()
        for _, d in ipairs({0.2, 0.7, 1.5, 3.0}) do
            task.wait(d)
            if not session.active then return end
            if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
            if isFollowing() then return end
        end
    end)
end))
local function reset(stay)
    if G.MM_Resetting then return end
    G.MM_Resetting = true
    G.MM_StandPaused = true
    G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
    G.MM_StandLoopAlive = false
    G.MM_SummonUserId = nil
    G.MM_FollowUserId = nil
    G.MM_Hiding = false
    pcall(restoreStandBody)
    local rh = hrp()
    if G.MM_MarkIgnoreDrop then
        G.MM_MarkIgnoreDrop(rh and rh.Position, 12)
    else
        G.MM_BlockGunGrab = true
        G.MM_SkipGunUntil = tick() + 12
    end
    local function finishReset()
        G.MM_Resetting = false
        G.MM_StandPaused = false
        gunDelivered = false
        if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
    end
    if stay and G.MM_DieInPlace then
        G.MM_DieInPlace()
        task.delay(1.4, finishReset)
        return
    end
    local old = me.Character
    local function killNow(char)
        if not char then return end
        local h = char:FindFirstChild("HumanoidRootPart")
        if h then
            pcall(function()
                h.Anchored = false
                h.CanCollide = true
                h.CFrame = CFrame.new(0, -800, 0)
                h.AssemblyLinearVelocity = Vector3.new(0, -250, 0)
            end)
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                hum.BreakJointsOnDeath = true
                hum.Health = 0
            end)
            pcall(function() hum:TakeDamage(hum.MaxHealth * 4) end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
        end
        pcall(function() char:BreakJoints() end)
    end
    killNow(old)
    pcall(function() me:LoadCharacter() end)
    task.spawn(function()
        for _ = 1, 24 do
            task.wait(0.2)
            if me.Character and me.Character ~= old then
                break
            end
            killNow(me.Character or old)
            pcall(function() me:LoadCharacter() end)
        end
        finishReset()
    end)
end
G.MM_ResetBot = reset
local function runDeferredOwnerResetIfIdle()
    if not toggleResetOnOwnerDeath then
        _G.MM_OwnerDiedPendingReset = false
        return
    end
    if _G.MM_OwnerDiedPendingReset and not _G.MM_GunBusy and not G.MM_StabBusyActive() and not _G.MM_ShootBusy then
        local own = adoptedOwnerPlayer()
        if not ownerIsConfirmedDead(own) then
            _G.MM_OwnerDiedPendingReset = false
            return
        end
        _G.MM_OwnerDiedPendingReset = false
        log("owner died during combat -> resetting bot (" .. own.Name .. ")")
        task.spawn(function() pcall(reset) end)
    end
end
local function standOnTarget(target)
    stopFollow()
    if not isAlive(target) or not isAlive(me) then return false end
    local oh0 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local samplePos = oh0 and oh0.Position
    local sampleAt = tick()
    task.wait(0.08)
    local ok = false
    for _ = 1, 6 do
        local h = hrp()
        local oh = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        if not (h and oh and isAlive(target) and isAlive(me)) then return ok end
        local dt = math.max(tick() - sampleAt, 0.03)
        local observed = samplePos and (oh.Position - samplePos) / dt or Vector3.zero
        local lead = Vector3.zero
        pcall(function()
            lead = G.MM_gunDropLead(oh, hum, 0.85, observed, target.UserId, dt)
        end)
        if lead.Magnitude > 7 then
            lead = lead.Unit * 7
        end
        local dest = oh.Position + lead + Vector3.new(0, 0.2, 0)
        local look = dest + (lead.Magnitude > 0.25 and lead or oh.CFrame.LookVector)
        zeroVel(h)
        h.CFrame = CFrame.new(dest, look)
        zeroVel(h)
        samplePos, sampleAt = oh.Position, tick()
        ok = true
        task.wait(0.04)
    end
    return ok
end
local function settleAtSpawn()
    local park = G.MM_UnderSpawn or (SPAWN_CFRAME and SPAWN_CFRAME * CFrame.new(0, -34, 0))
    if not park or not isAlive(me) then return false end
    for _ = 1, 14 do
        local h = hrp()
        if h then
            pcall(function()
                h.Anchored = false
                h.CFrame = park
                h.AssemblyLinearVelocity = Vector3.zero
            end)
            if (h.Position - park.Position).Magnitude < 8 then
                return true
            end
        end
        task.wait(0.07)
    end
    return isAlive(me) and hrp() ~= nil
end
function G.MM_TargetHasGun(target)
    return target and playerHas(target, G.MM_GunNames)
end
function G.MM_WaitForGunPickup(target, timeout)
    local deadline = tick() + (timeout or 1.6)
    while tick() < deadline do
        if G.MM_TargetHasGun(target) then return true end
        task.wait(0.05)
    end
    return G.MM_TargetHasGun(target)
end
local function bringGun(target, force)
    if _G.MM_StabBusy then return false end
    local heldBusy = _G.MM_GunBusy == true
    _G.MM_GunBusy = true
    if G.MM_PauseStand then G.MM_PauseStand() end
    G.MM_ActionBegin()
    local function finish(ok)
        if not heldBusy then _G.MM_GunBusy = false end
        G.MM_ActionEnd()
        if G.MM_ResumeStand then G.MM_ResumeStand() end
        return ok
    end
    target = target or findOwner()
    if not isAlive(target) or not isAlive(me) then return finish(false) end
    local root = hrp()
    if root then
        pcall(function() root.Anchored = false end)
    end
    if G.MM_TargetHasGun(target) then return finish(true) end
    local drop = findDroppedGun()
    if not force and not drop and not botHasGun() then
        if G.MM_BlockGunGrab then return finish(false) end
        if tick() < (tonumber(G.MM_SkipGunUntil) or 0) then return finish(false) end
    end

    -- GunDrop on the map: touch it onto the target. Never pick it up / die.
    if drop and not botHasGun() then
        log("gun: delivering drop to " .. tostring(target.Name))
        if G.MM_DeliverDrop and G.MM_DeliverDrop(target, 2.6) then
            log("gun: delivered GunDrop without reset")
            return finish(true)
        end
        if G.MM_TargetHasGun(target) then return finish(true) end
        log("gun: drop still on map, staying alive")
        return finish(false)
    end

    -- Bot already holding the gun (sheriff/hero). Death is the only server drop.
    if not botHasGun() or not isAlive(target) or not isAlive(me) then return finish(false) end
    if not standOnTarget(target) then return finish(false) end
    if G.MM_DieInPlace then G.MM_DieInPlace() else reset(true) end
    return finish(G.MM_WaitForGunPickup(target, 2.1))
end
local function stashGunAtSpawn()
    G.MM_ActionBegin()
    if G.MM_PauseStand then G.MM_PauseStand() end
    local function finish(ok)
        G.MM_ActionEnd()
        if G.MM_ResumeStand then G.MM_ResumeStand() end
        return ok
    end
    if _G.MM_StabBusy then return finish(false) end
    local park = G.MM_UnderSpawn or (SPAWN_CFRAME and SPAWN_CFRAME * CFrame.new(0, -34, 0))
    if not park or not isAlive(me) then return finish(false) end
    local drop = findDroppedGun()
    if not drop and not botHasGun() then
        if G.MM_BlockGunGrab then return finish(false) end
        if tick() < (tonumber(G.MM_SkipGunUntil) or 0) then return finish(false) end
    end
    if drop and not botHasGun() then
        if (drop.Position - park.Position).Magnitude < 16 then
            return finish(true)
        end
    end
    if not botHasGun() then
        if not (G.MM_GrabDroppedGun and G.MM_GrabDroppedGun(2.8)) then
            return finish(false)
        end
        if not botHasGun() then return finish(false) end
    end
    if not settleAtSpawn() then return finish(false) end
    if G.MM_DieInPlace then G.MM_DieInPlace() else reset(true) end
    return finish(true)
end
local function ownerMurdererActive(murderer, ownerPlayer)
    return ownerPlayer and murderer and murderer.UserId == ownerPlayer.UserId
end
local function gunAvailableForOwnerMurdStash()
    if botHasGun() then return true end
    return findDroppedGun() ~= nil
end
local function equipTool(tool)
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if tool and hum and tool.Parent ~= me.Character then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.05)
    end
    return tool and tool.Parent == me.Character
end

--[[ Sheriff shoot. Remotes from spawn are ignored; fire from above the target. ]]--
do
    G.MM_ShootActive = false
    local function hitPos(target)
        local char = target and target.Character
        local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
        if not root then return end
        local vel = Vector3.zero
        pcall(function() vel = root.AssemblyLinearVelocity end)
        if math.abs(vel.Y) >= 10 then
            vel = Vector3.new(vel.X, 0, vel.Z)
        end
        return root.Position + vel / 40
    end
    local function addRemote(list, r)
        if not r then return end
        if not (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return end
        for i = 1, #list do
            if list[i] == r then return end
        end
        list[#list + 1] = r
    end
    local function collectShootRemotes(gun)
        local list = {}
        pcall(function()
            if gun then
                addRemote(list, gun:FindFirstChild("Shoot2", true))
                addRemote(list, gun:FindFirstChild("CreateBeam", true))
                addRemote(list, gun:FindFirstChild("ShootGun", true))
            end
            local we = RS:FindFirstChild("WeaponEvents")
            addRemote(list, we and we:FindFirstChild("GunBeam"))
            local cs = RS:FindFirstChild("ClientServices")
            local ws = cs and cs:FindFirstChild("WeaponService")
            addRemote(list, ws and ws:FindFirstChild("GunFired"))
        end)
        return list
    end
    local function fireOne(rf, ...)
        local args = { ... }
        if rf:IsA("RemoteEvent") then
            return pcall(function() rf:FireServer(unpack(args)) end)
        end
        return pcall(function() rf:InvokeServer(unpack(args)) end)
    end
    local function fireRemotes(gun, pos, origin)
        local ok = false
        for _, rf in ipairs(collectShootRemotes(gun)) do
            if fireOne(rf, 1, pos, "AH2") then ok = true end
            fireOne(rf, tick(), pos)
            if origin then fireOne(rf, origin, pos) end
        end
        return ok
    end
    local function callGunShoot(gun, pos, head)
        if not getsenv then return end
        pcall(function()
            for _, d in ipairs(gun:GetDescendants()) do
                if d:IsA("LocalScript") then
                    local env = getsenv(d)
                    if type(env) == "table" then
                        local fake = {Hit = CFrame.new(pos), Target = head, UnitRay = Ray.new(pos + Vector3.new(0, 12, 0), Vector3.new(0, -1, 0))}
                        if type(env.mouse) == "table" or type(env.mouse) == "userdata" then
                            pcall(function() env.mouse = fake end)
                        end
                        if type(env.Mouse) == "table" or type(env.Mouse) == "userdata" then
                            pcall(function() env.Mouse = fake end)
                        end
                        for k, v in pairs(env) do
                            if type(v) == "function" and tostring(k):lower():find("shoot", 1, true) then
                                pcall(v, pos)
                                pcall(v, 1, pos, "AH2")
                            end
                        end
                    end
                end
            end
        end)
    end
    local function shootOnce(target, gun)
        local pos = hitPos(target)
        if not pos then return false end
        local head = target.Character and target.Character:FindFirstChild("Head")
        local handle = gun:FindFirstChild("Handle")
        local origin = handle and handle.Position
        local h = hrp()
        local above = pos + Vector3.new(0, 12, 0)
        if h then
            pcall(function()
                h.Anchored = false
                zeroVel(h)
                h.CFrame = CFrame.new(above, pos)
                zeroVel(h)
            end)
        end
        if cam then
            pcall(function() cam.CFrame = CFrame.new(above, pos) end)
        end
        task.wait(0.04)
        origin = (handle and handle.Position) or above
        fireRemotes(gun, pos, origin)
        callGunShoot(gun, pos, head)
        pcall(function() gun:Activate() end)
        task.wait(0.08)
        tpHome()
        return true
    end
    local function resolveShootTarget(query)
        query = tostring(query or ""):match("^%s*(.-)%s*$") or ""
        local first = query:lower():match("^(%S+)") or ""
        if first == "" or first == "murder" or first == "murd" or first == "murderer" then
            local murd = (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
            if murd and murd ~= me then return murd, nil end
            return nil, "Murderer not found"
        end
        if first == "sheriff" or first == "sher" or first == "sherif" then
            local sher = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
                or (G.MM_FindRole and G.MM_FindRole("Hero"))
                or findHolder(G.MM_GunNames)
            if sher and sher ~= me then return sher, nil end
            return nil, "Sheriff not found"
        end
        local picked = findOtherPlayer(query)
        if not picked then return nil, "Player not found" end
        return picked, nil
    end
    local function shootTargetLoop(target)
        G.MM_ShootActive = true
        if G.MM_PauseStand then G.MM_PauseStand() end
        local function done(ok, msg)
            G.MM_ShootActive = false
            if G.MM_ResumeStand then G.MM_ResumeStand() end
            return ok, msg
        end
        if target == me then
            return done(false, "Can't shoot the bot")
        end
        if botHasKnife() then
            return done(false, "Bot is murderer — no gun")
        end
        local name = shortName(target)
        local deadline = tick() + 28
        while G.MM_ShootActive and tick() < deadline do
            if not Players:GetPlayerByUserId(target.UserId) then
                return done(false, name .. " left")
            end
            if not isAlive(target) then
                return done(true, "Shot " .. name)
            end
            if botHasKnife() or not isAlive(me) then
                return done(false, botHasKnife() and "Bot is murderer — no gun" or "Bot died")
            end
            if not botHasGun() then
                if G.MM_BlockGunGrab or not (G.MM_GrabDroppedGun and G.MM_GrabDroppedGun(2.5)) then
                    return done(false, "No gun available")
                end
            end
            local gun = getHeldTool(me, G.MM_GunNames)
            if not gun or not equipTool(gun) then
                return done(false, "No gun available")
            end
            pcall(function() shootOnce(target, gun) end)
            if not isAlive(target) then
                return done(true, "Shot " .. name)
            end
            local waitUntil = tick() + 2.15
            while G.MM_ShootActive and tick() < waitUntil do
                if not isAlive(target) then
                    return done(true, "Shot " .. name)
                end
                task.wait(0.08)
            end
        end
        if not isAlive(target) then return done(true, "Shot " .. name) end
        return done(false, "Shoot timed out")
    end
    function G.MM_CombatBusy()
        return G.MM_StabBusyActive() or _G.MM_GunBusy or _G.MM_ShootBusy
    end
    G.MM_ShootTargetLoop = shootTargetLoop
    G.MM_ResolveShootTarget = resolveShootTarget
    G.MM_EnsureShootGun = function()
        return botHasGun() or findDroppedGun() ~= nil
    end
end

local stabTargetLoop, stabAllTargets
do
local STAB_PREDICT_T = 0.12
local STAB_MAX_LEAD = 2.6
local STAB_MELEE_OFFSET = 1.05
local STAB_MOVE_MIN = 2
local STAB_IDLE_LOCAL = CFrame.new(-0.6, 0.08, 2.05)
local STAB_SETTLE_SEC = 0.04
local STAB_HOLD_SEC = 0.07
local STAB_POST_STAB_SEC = 0.11

local function getStabHorizontalVelocity(th, hum, lastPos, lastT)
    local v = th.AssemblyLinearVelocity
    if v.Magnitude < 1e-3 then v = th.Velocity end
    local blend = Vector3.new(v.X, 0, v.Z)
    if hum then
        local md = hum.MoveDirection
        if md.Magnitude > 0.04 then
            local mdVel = Vector3.new(md.X, 0, md.Z) * hum.WalkSpeed
            if blend.Magnitude < 0.4 then
                blend = mdVel
            else
                blend = blend * 0.45 + mdVel * 0.55
            end
        end
    end
    if lastPos and lastT then
        local dt = tick() - lastT
        if dt > 0.03 and dt < 0.4 then
            local ev = (th.Position - lastPos) / dt
            local emp = Vector3.new(ev.X, 0, ev.Z)
            if emp.Magnitude > 1.5 then
                if blend.Magnitude < 0.5 then
                    blend = emp
                else
                    blend = blend * 0.3 + emp * 0.7
                end
            end
        end
    end
    return blend
end

local function getStabCFrame(target, lastPos, lastT)
    local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not th then return end
    local anchor = th.Position + Vector3.new(0, 0.25, 0)
    local vel = getStabHorizontalVelocity(th, hum, lastPos, lastT)
    local spd = vel.Magnitude
    if spd >= STAB_MOVE_MIN then
        local dir = vel.Unit
        local lead = dir * math.min(spd * STAB_PREDICT_T, STAB_MAX_LEAD)
        local pred = anchor + lead
        local pos = pred + dir * STAB_MELEE_OFFSET
        return CFrame.new(pos, pred), th.Position
    end
    return th.CFrame * STAB_IDLE_LOCAL, th.Position
end

local function whisperCombatResult(msg)
    if not msg or msg == "" then return end
    if msg == "Bot died" then
        log("bot died")
        return
    end
    whisper(msg)
end

local function holdStabAt(target, mh, seconds)
    local deadline = tick() + seconds
    local lastPos
    while tick() < deadline do
        if not isAlive(target) or not isAlive(me) then return true end
        local cf, cur = getStabCFrame(target, lastPos, tick())
        if cf then
            lastPos = cur
            zeroVel(mh)
            mh.CFrame = cf
            zeroVel(mh)
        end
        task.wait(0.03)
    end
    return not isAlive(target)
end

local function slashKnife(knife, target)
    if not knife then return end
    local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
    local th = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    pcall(function()
        local ks = knife:FindFirstChild("KnifeServer")
        if ks and handle then
            local c = (handle.CFrame * CFrame.new(0, 1, 0)).Position
            local slash = ks:FindFirstChild("SlashStart")
            if slash then slash:FireServer(1, c) end
            local stab = ks:FindFirstChild("Stab")
            if stab then stab:FireServer() end
        end
        local stab2 = knife:FindFirstChild("Stab")
        if stab2 and stab2:IsA("RemoteEvent") then stab2:FireServer() end
        knife:Activate()
    end)
    local fti = rawget(G, "firetouchinterest") or rawget(_G, "firetouchinterest")
    if type(fti) == "function" and handle and th then
        pcall(fti, handle, th, 0)
        pcall(fti, handle, th, 1)
        pcall(fti, th, handle, 0)
        pcall(fti, th, handle, 1)
    end
end

local function stabPass(target, lastPos, lastT)
    if not isAlive(target) or not isAlive(me) then return false end
    if not botHasKnife() then return false end
    local knife = getHeldTool(me, {"Knife"})
    if not knife or not equipTool(knife) then return false end
    stopFollow()
    local cf, curPos = getStabCFrame(target, lastPos, lastT)
    local mh = hrp()
    if not (cf and mh) then return false end
    zeroVel(mh)
    mh.CFrame = cf
    zeroVel(mh)
    task.wait(STAB_SETTLE_SEC)
    if not isAlive(target) then return true, curPos end
    holdStabAt(target, mh, STAB_HOLD_SEC)
    slashKnife(knife, target)
    pcall(function() knife:Activate() end)
    if isAlive(target) then
        holdStabAt(target, mh, STAB_POST_STAB_SEC)
        if isAlive(target) then slashKnife(knife, target) end
    end
    local fresh = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    return true, (fresh and fresh.Position) or curPos
end

local STAB_TIMEOUT_SEC = 45

function stabTargetLoop(target)
    if target == me then return false, "Invalid target" end
    if not botHasKnife() then return false, "Bot needs to be murderer" end
    if not isAlive(target) then return false, "Player not found" end
    local started = tick()
    local lastPos, lastT
    while session.active and isAlive(me) and isAlive(target) and (tick() - started) < STAB_TIMEOUT_SEC do
        if not botHasKnife() then
            return false, "Bot needs to be murderer"
        end
        local ok, curPos = stabPass(target, lastPos, lastT)
        if not isAlive(target) then
            tpHome()
            stowKnife()
            return true, "Killed " .. shortName(target)
        end
        if not ok then
            return false, "Stab failed"
        end
        if curPos then lastPos, lastT = curPos, tick() end
        tpHome()
        if not isAlive(me) then
            log("bot died during stab")
            return false, "Bot died"
        end
        task.wait(0.42)
    end
    tpHome()
    if not isAlive(me) then
        log("bot died during stab")
        return false, "Bot died"
    end
    if not isAlive(target) then
        stowKnife()
        return true, "Killed " .. shortName(target)
    end
    if (tick() - started) >= STAB_TIMEOUT_SEC then
        log("stab timed out on " .. shortName(target))
        return true, "Stab timed out"
    end
    return true, "Stopped stabbing " .. shortName(target)
end

local function stabAllTargets()
    if not botHasKnife() then return false, "Bot needs to be murderer" end
    local killed, attempted = 0, 0
    for _, pl in ipairs(Players:GetPlayers()) do
        if not session.active or not botHasKnife() or not isAlive(me) then break end
        if pl ~= me and (not session.ownerId or pl.UserId ~= session.ownerId) and isAlive(pl) then
            attempted = attempted + 1
            local ok, msg = stabTargetLoop(pl)
            if msg and msg:find("Killed", 1, true) then
                killed = killed + 1
            end
            if not ok and msg == "Bot died" then
                return false, msg
            end
            task.wait(0.08)
        end
    end
    if attempted == 0 then return false, "No targets found" end
    if killed > 0 then return true, "Stabbed " .. tostring(killed) .. " player(s)" end
    return true, "Stab all finished"
end
end

--[[ Fling ]]--
local flingActive = false
local flingLoopGen = 0
local flingLoopActive = false
local flingLoopContinuous = false
local flingSettling = false
local cancelFlingWork, fling, waitFlingDone, runFlingLoop
do
function cancelFlingWork()
    flingLoopGen = flingLoopGen + 1
    flingLoopActive = false
    flingLoopContinuous = false
    flingActive = false
    flingSettling = false
    G.MM_FlingBusy = false
    G.MM_StandPaused = false
    if G.MM_EnsureAutoStand then
        task.defer(G.MM_EnsureAutoStand)
    end
end

local function snapFlingHome()
    local mh = hrp()
    if not mh then return false end
    local dest = G.MM_UnderSpawn or SPAWN_CFRAME
    pcall(function()
        mh.Anchored = false
        mh.AssemblyLinearVelocity = Vector3.zero
        mh.AssemblyAngularVelocity = Vector3.zero
        mh.Velocity = Vector3.zero
        mh.RotVelocity = Vector3.zero
        if dest then mh.CFrame = dest end
        mh.AssemblyLinearVelocity = Vector3.zero
        mh.Velocity = Vector3.zero
        mh.RotVelocity = Vector3.zero
    end)
    return dest and (mh.Position - dest.Position).Magnitude < 22
end

local function recoverAfterFling()
    flingSettling = true
    pcall(function()
        local mh = hrp()
        if mh then
            mh.AssemblyLinearVelocity = Vector3.zero
            mh.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    if isAlive(me) then
        snapFlingHome()
    else
        local t0 = tick()
        while tick() - t0 < 6 do
            if isAlive(me) and hrp() then break end
            task.wait(0.15)
        end
        if not (isAlive(me) and hrp()) then
            pcall(reset)
            local t1 = tick()
            while tick() - t1 < 5 do
                if isAlive(me) and hrp() then break end
                task.wait(0.15)
            end
        end
    end
    flingSettling = false
end

function fling(target, onDone)
    local onDoneFn = onDone
    if flingActive then
        if onDoneFn then onDoneFn(false) end
        return
    end
    if not isAlive(target) or not isAlive(me) then
        if onDoneFn then onDoneFn(false) end
        return
    end
    local mh0 = hrp()
    if not mh0 or mh0.Position.Y < -25 then
        snapFlingHome()
        if onDoneFn then onDoneFn(false) end
        return
    end
    flingActive = true
    G.MM_FlingBusy = true
    G.MM_StandPaused = true
    log("flinging " .. target.DisplayName)
    task.spawn(function()
        G.MM_ActionBegin()
        G.MM_FollowGen = (tonumber(G.MM_FollowGen) or 0) + 1
        G.MM_StandLoopAlive = false
        G.MM_SummonUserId = nil
        G.MM_Hiding = false
        pcall(restoreStandBody)
        local flung = false
        local okRun, errRun = pcall(function()
            local char = me.Character
            pcall(function()
                if char then
                    for _, part in ipairs(char:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = true end
                    end
                end
            end)
            local th0 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not th0 then return end
            local burstUntil = tick() + 0.42
            while flingActive and tick() < burstUntil and isAlive(target) and isAlive(me) do
                local mh = hrp()
                local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                local thum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if not (mh and th) then break end
                if mh.Position.Y < -25 then break end
                local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health < hum.MaxHealth * 0.35 then break end
                local lead = flingApproachLead(th, thum)
                pcall(function()
                    mh.Anchored = false
                    mh.CFrame = th.CFrame + lead
                    local punch = Vector3.new(14000, 10000, 14000)
                    mh.AssemblyLinearVelocity = punch
                    mh.AssemblyAngularVelocity = Vector3.new(9000, 9000, 9000)
                    mh.Velocity = punch
                    mh.RotVelocity = Vector3.new(9000, 9000, 9000)
                end)
                local tv = th.AssemblyLinearVelocity
                if tv.Magnitude < 1 then tv = th.Velocity end
                if tv.Magnitude > 450 then flung = true end
                task.wait()
            end
            snapFlingHome()
            task.wait()
            snapFlingHome()
        end)
        flingActive = false
        if not okRun then
            log("fling error: " .. tostring(errRun))
        else
            log(flung and "fling success" or "fling done")
        end
        if onDoneFn then
            onDoneFn(flung)
        elseif flung then
            whisper("Flung " .. shortName(target))
        end
        recoverAfterFling()
        G.MM_ActionEnd()
        if flingLoopContinuous then
            G.MM_FlingBusy = true
            G.MM_StandPaused = true
        else
            G.MM_FlingBusy = false
            G.MM_StandPaused = false
            if G.MM_EnsureAutoStand then
                G.MM_EnsureAutoStand()
                task.delay(0.35, function()
                    if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
                end)
                task.delay(1.1, function()
                    if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
                end)
            end
        end
    end)
end

function waitFlingDone(gen, timeout)
    local t0 = tick()
    while (flingActive or flingSettling) and tick() - t0 < (timeout or 25) do
        if gen ~= flingLoopGen then break end
        task.wait(0.03)
    end
end

local FLING_LOOP_MAX_SEC = 300

local function flingLoopTimedOut(loopBegan)
    return tick() - loopBegan >= FLING_LOOP_MAX_SEC
end

--- Between loop flings: retry fast on miss; on hit, short pause if still alive or wait for respawn if dead.
local function waitAfterLoopFling(target, gen, loopBegan, hadSuccess)
    if not target or not target.Parent then return end
    if flingLoopTimedOut(loopBegan) then return end
    if not hadSuccess then
        task.wait(0.55)
        return
    end
    task.wait(0.35)
    if not isAlive(target) then
        local t0 = tick()
        while gen == flingLoopGen and flingLoopActive and session.active and not flingLoopTimedOut(loopBegan) do
            if not target.Parent then return end
            if isAlive(target) and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                break
            end
            if tick() - t0 > 40 then break end
            task.wait(0.12)
        end
        task.wait(0.25)
    else
        task.wait(0.85)
    end
end

function runFlingLoop(mode, playerQuery, gen, continuousLoop)
    task.spawn(function()
        if mode == "all" then
            local targets = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= me and (not session.ownerId or pl.UserId ~= session.ownerId) then
                    table.insert(targets, pl)
                end
            end
            for i, tgt in ipairs(targets) do
                if gen ~= flingLoopGen or not flingLoopActive or not session.active then break end
                if isAlive(tgt) and isAlive(me) then
                    fling(tgt, function(ok)
                        if ok and flingLoopActive and gen == flingLoopGen then
                            whisper("Flung " .. shortName(tgt))
                        end
                    end)
                    waitFlingDone(gen, 25)
                    if i < #targets and gen == flingLoopGen and flingLoopActive then
                        task.wait(0.5)
                    end
                end
            end
            if gen == flingLoopGen then
                flingLoopActive = false
                flingLoopContinuous = false
                G.MM_FlingBusy = false
                G.MM_StandPaused = false
                if G.MM_EnsureAutoStand then task.defer(G.MM_EnsureAutoStand) end
            end
            return
        end

        local loopTargetUserId = nil
        local function collectTargets()
            local targets = {}
            if mode == "sheriff" then
                local s = findHolder(G.MM_GunNames)
                if s and s ~= me then table.insert(targets, s) end
            elseif mode == "murder" then
                local murd = findHolder({"Knife"})
                if murd and murd ~= me then table.insert(targets, murd) end
            else
                if loopTargetUserId then
                    local pl = Players:GetPlayerByUserId(loopTargetUserId)
                    if pl and pl ~= me then table.insert(targets, pl) end
                else
                    local t = findOtherPlayer(playerQuery)
                    if t then table.insert(targets, t) end
                end
            end
            return targets
        end

        if not continuousLoop then
            local targets = collectTargets()
            for i, tgt in ipairs(targets) do
                if gen ~= flingLoopGen or not flingLoopActive or not session.active then break end
                if isAlive(tgt) and isAlive(me) then
                    fling(tgt, function(ok)
                        if ok and flingLoopActive and gen == flingLoopGen then
                            whisper("Flung " .. shortName(tgt))
                        end
                    end)
                    waitFlingDone(gen, 25)
                    if i < #targets and gen == flingLoopGen and flingLoopActive then
                        task.wait(0.5)
                    end
                end
            end
            if gen == flingLoopGen then
                flingLoopActive = false
                flingLoopContinuous = false
                G.MM_FlingBusy = false
                G.MM_StandPaused = false
                if G.MM_EnsureAutoStand then task.defer(G.MM_EnsureAutoStand) end
            end
            return
        end

        local loopBegan = tick()
        while session.active and gen == flingLoopGen and flingLoopActive do
            if flingLoopTimedOut(loopBegan) then
                whisper("Fling loop stopped")
                cancelFlingWork()
                return
            end
            if mode == "player" and loopTargetUserId and not Players:GetPlayerByUserId(loopTargetUserId) then
                whisper("Fling target left")
                cancelFlingWork()
                return
            end
            if not isAlive(me) then
                task.wait(0.5)
            else
                local targets = collectTargets()
                if #targets == 0 then
                    task.wait(0.6)
                else
                    for _, tgt in ipairs(targets) do
                        if gen ~= flingLoopGen or not flingLoopActive or flingLoopTimedOut(loopBegan) then break end
                        if mode == "player" and not loopTargetUserId and tgt.UserId then
                            loopTargetUserId = tgt.UserId
                        end
                        if isAlive(tgt) then
                            local lastOk = false
                            fling(tgt, function(ok)
                                lastOk = ok
                            end)
                            waitFlingDone(gen, 25)
                            if gen ~= flingLoopGen or not flingLoopActive then break end
                            waitAfterLoopFling(tgt, gen, loopBegan, lastOk)
                        elseif mode == "player" and loopTargetUserId then
                            task.wait(0.45)
                        end
                    end
                end
            end
            if gen == flingLoopGen and flingLoopActive then
                task.wait(0.15)
            end
        end
        if gen == flingLoopGen then
            flingLoopActive = false
            flingLoopContinuous = false
            G.MM_FlingBusy = false
            G.MM_StandPaused = false
            if G.MM_EnsureAutoStand then task.defer(G.MM_EnsureAutoStand) end
        end
    end)
end
end

--[[ Round ]]--
local function isRoundActive()
    if G.MM_HasRoundRoles and G.MM_HasRoundRoles() then return true end
    return findHolder({"Knife"}) or findHolder(G.MM_GunNames)
        or botHasKnife() or botHasGun()
end

local function getAliveExcludingBot()
    local list = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= me and isAlive(pl) then
            table.insert(list, pl)
        end
    end
    return list
end

--[[ Commands ]]--
local COMMAND_HELP = {
    owner = "Show who currently owns the bot",
    adopt = "Claim the bot if nobody owns it",
    unadopt = "Release the bot so someone else can !adopt",
    reveal = "[player] - Whisper murderer and sheriff (optionally to someone else)",
    stab = "all | sheriff | <name> - Murderer only, stab targets",
    shoot = "murderer | sheriff | <name> - Silent aim (hit-pos), stays put",
    togglereveal = "Toggle automatic role callout each round",
    togglealerts = "Toggle kill alerts (ignores resets)",
    togglereset = "Toggle auto-reset when owner dies (on by default)",
    toggledrop = "Toggle stashing guns when you are murderer",
    drop = "Stash gun at spawn (touch-drop if possible, else die in place)",
    reset = "Force bot respawn",
    tp = "<player> - Teleport bot to a player",
    tpmurd = "Teleport bot to the murderer",
    tpsher = "Teleport bot to the sheriff",
    spawn = "Teleport bot to spawn",
    home = "Same as !spawn",
    hide = "Stay under the map until !summon",
    summon = "[player] - Stand follow you, or a player",
    unsummon = "Same as !hide",
    emote = "<name|id> - Play an equipped emote (Endless Angelic Aura / 124474822519936)",
    gun = "<player> - Give GunDrop via touch if dropped; else die-in-place (no GiveGun remote)",
    togglegun = "<player> - Auto-deliver gun to a player",
    toggleshoot = "[murderer | name] - Auto-grab dropped gun and silent-aim shoot",
    chat = "<msg> - Make bot send a public chat message",
    fling = "<player> - Flings player off the map",
    help = "<cmd> - Show command list or explain one command",
}
local HELP_ORDER = {
    "owner", "adopt", "unadopt", "tp", "tpmurd", "tpsher", "reveal", "stab", "shoot", "gun", "drop", "fling",
    "togglegun", "toggleshoot", "togglereveal", "togglealerts", "togglereset", "toggledrop",
    "reset", "spawn", "hide", "summon", "unsummon", "emote", "chat", "help",
}
local PREMIUM_ONLY_COMMANDS = {
    togglereset = true,
    toggledrop = true,
    togglegun = true,
    toggleshoot = true,
    togglereveal = true,
    togglealerts = true,
    fling = true,
    chat = true,
}

local function ownerIsPremium()
    return true
end

local function helpKeysForOwner()
    local keys = {}
    for _, k in ipairs(HELP_ORDER) do
        table.insert(keys, k)
    end
    local out = {}
    for _, k in ipairs(keys) do
        table.insert(out, k)
    end
    return out
end

local function isPremiumOnlyCommand(cmd)
    return PREMIUM_ONLY_COMMANDS[cmd] == true
end

local function sendFullHelp(target, gapBetween, replyFn)
    gapBetween = gapBetween or 0.5
    replyFn = replyFn or whisper
    local uid
    if type(target) == "number" then
        uid = target
    elseif target and typeof(target) == "Instance" and target:IsA("Player") then
        uid = target.UserId
    end
    local function resolve()
        if uid then return Players:GetPlayerByUserId(uid) end
        return findOwner()
    end
    local o
    for _ = 1, 15 do
        o = resolve()
        if o then break end
        task.wait(0.2)
    end
    if not o then return end
    replyFn("Use !help <command> for what a command does", o)
    if gapBetween > 0 then task.wait(gapBetween) end
    o = resolve()
    if not o then
        for _ = 1, 12 do
            task.wait(0.15)
            o = resolve()
            if o then break end
        end
    end
    if not o then return end
    local keys = helpKeysForOwner()
    local line = "cmds: " .. table.concat(keys, "  ")
    if #line <= 200 then
        replyFn(line, o)
        return
    end
    local mid = math.ceil(#keys / 2)
    local a, b = {}, {}
    for i, key in ipairs(keys) do
        if i <= mid then table.insert(a, key) else table.insert(b, key) end
    end
    replyFn("cmds: " .. table.concat(a, "  "), o)
    if gapBetween > 0 then task.wait(gapBetween) end
    o = resolve()
    if not o then
        for _ = 1, 12 do
            task.wait(0.15)
            o = resolve()
            if o then break end
        end
    end
    if o then replyFn("cmds: " .. table.concat(b, "  "), o) end
end

local ownerOnboardingGen = 0

local function resolveOwnerPlayer(userId)
    if session.ownerId ~= userId then return nil end
    return Players:GetPlayerByUserId(userId)
end

local function ownerAnnouncementText(owner)
    local msg = ANNOUNCEMENT_MESSAGE
    if msg == "" or not owner then return "" end
    local username = tostring(owner.Name or XENO_OWNER_USERNAME or "")
    local display = tostring(owner.DisplayName or username)
    msg = msg:gsub("{owner}", username)
    msg = msg:gsub("{username}", username)
    msg = msg:gsub("{display_name}", display)
    msg = msg:gsub("'%.%.%.'", "'" .. username .. "'")
    return msg:gsub("%.%.%.", username)
end

local function deliverOwnerLine(userId, msg, attempts, step)
    attempts = attempts or 3
    step = step or 0.55
    for _ = 1, attempts do
        if session.ownerId ~= userId then return false end
        local o = resolveOwnerPlayer(userId)
        if o and whisperOk(msg, o) then return true end
        task.wait(step)
    end
    return false
end

local function sendFullHelpToOwner(userId, gapBetween)
    gapBetween = gapBetween or 0.75
    if session.ownerId ~= userId then return false end

    if not deliverOwnerLine(userId, "Use !help <command> for what a command does", 3, 0.55) then
        return false
    end
    task.wait(gapBetween)

    local keys = helpKeysForOwner()
    local line = "cmds: " .. table.concat(keys, "  ")
    if #line <= 200 then
        return deliverOwnerLine(userId, line, 3, 0.55)
    end

    local mid = math.ceil(#keys / 2)
    local a, b = {}, {}
    for i, key in ipairs(keys) do
        if i <= mid then table.insert(a, key) else table.insert(b, key) end
    end
    if not deliverOwnerLine(userId, "cmds: " .. table.concat(a, "  "), 3, 0.55) then return false end
    task.wait(gapBetween)
    return deliverOwnerLine(userId, "cmds: " .. table.concat(b, "  "), 3, 0.55)
end

local function syncOwnerPremiumFromClaim(claim)
    G.MM_OwnerPremium = true
end

scheduleOwnerOnboarding = function(userId)
    ownerOnboardingGen = ownerOnboardingGen + 1
    local gen = ownerOnboardingGen
    task.spawn(function()
        task.wait(1.1)
        if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end
        local o
        for _ = 1, 40 do
            if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end
            o = resolveOwnerPlayer(userId)
            if o then break end
            task.wait(0.12)
        end
        if not o then
            log("onboarding: owner player not found")
            return
        end
        log("new owner: " .. o.DisplayName)
        local announcement = ownerAnnouncementText(o)
        if announcement ~= "" then
            sendChat(announcement)
        end

        if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end

        if not sendFullHelpToOwner(userId, 0.75) then
            log("onboarding: help whisper failed")
        end

    end)
end

task.spawn(function()
    if session.active and session.ownerId then
        local o = findOwner()
        if o then
            log("startup: owner " .. o.Name)
            return
        end
    end
    if session.active and not session.ownerId and G.MM_SendAdoptAd then
        G.MM_AdoptAdRounds = 0
        G.MM_SendAdoptAd()
    end
end)

local function ownerLabel(pl)
    if not pl then return "?" end
    local dn = tostring(pl.DisplayName or "")
    if dn ~= "" and dn:lower() ~= pl.Name:lower() then
        return dn .. " (@" .. pl.Name .. ")"
    end
    return pl.Name
end

local function setAdoptedOwner(pl)
    if session.ownerId and session.ownerId ~= pl.UserId then
        pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end)
    end
    session.ownerId = pl.UserId
    G.MM_PendingOwnerId = pl.UserId
    G.MM_OwnerAdopted = true
    G.MM_OwnerReleased = false
    _G.MM_OwnerDiedPendingReset = false
    pcall(function() G.MM_LoadOwnerPrefs(pl.UserId) end)
    G.MM_AdoptAdRounds = 0
    G.MM_ForceHide = false
    G.MM_HoldMove = false
    G.MM_AdoptAt = tick()
    scheduleOwnerOnboarding(pl.UserId)
    if G.MM_EnsureAutoStand then
        task.defer(G.MM_EnsureAutoStand)
    end
end

local function handleCommand(p, msg, viaPublic)
    if msg:sub(1, 1) ~= "!" then return end
    local args = splitChatArgs(msg)
    if not args[1] or args[1]:sub(1, 1) ~= "!" then return end
    local cmd, rest = args[1]:sub(2):lower(), msg:sub(#args[1] + 2)
    if cmd == "" or (cmd ~= "dethrone" and not COMMAND_HELP[cmd]) then
        return
    end
    local privateWhisper = whisper
    local function whisper(m, target)
        if viaPublic then
            sendChat(m)
            return true
        end
        privateWhisper(m, target or p)
        return true
    end
    if cmd == "owner" then
        local cur = findOwner()
        if cur then
            whisper("Owner: " .. ownerLabel(cur))
        else
            whisper("No owner — !adopt to claim")
        end
        return
    elseif cmd == "adopt" then
        local cur = findOwner()
        if cur then
            if cur.UserId == p.UserId then
                whisper("Already adopted")
            else
                whisper("Already adopted by " .. ownerLabel(cur))
            end
            return
        end
        setAdoptedOwner(p)
        whisper("Adopted — you are owner")
        return
    elseif cmd == "unadopt" or cmd == "dethrone" then
        if not session.ownerId or p.UserId ~= session.ownerId then
            whisper("You are not the owner")
            return
        end
        ownerOnboardingGen = ownerOnboardingGen + 1
        clearAdoptedOwner("unadopt")
        G.MM_HoldMove = false
        G.MM_HoldStand = false
        G.MM_ForceHide = true
        G.MM_SummonFocusId = nil
        stopFollow()
        whisper("Unadopted — !adopt to claim")
        if G.MM_SendAdoptAd then G.MM_SendAdoptAd() end
        if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
        return
    end
    if not authorizeCommand(p) then
        return
    end
    if flingLoopContinuous and cmd ~= "fling" then
        whisper('You need to toggle off fling loop using "!fling"')
        return
    end
    if cmd == "fling" then
        local raw = restOfChatArgs(args)
        local trimmed = (raw:match("^%s*(.-)%s*$") or "")
        local wl = trimmed:lower()
        local continuousLoop = wl:match(" loop%s*$") ~= nil
        local work = trimmed
        if continuousLoop then
            work = (trimmed:gsub("%s+[Ll][Oo][Oo][Pp]%s*$", ""):match("^%s*(.-)%s*$") or "")
        end
        local q = (work:match("^%s*(.-)%s*$") or ""):lower()
        if q == "" then
            if flingLoopActive or flingActive or flingSettling then
                cancelFlingWork()
                whisper("Fling loop stopped")
        return
    end
            whisper("!fling all | sheriff | murder | <name> — add loop to repeat, !fling alone stops")
        return
        end

        if flingLoopContinuous then
            whisper('You need to toggle off fling loop using "!fling"')
            return
        end
        if flingLoopActive or flingActive or flingSettling then
            return
        end
        local flingKey = tostring(p.UserId) .. ":" .. q
        if G.MM_LastFlingKey == flingKey and tick() - (tonumber(G.MM_LastFlingAt) or 0) < 20 then
            return
        end
        G.MM_LastFlingKey = flingKey
        G.MM_LastFlingAt = tick()

        local mode, playerQuery = "player", work
        local first = q:match("^(%S+)")
        if first == "all" then
            mode, playerQuery = "all", ""
        elseif first == "sheriff" or first == "sher" or first == "sherif" then
            mode, playerQuery = "sheriff", ""
        elseif first == "murder" or first == "murd" or first == "murderer" then
            mode, playerQuery = "murder", ""
        end

        if continuousLoop and mode == "all" then
            whisper("Use !fling all only")
            return
        end

        local matchLabel = mode
        if mode == "player" then
            local tgt = findOtherPlayer(work)
            if not tgt then
                whisper("Could not find player: " .. work)
                return
            end
            matchLabel = matchedPlayerLabel(tgt, work)
            log("fling: \"" .. work .. "\" -> " .. tgt.Name)
        end

        flingActive = false
        flingLoopGen = flingLoopGen + 1
        local gen = flingLoopGen
        flingLoopActive = true

        local loopArg = continuousLoop and mode ~= "all"
        flingLoopContinuous = loopArg
        runFlingLoop(mode, playerQuery, gen, loopArg)
        if mode == "all" then
            whisper("Flinging everyone")
        elseif loopArg then
            whisper("Say !fling alone to stop the loop")
            task.wait(0.3)
            whisper("Looping on: " .. matchLabel)
        else
            whisper("Flinging " .. matchLabel)
        end
        return
    end
    local m, s = findHolder({"Knife"}), findHolder(G.MM_GunNames)
    local ownerPlayer = findOwner()
    local ownerIsMurd = ownerMurdererActive(m, ownerPlayer) and not botHasKnife()
    if cmd == "chat" then
        if rest == "" then
            whisper("!chat <msg>")
        elseif sendChat(rest) then
            whisper("Chat sent")
        else
            whisper("Chat failed")
        end
    elseif cmd == "reveal" then
        local revealTo
        local q = restOfChatArgs(args)
        if q ~= "" then
            revealTo = findOtherPlayer(q) or findPlayer(q)
            if not revealTo then whisper("Player not found") return end
        end
        local pub = viaPublic == true and not revealTo
        task.spawn(function()
            local murd = (G.MM_FindRole and G.MM_FindRole("Murderer")) or m
            local sher = (G.MM_FindRole and G.MM_FindRole("Sheriff")) or s
            local hero = G.MM_FindRole and G.MM_FindRole("Hero")
            for _ = 1, 6 do
                if (murd or botHasKnife()) and (sher or hero or botHasGun()) then break end
                task.wait(0.2)
                murd = murd or (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
                sher = sher or (G.MM_FindRole and G.MM_FindRole("Sheriff")) or findHolder(G.MM_GunNames)
                hero = hero or (G.MM_FindRole and G.MM_FindRole("Hero"))
            end
            local useMe = not revealTo
            if not murd and botHasKnife() then murd = me end
            if not sher and not hero and botHasGun() then sher = me end
            local mL = (murd == me) and (useMe and "Me" or shortName(me)) or (murd and shortName(murd)) or "?"
            local sL
            if hero then
                sL = (hero == me) and (useMe and "Me (hero)" or (shortName(me) .. " (hero)")) or (shortName(hero) .. " (hero)")
            else
                sL = (sher == me) and (useMe and "Me" or shortName(me)) or (sher and shortName(sher)) or "?"
            end
            sendRoleLines(mL, sL, pub, revealTo)
            if revealTo then
                whisper("Revealed to " .. commandTargetLabel(revealTo))
            end
        end)
    elseif cmd == "tp" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        commandTakesMove()
        tpTo(t)
        whisper("Teleported to " .. commandTargetLabel(t))
    elseif cmd == "tpmurd" then
        local murd = (G.MM_FindRole and G.MM_FindRole("Murderer")) or m
        if not murd then whisper("Murderer not found") return end
        commandTakesMove()
        tpTo(murd)
        whisper("Teleported to murderer")
    elseif cmd == "tpsher" then
        local sher = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
            or (G.MM_FindRole and G.MM_FindRole("Hero"))
            or s
        if not sher then whisper("Sheriff not found") return end
        commandTakesMove()
        tpTo(sher)
        whisper("Teleported to sheriff")
    elseif cmd == "stab" then
        if not botHasKnife() then whisper("Bot needs to be murderer") return end
        local q = restOfChatArgs(args)
        if q == "" then whisper("!stab all | sheriff | <name>") return end
        local wl = q:lower()
        local first = wl:match("^(%S+)")
        local picked
        local stabAll = first == "all"
        if stabAll then
            picked = nil
        elseif first == "sheriff" or first == "sher" or first == "sherif" then
            picked = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
                or (G.MM_FindRole and G.MM_FindRole("Hero"))
                or findHolder(G.MM_GunNames)
            if not picked or picked == me then whisper("Sheriff not found") return end
        else
            picked = findOtherPlayer(q)
            if not picked then whisper("Player not found") return end
        end
        if G.MM_StabBusyActive() then whisper("Stab busy, try again") return end
        if _G.MM_GunBusy then whisper("Gun busy, try again") return end
        if _G.MM_ShootBusy then whisper("Shoot busy, try again") return end
        G.MM_BeginStabBusy()
        local targetUid = picked and picked.UserId or nil
        whisper(stabAll and "Stabbing everyone" or ("Stabbing " .. shortName(picked)))
        task.spawn(function()
            local status = "Player not found"
            local ok, err = pcall(function()
                local _, msg
                if stabAll then
                    _, msg = stabAllTargets()
                else
                    local tgt = Players:GetPlayerByUserId(targetUid)
                    if not tgt or not isAlive(tgt) then return end
                    _, msg = stabTargetLoop(tgt)
                end
                status = msg
            end)
            if not ok then
                status = "Stab failed"
                log(tostring(err))
            end
            whisper(status)
            G.MM_EndStabBusy()
            runDeferredOwnerResetIfIdle()
        end)
    elseif cmd == "shoot" then
        local q = restOfChatArgs(args)
        local picked, err = G.MM_ResolveShootTarget(q)
        if not picked then whisper(err or "Player not found") return end
        if G.MM_StabBusyActive() then whisper("Stab busy, try again") return end
        if _G.MM_GunBusy then whisper("Gun busy, try again") return end
        if _G.MM_ShootBusy then whisper("Shoot busy, try again") return end
        if botHasKnife() then whisper("Bot is murderer — no gun") return end
        if not G.MM_EnsureShootGun() then
            whisper(G.MM_GunWhere and G.MM_GunWhere() or "No gun available")
            return
        end
        _G.MM_ShootBusy = true
        G.MM_ActionBegin()
        local targetUid = picked.UserId
        whisper("Shooting " .. shortName(picked))
        task.spawn(function()
            local status = "Shoot failed"
            local ok, runErr = pcall(function()
                local tgt = Players:GetPlayerByUserId(targetUid)
                if not tgt then
                    status = "Player left"
                    return
                end
                local _, msg = G.MM_ShootTargetLoop(tgt)
                status = msg or status
            end)
            if not ok then
                status = "Shoot failed"
                log(tostring(runErr))
            end
            whisper(status)
            _G.MM_ShootBusy = false
            G.MM_ActionEnd()
            runDeferredOwnerResetIfIdle()
        end)
    elseif cmd == "gun" then
        if restOfChatArgs(args) == "" and not findOwner() then
            whisper("!gun <player>")
            return
        end
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        if ownerIsMurd then whisper(OWNER_MURD_GUN_MSG) return end
        if botHasKnife() then whisper("No gun available") return end
        if not botHasGun() and not findDroppedGun() then
            whisper(G.MM_GunWhere and G.MM_GunWhere() or "No gun available")
            return
        end
        local ok = bringGun(t, true)
        whisper(ok and ("Gun delivered to " .. commandTargetLabel(t)) or "Gun missed, try again")
    elseif cmd == "drop" then
        if _G.MM_GunBusy then whisper("Gun busy, try again") return end
        if G.MM_StabBusyActive() then whisper("Stab busy, try again") return end
        if botHasKnife() then whisper("No gun available") return end
        if not gunAvailableForOwnerMurdStash() then
            whisper(G.MM_GunWhere and G.MM_GunWhere() or "No gun available")
            return
        end
        _G.MM_GunBusy = true
        local ok = stashGunAtSpawn()
        _G.MM_GunBusy = false
        whisper(ok and "Gun dropped at spawn" or "No gun available")
    elseif cmd == "spawn" or cmd == "home" then
        commandTakesMove()
        tpHome()
        whisper("Teleported to spawn")
    elseif cmd == "reset" then
        whisper("Resetting")
        reset()
    elseif cmd == "togglegun" then
        if args[2] and ownerIsMurd then whisper(OWNER_MURD_GUN_MSG) return end
        G.MM_BlockGunGrab = false
        G.MM_SkipGunUntil = 0
        if args[2] then
            local t = findPlayer(args[2])
            if not t then whisper("Player not found") return end
            toggleGun, gunTargetId, gunDelivered = true, t.UserId, false
            whisper("Auto-gun on: " .. shortName(t))
        else
            toggleGun = not toggleGun
            gunTargetId, gunDelivered = nil, false
            whisper("Auto-gun: " .. (toggleGun and "on" or "off"))
        end
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
    elseif cmd == "toggleshoot" then
        local q = restOfChatArgs(args):lower()
        if q == "off" or q == "stop" or q == "disable" then
            toggleShoot, shootTargetId, shootDone = false, nil, false
            whisper("Auto-shoot: off")
        elseif q ~= "" then
            local first = q:match("^(%S+)") or ""
            if first == "murder" or first == "murd" or first == "murderer" then
                toggleShoot, shootTargetId, shootDone = true, nil, false
                whisper("Auto-shoot on: murderer")
            else
                local t = findOtherPlayer(q) or findPlayer(q)
                if not t or t == me then whisper("Player not found") return end
                toggleShoot, shootTargetId, shootDone = true, t.UserId, false
                whisper("Auto-shoot on: " .. shortName(t))
            end
        else
            toggleShoot = not toggleShoot
            shootTargetId, shootDone = nil, false
            whisper("Auto-shoot: " .. (toggleShoot and "on (murderer)" or "off"))
        end
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
    elseif cmd == "togglealerts" then
        toggleAlerts = not toggleAlerts
        whisper("Kill alerts: " .. (toggleAlerts and "on" or "off"))
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
    elseif cmd == "togglereveal" then
        toggleReveal = not toggleReveal
        whisper("Role callouts: " .. (toggleReveal and "on" or "off"))
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
    elseif cmd == "togglereset" then
        toggleResetOnOwnerDeath = not toggleResetOnOwnerDeath
        G.MM_ResetUserSet = true
        _G.MM_OwnerDiedPendingReset = false
        whisper("Reset on owner death: " .. (toggleResetOnOwnerDeath and "on" or "off"))
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
    elseif cmd == "toggledrop" then
        toggleDrop = not toggleDrop
        whisper("Murderer gun stash: " .. (toggleDrop and "on" or "off"))
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
    elseif cmd == "hide" or cmd == "unsummon" then
        G.MM_HoldMove = false
        G.MM_HoldStand = false
        G.MM_ForceHide = true
        G.MM_SummonFocusId = nil
        startHideLoop()
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
        whisper("Hidden under map — !summon to bring stand back")
    elseif cmd == "summon" then
        local q = restOfChatArgs(args)
        local target
        if q ~= "" then
            target = findOtherPlayer(q) or findPlayer(q)
            if not target or target == me then whisper("Player not found") return end
            G.MM_SummonFocusId = target.UserId
        else
            target = findOwner()
            G.MM_SummonFocusId = nil
            if not target or target == me then whisper("No owner to summon to") return end
        end
        G.MM_HoldMove = false
        G.MM_HoldStand = true
        G.MM_ForceHide = false
        startSummonLoop(target.UserId)
        if session.ownerId then pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end) end
        whisper("Stand on " .. commandTargetLabel(target))
    elseif cmd == "emote" then
        local q = restOfChatArgs(args)
        local ok, info = playBotEmote(q)
        if q == "" then
            whisper("!emote " .. tostring(info))
        elseif ok then
            whisper("Emote: " .. tostring(info))
        else
            whisper("Emote failed — try wave, dance, laugh")
        end
    elseif cmd == "help" then
        local tail = restOfChatArgs(args)
        tail = (tail:gsub("^!+", ""):match("^%s*(.-)%s*$") or "")
        local helpCmd = (tail:match("^(%S+)") or ""):lower()
        if helpCmd == "" and args[2] then
            helpCmd = (tostring(args[2]):gsub("^!+", ""):match("^%s*(.-)%s*$") or ""):lower()
        end
        if helpCmd ~= "" and COMMAND_HELP[helpCmd] then
            whisper("!" .. helpCmd .. ": " .. COMMAND_HELP[helpCmd])
        elseif helpCmd ~= "" then
            whisper("No help for !" .. helpCmd .. " — use !help for the list")
        else
            sendFullHelp(p, viaPublic and 0.35 or 0.5, viaPublic and function(m) sendChat(m) end or whisper)
        end
    end
end
local function routeCommand(p, msg, viaPublic)
    if not session.active or not p or isSelfPlayer(p) then return end
    msg = extractCommandText(msg)
    if msg == "" then return end
    local bangs = 0
    for _ in msg:gmatch("!%w+") do
        bangs = bangs + 1
        if bangs > 1 then return end
    end
    if seenCommandRecently(p, msg) then return end
    log("cmd " .. p.Name .. ": " .. msg)
    handleCommand(p, msg, viaPublic == true)
end
local function watchHiddenChat(p, msg)
    local event = getHiddenChatEvent()
    if not event or p == me then return end
    local clean = cleanChatText(msg)
    if clean == "" then return end
    local hidden = true
    local conn
    conn = trackConnection(event.OnClientEvent:Connect(function(packet)
        if not session.active then return end
        local packetMsg = packet and packet.Message
        if packet and packet.SpeakerUserId == p.UserId and type(packetMsg) == "string" then
            local suffix = clean:sub(math.max(1, #clean - #packetMsg + 1))
            if packetMsg == suffix then
                hidden = false
            end
        end
    end))
    task.delay(1, function()
        if conn then conn:Disconnect() end
        if hidden and session.active then
            showHiddenChat(p, clean)
        end
    end)
end
local function hookSpeaker(p)
    if not p or isSelfPlayer(p) then return end
    pcall(function()
        local chatted = p.Chatted
        if not chatted then return end
        trackConnection(chatted:Connect(function(msg)
            if not session.active then return end
            watchHiddenChat(p, msg)
            task.delay(0.2, function()
                if session.active then routeCommand(p, msg, false) end
            end)
        end))
    end)
end
local function hookIncomingChatChannels()
    if isLegacy then
        task.spawn(function()
            for _ = 1, 20 do
                if getHiddenChatEvent() then break end
                task.wait(0.25)
            end
            local event = getHiddenChatEvent()
            if not event then return end
            trackConnection(event.OnClientEvent:Connect(function(packet, channel)
                if not session.active or type(packet) ~= "table" then return end
                local uid = packet.SpeakerUserId or packet.SpeakerUserID
                local text = packet.Message
                if type(text) ~= "string" or text == "" or not uid then return end
                local speaker = Players:GetPlayerByUserId(uid)
                if not speaker or isSelfPlayer(speaker) then return end
                if channelLooksPrivate(channel) then
                    routeCommand(speaker, text, false)
                    return
                end
                routeCommand(speaker, text, true)
            end))
        end)
        return
    end
    local function onTextMessage(message, channelName)
        if not session.active or not message then return end
        local src = message.TextSource
        if not src then return end
        if src.UserId == me.UserId then return end
        local speaker = Players:GetPlayerByUserId(src.UserId)
        if not speaker or isSelfPlayer(speaker) then return end
        local ch = message.TextChannel
        local name = channelName or (ch and ch.Name)
        if ch and (channelLooksPrivate(name) or (name and name ~= "RBXGeneral" and not tostring(name):find("General", 1, true))) then
            rememberWhisperChannel(speaker.UserId, ch)
        end
        routeCommand(speaker, message.Text, not channelLooksPrivate(name))
    end
    local function bindTextChannel(ch)
        if not ch or not ch:IsA("TextChannel") then return end
        trackConnection(ch.MessageReceived:Connect(function(message)
            onTextMessage(message, ch.Name)
        end))
    end
    local function bindFolder(folder)
        if not folder then return end
        for _, ch in ipairs(folder:GetChildren()) do
            bindTextChannel(ch)
        end
        trackConnection(folder.ChildAdded:Connect(bindTextChannel))
    end
    pcall(function()
        trackConnection(TCS.MessageReceived:Connect(function(message)
            onTextMessage(message, message.TextChannel and message.TextChannel.Name)
        end))
    end)
    pcall(function()
        local raw = rawTCS()
        if raw then
            trackConnection(raw.MessageReceived:Connect(function(message)
                onTextMessage(message, message.TextChannel and message.TextChannel.Name)
            end))
        end
    end)
    task.spawn(function()
        for _, tcs in ipairs({ rawTCS(), TCS }) do
            if tcs then
                local folder = tcs:FindFirstChild("TextChannels") or tcs:WaitForChild("TextChannels", 8)
                bindFolder(folder)
            end
        end
    end)
end
hookIncomingChatChannels()
pcall(function()
    for _, p in ipairs(Players:GetPlayers()) do
        hookSpeaker(p)
    end
end)
pcall(function()
    trackConnection(Players.PlayerAdded:Connect(function(p)
        if not session.active then return end
        hookSpeaker(p)
    end))
end)
pcall(function()
    trackConnection(Players.PlayerRemoving:Connect(function(p)
        if not session.active then return end
        if session.ownerId and p.UserId == session.ownerId then
            if hopBusy then return end
            pcall(function() G.MM_SaveOwnerPrefs(session.ownerId) end)
            local leftId = p.UserId
            task.defer(function()
                if hopBusy then return end
                if session.ownerId ~= leftId then return end
                ownerOnboardingGen = ownerOnboardingGen + 1
                clearAdoptedOwner("owner left")
                if G.MM_SendAdoptAd then G.MM_SendAdoptAd() end
                if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
            end)
        end
    end))
end)

--[[ Discord bridge (discord-xeno.py Flask) ]]--
local XENO_BRIDGE_ENABLED = not (getgenv and getgenv().XENO_BRIDGE_ENABLED == false)
local ensureRegionSpreadOnStart = function() end
local murdererRoundKills = 0
local sheriffRoundKills = 0
local whoKnifeIdPrev, whoGunIdPrev = nil, nil
;(function()
local XENO_BRIDGE_URL = (getgenv and getgenv().XENO_BRIDGE_URL) or "https://xenobotsmm2.xyz"
local XENO_POLL_SEC = (getgenv and tonumber(getgenv().XENO_POLL_SEC)) or 2.5
local BRIDGE_CLAIM_WAIT_SEC = 15 * 60
local REGION_PEER_MAX = 3
local REGION_SPREAD_MAX_ATTEMPTS = 12
local bridgeAcked = {}
local bridgeClaimId = nil
local bridgeAwaitingName = nil
local bridgeClaimExpiresAt = 0
local bridgeFulfilledClaimId = nil
local bridgePollOnce

local function nameMatchesPlayer(pl, name)
    if not pl or not name or name == "" then return false end
    local lower = name:lower()
    return pl.Name:lower() == lower or tostring(pl.DisplayName or ""):lower() == lower
end

local function findPlayerInServerByName(name)
    if not name or name == "" then return nil end
    name = name:match("^%s*(.-)%s*$") or name
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= me and nameMatchesPlayer(pl, name) then
            return pl
        end
    end
end

local function bridgeReportClaimEvent(event, extra)
    extra = extra or {}
    pcall(function()
        httpJson("POST", XENO_BRIDGE_URL .. "/api/xeno/poll", {
            job_id = game.JobId,
            bot_username = me.Name,
            bot_user_id = me.UserId,
            place_id = game.PlaceId,
            owner_id = extra.owner_id or session.ownerId,
            owner = G.MM_CurrentOwnerInfo(),
            toggle_config = G.MM_CurrentToggleConfig(),
            player_count = #Players:GetPlayers(),
            claim_event = event,
            claim_id = extra.claim_id or bridgeClaimId,
            bot_note = extra.note,
        })
    end)
end

local function fulfillBridgeClaim(claimId, username)
    if not claimId or not username then return false end
    if G.MM_OwnerReleased then
        log("bridge: ignore claim — in-game owner was released")
        return false
    end
    if bridgeFulfilledClaimId == claimId then return true end
    local pl = findPlayerInServerByName(username)
    if not pl then return false end
    local prevId = session.ownerId
    session.ownerId = pl.UserId
    G.MM_PendingOwnerId = pl.UserId
    G.MM_OwnerAdopted = true
    G.MM_OwnerReleased = false
    bridgeFulfilledClaimId = claimId
    bridgeAwaitingName = nil
    log("bridge: owner joined — " .. pl.Name)
    if prevId ~= pl.UserId then
        _G.MM_OwnerDiedPendingReset = false
        scheduleOwnerOnboarding(pl.UserId)
    end
    bridgeReportClaimEvent("owner_joined", { claim_id = claimId, owner_id = pl.UserId, note = pl.Name })
    return true
end

local function clearBridgeReservation(reason)
    if bridgeAwaitingName or bridgeClaimId then
        log("bridge: reservation cleared — " .. tostring(reason))
    end
    bridgeClaimId = nil
    bridgeAwaitingName = nil
    bridgeClaimExpiresAt = 0
    bridgeReportClaimEvent("released", { note = reason })
end

local function bridgeAck(jobId, commandId, status, message)
    if not commandId or commandId == "" then return end
    bridgeAcked[commandId] = true
    pcall(function()
        httpJson("POST", XENO_BRIDGE_URL .. "/api/xeno/ack", {
            job_id = jobId,
            command_id = commandId,
            status = status or "ok",
            message = message or "",
            bot_user_id = me.UserId,
        })
    end)
end

local function bridgeCommandDelay(cmd)
    return 0
end

-- Run as soon as poll delivers the command, then ack right away.
local function bridgeExecuteAfterPollDelay(jobId, commandId, fn, cmd)
    task.spawn(function()
        task.wait(bridgeCommandDelay(cmd))
        local ok, st, msg = pcall(fn)
        if ok and type(st) == "string" then
            bridgeAck(jobId, commandId, st, msg or "")
        else
            bridgeAck(jobId, commandId, "error", "Command failed")
        end
    end)
end

local function bridgeTrim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$") or "")
end

local function bridgeHelpMessage(topic)
    topic = bridgeTrim(topic):lower():gsub("^!", "")
    if topic ~= "" then
        if COMMAND_HELP[topic] then
            return "ok", "!" .. topic .. ": " .. COMMAND_HELP[topic]
        end
        return "error", "No help for !" .. topic .. " — use /help for the full list"
    end
    local lines = {
        "Discord: /help /gun /stab /shoot /fling /tp /reveal /reset /chat /alerts",
        "",
    }
    table.insert(lines, "In-game: !help and the same commands with !")
    table.insert(lines, "")
    for _, key in ipairs(helpKeysForOwner()) do
        local desc = COMMAND_HELP[key] or ""
        table.insert(lines, "• **!" .. key .. "** — " .. desc)
    end
    return "ok", table.concat(lines, "\n")
end

local function bridgeToggleGunMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local m = findHolder({"Knife"})
    local ownerPlayer = findOwner()
    if ownerMurdererActive(m, ownerPlayer) and not botHasKnife() then
        return "error", OWNER_MURD_GUN_MSG
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleGun then
            return "ok", "Automatic gun is already enabled"
        end
        toggleGun = true
        gunTargetId, gunDelivered = nil, false
        return "ok", "Automatic gun enabled"
    elseif mode == "disable" then
        if not toggleGun then
            return "error", "Automatic gun is not enabled"
        end
        toggleGun = false
        gunTargetId, gunDelivered = nil, false
        return "ok", "Automatic gun disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeToggleShootMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleShoot then
            return "ok", "Automatic shoot is already enabled"
        end
        toggleShoot, shootTargetId, shootDone = true, nil, false
        return "ok", "Automatic shoot enabled (murderer)"
    elseif mode == "disable" then
        if not toggleShoot then
            return "error", "Automatic shoot is not enabled"
        end
        toggleShoot, shootTargetId, shootDone = false, nil, false
        return "ok", "Automatic shoot disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeToggleRevealMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleReveal then
            return "ok", "Role callouts are already enabled"
        end
        toggleReveal = true
        return "ok", "Role callouts enabled"
    elseif mode == "disable" then
        if not toggleReveal then
            return "error", "Role callouts are not enabled"
        end
        toggleReveal = false
        return "ok", "Role callouts disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeToggleAlertsMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleAlerts then
            return "ok", "Kill alerts are already enabled"
        end
        toggleAlerts = true
        return "ok", "Kill alerts enabled"
    elseif mode == "disable" then
        if not toggleAlerts then
            return "error", "Kill alerts are not enabled"
        end
        toggleAlerts = false
        return "ok", "Kill alerts disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeToggleResetMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleResetOnOwnerDeath then
            return "ok", "Automatic reset is already enabled"
        end
        toggleResetOnOwnerDeath = true
        G.MM_ResetUserSet = true
        return "ok", "Automatic reset enabled"
    elseif mode == "disable" then
        if not toggleResetOnOwnerDeath then
            return "error", "Automatic reset is not enabled"
        end
        toggleResetOnOwnerDeath = false
        G.MM_ResetUserSet = true
        _G.MM_OwnerDiedPendingReset = false
        return "ok", "Automatic reset disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeToggleDropMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleDrop then
            return "ok", "Automatic drop is already enabled"
        end
        toggleDrop = true
        return "ok", "Automatic drop enabled"
    elseif mode == "disable" then
        if not toggleDrop then
            return "error", "Automatic drop is not enabled"
        end
        toggleDrop = false
        return "ok", "Automatic drop disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeDropMessage()
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    if _G.MM_GunBusy then return "error", "Gun busy, try again" end
    if G.MM_StabBusyActive() then return "error", "Stab busy, try again" end
    if botHasKnife() then return "error", "No gun available" end
    if not gunAvailableForOwnerMurdStash() then
        return "error", (G.MM_GunWhere and G.MM_GunWhere()) or "No gun available"
    end
    _G.MM_GunBusy = true
    local ok = stashGunAtSpawn()
    _G.MM_GunBusy = false
    return ok and "ok" or "error", ok and "Gun dropped at spawn" or "No gun available"
end

local function bridgeChatMessage(text)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    text = bridgeTrim(text)
    if text == "" then
        return "error", "Message required"
    end
    if sendChat(text) then
        return "ok", "Chat sent"
    end
    return "error", "Chat failed"
end

local function bridgeGunMessage(targetQuery)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local m = findHolder({"Knife"})
    local ownerPlayer = findOwner()
    local ownerIsMurd = ownerMurdererActive(m, ownerPlayer) and not botHasKnife()
    local t
    if bridgeTrim(targetQuery) == "" then
        t = ownerPlayer
    else
        t = findPlayer(targetQuery)
    end
    if not t then return "error", "Player not found" end
    if ownerIsMurd then return "error", OWNER_MURD_GUN_MSG end
    if botHasKnife() then return "error", "No gun available" end
    if not botHasGun() and not findDroppedGun() then
        return "error", (G.MM_GunWhere and G.MM_GunWhere()) or "No gun available"
    end
    local ok = bringGun(t, true)
    return ok and "ok" or "error", ok and ("Gun delivered to " .. bridgeTargetLabel(t)) or "Gun missed, try again"
end

local function bridgeParseFlingQuery(query)
    query = bridgeTrim(query)
    if query == "" then
        return nil, nil, "Use: **all**, **sheriff**, **murder**, or a player name"
    end
    local q = query:lower()
    local first = q:match("^(%S+)")
    local mode, playerQuery = "player", query
    if first == "all" then
        mode, playerQuery = "all", ""
    elseif first == "sheriff" or first == "sher" or first == "sherif" then
        mode, playerQuery = "sheriff", ""
    elseif first == "murder" or first == "murd" or first == "murderer" then
        mode, playerQuery = "murder", ""
    end
    return mode, playerQuery, nil
end

local function bridgeRunFlingOnce(mode, playerQuery, gen)
    if mode == "all" then
        local n = 0
        for _, pl in ipairs(Players:GetPlayers()) do
            if gen ~= flingLoopGen or not flingLoopActive or not session.active then break end
            if pl ~= me and (not session.ownerId or pl.UserId ~= session.ownerId) and isAlive(pl) and isAlive(me) then
                local flung = false
                fling(pl, function(ok) flung = ok end)
                waitFlingDone(gen, 25)
                if flung then n = n + 1 end
            end
        end
        if n > 0 then
            return "ok", "Flung " .. tostring(n) .. " player(s)"
        end
        return "ok", "Fling finished (no hits)"
    end

    local tgt
    if mode == "sheriff" then
        tgt = (G.MM_FindRole and (G.MM_FindRole("Sheriff") or G.MM_FindRole("Hero"))) or findHolder(G.MM_GunNames)
        if not tgt or tgt == me then return "error", "Sheriff not found" end
    elseif mode == "murder" then
        tgt = (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
        if not tgt or tgt == me then return "error", "Murderer not found" end
    else
        tgt = findOtherPlayer(playerQuery)
        if not tgt then return "error", "Player not found: " .. playerQuery end
    end
    if not isAlive(tgt) or not isAlive(me) then return "error", "Target or bot not alive" end
    local flung = false
    fling(tgt, function(ok) flung = ok end)
    waitFlingDone(gen, 25)
    if flung then
        return "ok", "Flung " .. bridgeTargetLabel(tgt)
    end
    return "ok", "Fling finished"
end

local function bridgeStabMessage(targetQuery)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    if not botHasKnife() then
        return "error", "Bot needs to be murderer"
    end
    local q = bridgeTrim(targetQuery)
    if q == "" then
        return "error", "Use: all, sheriff, or a player name"
    end
    local wl = q:lower()
    local first = wl:match("^(%S+)")
    local picked
    local stabAll = first == "all"
    if stabAll then
        picked = nil
    elseif first == "sheriff" or first == "sher" or first == "sherif" then
        picked = (G.MM_FindRole and (G.MM_FindRole("Sheriff") or G.MM_FindRole("Hero"))) or findHolder(G.MM_GunNames)
        if not picked or picked == me then return "error", "Sheriff not found" end
    else
        picked = findOtherPlayer(q)
        if not picked then return "error", "Player not found" end
    end
    if G.MM_StabBusyActive() then return "error", "Stab busy, try again" end
    if _G.MM_GunBusy then return "error", "Gun busy, try again" end
    G.MM_BeginStabBusy()
    local targetUid = picked and picked.UserId or nil
    local status = "Player not found"
    local okRun, errRun = pcall(function()
        local _, msg
        if stabAll then
            _, msg = stabAllTargets()
        else
            local tgt = Players:GetPlayerByUserId(targetUid)
            if not tgt or not isAlive(tgt) then return end
            _, msg = stabTargetLoop(tgt)
        end
        status = msg
    end)
    G.MM_EndStabBusy()
    runDeferredOwnerResetIfIdle()
    if not okRun then
        return "error", "Stab failed"
    end
    if status:find("not found", 1, true) or status:find("failed", 1, true) then
        return "error", status
    end
    if stabAll then
        return "ok", status or "Stab all finished"
    end
    return "ok", "Stabbed " .. bridgeTargetLabel(picked)
end

local function bridgeShootMessage(targetQuery)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    if botHasKnife() then
        return "error", "Bot is murderer — no gun"
    end
    if G.MM_StabBusyActive() or _G.MM_GunBusy or _G.MM_ShootBusy then
        return "error", "Busy, try again"
    end
    local picked, err = G.MM_ResolveShootTarget(targetQuery)
    if not picked then
        return "error", err or "Player not found"
    end
    if not G.MM_EnsureShootGun() then
        return "error", (G.MM_GunWhere and G.MM_GunWhere()) or "No gun available"
    end
    _G.MM_ShootBusy = true
    G.MM_ActionBegin()
    local status = "Shoot failed"
    local okRun, errRun = pcall(function()
        local _, msg = G.MM_ShootTargetLoop(picked)
        status = msg or status
    end)
    _G.MM_ShootBusy = false
    G.MM_ActionEnd()
    runDeferredOwnerResetIfIdle()
    if not okRun then
        log(tostring(errRun))
        return "error", "Shoot failed"
    end
    if not status or status:find("failed", 1, true) or status:find("not found", 1, true) or status:find("No gun", 1, true) then
        return "error", status or "Shoot failed"
    end
    return "ok", status
end

local function bridgeFlingMessage(query)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    if flingLoopContinuous then
        return "error", "Stop the in-game fling loop with !fling first"
    end
    local mode, playerQuery, err = bridgeParseFlingQuery(query)
    if err then return "error", err end
    if mode == "player" and not findOtherPlayer(playerQuery) then
        return "error", "Could not find player: " .. playerQuery
    end
    cancelFlingWork()
    flingLoopGen = flingLoopGen + 1
    local gen = flingLoopGen
    flingLoopActive = true
    local st, msg = bridgeRunFlingOnce(mode, playerQuery, gen)
    if gen == flingLoopGen then
        flingLoopActive = false
    end
    return st, msg
end

local function ownerHrp()
    local o = findOwner()
    if not o or o == me then return nil end
    return o.Character and o.Character:FindFirstChild("HumanoidRootPart")
end

local function distanceStudsToPlayer(p)
    local h = ownerHrp()
    local t = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not (h and t) then return nil end
    return math.floor((h.Position - t.Position).Magnitude + 0.5)
end

local function distanceStudsToPart(part)
    local h = ownerHrp()
    if not (h and part) then return nil end
    local pos = part.Position
    return math.floor((h.Position - pos).Magnitude + 0.5)
end

local function whoRoleEntry(p, kills)
    return {
        user_id = p and p.UserId or nil,
        username = p and bridgePlayerLabel(p) or nil,
        kills = kills or 0,
        distance_studs = p and distanceStudsToPlayer(p) or nil,
        is_bot = p == me,
    }
end

local function bridgeRevealMessage()
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local m = (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
    local s = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
        or (G.MM_FindRole and G.MM_FindRole("Hero"))
        or findHolder(G.MM_GunNames)
    local botM, botS = (m == me) or botHasKnife(), (s == me) or botHasGun()
    local murdererP = botM and me or m
    if not murdererP then
        return "error", "Round hasn't started yet"
    end
    local sheriffP = botS and me or s
    local gunDrop = findDroppedGun()
    local gunEquipped = botS or (sheriffP and playerHas(sheriffP, G.MM_GunNames))
    local gunDropped = gunDrop ~= nil and not sheriffP
    local gunAvailable = gunEquipped or gunDropped
    local sheriffDist = sheriffP and distanceStudsToPlayer(sheriffP)
        or (gunDrop and distanceStudsToPart(gunDrop))
    local payload = {
        murderer = whoRoleEntry(murdererP, murdererRoundKills),
        sheriff = {
            user_id = sheriffP and sheriffP.UserId or nil,
            username = sheriffP and bridgePlayerLabel(sheriffP) or nil,
            kills = sheriffRoundKills,
            distance_studs = sheriffDist,
            is_bot = sheriffP == me,
            gun_available = gunAvailable,
            gun_equipped = gunEquipped,
            gun_dropped = gunDropped,
        },
    }
    return "ok", Http:JSONEncode(payload)
end

local function bridgeTpMessage(targetQuery)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local t
    if bridgeTrim(targetQuery) == "" then
        t = findOwner()
    else
        t = findPlayer(targetQuery) or findOtherPlayer(targetQuery)
    end
    if not t then
        return "error", "Player not found"
    end
    commandTakesMove()
    tpTo(t)
    return "ok", "Teleported to " .. bridgeTargetLabel(t)
end

local function bridgeResetMessage()
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    reset()
    return "ok", "Bot reset"
end

local function bridgeOwnerMessage(targetQuery)
    targetQuery = bridgeTrim(targetQuery)
    if targetQuery == "" then
        local owner = findOwner()
        local payload = {
            owner = G.MM_CurrentOwnerInfo(),
            toggles = G.MM_CurrentToggleConfig(),
            players = {},
        }
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= me then
                table.insert(payload.players, {
                    user_id = pl.UserId,
                    username = pl.Name,
                    display_name = pl.DisplayName,
                })
            end
        end
        if not owner then
            payload.message = "Owner has not joined yet"
        end
        return "ok", Http:JSONEncode(payload)
    end
    local newOwner = findPlayer(targetQuery)
    if not newOwner or newOwner == me then
        return "error", "Player not found"
    end
    ACTIVE_OWNER_USERNAME = newOwner.Name
    bridgeOwnerConnected = true
    session.ownerId = newOwner.UserId
    G.MM_PendingOwnerId = newOwner.UserId
    G.MM_OwnerAdopted = true
    G.MM_OwnerReleased = false
    _G.MM_OwnerDiedPendingReset = false
    scheduleOwnerOnboarding(newOwner.UserId)
    log("bridge: owner changed — " .. newOwner.Name)
    return "ok", "Owner changed to " .. newOwner.Name
end

local function processBridgeCommands(jobId, commands)
    if not session.active or type(commands) ~= "table" then return end
    local fns = {
        toggle_gun = bridgeToggleGunMessage,
        toggle_shoot = bridgeToggleShootMessage,
        toggle_reveal = bridgeToggleRevealMessage,
        toggle_alerts = bridgeToggleAlertsMessage,
        toggle_reset = bridgeToggleResetMessage,
        toggle_drop = bridgeToggleDropMessage,
        chat = bridgeChatMessage,
        gun = bridgeGunMessage,
        drop = bridgeDropMessage,
        stab = bridgeStabMessage,
        shoot = bridgeShootMessage,
        fling = bridgeFlingMessage,
        tp = bridgeTpMessage,
        reveal = bridgeRevealMessage,
        reset = bridgeResetMessage,
        owner = bridgeOwnerMessage,
    }
    for _, cmd in ipairs(commands) do
        if not session.active then return end
        if type(cmd) == "table" and cmd.id and not bridgeAcked[cmd.id] then
            local ctype = cmd.type
            log("bridge: " .. tostring(ctype))
            if ctype == "help" then
                local st, msg = bridgeHelpMessage(cmd.topic or cmd.command or "")
                bridgeAck(jobId, cmd.id, st, msg)
            else
                local fn = fns[ctype]
                if not fn then
                    bridgeAck(jobId, cmd.id, "error", "unknown command")
                else
                    local arg = cmd.target or cmd.query or cmd.player or cmd.message or cmd.text or cmd.mode or cmd.action or ""
                    bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                        return fn(arg)
                    end, cmd)
                end
            end
        end
    end
end

local function processBridgeClaim(claim)
    if type(claim) ~= "table" then return end
    syncOwnerPremiumFromClaim(claim)
    if claim.roblox_username and claim.roblox_username ~= "" then
        ACTIVE_OWNER_USERNAME = tostring(claim.roblox_username)
    end
    G.MM_ApplyToggleConfig(claim.toggle_config)
    local st = claim.status
    if st == "in_use" or st == "fulfilled" then
        bridgeOwnerConnected = true
        return
    end
    if st == "awaiting_join" and claim.roblox_username and claim.id then
        bridgeOwnerConnected = true
        bridgeClaimId = claim.id
        bridgeAwaitingName = claim.roblox_username
        bridgeClaimExpiresAt = tonumber(claim.expires_at) or (os.time() + BRIDGE_CLAIM_WAIT_SEC)
        if claim.age_group then
            G.MM_OwnerAgeGroup = claim.age_group
        end
        if not G.MM_OwnerReleased and bridgeFulfilledClaimId ~= claim.id then
            fulfillBridgeClaim(claim.id, claim.roblox_username)
        end
    elseif st == "available" or not claim.roblox_username then
        bridgeOwnerConnected = false
        if bridgeAwaitingName and os.time() >= bridgeClaimExpiresAt then
            clearBridgeReservation("expired")
        elseif not bridgeAwaitingName then
            bridgeClaimId = nil
            bridgeClaimExpiresAt = 0
        end
    end
end

local function getServerLocationLabel()
    if G.MM_ServerLocationJob == game.JobId and G.MM_ServerLocationCache then
        return G.MM_ServerLocationCache
    end
    local raw = httpGet("http://ip-api.com/json/?fields=status,countryCode,city")
    if not raw then return nil end
    local ok, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or data.status ~= "success" then return nil end
    local country = tostring(data.countryCode or ""):upper()
    local city = tostring(data.city or "")
    local label
    if country ~= "" and city ~= "" then
        label = country .. ", " .. city
    elseif country ~= "" then
        label = country
    elseif city ~= "" then
        label = city
    end
    if label and label ~= "" then
        G.MM_ServerLocationJob = game.JobId
        G.MM_ServerLocationCache = label
        return label
    end
    return nil
end

local function countRegionPeers(location)
    if not location or location == "" or not XENO_BRIDGE_ENABLED then return 0 end
    local qs = "location=" .. Http:UrlEncode(location) .. "&bot_user_id=" .. tostring(me.UserId)
    local raw = httpJson("GET", XENO_BRIDGE_URL .. "/api/xeno/region-peers?" .. qs)
    if not raw then return 0 end
    local ok, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or not data.ok then return 0 end
    return tonumber(data.count) or 0
end

G.MM_RegionSpreadCheck = G.MM_RegionSpreadCheck or false
G.MM_RegionSpreadAttempts = G.MM_RegionSpreadAttempts or 0

ensureRegionSpreadOnStart = function()
    if not XENO_BRIDGE_ENABLED or hopBusy then return end
    if G.MM_RegionSpreadAttempts >= REGION_SPREAD_MAX_ATTEMPTS then
        log("region spread: max attempts reached, staying")
        G.MM_RegionSpreadAttempts = 0
        return
    end
    local loc = getServerLocationLabel()
    if not loc then
        log("region spread: location unknown")
        return
    end
    pcall(function() bridgePollOnce() end)
    local peers = countRegionPeers(loc)
    log(("region spread: %d other bot(s) in %s"):format(peers, loc))
    if peers < REGION_PEER_MAX then
        G.MM_RegionSpreadAttempts = 0
        G.MM_RegionSpreadCheck = false
        return
    end
    G.MM_RegionSpreadAttempts = (G.MM_RegionSpreadAttempts or 0) + 1
    log(("region spread: hopping (%d/%d)"):format(G.MM_RegionSpreadAttempts, REGION_SPREAD_MAX_ATTEMPTS))
    G.MM_RegionSpreadCheck = true
    queueRegionSpreadOnTeleport()
    hopServer("region spread", false)
end

bridgePollOnce = function()
    if not session.active then return false end
    local configuredOwner = findOwner()
    local playerNames = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= me then
            table.insert(playerNames, pl.Name)
        end
    end
    local claimEvent = nil
    if bridgeAwaitingName and bridgeClaimExpiresAt > 0 and os.time() >= bridgeClaimExpiresAt then
        claimEvent = "released"
        bridgeAwaitingName = nil
        bridgeClaimId = nil
        bridgeClaimExpiresAt = 0
    end
    local pollBody = {
        job_id = game.JobId,
        bot_username = me.Name,
        bot_user_id = me.UserId,
        owner_username = XENO_OWNER_USERNAME,
        owner_discord = XENO_OWNER_DISCORD,
        owner_discord_id = XENO_OWNER_DISCORD,
        owner_present = configuredOwner ~= nil,
        place_id = game.PlaceId,
        owner_id = configuredOwner and configuredOwner.UserId or nil,
        owner = G.MM_CurrentOwnerInfo(),
        toggle_config = G.MM_CurrentToggleConfig(),
        player_count = #Players:GetPlayers(),
        player_names = playerNames,
        claim_event = claimEvent,
        claim_id = bridgeClaimId,
        bot_note = bridgeAwaitingName and ("waiting:" .. bridgeAwaitingName) or nil,
    }
    local serverLoc = getServerLocationLabel()
    if serverLoc then
        pollBody.server_location = serverLoc
    end
    local raw = httpJson("POST", XENO_BRIDGE_URL .. "/api/xeno/poll", pollBody)
    if not session.active then return false end
    if not raw then return false end
    local ok, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or not data.ok then return false end
    processBridgeCommands(game.JobId, data.commands)
    processBridgeClaim(data.claim)
    if data.availability == "available" and bridgeAwaitingName and not claimEvent then
        clearBridgeReservation("server available")
    end
    return true
end

trackConnection(Players.PlayerAdded:Connect(function(pl)
    if not session.active or not XENO_BRIDGE_ENABLED or pl == me then return end
    if bridgeAwaitingName and nameMatchesPlayer(pl, bridgeAwaitingName) and bridgeClaimId then
        task.defer(function()
            fulfillBridgeClaim(bridgeClaimId, bridgeAwaitingName)
        end)
    end
end))

trackConnection(Players.PlayerRemoving:Connect(function(p)
    if not session.active or not XENO_BRIDGE_ENABLED then return end
    if session.ownerId and p.UserId == session.ownerId then
        if hopBusy then return end
        bridgeFulfilledClaimId = nil
        bridgeReportClaimEvent("owner_left", { owner_id = nil, note = p.Name })
    end
end))

if XENO_BRIDGE_ENABLED then
    task.spawn(function()
        log("bridge: polling " .. XENO_BRIDGE_URL .. " every " .. tostring(XENO_POLL_SEC) .. "s")
        local fails = 0
        while session.active do
            if not bridgePollOnce() then
                fails = fails + 1
                if fails == 3 then
                    log("bridge: cannot reach Flask (is discord-xeno.py running?)")
                end
            else
                fails = 0
            end
            task.wait(XENO_POLL_SEC)
        end
    end)
end
end)()

task.spawn(function()
    local joinedAt = tick()
    local badPingSince = nil
    local skipThisJoin = not hopState.pingSearchActive
    while session.active do
        if not skipThisJoin and not hopBusy then
            local ping = getPingMs()
            if ping then
                local inRange = ping >= PING_MIN_MS and ping <= PING_MAX_MS
                if inRange then
                    if hopState.pingSearchActive then
                        hopState.pingSearchActive = false
                        log(("ping hop: found %.0fms server"):format(ping))
                    end
                    badPingSince = nil
                else
                    badPingSince = badPingSince or tick()
                    if tick() - joinedAt >= 20 and tick() - badPingSince >= 15 then
                        local owner = findOwner()
                        if owner then whisper(("High ping (%dms), hopping"):format(math.floor(ping + 0.5))) end
                        if not hopServer(("ping %.0fms"):format(ping), true) then
                            badPingSince = tick() - 10
                        end
                    end
                end
            end
        end
        task.wait(5)
    end
end)

--[[ Alerts watcher ]]--
local function aliveState(p)
    local char = p.Character
    if not char then return nil end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return nil end
    return h.Health > 0
end

;(function()
    local alertAt = {}
    local function recentlyAlerted(key)
        local t = alertAt[key]
        return t and (tick() - t) < 5
    end
    local function markAlert(key)
        alertAt[key] = tick()
    end
    local function playerByName(name)
        local p = Players:FindFirstChild(name)
        if p and p:IsA("Player") then return p end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Name == name then return pl end
        end
    end
    local function roleOfName(name)
        local rec = G.MM_PlayerData[name]
        return rec and rec.Role
    end
    local function announceKill(name, rec)
        if not toggleAlerts then return end
        if recentlyAlerted(name) then return end
        local p = playerByName(name)
        if p == me then return end
        if not resolveWhisperTarget() then return end
        markAlert(name)
        local label = p and shortName(p) or tostring(name):sub(1, 4) .. "..."
        rec = rec or {}
        local role = rec.Role
        local killerRole = rec.Killer and roleOfName(rec.Killer)
        if killerRole == "Sheriff" or killerRole == "Hero" then
            if role == "Murderer" then
                G.MM_SuppressGunDrop = tick()
                whisper((killerRole == "Hero" and "Hero" or "Sheriff") .. " killed the murderer")
                return
            end
            sheriffRoundKills = sheriffRoundKills + 1
            whisper((killerRole == "Hero" and "Hero" or "Sheriff") .. " shot " .. label)
            return
        end
        if killerRole == "Murderer" then
            if role == "Sheriff" then
                whisper("Murderer killed the sheriff")
                return
            end
            if role == "Hero" then
                whisper("Murderer killed the hero")
                return
            end
            murdererRoundKills = murdererRoundKills + 1
            whisper("Murderer killed " .. label)
            return
        end
        if role == "Murderer" then
            G.MM_SuppressGunDrop = tick()
            local hero = G.MM_FindRole and G.MM_FindRole("Hero")
            whisper((hero and "Hero" or "Sheriff") .. " killed the murderer")
            return
        end
        if role == "Sheriff" then
            whisper("Murderer killed the sheriff")
            return
        end
        if role == "Hero" then
            whisper("Murderer killed the hero")
            return
        end
        murdererRoundKills = murdererRoundKills + 1
        whisper("Murderer killed " .. label)
    end
    G.MM_OnPlayerKilled = function(name, rec)
        if not session.active then return end
        announceKill(name, rec)
        local own = adoptedOwnerPlayer()
        if own and (own.Name == name or tostring(own.UserId) == tostring(name)) and ownerIsConfirmedDead(own) then
            if toggleResetOnOwnerDeath and not G.MM_Resetting and not _G.MM_GunBusy and not _G.MM_StabBusy and not _G.MM_ShootBusy then
                log("owner killed -> resetting bot (" .. own.Name .. ")")
                task.spawn(function() pcall(reset) end)
            elseif toggleResetOnOwnerDeath then
                _G.MM_OwnerDiedPendingReset = true
            end
        end
    end
    local function bindDied(p, char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        trackConnection(hum.Died:Connect(function()
            task.spawn(function()
                local deadline = tick() + 1.15
                while session.active and tick() < deadline do
                    local rec = G.MM_PlayerData[p.Name]
                    if rec then
                        if rec.Killed then
                            announceKill(p.Name, rec)
                            return
                        end
                        if G.MM_HasKilledField and rec.Dead and rec.Killed == false then
                            return
                        end
                    end
                    task.wait(0.1)
                end
                if G.MM_HasKilledField then return end
                local rec = G.MM_PlayerData[p.Name] or {}
                if not rec.Role and G.MM_RoleOf then rec.Role = G.MM_RoleOf(p) end
                local creator = hum:FindFirstChild("creator")
                local killer
                if creator and creator.Value then
                    killer = Players:GetPlayerFromCharacter(creator.Value) or creator.Value
                    if typeof(killer) ~= "Instance" or not killer:IsA("Player") then killer = nil end
                end
                if killer and killer ~= p then
                    rec.Killer = killer.Name
                    rec.Killed = true
                    announceKill(p.Name, rec)
                end
            end)
        end))
    end
    local function hookPlayer(p)
        if p.Character then bindDied(p, p.Character) end
        trackConnection(p.CharacterAdded:Connect(function(char)
            task.wait(0.1)
            bindDied(p, char)
        end))
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me then hookPlayer(p) end
    end
    trackConnection(Players.PlayerAdded:Connect(hookPlayer))
    task.spawn(function()
        local wasLive = false
        while session.active do
            local live = G.MM_RoundLive
            if wasLive and not live then alertAt = {} end
            wasLive = live
            task.wait(0.5)
        end
    end)
end)()

task.spawn(function()
    local alivePrev = {}
    local knifeIdPrev, gunIdPrev = nil, nil
    local droppedGunPrev = false
    local suppressDrop = false
    while session.active do
        local kHolder = findHolder({"Knife"})
        local gHolder = findHolder(G.MM_GunNames)
        local kid = kHolder and kHolder.UserId
        local gid = gHolder and gHolder.UserId
        local droppedGun = findDroppedGun() ~= nil
        if kid and not knifeIdPrev then suppressDrop = false end
        -- Always watch owner life (not gated on toggleAlerts); nil cur = character gone after death.
        local own = adoptedOwnerPlayer()
        if own then
            local cur = not ownerIsConfirmedDead(own)
            local prev = alivePrev[own.UserId]
            if prev == true and cur == false then
                local oh = own.Character and (own.Character:FindFirstChild("HumanoidRootPart") or own.Character.PrimaryPart)
                if G.MM_MarkIgnoreDrop then
                    G.MM_MarkIgnoreDrop(oh and oh.Position, 12)
                else
                    G.MM_BlockGunGrab = true
                    G.MM_SkipGunUntil = tick() + 12
                end
                if not toggleResetOnOwnerDeath then
                    log("owner died (reset on death off) (" .. own.Name .. ")")
                elseif G.MM_Resetting then
                    log("owner died (reset already running) (" .. own.Name .. ")")
                elseif _G.MM_GunBusy or _G.MM_StabBusy or _G.MM_ShootBusy then
                    _G.MM_OwnerDiedPendingReset = true
                    log("owner died during combat (reset deferred) (" .. own.Name .. ")")
                else
                    log("owner died -> resetting bot (" .. own.Name .. ")")
                    task.spawn(function() pcall(reset) end)
                end
            end
        end
        if toggleAlerts and resolveWhisperTarget() then
            if gunIdPrev and not gid and not suppressDrop then
                if G.MM_SuppressGunDrop and (tick() - G.MM_SuppressGunDrop) < 2.5 then
                    suppressDrop = true
                end
                local prevGun = Players:GetPlayerByUserId(gunIdPrev)
                local rec = prevGun and G.MM_PlayerData[prevGun.Name]
                if rec and (rec.Dead or rec.Killed) then
                    suppressDrop = true
                end
                if not suppressDrop and prevGun and aliveState(prevGun) == true then
                    whisper("Sheriff dropped the gun")
                end
            end
            if not gunIdPrev and gid and droppedGunPrev and gHolder then
                whisper(shortName(gHolder) .. " picked up the gun")
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            local cur = aliveState(p)
            if session.ownerId and p.UserId == session.ownerId then
                local rec = G.MM_PlayerData[p.Name] or G.MM_PlayerData[tostring(p.UserId)]
                if rec and (rec.Dead == true or rec.Killed == true) then
                    cur = false
                end
            end
            if cur ~= nil then
                alivePrev[p.UserId] = cur
            elseif alivePrev[p.UserId] == true then
                alivePrev[p.UserId] = false
            end
        end
        if kid ~= whoKnifeIdPrev then
            murdererRoundKills = 0
            whoKnifeIdPrev = kid
        end
        if gid ~= whoGunIdPrev then
            sheriffRoundKills = 0
            whoGunIdPrev = gid
        end
        knifeIdPrev = kid
        gunIdPrev = gid
        droppedGunPrev = droppedGun
        task.wait(0.12)
    end
end)

log("bot online")
if XENO_OWNER_USERNAME == "" then
    log("configured username missing: set getgenv().xeno_roblox before execute")
else
    log("configured username: " .. XENO_OWNER_USERNAME .. " (not session owner)")
end
if XENO_OWNER_DISCORD == "" then
    log("configured discord missing: set getgenv().xeno_discord before execute")
else
    log("configured discord: " .. XENO_OWNER_DISCORD)
end
do
    local o = findOwner()
    if o then
        log("adopted owner: " .. o.Name)
    else
        log("adopted owner: none")
    end
end

if XENO_BRIDGE_ENABLED then
    task.spawn(function()
        task.wait(G.MM_RegionSpreadCheck and 3 or 2)
        ensureRegionSpreadOnStart()
    end)
end

local runMainLoop
do
local function playerWithAssignedRole(want)
    want = tostring(want or ""):lower()
    for _, p in ipairs(Players:GetPlayers()) do
        local rec = G.MM_PlayerData[p.Name] or G.MM_PlayerData[tostring(p.UserId)]
        if rec and type(rec.Role) == "string" and rec.Role:lower() == want then
            return p
        end
    end
end

local function resolveAssignedRoles(timeout)
    local deadline = tick() + (timeout or 0)
    local curM, curS
    repeat
        curM = playerWithAssignedRole("Murderer")
        curS = playerWithAssignedRole("Sheriff") or playerWithAssignedRole("Hero")
        if curM and curS then break end
        if tick() >= deadline then break end
        task.wait(0.15)
    until false
    return curM, curS, curM == me, curS == me
end

local function sendRoundRoleCallouts(curM, curS)
    if G.MM_RoleSentThisRound then return true end
    if not resolveWhisperTarget() then return false end
    if not curM or not curS then return false end
    local mLabel = (curM == me) and "Me" or shortName(curM)
    local sLabel = (curS == me) and "Me" or shortName(curS)
    local rec = G.MM_PlayerData[curS.Name]
    if rec and tostring(rec.Role or ""):lower() == "hero" then
        sLabel = sLabel .. " (hero)"
    end
    sendRoleLines(mLabel, sLabel)
    G.MM_RoleSentThisRound = true
    G.MM_MurderOnlySent = false
    return true
end

local function waitForRoleCallouts()
    local curM, curS, curBotM, curBotS = resolveAssignedRoles(6)
    local ok = sendRoundRoleCallouts(curM, curS)
    return ok, curM, curS, curBotM, curBotS
end

--[[ Main loop ]]--
function runMainLoop()
    local lastMurderId, announced
    local lastRoundPulse = 0
    local lastAnnounceAt = 0
    local lobbySince = 0
    local ownerMurdStashBusy = false
    local nextAutoGunAt = 0
    local nextAutoShootAt = 0
    local lastAutoDropSig = nil
while session.active and gui and gui.Parent do
    local m = (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
    local s = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
        or (G.MM_FindRole and G.MM_FindRole("Hero"))
        or findHolder(G.MM_GunNames)
        local botM = (m == me) or botHasKnife()
        local roundActive = isRoundActive()

    if G.MM_BlockGunGrab and tick() >= (tonumber(G.MM_SkipGunUntil) or 0) then
        G.MM_BlockGunGrab = false
    end
    local liveNow = (G.MM_RoundLive == true) or (m ~= nil) or botM
    local pulse = tonumber(G.MM_RoundPulse) or 0
    if pulse > 0 and pulse ~= lastRoundPulse then
        lastRoundPulse = pulse
        G.MM_LastMurdReset = false
        G.MM_PeakAlive = 0
        G.MM_HoldStand = false
        G.MM_HoldMove = false
        G.MM_SummonFocusId = nil
        G.MM_AdoptAt = nil
        log("round start: hide under spawn")
        if G.MM_StartHideLoop then
            G.MM_StartHideLoop()
        elseif G.MM_EnsureAutoStand then
            G.MM_EnsureAutoStand()
        end
        G.MM_BlockGunGrab = false
    end
    if m then
        if lastMurderId ~= m.UserId then
            lastMurderId = m.UserId
            pcall(function() img.Image = Players:GetUserThumbnailAsync(m.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
            lbl.Text = m.DisplayName
        end
        f.Visible = true
    else
        f.Visible = false
        lastMurderId = nil
    end
    if not liveNow then
        if lobbySince == 0 then lobbySince = tick() end
        if tick() - lobbySince > 8 then
            announced, gunDelivered, shootDone, revealAnnouncePending = false, false, false, false
            ownerMurdStashBusy = false
            roleAnnounceUnlockAt = 0
            G.MM_BlockGunGrab = false
            G.MM_RoleSentThisRound = false
            G.MM_MurderOnlySent = false
            G.MM_LastMurdReset = false
            G.MM_PeakAlive = 0
            G.MM_RoleSentKey = nil
        end
    else
        lobbySince = 0
    end
    if G.MM_EnsureAutoStand then
        G.MM_EnsureAutoStand()
    end

    if liveNow then
        local living = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= me then
                local rec = G.MM_PlayerData[pl.Name] or G.MM_PlayerData[tostring(pl.UserId)]
                local down = rec and (rec.Dead == true or rec.Killed == true)
                if isAlive(pl) and not down then
                    table.insert(living, pl)
                end
            end
        end
        G.MM_PeakAlive = math.max(tonumber(G.MM_PeakAlive) or 0, #living)
        local owner = findOwner()
        local ownerAlive = false
        if owner and owner ~= me then
            local orec = G.MM_PlayerData[owner.Name] or G.MM_PlayerData[tostring(owner.UserId)]
            local ownerDown = orec and (orec.Dead == true or orec.Killed == true)
            ownerAlive = isAlive(owner) and not ownerDown
        end
        if announced and not G.MM_LastMurdReset and (tonumber(G.MM_PeakAlive) or 0) >= 2
           and #living == 1 and m and living[1] == m and m ~= me and m ~= owner
           and not ownerAlive and not botM and not G.MM_Resetting then
            G.MM_LastMurdReset = true
            log("only murderer & bot left -> reset")
            task.spawn(function() pcall(reset) end)
        end
    else
        G.MM_PeakAlive = 0
        G.MM_LastMurdReset = false
    end

    if (m or botM) and not announced then
        announced = true
        lastAnnounceAt = tick()
        gunDelivered = false
        shootDone = false
        revealAnnouncePending = true
        if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
        local owner = findOwner()
        task.spawn(function()
            local ok, err = pcall(function()
                local curM, curS, curBotM, curBotS
                if toggleReveal then
                    local _
                    _, curM, curS, curBotM, curBotS = waitForRoleCallouts()
                else
                    curM, curS, curBotM, curBotS = resolveAssignedRoles(0.5)
                end

                if curBotM and owner and curS and owner.UserId == curS.UserId then
                    tpTo(owner)
                elseif G.MM_EnsureAutoStand then
                    G.MM_EnsureAutoStand()
                end
            end)
            if not ok then log("reveal: " .. tostring(err)) end
            pcall(function()
                if G.MM_NoteRoundForTips then G.MM_NoteRoundForTips() end
                if G.MM_NoteRoundForAdoptAd then G.MM_NoteRoundForAdoptAd() end
            end)
            roleAnnounceUnlockAt = tick() + 0.35
            revealAnnouncePending = false
        end)
    end

    local ownerForDrop = findOwner()
        local ownerIsMurd = ownerMurdererActive(m, ownerForDrop) and not botM
        -- Do not clear toggleGun here — owner-murderer only pauses delivery below; user setting stays on.

        -- Owner murderer: stash guns at spawn when enabled with !toggledrop.
        if session.ownerId and ownerIsMurd and ownerIsPremium() and toggleDrop and roundActive and (G.MM_UnderSpawn or SPAWN_CFRAME)
           and not ownerMurdStashBusy and not revealAnnouncePending
           and tick() >= roleAnnounceUnlockAt
           and tick() >= (tonumber(G.MM_SkipGunUntil) or 0)
           and not _G.MM_OwnerDiedPendingReset
           and isAlive(me) and gunAvailableForOwnerMurdStash()
           and not _G.MM_GunBusy and not _G.MM_StabBusy and not _G.MM_ShootBusy
           and not flingActive and not flingLoopActive and not flingLoopContinuous and not flingSettling
        then
            ownerMurdStashBusy = true
        _G.MM_GunBusy = true
        task.spawn(function()
                pcall(stashGunAtSpawn)
                task.wait(OWNER_MURD_STASH_COOLDOWN)
            _G.MM_GunBusy = false
                ownerMurdStashBusy = false
        end)
    end

    if toggleShoot and not shootDone and not flingLoopContinuous and not botM and not ownerIsMurd
       and not _G.MM_GunBusy and not _G.MM_StabBusy and not _G.MM_ShootBusy
       and not _G.MM_OwnerDiedPendingReset
       and isAlive(me) and me.Character and not revealAnnouncePending and tick() >= roleAnnounceUnlockAt
       and tick() >= nextAutoShootAt
       and tick() >= (tonumber(G.MM_SkipGunUntil) or 0)
       and not flingActive and not flingLoopActive and not flingSettling
       and gunAvailableForOwnerMurdStash() then
        local shootTgt
        if shootTargetId then
            shootTgt = Players:GetPlayerByUserId(shootTargetId)
        else
            shootTgt = m
        end
        if shootTgt and shootTgt ~= me and isAlive(shootTgt) then
            nextAutoShootAt = tick() + 2.5
            _G.MM_ShootBusy = true
            G.MM_ActionBegin()
            local uid = shootTgt.UserId
            task.spawn(function()
                local status = ""
                pcall(function()
                    local tgt = Players:GetPlayerByUserId(uid)
                    if not tgt or not isAlive(tgt) then return end
                    if not G.MM_EnsureShootGun() then
                        status = "No gun"
                        return
                    end
                    local _, msg = G.MM_ShootTargetLoop(tgt)
                    status = tostring(msg or "")
                end)
                if status:find("Shot", 1, true) or status:find("timed out", 1, true) or status:find("Stopped", 1, true) then
                    shootDone = true
                end
                _G.MM_ShootBusy = false
                G.MM_ActionEnd()
                runDeferredOwnerResetIfIdle()
            end)
        end
    end

    local gunTarget = (gunTargetId and Players:GetPlayerByUserId(gunTargetId)) or findOwner()
    local dropNow = findDroppedGun()
    if dropNow then
        local sig = string.format("%.0f:%.0f:%.0f", dropNow.Position.X, dropNow.Position.Y, dropNow.Position.Z)
        if sig ~= lastAutoDropSig then
            lastAutoDropSig = sig
            if toggleGun and gunTarget and not G.MM_TargetHasGun(gunTarget) then
                gunDelivered = false
                log("gun: drop seen, auto-gun queued")
            end
        end
    else
        lastAutoDropSig = nil
    end
        if toggleGun and not flingLoopContinuous and not botM and not ownerIsMurd and not gunDelivered and not _G.MM_GunBusy and not _G.MM_StabBusy and not _G.MM_ShootBusy
           and not _G.MM_OwnerDiedPendingReset
           and isAlive(me) and me.Character
           and (dropNow or botHasGun() or tick() >= roleAnnounceUnlockAt)
           and tick() >= nextAutoGunAt
           and not flingActive and not flingLoopActive and not flingSettling
       and gunTarget and gunTarget ~= me and isAlive(gunTarget)
           and (botHasGun() or dropNow) then
        nextAutoGunAt = tick() + 2.2
        _G.MM_GunBusy = true
        log("gun: auto-deliver to " .. gunTarget.Name)
        task.spawn(function()
            local ok = bringGun(gunTarget)
            gunDelivered = ok or G.MM_TargetHasGun(gunTarget)
            if not gunDelivered then
                log("gun: auto-deliver missed, retrying")
                nextAutoGunAt = tick() + 0.35
            end
            task.wait(0.4)
            _G.MM_GunBusy = false
        end)
    end

    local spec = findOwner()
    local subject = (spec and spec.Character and spec.Character:FindFirstChildOfClass("Humanoid"))
                  or (me and me.Character and me.Character:FindFirstChildOfClass("Humanoid"))
    pcall(function()
        if not cam then cam = workspace.CurrentCamera end
        if not cam then return end
        if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
        if subject then cam.CameraSubject = subject end
        cam.FieldOfView = WIDE_FOV
    end)
    task.wait(0.5)
end

--[[ Cleanup ]]--
pcall(function()
    if not cam then cam = workspace.CurrentCamera end
    if cam then cam.FieldOfView = DEFAULT_FOV end
    local h = me and me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if cam and h then cam.CameraSubject = h end
end)
    cleanupSession()
end
end

G.MM_BootReady = true
pcall(function()
    if G.MM_EnsureAutoStand then G.MM_EnsureAutoStand() end
end)
runMainLoop()