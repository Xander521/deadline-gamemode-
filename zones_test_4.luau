shared.zt4 = {};

local function info(inst)
	local nm, sz, pos, tr, cc, cq = "?", nil, nil, "?", "?", "?";
	pcall(function()
		nm = tostring(inst.Name);
	end);
	pcall(function()
		sz = inst.Size;
	end);
	pcall(function()
		pos = inst.Position;
	end);
	pcall(function()
		tr = tostring(inst.Transparency);
	end);
	pcall(function()
		cc = tostring(inst.CanCollide);
	end);
	pcall(function()
		cq = tostring(inst.CanQuery);
	end);
	return nm, sz, pos, tr, cc, cq;
end

shared.zt4.volumes = function(minvol)
	local mv = tonumber(minvol) or 2000;
	local root = get_map_root();
	if not root then
		return "no map root";
	end
	local ok, all = pcall(function()
		return root.get_descendants();
	end);
	if not ok or type(all) ~= "table" then
		return "no descendants";
	end

	local me = players.get(sharedvars.vip_owner);
	local mypos = nil;
	if me then
		local pok, p = pcall(me.get_position);
		if pok then
			mypos = p;
		end
	end

	local found = 0;
	for _, inst in ipairs(all) do
		local isp = false;
		pcall(function()
			isp = inst.is_a("BasePart");
		end);
		if isp then
			local nm, sz, pos, tr, cc, cq = info(inst);
			if sz then
				local vol = sz.X * sz.Y * sz.Z;
				local invisible = (tr ~= "?" and tonumber(tr) and tonumber(tr) > 0.5);
				local passable = (cc == "false");
				if vol >= mv and (invisible or passable) then
					found = found + 1;
					local dist = "?";
					if mypos and pos then
						dist = tostring(math.floor((pos - mypos).Magnitude));
					end
					if found <= 30 then
						print(string.format(
							"   %s  vol=%d  size=%dx%dx%d  transp=%s collide=%s query=%s  %sm away",
							nm, math.floor(vol), math.floor(sz.X), math.floor(sz.Y), math.floor(sz.Z), tr, cc, cq, dist
						));
					end
				end
			end
		end
	end
	print("[zt4] " .. tostring(found) .. " large invisible or non-colliding parts of " .. tostring(#all) .. " descendants");
	return "volume scan done";
end

shared.zt4.near = function(range)
	local r = tonumber(range) or 40;
	local me = players.get(sharedvars.vip_owner);
	if not me then
		return "host not found";
	end
	local ok, mypos = pcall(me.get_position);
	if not ok or not mypos then
		return "no position";
	end
	local root = get_map_root();
	local rok, all = pcall(function()
		return root.get_descendants();
	end);
	if not rok then
		return "no descendants";
	end
	local n = 0;
	for _, inst in ipairs(all) do
		local isp = false;
		pcall(function()
			isp = inst.is_a("BasePart");
		end);
		if isp then
			local nm, sz, pos, tr, cc, cq = info(inst);
			if pos and (pos - mypos).Magnitude <= r and sz then
				local vol = sz.X * sz.Y * sz.Z;
				if vol > 500 then
					n = n + 1;
					if n <= 30 then
						print(string.format("   %s  vol=%d  transp=%s collide=%s query=%s", nm, math.floor(vol), tr, cc, cq));
					end
				end
			end
		end
	end
	print("[zt4] " .. tostring(n) .. " sizeable parts within " .. tostring(r) .. " studs");
	return "proximity scan done";
end

print("[zt4] ready: shared.zt4.volumes(2000) / shared.zt4.near(40)");
