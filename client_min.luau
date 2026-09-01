local role="" local reveal=0 local rev=0 local flash=0 local fhl=nil local hid="" local changed={} local hl={} local amb={} local hb=nil
local function nv() if role~="" then pcall(framework.character.set_nv_enabled,role=="hunter") end end
local function mk(id,vol,loop,at)
 local sok,s=pcall(create_instance,"Sound")
 if not sok or not s then print("[hc] Sound create FAILED") return nil end
 local parent=get_map_root()
 local part=nil
 if at then
  local pok,pt=pcall(create_instance,"Part")
  if pok and pt then
   pcall(function()
    pt.Anchored=true pt.CanCollide=false pt.CastShadow=false
    pt.Transparency=1 pt.Size=Vector3.new(1,1,1)
    pt.Position=at pt.Parent=get_map_root()
   end)
   part=pt parent=pt
  end
 end
 pcall(function()
  s.SoundId="rbxassetid://"..id s.Volume=vol s.Looped=loop
  if at then s.RollOffMaxDistance=(loop and 3000 or 400) end
  s.Parent=parent
 end)
 pcall(function() s.play() end)
 if not loop then
  time.delay(14,function()
   pcall(function() s.destroy() end)
   if part then pcall(function() part.destroy() end) end
  end)
 end
 return s,part
end

local ambparts={}
local function ambience()
 for _,o in ipairs(amb) do pcall(function() o.destroy() end) end
 for _,o in ipairs(ambparts) do pcall(function() o.destroy() end) end
 amb={} ambparts={}
 print("[hc] ambience cleared (server pushes loops)")
end

local function chars()
 local ok,k=pcall(function() return get_chars_root().get_children() end)
 if ok and type(k)=="table" then return k end
 return {}
end
local function hide(c,t)
 local ok,d=pcall(function() return c.get_descendants() end)
 if not ok then return end
 for _,v in ipairs(d) do
  local bok,isb=pcall(function() return v.is_a("BasePart") end)
  if bok and isb then
   local cok,cur=pcall(function() return v.Transparency end)
   if cok and cur and cur<t then
    if changed[v]==nil then changed[v]=cur end
    pcall(function() v.Transparency=t end)
   end
  end
 end
end
local function restore() for v,o in pairs(changed) do pcall(function() v.Transparency=o end) end changed={} end
local function clearhl() for k,h in pairs(hl) do pcall(function() h.destroy() end) end hl={} end
on_server_event:Connect(function(a)
 if type(a)=="table" then a=a[1] end
 if type(a)~="string" then return end
 if a=="amb" then print("[hc] ambience restart requested") ambience() return end
 if string.sub(a,1,6)=="flash:" then flash=tick()+(tonumber(string.sub(a,7)) or 2) return end
 if string.sub(a,1,7)=="reveal:" then rev=tick()+(tonumber(string.sub(a,8)) or 3) return end
 if string.sub(a,1,6)=="hlall:" then reveal=tick()+(tonumber(string.sub(a,7)) or 8) return end
 if string.sub(a,1,5)=="note:" then print("[hc] "..string.sub(a,6)) return end
 if string.sub(a,1,5)=="loop:" then
  local id,vol=string.match(string.sub(a,6),"^(%d+):([%d%.]+)$")
  if id then
   local base=nil
   local pk,pp=pcall(framework.character.get_position)
   if pk then base=pp end
   local sn,pt=mk(id,tonumber(vol) or 0.4,true,base or Vector3.new())
   if sn then table.insert(amb,sn) end
   if pt then table.insert(ambparts,pt) end
   print("[hc] loop "..id.." vol "..vol.." sound="..tostring(sn~=nil).." part="..tostring(pt~=nil))
  end
  return end
 if string.sub(a,1,7)=="hbloop:" then
  local id=string.sub(a,8)
  local base=nil
  local pk,pp=pcall(framework.character.get_position)
  if pk then base=pp end
  local hpt
  hb,hpt=mk(id,0,true,base or Vector3.new())
  if hpt then table.insert(ambparts,hpt) end
  if hb then table.insert(amb,hb) print("[hc] heartbeat loop "..id) end
  return end
 if string.sub(a,1,4)=="sfx:" then
  local rest=string.sub(a,5)
  local id,x,y,z=string.match(rest,"^(%d+):([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
  if id then mk(id,0.9,false,Vector3.new(tonumber(x),tonumber(y),tonumber(z)))
  else mk(rest,0.55,false) end
  return end
 if string.sub(a,1,2)=="h:" then hid=string.sub(a,3) restore()
 else role=a clearhl() restore() time.delay(0.3,nv) end
end)
framework.on_spawned:Connect(function()
 time.delay(0.5,nv)
 time.delay(1.2,function()
  if role=="hunter" then
   local dok,derr=pcall(input.disable_default_action,"prone")
   print("[hc] prone disable ok="..tostring(dok).." "..tostring(derr))
  else
   pcall(input.enable_default_action,"prone")
  end
 end)
end)
local followt=0
time.heartbeat("hidden_ambfollow",function(dt)
 followt=followt+(dt or 0.03)
 if followt<0.2 then return end
 followt=0
 if #ambparts==0 then return end
 local ok,pp=pcall(framework.character.get_position)
 if not ok or not pp then return end
 for _,pt in ipairs(ambparts) do pcall(function() pt.Position=pp end) end
end)
time.heartbeat("hidden_hp",function()
 if not hb then return end
 local ok,h=pcall(framework.character.get_health)
 if not ok or not h then return end
 local v=0
 if h<60 then v=(60-h)/60*0.9 end
 pcall(function() hb.Volume=v end)
end)
time.heartbeat("hidden_nv",function()
 if role~="survivor" then return end
 local ok,on=pcall(framework.character.is_nv_enabled)
 if ok and on then pcall(framework.character.set_nv_enabled,false) end
end)
local vist=0
time.heartbeat("hidden_vis",function(dt)
 vist=vist+(dt or 0.03)
 if vist<0.25 then return end
 vist=0
 if role=="hunter" then
  local mypos=nil
  local pok,pp=pcall(framework.character.get_position)
  if pok then mypos=pp end
  local showall=(tick()<reveal)
  for _,c in ipairs(chars()) do
   local nm=tostring(c.Name)
   local near=showall
   if not near and mypos then
    local rp=c.find_first_child("humanoid_root_part")
    if rp then
     local rok,rpos=pcall(function() return rp.Position end)
     if rok and rpos and (rpos-mypos).Magnitude<45 then near=true end
    end
   end
   if nm~="StarterCharacter" and near and not hl[nm] then
    local ok,h=pcall(create_instance,"Highlight")
    if ok and h then
     pcall(function() h.FillColor=Color3.fromRGB(255,60,60) h.FillTransparency=0.6 h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop h.Parent=c end)
     hl[nm]=h
    end
   elseif nm~="StarterCharacter" and not near and hl[nm] then
    pcall(function() hl[nm].destroy() end)
    hl[nm]=nil
   end
  end
  return
 end
 if hid=="" then return end
 local fl=(tick()<flash)
 local t=0.9 if tick()<rev then t=0.25 end
 if fl then t=0.15 end
 for _,c in ipairs(chars()) do
  if tostring(c.Name)==tostring(hid) then
   if t<0.9 then restore() end
   hide(c,t)
   if fl and not fhl then
    local ok,h=pcall(create_instance,"Highlight")
    if ok and h then
     pcall(function() h.FillColor=Color3.fromRGB(255,80,80) h.OutlineColor=Color3.fromRGB(255,220,220) h.FillTransparency=0.5 h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop h.Parent=c end)
     fhl=h
    end
   end
  end
 end
 if not fl and fhl then pcall(function() fhl.destroy() end) fhl=nil restore() end
end)
local g=InputGroup.new()
g:bind_key(function() if role=="hunter" then fire_server("screech") end end,InputType.Began,false,Enum.KeyCode.F)
g:bind_key(function()
 if role=="hunter" then
  local d=framework.character.get_camera_cframe().LookVector
  fire_server(string.format("pounce:%.3f,%.3f,%.3f",d.X,d.Y,d.Z))
 else
  print("[hc] ping")
  fire_server("ping")
 end
end,InputType.Began,false,Enum.KeyCode.G)
g:bind_key(function() if role~="hunter" then return end fire_server("radio") end,InputType.Began,false,Enum.KeyCode.V)
g:bind_key(function() if role=="hunter" then fire_server("latch_toggle") end end,InputType.Began,false,Enum.KeyCode.X)
local bok,bl=pcall(create_instance,"BlurEffect")
if bok and bl then pcall(function() bl.Size=0 bl.Parent=get_map_root() end) print("[hc] blur instance created (may not render)") end
print("[hc] loaded v24 F=screech G=pounce/ping X=hang V=radio F=screech G=pounce X=hang V=radio")
