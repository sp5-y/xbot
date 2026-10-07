--[[ MM2 shoot test. Finds raIentless, hops above, tries each fire path. execute2.lua ]]--

local TARGET_NAME = "raIentless"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
local cam = workspace.CurrentCamera
local SPAWN = CFrame.new(14.3513288, 505.044952, -58.2513657, 1, 0, 0, 0, 1, 0, 0, 0, 1)

local function say(msg)
    local s = tostring(msg)
    print("[shoot-test] " .. s)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "shoot-test",
            Text = s,
            Duration = 3,
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

local function hrp()
    return me.Character and me.Character:FindFirstChild("HumanoidRootPart")
end

local function goAbove(pos)
    local h = hrp()
    local above = pos + Vector3.new(0, 12, 0)
    if h then
        pcall(function()
            h.Anchored = false
            h.AssemblyLinearVelocity = Vector3.zero
            h.CFrame = CFrame.new(above, pos)
        end)
    end
    if cam then
        pcall(function() cam.CFrame = CFrame.new(above, pos) end)
    end
    task.wait(0.05)
end

local function goHome()
    local h = hrp()
    if h then
        pcall(function()
            h.CFrame = SPAWN
            h.AssemblyLinearVelocity = Vector3.zero
        end)
    end
end

local function fire(label, rf, ...)
    if not rf then
        say("SKIP " .. label)
        return false
    end
    local args = { ... }
    say("TRY " .. label .. " " .. rf.ClassName .. " " .. rf:GetFullName())
    local ok, err
    if rf:IsA("RemoteFunction") then
        ok, err = pcall(function() return rf:InvokeServer(unpack(args)) end)
    elseif rf:IsA("RemoteEvent") then
        ok, err = pcall(function() rf:FireServer(unpack(args)) end)
    else
        say("SKIP not remote")
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
say("gun " .. gun:GetFullName())

local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
if hum and gun.Parent ~= me.Character then
    pcall(function() hum:EquipTool(gun) end)
    task.wait(0.2)
end
say("equipped parent=" .. tostring(gun.Parent and gun.Parent.Name))

say("--- remotes ---")
for _, d in ipairs(gun:GetDescendants()) do
    if d:IsA("RemoteFunction") or d:IsA("RemoteEvent") then
        say(d.ClassName .. " " .. d:GetFullName())
    end
end

local shoot2 = gun:FindFirstChild("Shoot2", true)
local shootGun = gun:FindFirstChild("ShootGun", true)
local createBeam = gun:FindFirstChild("CreateBeam", true)
local we = RS:FindFirstChild("WeaponEvents")
local gunBeam = we and we:FindFirstChild("GunBeam")
local cs = RS:FindFirstChild("ClientServices")
local ws = cs and cs:FindFirstChild("WeaponService")
local gunFired = ws and ws:FindFirstChild("GunFired")
say("Shoot2=" .. tostring(shoot2 and shoot2:GetFullName()))
say("ShootGun=" .. tostring(shootGun and shootGun:GetFullName()))
say("CreateBeam=" .. tostring(createBeam and createBeam:GetFullName()))
say("GunBeam=" .. tostring(gunBeam and gunBeam:GetFullName()))
say("GunFired=" .. tostring(gunFired and gunFired:GetFullName()))

local function stillUp()
    return alive(target)
end

for attempt = 1, 4 do
    if not stillUp() then
        say("DEAD before attempt " .. attempt)
        break
    end
    local pos = hitPos(target)
    if not pos then
        say("no hit pos")
        break
    end
    say("=== attempt " .. attempt .. " above target ===")
    goAbove(pos)
    local handle = gun:FindFirstChild("Handle")
    local origin = handle and handle.Position or (pos + Vector3.new(0, 12, 0))

    fire("GunBeam 1,pos,AH2", gunBeam, 1, pos, "AH2")
    task.wait(0.25)
    say("alive after GunBeam=" .. tostring(stillUp()))
    if not stillUp() then break end

    fire("Shoot2 1,pos,AH2", shoot2, 1, pos, "AH2")
    task.wait(0.25)
    say("alive after Shoot2 AH2=" .. tostring(stillUp()))
    if not stillUp() then break end

    fire("Shoot2 tick,pos", shoot2, tick(), pos)
    task.wait(0.25)
    say("alive after Shoot2 tick=" .. tostring(stillUp()))
    if not stillUp() then break end

    fire("GunBeam origin,pos", gunBeam, origin, pos)
    task.wait(0.25)
    say("alive after GunBeam origin=" .. tostring(stillUp()))
    if not stillUp() then break end

    fire("GunFired 1,pos,AH2", gunFired, 1, pos, "AH2")
    fire("ShootGun tick,pos", shootGun, tick(), pos)
    fire("CreateBeam 1,pos,AH2", createBeam, 1, pos, "AH2")
    say("Activate()")
    pcall(function() gun:Activate() end)
    task.wait(0.35)
    say("alive after Activate=" .. tostring(stillUp()))
    if not stillUp() then break end

    goHome()
    say("miss attempt " .. attempt .. " — waiting cooldown")
    task.wait(2.1)
end

goHome()
say("DONE alive=" .. tostring(stillUp()) .. " target=" .. target.Name)
