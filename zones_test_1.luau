local FOUND = {};

shared.zt = {};

local function describe(inst)
	local nm, parent, cls, tags = "?", "?", "?", "";
	pcall(function()
		nm = tostring(inst.Name);
	end);
	pcall(function()
		parent = tostring(inst.Parent.Name);
	end);
	pcall(function()
		if inst.is_a("BasePart") then
			cls = "BasePart";
		end
	end);
	pcall(function()
		local t = inst.get_tags();
		if type(t) == "table" then
			for _, v in ipairs(t) do
				tags = tags .. tostring(v) .. " ";
			end
		end
	end);
	return nm, parent, cls, tags;
end

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
	while i < 12 do
		local a = (i / 12) * 6.28318;
		table.insert(dirs, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r));
		i = i + 1;
	end
	table.insert(dirs, Vector3.new(0, r, 0));

	local shown = 0;
	for _, d in ipairs(dirs) do
		local params = query.create_raycast_params();
		pcall(function()
			params.filter_type(Enum.RaycastFilterType.Exclude);
		end);
		local layer = 0;
		while layer < 10 do
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
			local nm, parent, cls, tags = describe(inst);
			local key = nm .. " < " .. parent;
			if not FOUND[key] then
				FOUND[key] = inst;
				shown = shown + 1;
				if shown <= 40 then
					print("   " .. nm .. "   parent=" .. parent .. "   tags=" .. (tags ~= "" and tags or "none"));
				end
			end
			pcall(function()
				params.add_to_filter({ inst });
			end);
		end
	end
	print("[zt] " .. tostring(shown) .. " unique name+parent combinations");
	return "scan done";
end

shared.zt.tags = function()
	for _, t in ipairs({ "ceasefire", "defender_ceasefire", "attacker_ceasefire", "spawn", "spawn_zone", "no_build", "restricted" }) do
		local ok, list = pcall(tags.get_tagged, t);
		local c = 0;
		if ok and type(list) == "table" then
			c = #list;
		end
		print("   tag '" .. t .. "' -> " .. tostring(c));
	end
	return "tag counts printed";
end

shared.zt.kill = function(needle)
	local pat = string.lower(tostring(needle or "ceasefire"));
	local n = 0;
	for key, inst in pairs(FOUND) do
		if string.find(string.lower(key), pat, 1, true) then
			local a = pcall(function()
				inst.CanCollide = false;
			end);
			local c = pcall(function()
				inst.destroy();
			end);
			print("   " .. key .. " collide=" .. tostring(a) .. " destroy=" .. tostring(c));
			n = n + 1;
		end
	end
	return "processed " .. tostring(n);
end

print("[zt] ready: shared.zt.scan(60) / shared.zt.tags() / shared.zt.kill('ceasefire')");
