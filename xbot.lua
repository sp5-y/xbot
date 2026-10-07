--[[ Xeno V1.03 XBOT_BUILD 20261006d ]]--
local Players = game:GetService("Players")
local cref = cloneref or function(x) return x end
local TCS = cref(game:GetService("TextChatService"))
local Tween = game:GetService("TweenService")
local RunSvc = game:GetService("RunService")
local RS = cref(game:GetService("ReplicatedStorage"))
local Http = cref(game:GetService("HttpService"))
local Stats = cref(game:GetService("Stats"))
local StarterGui = cref(game:GetService("StarterGui"))
local TeleportSvc = cref(game:GetService("TeleportService"))
local isLegacy = TCS.ChatVersion == Enum.ChatVersion.LegacyChatService
local me, cam = Players.LocalPlayer, workspace.CurrentCamera
local UIS = cref(game:GetService("UserInputService"))
local DEFAULT_FOV, WIDE_FOV = 70, 100
local SPAWN_CFRAME = CFrame.new(14.3513288, 505.044952, -58.2513657, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local toggleGun = false
local toggleShoot = false
local toggleAlerts = false
local toggleReveal = true
local toggleResetOnOwnerDeath = false
local toggleDrop = false
local gunTargetId = nil
local gunDelivered = false
local shootTargetId = nil
local shootDone = false
local hopBusy = false
local PING_MIN_MS, PING_MAX_MS = 50, 90
local G = getgenv and getgenv() or _G
-- true = keep 3D on (no white screen). false = background mode for farm bots.
local GRAPHICS = G.xeno_graphics ~= on
local TARGET_FPS = tonumber(G.xeno_fps) or 50
local XENO_OWNER_USERNAME = tostring(G.xeno_roblox or _G.xeno_roblox or xeno_roblox or ""):match("^%s*(.-)%s*$") or ""
local XENO_OWNER_DISCORD = tostring(G.xeno_discord or _G.xeno_discord or xeno_discord or ""):match("^%s*(.-)%s*$") or ""
local PUBLIC_MODE = G.public_mode == true or _G.public_mode == true
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
    if G.MM_AntiFlingShutdown then pcall(G.MM_AntiFlingShutdown) end
    if gui and gui.Parent then pcall(function() gui:Destroy() end) end
end
G.MM_Session = session
G.MM_Cleanup = cleanupSession
_G.MM_Session = session
_G.MM_Cleanup = cleanupSession
do
    local pending = tonumber(G.MM_PendingOwnerId)
    if pending and pending > 0 then
        session.ownerId = pending
    end
end
cam.FieldOfView = DEFAULT_FOV
do local h = me.Character and me.Character:FindFirstChildOfClass("Humanoid") 
   if h then cam.CameraSubject = h end end

--[[ Render / FPS ]]--
-- GRAPHICS on = normal view. GRAPHICS off = white/blank 3D off (old farm mode).
task.spawn(function()
    local VU = game:GetService("VirtualUser")
    local UGS = UserSettings():GetService("UserGameSettings")
    pcall(function()
        trackConnection(Players.LocalPlayer.Idled:Connect(function()
            if not session.active then return end
            VU:CaptureController()
            VU:ClickButton2(Vector2.new(math.random(10, 50), math.random(10, 50)))
        end))
    end)
    pcall(function()
        RunSvc:Set3dRenderingEnabled(GRAPHICS)
        if setfpscap then setfpscap(TARGET_FPS) end
        if GRAPHICS then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        else
            settings().Rendering.QualityLevel = 1
            UGS.MasterVolume = 0
        end
    end)
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
local logFrame = Instance.new("Frame", gui)
logFrame.Size = UDim2.new(0, 260, 0, 130)
logFrame.Position = UDim2.new(1, -270, 1, -140)
logFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
logFrame.BackgroundTransparency = 0.3
logFrame.BorderSizePixel = 0
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 6)
local logList = Instance.new("UIListLayout", logFrame)
logList.SortOrder = Enum.SortOrder.LayoutOrder
logList.Padding = UDim.new(0, 1)
local logPad = Instance.new("UIPadding", logFrame)
logPad.PaddingLeft, logPad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
logPad.PaddingTop, logPad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
local logCounter = 0
local function log(msg)
    logCounter = logCounter + 1
    local order = logCounter
    local t = Instance.new("TextLabel", logFrame)
    t.Size = UDim2.new(1, 0, 0, 14)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.Code
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = Color3.fromRGB(180, 230, 180)
    t.Text = "[" .. os.date("%X") .. "] " .. tostring(msg)
    t.LayoutOrder = order
    t.TextTruncate = Enum.TextTruncate.AtEnd
    local kids = logFrame:GetChildren()
    local labels = {}
    for _, c in ipairs(kids) do
        if c:IsA("TextLabel") then table.insert(labels, c) end
    end
    table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #labels > 8 do
        labels[1]:Destroy()
        table.remove(labels, 1)
    end
end

--[[ Finders ]]--
G.MM_GunNames = G.MM_GunNames or {"Gun", "Revolver", "SheriffGun", "Laser", "Luger", "Blaster"}
G.MM_KnifeNames = G.MM_KnifeNames or {"Knife"}
local function hasItem(parent, names)
    for _, c in ipairs(parent and parent:GetChildren() or {}) do
        if table.find(names, c.Name) then return true end
    end
end
local function playerHas(p, names)
    return hasItem(p.Character, names) or hasItem(p:FindFirstChildOfClass("Backpack"), names)
end
local function findHolder(names)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me and playerHas(p, names) then return p end
    end
end
local function botHasGun() return playerHas(me, G.MM_GunNames) end
local function botHasKnife() return playerHas(me, G.MM_KnifeNames) end
local function findDroppedGun()
    local function asPart(obj)
        if not obj then return end
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
        end
        if obj:IsA("Tool") then
            return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
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
            local h = o:FindFirstChild("Handle") or o:FindFirstChildWhichIsA("BasePart")
            if h then return h end
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") and (o.Name == "GunDrop" or o.Name == "DroppedGun") then return o end
    end
end

-- MM2 GetPlayerData: Role, Dead, Killed. Killed = stabbed/shot. Dead without Killed = reset.
G.MM_PlayerData = {}
G.MM_HasKilledField = false
G.MM_RoundLive = false
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
        local role = info.Role or info.role
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
                if old and not old.Killed and rec.Killed then
                    local cb = G.MM_OnPlayerKilled
                    if cb then pcall(cb, name, rec) end
                end
            end
        end
        if n == 0 then return end
        local playerCount = #Players:GetPlayers()
        if sawRole then
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
    pcall(function()
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
        end)
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
        end)
    end)
    G.MM_FindRole = function(want)
        for _, p in ipairs(Players:GetPlayers()) do
            local rec = G.MM_PlayerData[p.Name]
            if rec and rec.Role == want and not rec.Dead then
                return p
            end
        end
        if want == "Murderer" then
            if botHasKnife() then return me end
            return findHolder({"Knife"})
        end
        if want == "Sheriff" or want == "Hero" then
            if botHasGun() then
                local rec = G.MM_PlayerData[me.Name]
                if rec and rec.Role == want then return me end
                if want == "Sheriff" and (not rec or rec.Role ~= "Hero") then return me end
            end
            local h = findHolder(G.MM_GunNames)
            if not h then return end
            local rec = G.MM_PlayerData[h.Name]
            if rec and rec.Role == want then return h end
            if not rec then return h end
            if want == "Sheriff" and rec.Role ~= "Hero" then return h end
            if want == "Hero" and rec.Role == "Hero" then return h end
        end
    end
    G.MM_RoleOf = function(p)
        if not p then return end
        local rec = G.MM_PlayerData[p.Name]
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
                local rf = findRemote("GetPlayerData", "RemoteFunction")
                if rf then
                    ingest(rf:InvokeServer())
                end
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
    if not session.ownerId then return end
    return Players:GetPlayerByUserId(session.ownerId)
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
    local p = findConfiguredOwner()
    if p then
        if session.ownerId ~= p.UserId then
            session.ownerId = p.UserId
            G.MM_PendingOwnerId = p.UserId
            _G.MM_OwnerDiedPendingReset = false
            if bridgeOwnerConnected then
                scheduleOwnerOnboarding(p.UserId)
            end
            log("configured owner found: " .. p.Name)
        end
        return p
    end
    if session.ownerId then
        local current = Players:GetPlayerByUserId(session.ownerId)
        if not current then
            session.ownerId = nil
            G.MM_PendingOwnerId = nil
        elseif ACTIVE_OWNER_USERNAME ~= "" and not configuredOwnerMatches(current) then
            session.ownerId = nil
            G.MM_PendingOwnerId = nil
        end
    end
    return nil
end

local function authorizeCommand(p)
    if ACTIVE_OWNER_USERNAME ~= "" and configuredOwnerMatches(p) then
        syncConfiguredOwner()
    end
    return session.ownerId and p.UserId == session.ownerId
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
    return p and session.ownerId and p.UserId == session.ownerId
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
local function sendChat(msg)
    msg = tostring(msg or ""):match("^%s*(.-)%s*$") or ""
    if msg == "" then return false end
    local ok = pcall(function()
        if not isLegacy then
            TCS.TextChannels.RBXGeneral:SendAsync(msg)
        else
            RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
        end
    end)
    return ok == true
end
pcall(function() StarterGui:SetCore("ChatActive", true) end)

local function getGeneralChannel()
    local channels = TCS:FindFirstChild("TextChannels") or TCS:WaitForChild("TextChannels", 8)
    if not channels then return end
    return channels:FindFirstChild("RBXGeneral") or channels:WaitForChild("RBXGeneral", 8)
end

local function whisperChannelNameFor(uid)
    local a, b = tonumber(me.UserId), tonumber(uid)
    if not a or not b then return end
    if a > b then a, b = b, a end
    return ("RBXWhisper:%d_%d"):format(a, b)
end

local function findWhisperChannel(uid)
    uid = tostring(uid)
    local channels = TCS:FindFirstChild("TextChannels")
    if channels then
        local exact = channels:FindFirstChild(whisperChannelNameFor(uid) or "")
        if exact and exact:IsA("TextChannel") then return exact end
        for _, ch in ipairs(channels:GetChildren()) do
            if ch:IsA("TextChannel") and ch.Name:match("RBXWhisper") then
                if tostring(ch.Name):find(uid, 1, true) then
                    return ch
                end
            end
        end
    end
end

local function pollWhisperChannel(uid, duration)
    local t0 = tick()
    while tick() - t0 < duration do
        local ch = findWhisperChannel(uid)
        if ch then return ch end
        task.wait(0.08)
    end
    return findWhisperChannel(uid)
end

local function whisperTargets(o)
    local targets, seen = {}, {}
    local function add(handle)
        handle = tostring(handle or ""):gsub("^%s*(.-)%s*$", "%1")
        if handle == "" or seen[handle:lower()] then return end
        seen[handle:lower()] = true
        table.insert(targets, handle)
    end
    add("@" .. o.Name)
    add(o.Name)
    local dn = tostring(o.DisplayName or ""):gsub("^@", "")
    if dn ~= "" then
        add(dn)
        add("@" .. dn)
    end
    return targets
end

local function fireLegacyWhisper(o, m)
    local events = RS:FindFirstChild("DefaultChatSystemChatEvents")
    if not events then return false end
    local say = events:FindFirstChild("SayMessageRequest")
    if not say then return false end
    for _, handle in ipairs(whisperTargets(o)) do
        local ok = pcall(function()
            say:FireServer("/w " .. handle .. " " .. m, "All")
        end)
        if ok then return true end
    end
    return false
end

local function sendOnWhisperChannel(chan, m)
    if not chan then return false end
    local ok, result = pcall(function()
        return chan:SendAsync(m)
    end)
    return ok and result ~= false
end

local function openWhisperChannel(o)
    local ch = findWhisperChannel(o.UserId)
    if ch then return ch end
    local general = getGeneralChannel()
    if not general then return end
    for _, handle in ipairs(whisperTargets(o)) do
        pcall(function()
            general:SendAsync("/w " .. handle .. " .")
        end)
        ch = pollWhisperChannel(o.UserId, 2.5)
        if ch then return ch end
    end
    return findWhisperChannel(o.UserId)
end

local function deliverWhisper(o, m)
    m = tostring(m or "")
    if m == "" then return false end
    if isLegacy then
        return fireLegacyWhisper(o, m)
    end
    local ch = openWhisperChannel(o)
    if sendOnWhisperChannel(ch, m) then return true end
    task.wait(0.25)
    ch = findWhisperChannel(o.UserId) or openWhisperChannel(o)
    if sendOnWhisperChannel(ch, m) then return true end
    local general = getGeneralChannel()
    if general then
        for _, handle in ipairs(whisperTargets(o)) do
            local ok = pcall(function()
                general:SendAsync("/w " .. handle .. " " .. m)
            end)
            if ok then return true end
        end
    end
    return fireLegacyWhisper(o, m)
end

local function resolveWhisperTarget(target)
    local isInst = false
    if typeof then
        isInst = typeof(target) == "Instance"
    elseif type(target) == "userdata" then
        isInst = pcall(function() return target:IsA("Player") end)
    end
    if isInst and target:IsA("Player") then
        return target
    end
    local o = findOwner() or findConfiguredOwner()
    if not o and session.ownerId then
        o = Players:GetPlayerByUserId(session.ownerId)
    end
    return o
end

local function whisper(m, target)
    local o = resolveWhisperTarget(target)
    if not o then log("whisper: no target") return end
    log("-> " .. o.DisplayName .. ": " .. m)
    local ok, err = pcall(function()
        if not deliverWhisper(o, m) then
            log("whisper: send failed for " .. o.Name)
        end
    end)
    if not ok then log("whisper: " .. tostring(err)) end
end

local function whisperOk(m, target)
    local o = resolveWhisperTarget(target)
    if not o then return false end
    log("-> " .. o.DisplayName .. ": " .. m)
    local ok, result = pcall(function()
        return deliverWhisper(o, m)
    end)
    return ok and result == true
end
local function commandReply(msg)
    if PUBLIC_MODE then
        return sendChat(msg)
    end
    whisper(msg)
    return true
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
local function seenCommandRecently(p, msg)
    msg = tostring(msg or "")
    if msg == "" then return true end
    local key = tostring(p.UserId) .. "\0" .. msg
    local now = tick()
    local last = recentCommandKeys[key]
    recentCommandKeys[key] = now
    if last and now - last < 1.5 then return true end
    task.delay(3, function()
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

local function queueRegionSpreadOnTeleport()
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

local function getPingMs()
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

local function hopServer(reason, continuePingSearch, targetServerId)
    if hopBusy then return false end
    hopBusy = true
    stopFollow()
    if continuePingSearch then
        hopState.pingSearchActive = true
        queuePingSearchOnTeleport()
    else
        if session.ownerId then
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

--[[ Movement ]]--
local function hrp() return me.Character and me.Character:FindFirstChild("HumanoidRootPart") end
local followTarget = nil
local function stopFollow()
    followTarget = nil
end
local GUN_MOTION_SAMPLE_SEC = 0.1
do
local GUN_DROP_PREDICT_SEC = 0.45
local GUN_RESET_LATENCY_SEC = 0.18
local GUN_PICKUP_FORWARD = 0.8
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
    lead = math.clamp(lead, 1.7, 10.5)
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
    G.MM_GrabDroppedGun = function(timeout)
        if botHasGun() then return true end
        timeout = timeout or 3.2
        local h = hrp()
        if not (h and isAlive(me)) then return false end
        local t0 = tick()
        local logged = false
        while session.active and tick() - t0 < timeout do
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
        timeout = timeout or 1.35
        if not isAlive(target) then return false end
        local t0 = tick()
        while session.active and tick() - t0 < timeout do
            if playerHas(target, G.MM_GunNames) then return true end
            if botHasGun() then return false end
            local drop = findDroppedGun()
            if not drop then return playerHas(target, G.MM_GunNames) end
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
        local char = me.Character
        if not char then return end
        local h = char:FindFirstChild("HumanoidRootPart")
        if h then
            pcall(function() h.Anchored = false end)
            zeroVel(h)
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.Health = 0 end)
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
    stopFollow()
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
    stopFollow()
    local h = hrp()
    if h and SPAWN_CFRAME then
        pcall(function() h.Anchored = false end)
        zeroVel(h)
        h.CFrame = SPAWN_CFRAME
        zeroVel(h)
    end
end
local function reset(stay)
    stopFollow()
    if stay and G.MM_DieInPlace then
        G.MM_DieInPlace()
        return
    end
    local char = me.Character
    if not char then return end
    local h = char:FindFirstChild("HumanoidRootPart")
    if h then
        pcall(function() h.CFrame = CFrame.new(0, -10000, 0) end)
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.Health = 0 end)
        pcall(function() hum:TakeDamage(hum.MaxHealth * 2) end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
    end
    pcall(function() char:BreakJoints() end)
    pcall(function() me:LoadCharacter() end)
end
local function runDeferredOwnerResetIfIdle()
    if not toggleResetOnOwnerDeath then
        _G.MM_OwnerDiedPendingReset = false
        return
    end
    if _G.MM_OwnerDiedPendingReset and not _G.MM_GunBusy and not G.MM_StabBusyActive() and not _G.MM_ShootBusy then
        _G.MM_OwnerDiedPendingReset = false
        log("owner died during combat -> resetting bot")
        task.spawn(function() pcall(reset) end)
    end
end
local function standOnTarget(target, boost)
    boost = boost or 1
    stopFollow()
    local h = hrp()
    local oh = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not (h and oh) then return false end
    local samplePos, sampleAt = oh.Position, tick()
    task.wait(GUN_MOTION_SAMPLE_SEC)
    oh = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not (h and oh and isAlive(target)) then return false end
    local dt = math.max(tick() - sampleAt, 0.03)
    local observedVelocity = (oh.Position - samplePos) / dt
    local lead = G.MM_gunDropLead(oh, hum, boost, observedVelocity, target.UserId, dt)
    local dropPos = oh.Position + lead + Vector3.new(0, 0.25, 0)
    local face = lead.Magnitude > 0.1 and (dropPos + lead.Unit) or (oh.Position + oh.CFrame.LookVector)
    zeroVel(h)
    h.CFrame = CFrame.new(dropPos, face)
    zeroVel(h)
    return true
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
local function bringGun(target)
    if _G.MM_StabBusy then return false end
    G.MM_ActionBegin()
    local function finish(ok)
        G.MM_ActionEnd()
        return ok
    end
    target = target or findOwner()
    if not isAlive(target) then return finish(false) end
    if G.MM_TargetHasGun(target) then return finish(true) end

    -- 1) GunDrop already on the map: touch it to the target. Bot stays alive.
    if findDroppedGun() and not botHasGun() then
        if G.MM_DeliverDrop and G.MM_DeliverDrop(target, 1.4) then
            log("gun: delivered GunDrop without reset")
            return finish(true)
        end
        if G.MM_TargetHasGun(target) then return finish(true) end
    end

    -- 2) Bot must hold it (sheriff/hero or we just picked up). No GiveGun remote.
    if not botHasGun() then
        if not (G.MM_GrabDroppedGun and G.MM_GrabDroppedGun(2.4)) then
            return finish(false)
        end
    end
    if not botHasGun() then return finish(false) end

    if not standOnTarget(target, 0.8) then return finish(false) end
    if G.MM_TryClientDrop and G.MM_TryClientDrop() then
        if G.MM_DeliverDrop then G.MM_DeliverDrop(target, 0.8) end
        if G.MM_WaitForGunPickup(target, 1.2) then
            log("gun: CanBeDropped worked — no reset")
            tpHome()
            return finish(true)
        end
    end

    -- 3) Only server-legal drop left: die in place on them. No LoadCharacter / void.
    if not standOnTarget(target, 1) then return finish(false) end
    task.wait(0.08)
    if G.MM_DieInPlace then G.MM_DieInPlace() else reset(true) end
    return finish(G.MM_WaitForGunPickup(target, 2.1))
end
local function stashGunAtSpawn()
    G.MM_ActionBegin()
    local function finish(ok)
        G.MM_ActionEnd()
        return ok
    end
    if _G.MM_StabBusy then return finish(false) end
    if not SPAWN_CFRAME or not isAlive(me) then return finish(false) end
    local drop = findDroppedGun()
    if drop and not botHasGun() then
        local nearSpawn = (drop.Position - SPAWN_CFRAME.Position).Magnitude < 18
        if nearSpawn then
            return finish(true)
        end
    end
    if not botHasGun() then
        if not (G.MM_GrabDroppedGun and G.MM_GrabDroppedGun(2.8)) then
            return finish(false)
        end
        if not botHasGun() then return finish(false) end
    end
    tpHome()
    task.wait(0.12)
    if G.MM_TryClientDrop and G.MM_TryClientDrop() then
        return finish(true)
    end
    if G.MM_DieInPlace then G.MM_DieInPlace() else reset(true) end
    return finish(true)
end
local function ownerMurdererActive(murderer, ownerPlayer)
    return ownerPlayer and murderer and murderer.UserId == ownerPlayer.UserId
end
local function gunAvailableForOwnerMurdStash()
    return botHasGun() or findDroppedGun() ~= nil
end
local function equipTool(tool)
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if tool and hum and tool.Parent ~= me.Character then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.05)
    end
    return tool and tool.Parent == me.Character
end

--[[ Sheriff shoot (scoped to stay under Luau's 200-local limit) ]]--
-- MM2 gun: ShootGun:InvokeServer(tick(), hitPos). Silent aim rewrites arg 2.
-- Range is map-wide — do NOT TP onto the murderer (knife range ~16).
do
    local SHOOT_RELOAD_MIN = 2.15
    local SHOOT_TIMEOUT_SEC = 8
    local SHOOT_MAX = 3
    local KNIFE_DANGER = 22

    G.MM_ComputeShootAim = function()
        local target = G.MM_ShootTarget
        if not (target and target.Character) then return end
        local root = target.Character:FindFirstChild("HumanoidRootPart") or target.Character.PrimaryPart
        local head = target.Character:FindFirstChild("Head")
        if not root then return end
        local vel = root.AssemblyLinearVelocity
        if vel.Magnitude < 1e-3 then vel = root.Velocity end
        local pingMs = getPingMs() or 80
        local t = math.clamp((pingMs / 1000) * 0.45 + 0.08, 0.06, 0.22)
        local lead = Vector3.new(vel.X, 0, vel.Z) * t
        if lead.Magnitude > 12 then lead = lead.Unit * 12 end
        local base = head and head.Position or (root.Position + Vector3.new(0, 1.2, 0))
        return base + lead
    end

    local function installShootHooks()
        if G.MM_ShootHooksInstalled then return true end
        if type(hookmetamethod) ~= "function" then return false end
        local wrap = newcclosure or function(f) return f end
        local mouse = me:GetMouse()
        local oldIndex, oldNamecall
        local okIndex, hookedIndex = pcall(function()
            oldIndex = hookmetamethod(game, "__index", wrap(function(self, key)
                if G.MM_ShootActive and self == mouse then
                    local aim = G.MM_ComputeShootAim and G.MM_ComputeShootAim()
                    if aim then
                        if key == "Hit" then return CFrame.new(aim) end
                        if key == "Target" then return G.MM_ShootAimPart end
                    end
                end
                if oldIndex then return oldIndex(self, key) end
            end))
            return oldIndex
        end)
        local okName, hookedName = pcall(function()
            oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                if G.MM_ShootActive then
                    local method = getnamecallmethod and getnamecallmethod()
                    local name = ""
                    pcall(function() name = self.Name end)
                    local args = { ... }
                    local aim = G.MM_ComputeShootAim and G.MM_ComputeShootAim()
                    -- Rewrite the gun LocalScript's own shot only. Do not invent args.
                    if aim and method == "InvokeServer" and name == "ShootGun" then
                        if typeof(args[2]) == "Vector3" then args[2] = aim
                        elseif typeof(args[1]) == "Vector3" then args[1] = aim end
                        if oldNamecall then return oldNamecall(self, unpack(args)) end
                    end
                end
                if oldNamecall then return oldNamecall(self, ...) end
            end))
            return oldNamecall
        end)
        if (okIndex and hookedIndex) or (okName and hookedName) then
            G.MM_ShootHooksInstalled = true
            return true
        end
        return false
    end

    local function clearShootAimTarget()
        G.MM_ShootActive = false
        G.MM_ShootTarget = nil
        G.MM_ShootAimPart, G.MM_ShootAimCf = nil, nil
    end

    local function distToTarget(target)
        local a = hrp()
        local b = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not (a and b) then return math.huge end
        return (a.Position - b.Position).Magnitude
    end

    local function leaveIfClose(target)
        if distToTarget(target) < KNIFE_DANGER then
            tpHome()
        end
    end

    local function pickUpDroppedGun()
        if G.MM_GrabDroppedGun then return G.MM_GrabDroppedGun(3.2) end
        if botHasGun() then return true end
        local h = hrp()
        if not (h and isAlive(me)) then return false end
        local drop = workspace:FindFirstChild("GunDrop") or findDroppedGun()
        if drop and drop:IsA("BasePart") then
            pcall(function()
                h.CFrame = drop.CFrame + Vector3.new(0, 2.2, 0)
            end)
        end
        local t0 = tick()
        while session.active and tick() - t0 < 3 do
            if botHasGun() then return true end
            task.wait(0.05)
        end
        return botHasGun()
    end

    local function fireSilentShot(target, gun)
        if not gun or not isAlive(target) or not isAlive(me) then return false end
        installShootHooks()
        if gun.Parent ~= me.Character then
            equipTool(gun)
            task.wait(0.06)
        end
        local part = target.Character and (target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart"))
        G.MM_ShootTarget = target
        G.MM_ShootAimPart = part
        G.MM_ShootActive = true
        local aim = G.MM_ComputeShootAim and G.MM_ComputeShootAim()
        if not aim then return false end
        local mh = hrp()
        local shootCam = workspace.CurrentCamera
        if shootCam and mh then
            pcall(function() shootCam.CFrame = CFrame.lookAt(mh.Position + Vector3.new(0, 1.5, 0), aim) end)
        end
        -- Never InvokeServer ShootGun ourselves — MM2 kicks that. Let the gun LocalScript fire.
        pcall(function() gun:Activate() end)
        return true
    end

    local function resolveShootTarget(query)
        query = tostring(query or ""):match("^%s*(.-)%s*$") or ""
        local first = query:lower():match("^(%S+)") or ""
        if first == "" or first == "murder" or first == "murd" or first == "murderer" then
            local murd = (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
            if murd and murd ~= me then return murd, nil end
            if first == "" then return nil, "Murderer not found — try !shoot <name>" end
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
        if target == me then return false, "Invalid target" end
        if not isAlive(target) then return false, "Player not found" end
        if botHasKnife() then return false, "Bot is murderer — no gun" end
        if not botHasGun() and not pickUpDroppedGun() then return false, "No gun available" end
        tpHome()
        leaveIfClose(target)
        installShootHooks()
        local gun = getHeldTool(me, G.MM_GunNames)
        if not gun or not equipTool(gun) then return false, "No gun available" end
        G.MM_ShootTarget = target
        G.MM_ShootActive = true
        local started = tick()
        local shots = 0
        while session.active and isAlive(me) and isAlive(target) and shots < SHOOT_MAX and (tick() - started) < SHOOT_TIMEOUT_SEC do
            if botHasKnife() then
                clearShootAimTarget()
                tpHome()
                return false, "Bot is murderer — no gun"
            end
            if not botHasGun() then
                if not pickUpDroppedGun() then
                    clearShootAimTarget()
                    return false, "No gun available"
                end
                tpHome()
            end
            leaveIfClose(target)
            gun = getHeldTool(me, G.MM_GunNames)
            if not gun then break end
            pcall(function() fireSilentShot(target, gun) end)
            shots = shots + 1
            task.wait(0.12)
            if not isAlive(target) then
                clearShootAimTarget()
                tpHome()
                return true, "Shot " .. shortName(target)
            end
            tpHome()
            if not isAlive(me) then
                clearShootAimTarget()
                return false, "Bot died"
            end
            if shots < SHOOT_MAX and isAlive(target) then
                task.wait(SHOOT_RELOAD_MIN)
            end
        end
        clearShootAimTarget()
        tpHome()
        if not isAlive(me) then return false, "Bot died" end
        if not isAlive(target) then return true, "Shot " .. shortName(target) end
        if (tick() - started) >= SHOOT_TIMEOUT_SEC then return true, "Shoot timed out" end
        return true, "Stopped shooting " .. shortName(target)
    end

    function G.MM_CombatBusy()
        return G.MM_StabBusyActive() or _G.MM_GunBusy or _G.MM_ShootBusy
    end
    G.MM_ShootTargetLoop = shootTargetLoop
    G.MM_ResolveShootTarget = resolveShootTarget
    G.MM_EnsureShootGun = function()
        return botHasGun() or pickUpDroppedGun()
    end
end

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

local function stabTargetLoop(target)
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

--[[ Fling ]]--
local flingActive = false
local flingLoopGen = 0
local flingLoopActive = false
local flingLoopContinuous = false
local flingSettling = false

local function cancelFlingWork()
    flingLoopGen = flingLoopGen + 1
    flingLoopActive = false
    flingLoopContinuous = false
    flingActive = false
    flingSettling = false
end

local function recoverAfterFling()
    flingSettling = true
    for i = 1, 5 do
        local mh = hrp()
        if mh then
            zeroVel(mh)
            mh.Velocity = Vector3.zero
            mh.RotVelocity = Vector3.zero
        end
        tpHome()
        task.wait(0.06)
        if isAlive(me) then break end
    end
    if not isAlive(me) then
        pcall(reset)
        local t0 = tick()
        while tick() - t0 < 4 do
            if isAlive(me) then break end
            task.wait(0.15)
        end
    end
    local mh = hrp()
    if mh then zeroVel(mh) end
    flingSettling = false
end

local function fling(target, onDone)
    local onDoneFn = onDone
    if flingActive then
        if onDoneFn then onDoneFn(false) end
        return
    end
    if not isAlive(target) or not isAlive(me) then
        if onDoneFn then onDoneFn(false) end
        return
    end
    flingActive = true
    log("flinging " .. target.DisplayName)
    task.spawn(function()
        G.MM_ActionBegin()
        local okRun, errRun = pcall(function()
        local thrp0 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local startPos = thrp0 and thrp0.Position
        local startedAt = tick()
        local stopAt = startedAt + 10
        local flung = false
        local hiVelFrames = 0
        while flingActive and tick() < stopAt and isAlive(target) and isAlive(me) do
            local mh = hrp()
            local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local thum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
            if mh and th then
                local lead = flingApproachLead(th, thum)
                mh.CFrame = th.CFrame + lead
                mh.Velocity = Vector3.new(99999, 99999, 99999)
                mh.RotVelocity = Vector3.new(99999, 99999, 99999)
            end
            if th and startPos and tick() - startedAt > 2 then
                local vel = th.Velocity.Magnitude
                if vel > 600 then hiVelFrames = hiVelFrames + 1
                else hiVelFrames = 0 end
                local moved = (th.Position - startPos).Magnitude
                local state = thum and thum:GetState()
                local ragdoll = state == Enum.HumanoidStateType.PlatformStanding
                             or state == Enum.HumanoidStateType.FallingDown
                             or state == Enum.HumanoidStateType.Physics
                if hiVelFrames >= 5 or moved > 60 or ragdoll then
                    flung = true
                    flingActive = false
                    local mh = hrp()
                    if mh then
                        zeroVel(mh)
                        mh.Velocity = Vector3.zero
                        mh.RotVelocity = Vector3.zero
                        pcall(function() mh.CFrame = SPAWN_CFRAME or mh.CFrame end)
                    end
                    break
                end
            end
            task.wait()
        end
        log(flung and "fling success" or "fling done")
        flingActive = false
        if onDoneFn then
            onDoneFn(flung)
        elseif flung then
            whisper("Flung " .. shortName(target))
        end
        recoverAfterFling()
        end)
        if not okRun then
            log("fling error: " .. tostring(errRun))
        end
        G.MM_ActionEnd()
    end)
end

local function waitFlingDone(gen, timeout)
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

local function runFlingLoop(mode, playerQuery, gen, continuousLoop)
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
        end
    end)
end

--[[ Follow ]]-- (followTarget / stopFollow are under Movement)

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

local function startFollowLoop()
    task.spawn(function()
        while followTarget and session.active do
            local target = followTarget
            if target and isAlive(target) and isAlive(me) then
                local thrp = target.Character:FindFirstChild("HumanoidRootPart")
                local thum = target.Character:FindFirstChildOfClass("Humanoid")
                local hum = me.Character:FindFirstChildOfClass("Humanoid")
                if thrp and hum then
                    hum:MoveTo(thrp.Position)
                    if thum then
                        local st = thum:GetState()
                        local j = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
                        if j or thrp.Velocity.Y > 10 then
                            hum.Jump = true
                        end
                    end
                end
            end
            task.wait(0.12)
        end
    end)
end

--[[ Commands ]]--
local COMMAND_HELP = {
    reveal = "Show current murderer and sheriff",
    stab = "all | sheriff | <name> - Murderer only, stab targets",
    shoot = "murderer | sheriff | <name> - Silent-aim from range, does not TP onto them",
    togglereveal = "Toggle automatic role callout each round",
    togglealerts = "Toggle kill alerts (ignores resets)",
    togglereset = "Toggle auto-reset when owner dies",
    toggledrop = "Toggle stashing guns when you are murderer",
    drop = "Stash gun at spawn (touch-drop if possible, else die in place)",
    reset = "Force bot respawn",
    tp = "<player> - Teleport bot to a player",
    tpmurd = "Teleport bot to the murderer",
    tpsher = "Teleport bot to the sheriff",
    spawn = "Teleport bot to spawn",
    follow = "<player> - Follow a player",
    unfollow = "Stop following current player",
    gun = "<player> - Give GunDrop via touch if dropped; else die-in-place (no GiveGun remote)",
    togglegun = "<player> - Auto-deliver gun to a player",
    toggleshoot = "[murderer | name] - Auto-grab dropped gun and silent-aim shoot",
    chat = "<msg> - Make bot send a public chat message",
    fling = "<player> - Flings player off the map",
    help = "<cmd> - Show command list or explain one command",
}
local HELP_ORDER = {
    "tp", "reveal", "stab", "shoot", "gun", "drop", "fling", "togglegun", "toggleshoot", "togglereveal", "togglealerts",
    "reset", "follow", "unfollow", "chat", "help",
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
        if k == "reset" then
            table.insert(out, "togglereset")
            table.insert(out, "toggledrop")
        end
        table.insert(out, k)
    end
    return out
end

local function isPremiumOnlyCommand(cmd)
    return PREMIUM_ONLY_COMMANDS[cmd] == true
end

local function sendFullHelp(target, gapBetween)
    gapBetween = gapBetween or 0.5
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
    whisper("Use !help <command> for what a command does", o)
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
    local parts = {}
    for _, key in ipairs(keys) do
        table.insert(parts, "!" .. key)
    end
    local line = table.concat(parts, " ")
    if #line <= 200 then
        whisper(line, o)
        return
    end
    local mid = math.ceil(#keys / 2)
    local a, b = {}, {}
    for i, key in ipairs(keys) do
        if i <= mid then table.insert(a, "!" .. key) else table.insert(b, "!" .. key) end
    end
    whisper(table.concat(a, " "), o)
    if gapBetween > 0 then task.wait(gapBetween) end
    o = resolve()
    if not o then
        for _ = 1, 12 do
            task.wait(0.15)
            o = resolve()
            if o then break end
        end
    end
    if o then whisper(table.concat(b, " "), o) end
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

-- One line at a time; retry whisperOk, then one best-effort whisper() if all acks fail.
local function deliverOwnerLine(userId, msg, attempts, step)
    attempts = attempts or 14
    step = step or 0.42
    for _ = 1, attempts do
        if session.ownerId ~= userId then return false end
        local o = resolveOwnerPlayer(userId)
        if o and whisperOk(msg, o, true) then return true end
        task.wait(step)
    end
    local o = resolveOwnerPlayer(userId)
    if not o then return false end
    whisper(msg, o, true)
    task.wait(0.35)
    return whisperOk(msg, o, true) or session.ownerId == userId
end

local function sendFullHelpToOwner(userId, gapBetween)
    gapBetween = gapBetween or 0.75
    if session.ownerId ~= userId then return false end

    if not deliverOwnerLine(userId, "Use !help <command> for what a command does", 16, 0.45) then
        return false
    end
    task.wait(gapBetween)

    local keys = helpKeysForOwner()
    local parts = {}
    for _, key in ipairs(keys) do
        table.insert(parts, "!" .. key)
    end
    local line = table.concat(parts, " ")
    if #line <= 200 then
        return deliverOwnerLine(userId, line, 16, 0.45)
    end

    local mid = math.ceil(#keys / 2)
    local a, b = {}, {}
    for i, key in ipairs(keys) do
        if i <= mid then table.insert(a, "!" .. key) else table.insert(b, "!" .. key) end
    end
    if not deliverOwnerLine(userId, table.concat(a, " "), 16, 0.45) then return false end
    task.wait(gapBetween)
    return deliverOwnerLine(userId, table.concat(b, " "), 16, 0.45)
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

        if not deliverOwnerLine(userId, "Loading new owner", 12, 0.4) then
            log("onboarding: could not whisper Loading new owner")
        end

        task.wait(0.85)
        if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end

        local helpOk = false
        for attempt = 1, 4 do
            if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end
            if sendFullHelpToOwner(userId, 0.75) then
                helpOk = true
                break
            end
            log("onboarding: help send attempt " .. attempt .. " failed, retrying")
            task.wait(0.5 + attempt * 0.35)
        end
        if not helpOk then
            log("onboarding: help whispers failed after retries")
        end

    end)
end

task.spawn(function()
    for _ = 1, 30 do
        if not session.active then return end
        local p = findConfiguredOwner()
        if p then
            syncConfiguredOwner()
            log("startup: owner " .. p.Name)
            break
        end
        task.wait(0.5)
    end
end)

local function handleCommand(p, msg)
    if msg:sub(1, 1) ~= "!" then return end
    local args = splitChatArgs(msg)
    local cmd, rest = args[1]:sub(2):lower(), msg:sub(#args[1] + 2)
    if not authorizeCommand(p) then return end
    local privateWhisper = whisper
    local whisper = commandReply
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

        if mode == "player" then
            if not findOtherPlayer(work) then
                whisper("Could not find player: " .. work)
                return
            end
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
            local label = mode == "player" and work or mode
            whisper("Say !fling alone to stop the loop")
            task.wait(0.3)
            whisper("Looping on: " .. label)
        else
            whisper("Flinging " .. (mode == "player" and work or mode))
        end
        return
    end
    local m, s = findHolder({"Knife"}), findHolder(G.MM_GunNames)
    local ownerPlayer = findOwner()
    local ownerIsMurd = ownerMurdererActive(m, ownerPlayer) and not botHasKnife()
    if cmd == "chat" then
        sendChat(rest)
        whisper("Chat sent")
    elseif cmd == "reveal" then
        local murd = (G.MM_FindRole and G.MM_FindRole("Murderer")) or m
        local sher = (G.MM_FindRole and G.MM_FindRole("Sheriff")) or s
        local hero = G.MM_FindRole and G.MM_FindRole("Hero")
        local botM, botS = botHasKnife(), botHasGun()
        local mL = (murd == me or botM) and "Me" or (murd and shortName(murd)) or "?"
        local sL
        if hero then
            sL = (hero == me) and "Me (hero)" or (shortName(hero) .. " (hero)")
        else
            sL = (sher == me or botS) and "Me" or (sher and shortName(sher)) or "?"
        end
        whisper("Murderer: " .. mL)
        task.wait(0.3)
        whisper("Sheriff: " .. sL)
    elseif cmd == "tp" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        tpTo(t)
        whisper("Teleported to " .. commandTargetLabel(t))
    elseif cmd == "tpmurd" then
        local murd = (G.MM_FindRole and G.MM_FindRole("Murderer")) or m
        if not murd then whisper("Murderer not found") return end
        tpTo(murd)
        whisper("Teleported to murderer")
    elseif cmd == "tpsher" then
        local sher = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
            or (G.MM_FindRole and G.MM_FindRole("Hero"))
            or s
        if not sher then whisper("Sheriff not found") return end
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
            local status = "Player not found"
            local ok, runErr = pcall(function()
                local tgt = Players:GetPlayerByUserId(targetUid)
                if not tgt or not isAlive(tgt) then return end
                local _, msg = G.MM_ShootTargetLoop(tgt)
                status = msg
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
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        if ownerIsMurd then whisper(OWNER_MURD_GUN_MSG) return end
        if botHasKnife() then whisper("No gun available") return end
        if not gunAvailableForOwnerMurdStash() then
            whisper(G.MM_GunWhere and G.MM_GunWhere() or "No gun available")
            return
        end
        local ok = bringGun(t)
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
        tpHome()
        whisper("Teleported to spawn")
    elseif cmd == "reset" then
        whisper("Resetting")
        reset()
    elseif cmd == "togglegun" then
        if args[2] and ownerIsMurd then whisper(OWNER_MURD_GUN_MSG) return end
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
    elseif cmd == "togglealerts" then
        toggleAlerts = not toggleAlerts
        whisper("Kill alerts: " .. (toggleAlerts and "on" or "off"))
    elseif cmd == "togglereveal" then
        toggleReveal = not toggleReveal
        whisper("Role callouts: " .. (toggleReveal and "on" or "off"))
    elseif cmd == "togglereset" then
        toggleResetOnOwnerDeath = not toggleResetOnOwnerDeath
        _G.MM_OwnerDiedPendingReset = false
        whisper("Reset on owner death: " .. (toggleResetOnOwnerDeath and "on" or "off"))
    elseif cmd == "toggledrop" then
        toggleDrop = not toggleDrop
        whisper("Murderer gun stash: " .. (toggleDrop and "on" or "off"))
    elseif cmd == "follow" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        local wasActive = followTarget ~= nil
        local switching = followTarget ~= t
        followTarget = t
        if switching then tpTo(t) end
        whisper("Following " .. shortName(t))
        if not wasActive then startFollowLoop() end
    elseif cmd == "unfollow" then
        if not followTarget then whisper("Not following anyone") return end
        local name = shortName(followTarget)
        followTarget = nil
        whisper("Unfollowed " .. name)
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
            sendFullHelp()
        end
    end
end
local function routeCommand(p, msg)
    if not session.active then return end
    msg = cleanChatText(msg)
    if msg == "" or seenCommandRecently(p, msg) then return end
    if ACTIVE_OWNER_USERNAME ~= "" and configuredOwnerMatches(p) then
        syncConfiguredOwner()
    end
    handleCommand(p, msg)
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
            routeCommand(p, clean)
        end
    end)
end
local function hookSpeaker(p)
    if not p then return end
    pcall(function()
        local chatted = p.Chatted
        if not chatted then return end
        trackConnection(chatted:Connect(function(msg)
            if not session.active then return end
            routeCommand(p, msg)
            watchHiddenChat(p, msg)
        end))
    end)
end
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
            session.ownerId = nil
            G.MM_PendingOwnerId = nil
            gunTargetId, gunDelivered = nil, false
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
    if bridgeFulfilledClaimId == claimId then return true end
    local pl = findPlayerInServerByName(username)
    if not pl then return false end
    local prevId = session.ownerId
    session.ownerId = pl.UserId
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
            return "ok", "In-game whispers are already enabled"
        end
        toggleReveal = true
        return "ok", "In-game whispers enabled"
    elseif mode == "disable" then
        if not toggleReveal then
            return "error", "In-game whispers are not enabled"
        end
        toggleReveal = false
        return "ok", "In-game whispers disabled"
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
            return "ok", "In-game whispers are already enabled"
        end
        toggleAlerts = true
        return "ok", "In-game whispers enabled"
    elseif mode == "disable" then
        if not toggleAlerts then
            return "error", "In-game whispers are not enabled"
        end
        toggleAlerts = false
        return "ok", "In-game whispers disabled"
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
        return "ok", "Automatic reset enabled"
    elseif mode == "disable" then
        if not toggleResetOnOwnerDeath then
            return "error", "Automatic reset is not enabled"
        end
        toggleResetOnOwnerDeath = false
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
    sendChat(text)
    return "ok", "Chat sent"
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
    if not gunAvailableForOwnerMurdStash() then
        return "error", (G.MM_GunWhere and G.MM_GunWhere()) or "No gun available"
    end
    local ok = bringGun(t)
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
        tgt = findHolder(G.MM_GunNames)
        if not tgt or tgt == me then return "error", "Sheriff not found" end
    elseif mode == "murder" then
        tgt = findHolder({"Knife"})
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
        picked = findHolder(G.MM_GunNames)
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
    local status = "Player not found"
    local okRun, errRun = pcall(function()
        local _, msg = G.MM_ShootTargetLoop(picked)
        status = msg
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
        syncConfiguredOwner()
        local oid = tonumber(claim.owner_id)
        if oid and oid > 0 and session.ownerId ~= oid then
            session.ownerId = oid
            G.MM_PendingOwnerId = oid
            log("bridge: restored owner " .. tostring(oid))
        end
        if claim.roblox_username and claim.id then
            bridgeClaimId = claim.id
            if bridgeFulfilledClaimId ~= claim.id then
                fulfillBridgeClaim(claim.id, claim.roblox_username)
            end
        end
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
        if bridgeFulfilledClaimId ~= claim.id then
            fulfillBridgeClaim(claim.id, claim.roblox_username)
        end
    elseif st == "available" or not claim.roblox_username then
        bridgeOwnerConnected = false
        if not findConfiguredOwner() then
            session.ownerId = nil
            G.MM_PendingOwnerId = nil
        else
            syncConfiguredOwner()
        end
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
    local configuredOwner = findConfiguredOwner()
    if bridgeOwnerConnected or configuredOwner then
        configuredOwner = syncConfiguredOwner() or configuredOwner
    end
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
    if configuredOwnerMatches(pl) then
        task.defer(syncConfiguredOwner)
    end
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
        if session.ownerId then
            local own = Players:GetPlayerByUserId(session.ownerId)
            if own and own ~= me then
                local cur = aliveState(own)
                local prev = alivePrev[own.UserId]
                if prev == true and (cur == false or cur == nil) then
                    if not toggleResetOnOwnerDeath then
                        log("owner died (reset on death off)")
                    elseif _G.MM_GunBusy or _G.MM_StabBusy or _G.MM_ShootBusy then
                        _G.MM_OwnerDiedPendingReset = true
                        log("owner died during combat (reset deferred)")
                    else
                        log("owner died -> resetting bot")
                        task.spawn(function() pcall(reset) end)
                    end
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
    log("owner username missing: set getgenv().xeno_roblox before execute")
else
    log("owner username: " .. XENO_OWNER_USERNAME)
end
if XENO_OWNER_DISCORD == "" then
    log("owner discord missing: set getgenv().xeno_discord before execute")
else
    log("owner discord: " .. XENO_OWNER_DISCORD)
end

if XENO_BRIDGE_ENABLED then
    task.spawn(function()
        task.wait(G.MM_RegionSpreadCheck and 3 or 2)
        ensureRegionSpreadOnStart()
    end)
end

local function resolveRoleSnapshot(timeout)
    local deadline = tick() + (timeout or 0)
    local curM, curS, curBotM, curBotS
    repeat
        curM = (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
        curS = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
            or (G.MM_FindRole and G.MM_FindRole("Hero"))
            or findHolder(G.MM_GunNames)
        curBotM = (curM == me) or botHasKnife()
        curBotS = (curS == me) or botHasGun()
        if curBotM then curM = me end
        if curBotS then curS = me end
        if (curBotM or curM) and (curBotS or curS) then
            break
        end
        if tick() >= deadline then break end
        task.wait(0.15)
    until false
    return curM, curS, curBotM, curBotS
end

local function sendRoundRoleCallouts(curM, curS, curBotM, curBotS)
    if not resolveWhisperTarget() then return false end
    local mLabel = curBotM and "Me" or (curM and shortName(curM)) or "?"
    local sLabel = curBotS and "Me" or (curS and shortName(curS)) or "?"
    if not whisperOk("Murderer: " .. mLabel) then return false end
    task.wait(0.35)
    return whisperOk("Sheriff: " .. sLabel)
end

local function waitForRoleCallouts(curM, curS, curBotM, curBotS)
    for _ = 1, 8 do
        if sendRoundRoleCallouts(curM, curS, curBotM, curBotS) then
            return true, curM, curS, curBotM, curBotS
        end
        task.wait(0.55)
        curM, curS, curBotM, curBotS = resolveRoleSnapshot(0.5)
    end
    return false, curM, curS, curBotM, curBotS
end

--[[ Main loop ]]--
local function runMainLoop()
    local lastMurderId, announced
    local ownerMurdStashBusy = false
    local nextAutoGunAt = 0
    local nextAutoShootAt = 0
while session.active and gui.Parent do
    local m = (G.MM_FindRole and G.MM_FindRole("Murderer")) or findHolder({"Knife"})
    local s = (G.MM_FindRole and G.MM_FindRole("Sheriff"))
        or (G.MM_FindRole and G.MM_FindRole("Hero"))
        or findHolder(G.MM_GunNames)
        local botM = (m == me) or botHasKnife()
        local roundActive = isRoundActive()

    if m then
        if lastMurderId ~= m.UserId then
            lastMurderId = m.UserId
            pcall(function() img.Image = Players:GetUserThumbnailAsync(m.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
            lbl.Text = m.DisplayName
        end
        f.Visible = true
    else f.Visible, lastMurderId = false, nil end

    if (m or botM) and not announced then
        announced = true
            gunDelivered = false
            shootDone = false
            revealAnnouncePending = true
            tpHome()
        local owner = findOwner()
        task.spawn(function()
                local curM, curS, curBotM, curBotS = resolveRoleSnapshot(2.5)

                if toggleReveal and resolveWhisperTarget() then
                    local ok
                    ok, curM, curS, curBotM, curBotS = waitForRoleCallouts(curM, curS, curBotM, curBotS)
                    if not ok then
                        curM, curS, curBotM, curBotS = resolveRoleSnapshot(0.5)
                end
            else
                    curM, curS, curBotM, curBotS = resolveRoleSnapshot(0.5)
                end

                if curBotM and owner and curS and owner.UserId == curS.UserId then
                    tpTo(owner)
                elseif session.ownerId and not curBotM then
                    tpHome()
                end

                roleAnnounceUnlockAt = tick() + 0.35
                revealAnnouncePending = false
        end)
    elseif not roundActive then
            announced, gunDelivered, shootDone, revealAnnouncePending = false, false, false, false
            ownerMurdStashBusy = false
        roleAnnounceUnlockAt = 0
    end

    local ownerForDrop = findOwner()
        local ownerIsMurd = ownerMurdererActive(m, ownerForDrop) and not botM
        -- Do not clear toggleGun here — owner-murderer only pauses delivery below; user setting stays on.

        -- Owner murderer: stash guns at spawn when enabled with !toggledrop.
        if session.ownerId and ownerIsMurd and ownerIsPremium() and toggleDrop and roundActive and SPAWN_CFRAME
           and not ownerMurdStashBusy and not revealAnnouncePending
           and tick() >= roleAnnounceUnlockAt
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
       and me.Character and not revealAnnouncePending and tick() >= roleAnnounceUnlockAt
       and tick() >= nextAutoShootAt
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
        if toggleGun and not flingLoopContinuous and not botM and not ownerIsMurd and not gunDelivered and not _G.MM_GunBusy and not _G.MM_StabBusy and not _G.MM_ShootBusy and me.Character
           and not revealAnnouncePending and tick() >= roleAnnounceUnlockAt
           and tick() >= nextAutoGunAt
           and not flingActive and not flingLoopActive and not flingSettling
       and gunTarget and gunTarget ~= me and isAlive(gunTarget)
           and gunAvailableForOwnerMurdStash() then
        nextAutoGunAt = tick() + 2.2
        _G.MM_GunBusy = true
        task.spawn(function()
            local ok = bringGun(gunTarget)
            gunDelivered = ok or G.MM_TargetHasGun(gunTarget)
            if not gunDelivered then
                nextAutoGunAt = tick() + 0.35
            end
            task.wait(0.4)
            _G.MM_GunBusy = false
        end)
    end

    local subject = (s and s.Character and s.Character:FindFirstChildOfClass("Humanoid"))
                  or findDroppedGun()
                  or (me.Character and me.Character:FindFirstChildOfClass("Humanoid"))
    if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
    if subject then cam.CameraSubject = subject end
    cam.FieldOfView = WIDE_FOV
    task.wait(0.5)
end

--[[ Cleanup ]]--
cam.FieldOfView = DEFAULT_FOV
do local h = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
   if h then cam.CameraSubject = h end end
    cleanupSession()
end

runMainLoop()
