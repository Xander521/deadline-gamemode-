local function dump(title, list)
	table.sort(list);
	print("=== " .. title .. " (" .. #list .. ") ===");
	local line = "";
	for _, v in ipairs(list) do
		if string.len(line) + string.len(v) > 85 then
			print(line);
			line = "";
		end
		line = line .. v .. ", ";
	end
	if line ~= "" then
		print(line);
	end
end

local function keys_of(tbl)
	local out = {};
	if type(tbl) ~= "table" then
		return out;
	end
	for k, v in pairs(tbl) do
		table.insert(out, tostring(k) .. "(" .. string.sub(type(v), 1, 3) .. ")");
	end
	return out;
end

local sv = {};
local ui = {};
for name in pairs(sharedvars_descriptions) do
	table.insert(sv, name);
	local l = string.lower(name);
	if
		string.find(l, "ui")
		or string.find(l, "hud")
		or string.find(l, "cross")
		or string.find(l, "tag")
		or string.find(l, "icon")
		or string.find(l, "blur")
		or string.find(l, "fov")
		or string.find(l, "dof")
		or string.find(l, "hit")
		or string.find(l, "marker")
		or string.find(l, "minimap")
	then
		table.insert(ui, name .. "=" .. tostring(sharedvars[name]));
	end
end
dump("ALL SHAREDVARS", sv);

local presets = {};
if config and config.lighting_presets then
	for name in pairs(config.lighting_presets) do
		table.insert(presets, name);
	end
end
dump("LIGHTING PRESETS", presets);

local tg = {};
local ok, res = pcall(tags.get_tags);
if ok and type(res) == "table" then
	for _, t in pairs(res) do
		table.insert(tg, tostring(t));
	end
end
dump("TAGS", tg);

dump("GLOBALS", keys_of(_G));

local target = sharedvars.vip_owner;
local p = nil;
if target then
	local pok, pr = pcall(players.get, target);
	if pok then
		p = pr;
	end
end
if not p then
	local list = players.get_all();
	p = list and list[1];
end

if p then
	dump("PLAYER OBJECT: " .. tostring(p.name), keys_of(p));
else
	print("=== PLAYER OBJECT: no player found ===");
end

dump("UI / HUD / OVERLAY SHAREDVARS", ui);

print("=== END AUDIT ===");
