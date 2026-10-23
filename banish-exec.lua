-- paste this on any device — fetches latest banish.lua
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
    warn("[banish] download failed")
    return
end
local fn, err = loadstring(src)
if not fn then
    warn("[banish] compile failed: " .. tostring(err))
    return
end
fn()
