local CAND = {};

shared.zt5 = {};

local function info(inst)
	local nm, sz, pos, tr, cc = "?", nil, nil, "?", "?";
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
	return nm, sz, pos, tr, cc;
end

shared.zt5.scan = function(range)
	local r = tonumber(range) or 120;
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
	if not rok or type(all) ~= "table" then
		return "no descendants";
	end

	CAND = {};
	for _, inst in ipairs(all) do
		local isp = false;
		pcall(function()
			isp = inst.is_a("BasePart");
		end);
		if isp then
			local nm, sz, pos, tr, cc = info(inst);
			if sz and pos then
				local vol = sz.X * sz.Y * sz.Z;
				local invisible = tonumber(tr) and tonumber(tr) > 0.5;
				local d = (pos - mypos).Magnitude;
				if vol >= 500 and invisible and d <= r then
					table.insert(CAND, { inst = inst, d = d, vol = vol, sz = sz, cc = cc });
				end
			end
		end
	end

	table.sort(CAND, function(a, b)
		return a.d < b.d;
	end);

	for i, c in ipairs(CAND) do
		if i <= 25 then
			print(string.format(
				"   [%d] %dm away  vol=%d  size=%dx%dx%d  collide=%s",
				i, math.floor(c.d), math.floor(c.vol),
				math.floor(c.sz.X), math.floor(c.sz.Y), math.floor(c.sz.Z), c.cc
			));
		end
	end
	print("[zt5] " .. tostring(#CAND) .. " invisible volumes within " .. tostring(r) .. " studs, nearest first");
	return "scan done - use shared.zt5.kill(1) on the closest";
end

shared.zt5.kill = function(i)
	local idx = tonumber(i) or 1;
	local c = CAND[idx];
	if not c then
		return "no candidate " .. tostring(idx);
	end
	local ok = pcall(function()
		c.inst.destroy();
	end);
	print("[zt5] destroyed candidate " .. tostring(idx) .. " ok=" .. tostring(ok));
	return "destroyed " .. tostring(idx) .. " - now test whether the restriction is gone";
end

shared.zt5.killall = function(range)
	local r = tonumber(range) or 60;
	local n = 0;
	for _, c in ipairs(CAND) do
		if c.d <= r then
			if pcall(function()
				c.inst.destroy();
			end) then
				n = n + 1;
			end
		end
	end
	return "destroyed " .. tostring(n) .. " volumes within " .. tostring(r) .. " studs";
end

print("[zt5] ready: shared.zt5.scan(120) / .kill(1) / .killall(60)");
