shared.gd = {};

local function read(who, slot)
	local p = players.get(who);
	if not p then
		return nil, "no player " .. tostring(who);
	end
	local ok, w = pcall(p.get_weapon_data_from_character, slot);
	if not ok or type(w) ~= "table" or not w.client_data then
		return nil, "nothing readable in " .. slot .. " for " .. who;
	end
	return w.client_data, nil;
end

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
	local cd, err = read(who, slot);
	if not cd then
		return err;
	end
	print("[gd] " .. who .. " / " .. slot .. " / NAME = " .. tostring(cd.name));
	print(tostring(cd.setup));
	return "printed " .. slot .. " (" .. tostring(string.len(tostring(cd.setup))) .. " chars) as one line";
end

shared.gd.all = function(who)
	who = who or sharedvars.vip_owner;
	shared.gd.slot(who .. " primary");
	shared.gd.slot(who .. " secondary");
	return "printed primary and secondary for " .. who;
end

shared.gd.chunked = function(arg)
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
	local cd, err = read(who, slot);
	if not cd then
		return err;
	end
	print("[gd] " .. tostring(cd.name));
	local s = tostring(cd.setup);
	local i = 1;
	while i <= string.len(s) do
		print(string.sub(s, i, i + 89));
		i = i + 90;
	end
	return "printed in chunks";
end

print("[gd] ready: shared.gd.slot('primary') / shared.gd.all() / shared.gd.chunked('primary')");
