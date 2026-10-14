local GE=getgenv and getgenv() or _G;local TARGET,PLACE_ID=GE.JOIN_TARGET or 4263338465,tonumber(GE.JOIN_PLACE) or 123974602339071
local P,TS,H=game:GetService("Players"),game:GetService("TeleportService"),game:GetService("HttpService");local me=P.LocalPlayer
local g=Instance.new("ScreenGui");g.ResetOnSpawn,g.DisplayOrder=false,999
if not pcall(function()g.Parent=gethui and gethui() or game:GetService("CoreGui")end)or not g.Parent then g.Parent=me:WaitForChild("PlayerGui")end
local b=Instance.new("TextLabel",g);b.Size,b.Position=UDim2.new(0,520,0,190),UDim2.new(0.5,-260,0,80);b.BackgroundColor3,b.TextColor3=Color3.new(0.07,0.07,0.1),Color3.new(1,1,1)
b.Font,b.TextSize,b.TextWrapped=Enum.Font.Code,14,true;b.TextXAlignment,b.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
local L={};local function say(m)m=tostring(m)print("[joinuser] "..m)table.insert(L,m)if #L>10 then table.remove(L,1)end b.Text=table.concat(L,"\n")end
local req=request or http_request or(syn and syn.request)
local function web(url,body,csrf)
local h={["Content-Type"]="application/json",Referer="https://www.roblox.com/"};if csrf then h["x-csrf-token"]=csrf end
local ok,r=pcall(req,{Url=url,Method=body and"POST"or"GET",Headers=h,Body=body and H:JSONEncode(body)or nil});if not ok or type(r)~="table"then return nil,0 end
local hd=r.Headers or{};local tok=hd["x-csrf-token"]or hd["X-CSRF-TOKEN"]or hd["X-Csrf-Token"]
if body and not csrf and tok and r.StatusCode==403 then return web(url,body,tok)end
local ok2,d=pcall(H.JSONDecode,H,r.Body or"");return ok2 and d or nil,r.StatusCode
end
local fail,moving,authed
me.OnTeleport:Connect(function(st)say("teleport: "..tostring(st))if st==Enum.TeleportState.Failed then fail="Failed"else moving=true end end)
TS.TeleportInitFailed:Connect(function(p,r,m)if p==me then fail=tostring(r).." "..tostring(m)end end)
local function find(uid)
local ok,list=pcall(function()return me:GetFriendsOnline(200)end)
if ok then for _,f in ipairs(list)do if tonumber(f.VisitorId)==uid then local j=tostring(f.GameId or"")
say("friends list: loc="..tostring(f.LocationType).." place="..tostring(f.PlaceId).." job="..(j~=""and j:sub(1,8)or"hidden"))
if f.PlaceId and #j>30 then return tonumber(f.PlaceId),j end end end end
if not req then return nil,nil,"no request function"end
if authed==nil then local d,c=web("https://users.roblox.com/v1/users/authenticated");authed=d and tonumber(d.id)==me.UserId or false;say("logged-in web requests: "..(authed and"yes"or"no (status "..tostring(c)..")"))end
if authed then
local d,c=web("https://gamejoin.roblox.com/v1/play-with-user",{userIdToFollow=uid,placeId=PLACE_ID,gameJoinAttemptId=H:GenerateGUID(false),isTeleport=false,isPlayTogetherGame=false,isQueueAllowedOverride=false,isImmersiveAdsTeleport=false,browserTrackerId=0,gamerTag="",channelName="",joinOrigin="",partyId=H:GenerateGUID(false)})
local j=d and(d.jobId or d.joinScript and d.joinScript.GameId);say("play-with-user: http "..tostring(c).." status "..tostring(d and d.status).." "..tostring(d and d.message or""))
if j and j~=""then return PLACE_ID,tostring(j)end
end
local m1=web("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..uid.."&size=150x150&format=Png&isCircular=false");local want=m1 and m1.data and m1.data[1]and m1.data[1].imageUrl
local cur,n=nil,0
for _=1,10 do
local d=want and web("https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?limit=100"..(cur and"&cursor="..H:UrlEncode(cur)or""));if not d or not d.data then break end
for _,s in ipairs(d.data)do n=n+1;local bt={}
for _,t in ipairs(s.playerTokens or{})do table.insert(bt,{requestId=t,token=t,type="AvatarHeadShot",size="150x150",format="Png",isCircular=false})end
local r=#bt>0 and web("https://thumbnails.roblox.com/v1/batch",bt);for _,t in ipairs(r and r.data or{})do if t.imageUrl==want then return PLACE_ID,s.id end end
end
cur=d.nextPageCursor;if not cur then break end
end
return nil,nil,"not found ("..n.." servers, only 5 players each are visible)"
end
local ok,err=pcall(function()
local uid=tonumber(TARGET)or P:GetUserIdFromNameAsync(TARGET)
for try=1,60 do
local pid,jid,why=find(uid);if jid and pid~=PLACE_ID then jid,why=nil,"different game "..tostring(pid)end
if jid==game.JobId then return say("already in their server")end
if jid then
say("teleporting, try "..try);fail,moving=nil,false
local okT,e=pcall(TS.TeleportToPlaceInstance,TS,pid,jid,me);if not okT then fail="error "..tostring(e)end
local t=tick();while not fail and tick()-t<(moving and 60 or 15)do task.wait(0.25)end
if fail then say("failed: "..fail)if fail:find("Unauthorized")or fail:find("GameEnded")then return end end
else say("try "..try..": "..tostring(why))end
task.wait(8)
end
say("gave up")
end)
if not ok then say("script error: "..tostring(err))end
