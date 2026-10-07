--[[ MM2 gameplay dump: remotes, tools, role/round/gun/knife scripts. execute-dump.lua ]]--

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
local lines = {}
local decompileFn = decompile or (syn and syn.decompile)
local getenv = getsenv
local KEYS = "shoot gun knife role round fade gameplay murder sheriff hero lobby spawn kill dead drop beam weapon"
local SKIP = "database shop inventory recipe code radio mystery crate currency nametag xbox featured badge perk"

local function add(s)
    s = tostring(s)
    lines[#lines + 1] = s
    print("[mm2-dump] " .. s)
end

local function safe(fn)
    local ok, a = pcall(fn)
    if ok then return a end
    return nil, tostring(a)
end

local function skipped(name)
    name = tostring(name or ""):lower()
    for w in SKIP:gmatch("%S+") do
        if name:find(w, 1, true) then return true end
    end
end

local function interesting(name)
    name = tostring(name or ""):lower()
    if skipped(name) then return false end
    for w in KEYS:gmatch("%S+") do
        if name:find(w, 1, true) then return true end
    end
end

local function dumpValue(v, indent)
    indent = indent or "  "
    if type(v) ~= "table" then
        add(indent .. tostring(v))
        return
    end
    local n = 0
    for k, x in pairs(v) do
        n = n + 1
        if type(x) == "table" then
            local bits = {}
            for a, b in pairs(x) do
                bits[#bits + 1] = tostring(a) .. "=" .. tostring(b)
            end
            add(indent .. tostring(k) .. " { " .. table.concat(bits, ", ") .. " }")
        else
            add(indent .. tostring(k) .. " = " .. tostring(x))
        end
        if n >= 80 then
            add(indent .. "...truncated")
            break
        end
    end
    if n == 0 then add(indent .. "(empty)") end
end

local function isRemote(d)
    return d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")
end

local function isScript(d)
    return d:IsA("LocalScript") or d:IsA("ModuleScript")
end

local function dumpTree(inst, prefix, depth)
    depth = depth or 0
    if depth > 8 then return end
    prefix = prefix or ""
    add(prefix .. inst.ClassName .. " " .. inst.Name)
    for _, c in ipairs(inst:GetChildren()) do
        dumpTree(c, prefix .. "  ", depth + 1)
    end
end

local function dumpRemotes(root, label)
    add("=== REMOTES " .. label .. " ===")
    if not root then add("(missing)") return end
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            if isRemote(d) then
                add(d.ClassName .. " " .. d:GetFullName())
            end
        end
    end)
end

local getconstants = debug and debug.getconstants or getconstants

local function dumpScript(d)
    add("-- SCRIPT " .. d.ClassName .. " " .. d:GetFullName())
    if d:IsA("ModuleScript") then
        local res, err = safe(function() return require(d) end)
        if type(res) == "table" then
            add("-- REQUIRE keys")
            for k, v in pairs(res) do
                local extra = type(v) == "function" and " fn" or (" " .. tostring(v))
                add("  ." .. tostring(k) .. " =" .. extra)
            end
        else
            add("require => " .. tostring(res or err))
        end
    end
    if getconstants then
        local consts, err = safe(function() return getconstants(d) end)
        if type(consts) == "table" then
            add("-- CONSTANTS")
            for i, v in ipairs(consts) do
                if i > 60 then add("  ...") break end
                add("  [" .. i .. "] " .. tostring(v))
            end
        elseif err then
            add("constants fail: " .. tostring(err))
        end
    end
    if decompileFn then
        local src, err = safe(function() return decompileFn(d) end)
        if src then add(src) else add("decompile fail: " .. tostring(err)) end
    else
        add("no decompile() on this executor")
    end
    if getenv and d:IsA("LocalScript") then
        local env, err = safe(function() return getenv(d) end)
        if type(env) == "table" then
            add("-- GETSENV " .. d.Name)
            for k, v in pairs(env) do
                local extra = ""
                if typeof and typeof(v) == "Instance" then
                    extra = " " .. v.ClassName .. " " .. v:GetFullName()
                elseif type(v) == "function" then
                    extra = " fn"
                end
                add("  env." .. tostring(k) .. " = " .. (typeof and typeof(v) or type(v)) .. extra)
            end
        else
            add("getsenv fail: " .. tostring(err))
        end
    end
end

local function dumpScriptsIn(root, label, force)
    add("=== SCRIPTS " .. label .. " ===")
    if not root then add("(missing)") return end
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            if isScript(d) and (force or interesting(d.Name) or interesting(d:GetFullName())) then
                dumpScript(d)
            end
        end
    end)
end

add("place=" .. tostring(game.PlaceId) .. " job=" .. tostring(game.JobId))
add("bot=" .. me.Name)
add("char=" .. tostring(me.Character and me.Character:GetFullName()))
add("decompile=" .. tostring(decompileFn ~= nil) .. " getsenv=" .. tostring(getenv ~= nil))

add("=== RS TOP ===")
pcall(function()
    for _, c in ipairs(RS:GetChildren()) do
        add(c.ClassName .. " " .. c.Name)
    end
end)

local remotesFolder = RS:FindFirstChild("Remotes")
if remotesFolder then
    add("=== RS.Remotes TREE ===")
    dumpTree(remotesFolder)
end

dumpRemotes(RS, "ReplicatedStorage")
dumpRemotes(me.Character, "Character")
dumpRemotes(me:FindFirstChildOfClass("Backpack"), "Backpack")
pcall(function()
    add("=== WORKSPACE REMOTES (interesting) ===")
    for _, d in ipairs(workspace:GetDescendants()) do
        if isRemote(d) and interesting(d.Name) then
            add(d.ClassName .. " " .. d:GetFullName())
        end
    end
end)

local function dumpRF(path)
    local inst = RS
    for part in string.gmatch(path, "[^%.]+") do
        inst = inst and inst:FindFirstChild(part)
    end
    add("RF " .. path .. " => " .. tostring(inst and inst.ClassName))
    if inst and inst:IsA("RemoteFunction") then
        local data, err = safe(function() return inst:InvokeServer() end)
        if data ~= nil then dumpValue(data) else add("  invoke fail: " .. tostring(err)) end
    end
end

pcall(function() dumpRF("Remotes.Gameplay.GetCurrentPlayerData") end)
pcall(function() dumpRF("Remotes.Extras.GetPlayerData") end)
pcall(function()
    local bf = RS:FindFirstChild("GetPlayerData_REMOTE")
    add("GetPlayerData_REMOTE=" .. tostring(bf and bf.ClassName))
    if bf and bf:IsA("BindableFunction") then
        local data, err = safe(function() return bf:Invoke() end)
        if data ~= nil then dumpValue(data) else add("  invoke fail: " .. tostring(err)) end
    end
end)

for _, folder in ipairs({ "WeaponEvents", "ClientServices" }) do
    local inst = RS:FindFirstChild(folder)
    if inst then
        add("=== TREE " .. folder .. " ===")
        dumpTree(inst)
    end
end

pcall(function()
    local mods = RS:FindFirstChild("Modules")
    if not mods then return end
    add("=== REQUIRE gameplay modules ===")
    for _, n in ipairs({ "CurrentRoundClient", "FadeModule", "ProfileData" }) do
        local m = mods:FindFirstChild(n)
        if m and m:IsA("ModuleScript") then dumpScript(m) end
    end
end)

for _, bag in ipairs({ me.Character, me:FindFirstChildOfClass("Backpack") }) do
    if bag then
        for _, t in ipairs(bag:GetChildren()) do
            if t:IsA("Tool") then
                add("=== TOOL TREE " .. t:GetFullName() .. " ===")
                dumpTree(t)
                dumpRemotes(t, "tool " .. t.Name)
                dumpScriptsIn(t, "tool " .. t.Name, true)
            end
        end
    end
end

dumpScriptsIn(RS, "ReplicatedStorage interesting", false)
if remotesFolder then
    dumpScriptsIn(remotesFolder, "RS.Remotes all", true)
end
local gp = remotesFolder and remotesFolder:FindFirstChild("Gameplay")
if gp then
    dumpScriptsIn(gp, "RS.Remotes.Gameplay all", true)
end
pcall(function()
    local ps = me:FindFirstChild("PlayerScripts")
    dumpScriptsIn(ps, "PlayerScripts interesting", false)
end)

local out = table.concat(lines, "\n")
if writefile then
    pcall(function()
        writefile("mm2-dump.txt", out)
        add("wrote mm2-dump.txt")
    end)
end
if setclipboard then
    pcall(function() setclipboard(out) end)
    add("copied dump to clipboard")
end
add("DONE — paste the [mm2-dump] output (or mm2-dump.txt)")
