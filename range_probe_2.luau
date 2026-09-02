shared.rp2 = {};

local function keys(t, label)
	if type(t) ~= "table" then
		print("[rp2] " .. label .. " is " .. type(t));
		return;
	end
	local out = "";
	for k, v in pairs(t) do
		out = out .. tostring(k) .. "(" .. string.sub(type(v), 1, 3) .. ") ";
	end
	print("[rp2] " .. label .. ": " .. out);
end

shared.rp2.run = function()
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end

	local sok, slot = pcall(p.get_active_slot);
	print("[rp2] active slot value=" .. tostring(slot) .. " type=" .. type(slot));

	if sok and slot ~= nil then
		local ok, w = pcall(p.get_weapon_data_from_character, slot);
		print("[rp2] read using raw active slot: ok=" .. tostring(ok) .. " type=" .. type(w));
		if ok and type(w) == "table" then
			keys(w, "returned table");
			if w.client_data then
				keys(w.client_data, "client_data");
			end
		end
	end

	for _, s in ipairs({ "primary", "1", "slot1", "Primary", "melee", "utility" }) do
		local ok, w = pcall(p.get_weapon_data_from_character, s);
		local got = "nil";
		if ok and type(w) == "table" then
			got = "table";
			if w.client_data and w.client_data.name then
				got = tostring(w.client_data.name);
			end
		end
		print("[rp2] slot '" .. s .. "' -> " .. got);
	end

	keys(weapons, "weapons global");
	keys(p, "player object");
	return "probe 2 done";
end

shared.rp2.weapons = function()
	keys(weapons, "weapons global");
	for k, v in pairs(weapons) do
		if type(v) == "function" then
			print("[rp2] trying weapons." .. tostring(k) .. "()");
			local ok, res = pcall(v);
			print("      ok=" .. tostring(ok) .. " -> " .. string.sub(tostring(res), 1, 70));
		end
	end
	return "weapons table probed";
end

print("[rp2] ready: shared.rp2.run() / shared.rp2.weapons()");
