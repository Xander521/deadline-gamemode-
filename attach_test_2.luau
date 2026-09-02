local function setup(laser, flash, mode)
	return '{"map":[],"tape":[],"stickers":[],"preferences":{"optics":[],"laser":'
		.. tostring(laser)
		.. ',"firemode":"'
		.. mode
		.. '","mounting":true,"flashlight":'
		.. tostring(flash)
		.. "}}";
end

local function trial(weapon, data, label)
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, err = pcall(p.set_weapon, "primary", weapon, data);
	print("[a2] " .. label .. " ok=" .. tostring(ok) .. " err=" .. tostring(err));
	return label .. " sent to " .. weapon;
end

shared.a2 = {};

shared.a2.laser = function(w)
	return trial(w or "AK_9", setup(true, false, "auto"), "laser only");
end

shared.a2.light = function(w)
	return trial(w or "AK_9", setup(false, true, "auto"), "flashlight only");
end

shared.a2.both = function(w)
	return trial(w or "AK_9", setup(true, true, "auto"), "laser + flashlight");
end

shared.a2.none = function(w)
	return trial(w or "AK_9", setup(false, false, "auto"), "bare");
end

shared.a2.semi = function(w)
	return trial(w or "AK_9", setup(true, true, "semi"), "semi + laser + light");
end

print("[a2] ready: .laser('AK_9') .light() .both() .none() .semi()");
