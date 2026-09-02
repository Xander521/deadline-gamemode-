local PREF = '"tape":[],"stickers":[],"preferences":{"optics":[],"laser":true,"firemode":"semi","mounting":true,"flashlight":true}';

local function build(nodes)
	return '{"map":[' .. nodes .. '],' .. PREF .. '}';
end

local function node(name)
	return '{"name":"' .. name .. '","id":1,"attributes":[],"attached":[]}';
end

shared.atest = {};

local function trial(weapon, data, label)
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, err = pcall(p.set_weapon, "primary", weapon, data);
	print("[atest] " .. label .. " ok=" .. tostring(ok) .. " err=" .. tostring(err));
	time.delay(1.5, function()
		local rok, w = pcall(p.get_weapon_data_from_character, "primary");
		local got = "empty";
		if rok and type(w) == "table" and w.client_data and w.client_data.name then
			got = tostring(w.client_data.name);
		end
		print("[atest] primary reads: " .. got);
	end);
	return label .. " sent";
end

shared.atest.plain = function(w)
	return trial(w or "AK_9", build(""), "plain");
end

shared.atest.laser = function(w)
	return trial(w or "AK_9", build(node("las_tac_2")), "laser las_tac_2");
end

shared.atest.reflex = function(w)
	return trial(w or "AK_9", build(node("strauss_deltapoint_reflex_sight")), "reflex strauss");
end

shared.atest.rmr = function(w)
	return trial(w or "AK_9", build(node("virticon_rmr_rm06_type2_adj_led_reflex")), "reflex virticon");
end

shared.atest.irons = function(w)
	return trial(w or "AK_9", build(node("hart_rear_ironsight_200m")), "irons hart");
end

shared.atest.custom = function(arg)
	local w, nm = nil, nil;
	if type(arg) == "string" then
		w, nm = arg:match("^%s*(%S+)%s+(%S+)");
	end
	if not w then
		return "usage: shared.atest.custom('AK_9 las_tac_2')";
	end
	return trial(w, build(node(nm)), "custom " .. nm);
end

print("[atest] ready: .plain('AK_9') .laser() .reflex() .rmr() .irons() .custom('AK_9 name')");
