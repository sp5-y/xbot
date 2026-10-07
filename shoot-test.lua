--[[ MM2 gun / silent-shoot test. Execute this alone in Xeno.
    Finds raIentless and tries every known gun fire path. ]]--

local TARGET_NAME = "raIentless"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer

local function say(msg)
    print("[shoot-test] " .. tostring(msg))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "shoot-test",
            Text = tostring(msg),
            Duration = 4,
        })
    end)
end

local function findPlayer(name)
    name = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me then
            if p.Name:lower() == name or tostring(p.DisplayName):lower() == name then
                return p
            end
            if p.Name:lower():find(name, 1, true) or tostring(p.DisplayName):lower():find(name, 1, true) then
                return p
            end
        end
    end
end

local GUN_NAMES = { "Gun", "Revolver", "SheriffGun", "Laser", "Luger", "Blaster" }

local function findGun()
    for _, bag in ipairs({ me.Character, me:FindFirstChildOfClass("Backpack") }) do
        if bag then
            for _, n in ipairs(GUN_NAMES) do
                local t = bag:FindFirstChild(n)
                if t and t:IsA("Tool") then return t end
            end
            for _, c in ipairs(bag:GetChildren()) do
                if c:IsA("Tool") then return c end
            end
        end
    end
end

local function dump(inst, prefix)
    prefix = prefix or ""
    say(prefix .. inst.ClassName .. " " .. inst.Name)
    for _, c in ipairs(inst:GetChildren()) do
        dump(c, prefix .. "  ")
    end
end

local function hitPos(p)
    local char = p.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char.PrimaryPart)
    if not root then return end
    local vel = Vector3.zero
    pcall(function() vel = root.AssemblyLinearVelocity end)
    return root.Position + Vector3.new(vel.X, 0, vel.Z) / 40
end

local function alive(p)
    local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function tryInvoke(label, rf, ...)
    if not rf then
        say("SKIP " .. label .. " (nil remote)")
        return false
    end
    local args = { ... }
    say("TRY " .. label .. " on " .. rf:GetFullName() .. " class=" .. rf.ClassName)
    local ok, err
    if rf:IsA("RemoteFunction") then
        ok, err = pcall(function()
            return rf:InvokeServer(unpack(args))
        end)
    elseif rf:IsA("RemoteEvent") then
        ok, err = pcall(function()
            rf:FireServer(unpack(args))
        end)
    else
        say("SKIP " .. label .. " not a remote")
        return false
    end
    say((ok and "OK " or "FAIL ") .. label .. " => " .. tostring(err))
    return ok
end

say("looking for " .. TARGET_NAME)
local target = findPlayer(TARGET_NAME)
if not target then
    say("player not in server: " .. TARGET_NAME)
    return
end

say("target " .. target.Name .. " / " .. tostring(target.DisplayName) .. " alive=" .. tostring(alive(target)))

local gun = findGun()
if not gun then
    say("no gun in character/backpack")
    return
end
say("gun " .. gun:GetFullName() .. " parent=" .. tostring(gun.Parent and gun.Parent.Name))

local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
if hum and gun.Parent ~= me.Character then
    pcall(function() hum:EquipTool(gun) end)
    task.wait(0.2)
    say("equipped gun parent=" .. tostring(gun.Parent and gun.Parent.Name))
end

say("--- gun tree ---")
dump(gun)

say("--- remotes under gun ---")
for _, d in ipairs(gun:GetDescendants()) do
    if d:IsA("RemoteFunction") or d:IsA("RemoteEvent") then
        say(d.ClassName .. " " .. d:GetFullName())
    end
end

local pos = hitPos(target)
if not pos then
    say("target has no root/head")
    return
end
say("hit pos " .. tostring(pos))

local kl = gun:FindFirstChild("KnifeLocal") or gun:FindFirstChild("KnifeLocal", true)
local beam = kl and (kl:FindFirstChild("CreateBeam") or kl:FindFirstChild("CreateBeam", true))
beam = beam or gun:FindFirstChild("CreateBeam", true)
local beamRf = beam and (beam:FindFirstChild("RemoteFunction") or beam:FindFirstChildWhichIsA("RemoteFunction"))
if not beamRf and beam and beam:IsA("RemoteFunction") then beamRf = beam end
local shootGun = gun:FindFirstChild("ShootGun", true)

say("KnifeLocal=" .. tostring(kl and kl:GetFullName()))
say("CreateBeam=" .. tostring(beam and beam:GetFullName()))
say("beam remote=" .. tostring(beamRf and beamRf:GetFullName()))
say("ShootGun=" .. tostring(shootGun and shootGun:GetFullName()))

-- Current MM2 silent shot
tryInvoke("beam 1,pos,AH2", beamRf, 1, pos, "AH2")
task.wait(0.4)
say("alive after beam AH2: " .. tostring(alive(target)))

tryInvoke("beam 1,pos", beamRf, 1, pos)
task.wait(0.3)
tryInvoke("classic tick,pos", shootGun, tick(), pos)
task.wait(0.3)
tryInvoke("classic 1,pos,AH2", shootGun, 1, pos, "AH2")
task.wait(0.3)

-- Any other remotes on the gun
for _, d in ipairs(gun:GetDescendants()) do
    if d:IsA("RemoteFunction") and d ~= beamRf and d ~= shootGun then
        tryInvoke("other " .. d.Name .. " 1,pos,AH2", d, 1, pos, "AH2")
        task.wait(0.2)
    end
end

say("Activate()")
pcall(function() gun:Activate() end)
task.wait(0.5)
say("done alive=" .. tostring(alive(target)))
