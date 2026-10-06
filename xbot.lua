_G.xeno_roblox = "balenc8i"
_G.xeno_discord = "mewrrw"

_G.public_mode = false
_G.announcement_message = "mr. cool has arrived"
-- true = workspace xbot.lua via readfile; false = GitHub xeno.lua
_G.xeno_local = _G.xeno_local ~= false

local gui = Instance.new("ScreenGui")
gui.Name = "XenoLoader"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local box = Instance.new("Frame", gui)
box.Size = UDim2.new(0, 420, 0, 150)
box.Position = UDim2.new(1, -440, 0, 20)
box.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
box.BorderSizePixel = 0
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", box)
title.Size = UDim2.new(1, -20, 0, 24)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(180, 125, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Xeno Loader"

local status = Instance.new("TextLabel", box)
status.Size = UDim2.new(1, -20, 1, -42)
status.Position = UDim2.new(0, 10, 0, 34)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(235, 235, 245)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top

local function setStatus(msg)
    status.Text = tostring(msg)
end

local function tryRead(name)
    if not readfile then return end
    local ok, body = pcall(readfile, name)
    if ok and type(body) == "string" and body ~= "" then
        return body
    end
end

setStatus(_G.xeno_local and "Loading local xbot.lua" or "Downloading Xeno")
local src
if _G.xeno_local then
    src = tryRead("xbot.lua") or tryRead("bot2.lua")
end
if not src then
    local ok, body = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/sp5-y/xbot/refs/heads/main/xbot.lua")
    end)
    if not ok or not body or body == "" then
        setStatus("Download failed: " .. tostring(body))
        return
    end
    src = body
end

local fn, err = loadstring(src)
if not fn then
    setStatus("Compile failed:\n" .. tostring(err))
    return
end

setStatus("Starting Xeno")
local runOk, runErr = pcall(fn)
if not runOk then
    setStatus("Runtime failed: " .. tostring(runErr))
else
    gui:Destroy()
end
