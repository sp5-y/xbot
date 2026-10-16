local P,RS=game:GetService("Players"),game:GetService("ReplicatedStorage");local me=P.LocalPlayer
local dec=decompile or(syn and syn.decompile);local gsb=getscriptbytecode
local g=Instance.new("ScreenGui");g.ResetOnSpawn,g.DisplayOrder=false,999
if not pcall(function()g.Parent=gethui and gethui() or game:GetService("CoreGui")end)or not g.Parent then g.Parent=me:WaitForChild("PlayerGui")end
local b=Instance.new("TextLabel",g);b.Size,b.Position=UDim2.new(0,460,0,60),UDim2.new(0.5,-230,0,80);b.BackgroundColor3,b.TextColor3=Color3.new(0.07,0.07,0.1),Color3.new(1,1,1);b.Font,b.TextSize,b.TextWrapped=Enum.Font.Code,14,true
local function st(m)b.Text="gundump: "..m;print("[gundump] "..m)end
local out,seen={},{}
local function add(s)out[#out+1]=tostring(s)end
local KEY={"gun","shoot","beam","bullet","weapon","knife","throw","stab","raycast","hit","fire"}
local function hot(n)n=n:lower()for _,k in ipairs(KEY)do if n:find(k,1,true)then return true end end end
local function tree(i,p,d)if d>7 then return end add(p..i.ClassName.." "..i.Name)for _,c in ipairs(i:GetChildren())do tree(c,p.."  ",d+1)end end
local function dump(s)
if seen[s]then return end seen[s]=true
add("\n-- ===== "..s.ClassName.." "..s:GetFullName().." =====")
local ok,src=pcall(function()return dec(s)end)
if ok and type(src)=="string"and#src>0 then add(src)return end
local okb,bc=pcall(function()return gsb and gsb(s)end)
add("-- decompile failed: "..tostring(src).." | bytecode bytes: "..tostring(okb and bc and#bc))
end
local function scripts(root,all)
for _,d in ipairs(root:GetDescendants())do
if(d:IsA("LocalScript")or d:IsA("ModuleScript"))and(all or hot(d:GetFullName()))then dump(d)end
end
end
local function findGun()
for _,pl in ipairs(P:GetPlayers())do
for _,bag in ipairs({pl.Character,pl:FindFirstChildOfClass("Backpack")})do
if bag then for _,t in ipairs(bag:GetChildren())do if t:IsA("Tool")and t.Name:lower():find("gun")then return t,pl end end end
end
end
end
if not dec then st("no decompile() in this executor")return end
st("waiting for someone to hold the gun...")
local gun,holder
for _=1,600 do gun,holder=findGun();if gun then break end task.wait(1)end
add("place="..game.PlaceId.." job="..game.JobId.." bot="..me.Name)
if gun then
add("=== GUN TOOL held by "..holder.Name.." ===");tree(gun,"",0)
st("dumping gun from "..holder.Name);scripts(gun,true)
else add("=== no gun seen in 10 min ===")end
for _,pl in ipairs(P:GetPlayers())do
local c=pl.Character;local k=c and c:FindFirstChild("Knife")
if k and k:IsA("Tool")then add("=== KNIFE TOOL held by "..pl.Name.." ===");tree(k,"",0);scripts(k,true)break end
end
for _,n in ipairs({"WeaponEvents","ClientServices","SharedServices","Modules"})do
local f=RS:FindFirstChild(n)
if f then add("\n=== RS."..n.." TREE ===");tree(f,"",0);st("dumping RS."..n);scripts(f,n=="WeaponEvents")end
end
local ps=me:FindFirstChild("PlayerScripts");if ps then scripts(ps,false)end
local txt=table.concat(out,"\n")
pcall(function()writefile("mm2-gun.txt",txt)end);pcall(function()setclipboard(txt)end)
st("done: "..#txt.." chars -> mm2-gun.txt (also on clipboard)")
