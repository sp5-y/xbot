local P=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SPS=game:GetService("StarterPlayer")
local SG=game:GetService("StarterGui")
local SS=game:GetService("StarterPack")
local LS=game:GetService("Lighting")
local me=P.LocalPlayer
local dec=decompile or(syn and syn.decompile)
local gsb=getscriptbytecode
local g=Instance.new("ScreenGui")
g.ResetOnSpawn,g.DisplayOrder=false,999
if not pcall(function()g.Parent=gethui and gethui() or game:GetService("CoreGui")end)or not g.Parent then
g.Parent=me:WaitForChild("PlayerGui")
end
local b=Instance.new("TextLabel",g)
b.Size,b.Position=UDim2.new(0,520,0,70),UDim2.new(0.5,-260,0,80)
b.BackgroundColor3,b.TextColor3=Color3.new(0.07,0.07,0.1),Color3.new(1,1,1)
b.Font,b.TextSize,b.TextWrapped=Enum.Font.Code,14,true
local function st(m)b.Text="srcdump: "..m print("[srcdump] "..m)end
local out,seen,nOK,nFail={},{},0,0
local function add(s)out[#out+1]=tostring(s)end
local SKIP={"CoreGui","Chat","BubbleChat","PlayerListManager","RbxCharacterSounds","PlayerModule","CameraModule","ControlModule"}
local function skip(s)
local n=s:GetFullName()
for _,k in ipairs(SKIP)do if n:find(k,1,true)then return true end end
end
local function tree(i,p,d)
if d>10 then return end
add(p..i.ClassName.." "..i.Name)
for _,c in ipairs(i:GetChildren())do tree(c,p.."  ",d+1)end
end
local function dump(s)
if seen[s]or skip(s)then return end
seen[s]=true
add("\n-- ===== "..s.ClassName.." "..s:GetFullName().." =====")
st("decompiling "..s:GetFullName())
local ok,src=pcall(function()return dec(s)end)
if ok and type(src)=="string"and#src>20 then
nOK=nOK+1
add(src)
return
end
nFail=nFail+1
local okb,bc=pcall(function()return gsb and gsb(s)end)
add("-- decompile failed: "..tostring(src).." | bytecode: "..tostring(okb and bc and#bc))
end
local function scripts(root)
if not root then return end
pcall(function()
for _,d in ipairs(root:GetDescendants())do
if d:IsA("LocalScript")or d:IsA("ModuleScript")then dump(d)end
end
end)
end
local function remotes(root,label)
add("\n=== REMOTES "..label.." ===")
if not root then add("(missing)")return end
pcall(function()
for _,d in ipairs(root:GetDescendants())do
if d:IsA("RemoteEvent")or d:IsA("RemoteFunction")or d:IsA("UnreliableRemoteEvent")or d:IsA("BindableEvent")or d:IsA("BindableFunction")then
add(d.ClassName.." "..d:GetFullName())
end
end
end)
end
local function tools(bag,who)
if not bag then return end
for _,t in ipairs(bag:GetChildren())do
if t:IsA("Tool")then
add("\n=== TOOL "..who.." "..t:GetFullName().." ===")
tree(t,"",0)
scripts(t)
end
end
end
if not dec then st("no decompile() on this executor")return end
add("place="..game.PlaceId.." job="..game.JobId.." bot="..me.Name)
add("decompile=true")
add("\n=== RS TOP ===")
pcall(function()for _,c in ipairs(RS:GetChildren())do add(c.ClassName.." "..c.Name)end end)
remotes(RS,"ReplicatedStorage")
remotes(me.Character,"Character")
remotes(me:FindFirstChildOfClass("Backpack"),"Backpack")
for _,n in ipairs({"Remotes","WeaponEvents","ClientServices","SharedServices","Modules","Resources"})do
local f=RS:FindFirstChild(n)
if f then add("\n=== TREE RS."..n.." ===")tree(f,"",0)end
end
st("dumping ReplicatedStorage")
scripts(RS)
st("dumping StarterPlayer")
scripts(SPS)
st("dumping StarterGui")
scripts(SG)
st("dumping StarterPack")
scripts(SS)
st("dumping Lighting")
scripts(LS)
st("dumping PlayerScripts")
scripts(me:FindFirstChild("PlayerScripts"))
st("dumping PlayerGui")
scripts(me:FindFirstChild("PlayerGui"))
st("dumping character/backpack")
scripts(me.Character)
scripts(me:FindFirstChildOfClass("Backpack"))
for _,pl in ipairs(P:GetPlayers())do
tools(pl.Character,pl.Name)
tools(pl:FindFirstChildOfClass("Backpack"),pl.Name)
end
local txt=table.concat(out,"\n")
pcall(function()writefile("mm2-src.txt",txt)end)
pcall(function()setclipboard(txt)end)
st("done "..nOK.." ok / "..nFail.." fail / "..#txt.." chars -> mm2-src.txt")
