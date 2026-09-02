local CFG = { charges = 3, radius = 8, base_mags = 1, restore_after = 0.6 };

local C = { pos = nil, left = 0, level = {}, conn = nil };

local function magcount()
	local ok, v = pcall(function()
		return sharedvars.plr_magazines;
	end);
	if ok and type(v) == "number" then
		return v;
	end
	return CFG.base_mags;
end

shared.ct2 = {};

shared.ct2.base = function(n)
	CFG.base_mags = tonumber(n) or 1;
	pcall(function()
		sharedvars.plr_magazines = CFG.base_mags;
	end);
	return "plr_magazines base set to " .. tostring(CFG.base_mags) .. " - respawn to apply";
end

shared.ct2.place = function()
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return "no position";
	end
	C.pos = pos;
	C.left = CFG.charges;
	C.level = {};
	for _, pl in pairs(players.get_all()) do
		pcall(pl.fire_client, string.format("mark:%.1f,%.1f,%.1f:600", pos.X, pos.Y, pos.Z));
	end
	return "crate placed, " .. tostring(C.left) .. " charges, base mags " .. tostring(CFG.base_mags);
end

shared.ct2.take = function(who)
	local name = who or sharedvars.vip_owner;
	local p = players.get(name);
	if not p then
		return "no player " .. tostring(name);
	end
	if not C.pos then
		return "no crate placed";
	end
	if C.left <= 0 then
		return "crate empty";
	end
	local ok, pos = pcall(p.get_position);
	if ok and pos and (pos - C.pos).Magnitude > CFG.radius then
		return "too far (" .. tostring(math.floor((pos - C.pos).Magnitude)) .. " studs)";
	end

	local wok, w = pcall(p.get_weapon_data_from_character, "primary");
	if not wok or type(w) ~= "table" or not w.client_data or not w.client_data.name then
		return "could not read your primary";
	end

	local cur = C.level[name] or CFG.base_mags;
	local want = cur + 1;
	C.level[name] = want;
	C.left = C.left - 1;

	local before = magcount();
	pcall(function()
		sharedvars.plr_magazines = want;
	end);
	local sok, serr = pcall(p.set_weapon, "primary", w.client_data.name, w.client_data.setup);
	print(
		"[c2] "
			.. name
			.. " mags "
			.. tostring(before)
			.. " -> "
			.. tostring(want)
			.. ", regave "
			.. tostring(w.client_data.name)
			.. " ok="
			.. tostring(sok)
			.. " "
			.. tostring(serr)
	);

	time.delay(CFG.restore_after, function()
		pcall(function()
			sharedvars.plr_magazines = CFG.base_mags;
		end);
		print("[c2] plr_magazines restored to " .. tostring(CFG.base_mags));
	end);

	pcall(p.fire_client, "note:AMMO  " .. tostring(want) .. " mags,  " .. tostring(C.left) .. " left");
	return "gave " .. name .. " " .. tostring(want) .. " mags, crate has " .. tostring(C.left);
end

shared.ct2.status = function()
	return "crate=" .. tostring(C.pos ~= nil)
		.. " charges=" .. tostring(C.left)
		.. " plr_magazines=" .. tostring(magcount())
		.. " base=" .. tostring(CFG.base_mags);
end

shared.ct2.clear = function()
	C.pos = nil;
	C.left = 0;
	pcall(function()
		sharedvars.plr_magazines = CFG.base_mags;
	end);
	return "crate cleared, magazines reset";
end

print("[c2] ready: shared.ct2.base(1) / .place() / .take() / .status() / .clear()");
