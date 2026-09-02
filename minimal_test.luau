local MINIMAL = '{"map":[],"tape":[],"stickers":[],"preferences":{"optics":[],"laser":false,"firemode":"semi","mounting":true,"flashlight":false}}';
local MINIMAL_AUTO = '{"map":[],"tape":[],"stickers":[],"preferences":{"optics":[],"laser":false,"firemode":"auto","mounting":true,"flashlight":false}}';

shared.gtest = {};

local function trial(weapon, data, label, slot)
	slot = slot or "primary";
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, err = pcall(p.set_weapon, slot, weapon, data);
	print("[gtest] " .. label .. " '" .. weapon .. "' set ok=" .. tostring(ok) .. " err=" .. tostring(err));
	time.delay(1.5, function()
		local rok, w = pcall(p.get_weapon_data_from_character, slot);
		local got = "empty";
		if rok and type(w) == "table" and w.client_data and w.client_data.name then
			got = tostring(w.client_data.name);
		end
		print("[gtest] " .. slot .. " reads back: " .. got);
	end);
	return "tried " .. weapon .. " (" .. label .. ")";
end

shared.gtest.minimal = function(weapon)
	return trial(weapon or "MP5", MINIMAL, "minimal-semi");
end

shared.gtest.auto = function(weapon)
	return trial(weapon or "MP5", MINIMAL_AUTO, "minimal-auto");
end

shared.gtest.list = function()
	local out = "";
	for _, n in pairs(config.weapon_names) do
		out = out .. n .. " ";
	end
	print("[gtest] weapons: " .. out);
	return "weapon names printed";
end

print("[gtest] ready: shared.gtest.minimal('AK_9') / .auto('UMP') / .list()");
