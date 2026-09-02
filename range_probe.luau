local SLOTS = { "primary", "secondary", "throwable1", "throwable2" };

shared.rprobe = {};

shared.rprobe.run = function(who)
	local name = who or sharedvars.vip_owner;
	local p = players.get(name);
	if not p then
		return "no player " .. tostring(name);
	end

	local aok, alive = pcall(p.is_alive);
	print("[rp] player=" .. name .. " alive=" .. tostring(aok and alive or "?"));
	local sok, slot = pcall(p.get_active_slot);
	print("[rp] active slot = " .. tostring(sok and slot or "?"));

	print("[rp] --- from character ---");
	for _, s in ipairs(SLOTS) do
		local ok, w = pcall(p.get_weapon_data_from_character, s);
		local nm = "nil";
		if ok and type(w) == "table" and w.client_data and w.client_data.name then
			nm = tostring(w.client_data.name) .. "  (setup " .. tostring(string.len(tostring(w.client_data.setup))) .. " chars)";
		end
		print("   " .. s .. ": " .. nm);
	end

	print("[rp] --- from loadouts 0-9 ---");
	local found = 0;
	for i = 0, 9 do
		for _, s in ipairs(SLOTS) do
			local ok, d = pcall(p.get_weapon_from_loadout, i, s);
			if ok and type(d) == "table" and d.weapon then
				found = found + 1;
				print("   loadout " .. tostring(i) .. " " .. s .. " = " .. tostring(d.weapon) .. "  (setup " .. tostring(string.len(tostring(d.data))) .. " chars)");
			end
		end
	end
	print("[rp] loadout entries found: " .. tostring(found));
	return "probe done - see console";
end

shared.rprobe.dump = function(arg)
	local i, s = nil, nil;
	if type(arg) == "string" then
		i, s = arg:match("^%s*(%d+)%s+(%S+)");
	end
	if not i then
		return "usage: shared.rprobe.dump('0 primary')";
	end
	local p = players.get(sharedvars.vip_owner);
	local ok, d = pcall(p.get_weapon_from_loadout, tonumber(i), s);
	if not ok or type(d) ~= "table" or not d.weapon then
		return "nothing in loadout " .. i .. " " .. s;
	end
	print("[rp] NAME = " .. tostring(d.weapon));
	local setup = tostring(d.data);
	local j = 1;
	while j <= string.len(setup) do
		print(string.sub(setup, j, j + 89));
		j = j + 90;
	end
	return "dumped loadout " .. i .. " " .. s;
end

print("[rp] ready: shared.rprobe.run() / shared.rprobe.dump('0 primary')");
