shared.ctest = {};

shared.ctest.refill = function(who)
	local name = who or sharedvars.vip_owner;
	local p = players.get(name);
	if not p then
		return "no player " .. tostring(name);
	end
	local ok, err = pcall(p.refill_ammo);
	print("[ctest] refill_ammo(" .. tostring(name) .. ") ok=" .. tostring(ok) .. " " .. tostring(err));
	return "refilled " .. tostring(name) .. " - check whether you got one magazine or all of them";
end

shared.ctest.dump = function(arg)
	local name, slot = nil, nil;
	if type(arg) == "string" then
		name, slot = arg:match("^%s*(%S+)%s+(%S+)");
		if not name then
			name = arg:match("%S+");
		end
	end
	name = name or sharedvars.vip_owner;
	slot = slot or "primary";
	local p = players.get(name);
	if not p then
		return "no player " .. tostring(name);
	end
	local ok, w = pcall(p.get_weapon_data_from_character, slot);
	if not ok or type(w) ~= "table" or not w.client_data then
		return "could not read " .. slot .. " for " .. name;
	end
	print("[ctest] " .. name .. " " .. slot .. " NAME = " .. tostring(w.client_data.name));
	local setup = tostring(w.client_data.setup);
	print("[ctest] setup length = " .. tostring(string.len(setup)));
	local i = 1;
	while i <= string.len(setup) do
		print(string.sub(setup, i, i + 89));
		i = i + 90;
	end
	return "dumped " .. name .. " " .. slot;
end

shared.ctest.who = function()
	local out = "";
	for _, p in pairs(players.get_all()) do
		out = out .. p.name .. " ";
	end
	return "players: " .. out;
end

print("[ctest] ready: shared.ctest.refill(name) / .dump('name primary') / .who()");
