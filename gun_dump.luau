local function chunk(s)
	local i = 1;
	while i <= string.len(s) do
		print(string.sub(s, i, i + 89));
		i = i + 90;
	end
end

shared.gd = {};

shared.gd.slot = function(arg)
	local slot = "primary";
	local who = sharedvars.vip_owner;
	if type(arg) == "string" then
		local a, b = arg:match("^%s*(%S+)%s+(%S+)");
		if a then
			who, slot = a, b;
		else
			slot = arg:match("%S+") or "primary";
		end
	end
	local p = players.get(who);
	if not p then
		return "no player " .. tostring(who);
	end
	local ok, w = pcall(p.get_weapon_data_from_character, slot);
	if not ok or type(w) ~= "table" or not w.client_data then
		return "nothing readable in " .. slot .. " for " .. who;
	end
	print("[gd] ===== " .. who .. " / " .. slot .. " =====");
	print("[gd] NAME = " .. tostring(w.client_data.name));
	local setup = tostring(w.client_data.setup);
	print("[gd] LENGTH = " .. tostring(string.len(setup)));
	chunk(setup);
	print("[gd] ===== end =====");
	return "dumped " .. slot;
end

shared.gd.all = function(who)
	who = who or sharedvars.vip_owner;
	for _, s in ipairs({ "primary", "secondary" }) do
		shared.gd.slot(who .. " " .. s);
	end
	return "dumped primary and secondary for " .. who;
end

print("[gd] ready: shared.gd.slot('primary') / shared.gd.slot('Bashoxia secondary') / shared.gd.all()");
