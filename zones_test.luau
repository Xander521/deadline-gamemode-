local FOUND = {};

local function newparams()
	local p = query.create_raycast_params();
	pcall(function()
		p.filter_type(Enum.RaycastFilterType.Exclude);
	end);
	return p;
end

shared.zt = {};

shared.zt.scan = function(range)
	local r = tonumber(range) or 60;
	local me = players.get(sharedvars.vip_owner);
	if not me then
		return "host not found";
	end
	local ok, pos = pcall(me.get_position);
	if not ok or not pos then
		return "no position";
	end

	FOUND = {};
	local dirs = {};
	local i = 0;
	while i < 16 do
		local a = (i / 16) * 6.28318;
		table.insert(dirs, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r));
		i = i + 1;
	end
	table.insert(dirs, Vector3.new(0, r, 0));
	table.insert(dirs, Vector3.new(0, -r, 0));

	local hits = 0;
	for _, d in ipairs(dirs) do
		local params = newparams();
		local layer = 0;
		while layer < 8 do
			layer = layer + 1;
			local rok, hit = pcall(query.raycast, pos, d, params);
			if not rok or not hit then
				break;
			end
			local inst = nil;
			pcall(function()
				inst = hit.instance;
			end);
			if not inst then
				break;
			end
			local nm = "?";
			pcall(function()
				nm = tostring(inst.Name);
			end);
			hits = hits + 1;
			if not FOUND[nm] then
				FOUND[nm] = inst;
				print("   hit: " .. nm);
			end
			pcall(function()
				params.add_to_filter({ inst });
			end);
		end
	end
	print("[zt] " .. tostring(hits) .. " hits, " .. tostring(#dirs) .. " rays");
	return "scan done - check the names above";
end

shared.zt.kill = function(needle)
	local pat = string.lower(tostring(needle or "ceasefire"));
	local n = 0;
	for nm, inst in pairs(FOUND) do
		if string.find(string.lower(nm), pat, 1, true) then
			local a = pcall(function()
				inst.CanCollide = false;
			end);
			local b = pcall(function()
				inst.CanQuery = false;
			end);
			local c = pcall(function()
				inst.destroy();
			end);
			print("   " .. nm .. " collide=" .. tostring(a) .. " query=" .. tostring(b) .. " destroy=" .. tostring(c));
			n = n + 1;
		end
	end
	return "processed " .. tostring(n) .. " parts matching '" .. pat .. "'";
end

shared.zt.list = function()
	local n = 0;
	for nm in pairs(FOUND) do
		n = n + 1;
		print("   " .. nm);
	end
	return tostring(n) .. " unique names from the last scan";
end

print("[zt] ready: shared.zt.scan(60) / shared.zt.list() / shared.zt.kill('ceasefire')");
