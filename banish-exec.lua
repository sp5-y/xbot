-- paste this on any device — fetches latest banish.lua
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local me = Players.LocalPlayer

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
    return pg or CoreGui
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "BanishLoader", false
gui.IgnoreGuiInset = true
gui.Enabled = true
pcall(function()
    gui.DisplayOrder = 100000
end)
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(gui)
    end
end)
gui.Parent = uiParent()

local box = Instance.new("Frame", gui)
box.Size, box.Position = UDim2.new(0, 420, 0, 120), UDim2.new(0.5, -210, 0, 80)
box.BackgroundColor3, box.BorderSizePixel = Color3.fromRGB(18, 18, 24), 0
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
local title = Instance.new("TextLabel", box)
title.Size, title.Position, title.BackgroundTransparency = UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 8), 1
title.Font, title.TextSize, title.TextColor3 = Enum.Font.GothamBold, 14, Color3.fromRGB(180, 125, 255)
title.TextXAlignment, title.Text = Enum.TextXAlignment.Left, "Banish Loader"
local status = Instance.new("TextLabel", box)
status.Size, status.Position, status.BackgroundTransparency = UDim2.new(1, -20, 1, -42), UDim2.new(0, 10, 0, 34), 1
status.Font, status.TextSize, status.TextWrapped = Enum.Font.Gotham, 13, true
status.TextColor3, status.TextXAlignment, status.TextYAlignment = Color3.fromRGB(235, 235, 245), Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
status.Text = "Downloading banish"

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and #body > 200 and not body:find("^%s*<") then
        return body
    end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return end
    local ok2, res = pcall(req, {
        Url = url,
        Method = "GET",
        Headers = {["Cache-Control"] = "no-cache", Pragma = "no-cache"},
    })
    if not ok2 or type(res) ~= "table" then return end
    local b = res.Body or res.body
    if type(b) == "string" and #b > 200 and not b:find("^%s*<") then
        return b
    end
end

local nonce = tostring(os.time()) .. tostring(math.random(10000, 99999))
local src = httpGet("https://raw.githubusercontent.com/sp5-y/xbot/main/banish.lua?v=" .. nonce)
if not src then
    src = httpGet("https://cdn.jsdelivr.net/gh/sp5-y/xbot@main/banish.lua?v=" .. nonce)
end
if not src then
    status.Text = "Download failed — panel stays so you can see this"
    return
end
status.Text = "Starting"
local fn, err = loadstring(src)
if not fn then
    status.Text = "Compile failed:\n" .. tostring(err)
    return
end
local ok, runErr = pcall(fn)
if not ok then
    status.Text = "Runtime failed:\n" .. tostring(runErr)
    return
end
pcall(function()
    gui:Destroy()
end)
