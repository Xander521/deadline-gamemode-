local CFG = {
	sound = "512957450",
	radius = 25,
	duration = 2,
	ping_hz = 5,
	require_los = true,
	cooldown = 20,
	ping_self = true,
};

local A = { pos = nil, owner = nil, ready = 0, firing = 0, pingt = 0, conn = nil };

local function los_clear(from, to)
	if not CFG.require_los then
		return true;
	end
	local dir = to - from;
	local dist = dir.Magnitude;
	if dist < 1 then
		return true;
	end
	local params = query.create_raycast_params();
	pcall(function()
		params.filter_type(Enum.RaycastFilterType.Exclude);
	end);
	for _ = 1, 5 do
		local ok, hit = pcall(query.raycast, from, dir, params);
		if not ok or not hit then
			return true;
		end
		local inst = nil;
		pcall(function()
			inst = hit.instance;
		end);
		if not inst then
			return true;
		end
		local nm = "";
		pcall(function()
			nm = string.lower(tostring(inst.Name));
		end);
		if not string.find(nm, "ceasefire") then
			local hp = nil;
			pcall(function()
				hp = hit.position;
			end);
			if hp and (hp - from).Magnitude < dist - 3 then
				return false, nm;
			end
			return true;
		end
		pcall(function()
			params.add_to_filter({ inst });
		end);
	end
	return true;
end

local function light_burst(pos, secs)
	local ok, part = pcall(create_instance, "Part");
	if not ok or not part then
		return;
	end
	pcall(function()
		part.Anchored = true;
		part.CanCollide = false;
		part.CanQuery = false;
		part.Transparency = 1;
		part.Size = Vector3.new(1, 1, 1);
		part.Position = pos + Vector3.new(0, 2, 0);
		part.Parent = get_map_root();
	end);
	local lok, li = pcall(create_instance, "PointLight");
	if lok and li then
		pcall(function()
			li.Color = Color3.fromRGB(255, 40, 40);
			li.Brightness = 3;
			li.Range = 28;
			li.Parent = part;
		end);
	end
	time.delay(secs, function()
		pcall(function()
			part.destroy();
		end);
	end);
end

local function survivors_and_owner()
	local out = {};
	for _, p in pairs(players.get_all()) do
		table.insert(out, p);
	end
	return out;
end

local function trigger(hunter_pos)
	A.firing = CFG.duration;
	A.pingt = 0;
	A.ready = CFG.cooldown;
	local payload = string.format("sfx:%s:%.1f,%.1f,%.1f", CFG.sound, A.pos.X, A.pos.Y, A.pos.Z);
	for _, p in pairs(players.get_all()) do
		pcall(p.fire_client, payload);
	end
	light_burst(A.pos, CFG.duration);
	print("[alarm] TRIGGERED at " .. tostring(A.pos));
end

shared.al = {};

shared.al.place = function()
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return "no position";
	end
	A.pos = pos;
	A.owner = sharedvars.vip_owner;
	A.ready = 0;
	pcall(p.fire_client, string.format("alm:%.1f,%.1f,%.1f", pos.X, pos.Y, pos.Z));
	print("[alarm] placed at " .. tostring(pos) .. " radius " .. tostring(CFG.radius));
	return "alarm placed - only you can see the marker";
end

shared.al.target = function(who)
	A.target = who or "Bashoxia";
	return "watching for " .. tostring(A.target);
end

shared.al.clear = function()
	A.pos = nil;
	for _, pl in pairs(players.get_all()) do
		pcall(pl.fire_client, "almoff");
	end
	return "alarm cleared and marker removed";
end

shared.al.self = function()
	A.target = sharedvars.vip_owner;
	return "now watching YOU - walk out of range and back in to trigger it";
end

shared.al.set = function(k, v)
	if CFG[k] == nil then
		return "unknown key";
	end
	if type(CFG[k]) == "boolean" then
		CFG[k] = (tostring(v) == "true");
	else
		CFG[k] = tonumber(v) or v;
	end
	return k .. " = " .. tostring(CFG[k]);
end

if A.conn then
	pcall(function()
		A.conn:Disconnect();
	end);
end

A.conn = time.heartbeat("alarm_test", function(dt)
	if not A.pos then
		return;
	end
	if A.ready > 0 then
		A.ready = A.ready - dt;
	end

	local target = A.target or "Bashoxia";
	local tp = players.get(target);
	if not tp then
		return;
	end
	local ok, hpos = pcall(tp.get_position);
	if not ok or not hpos then
		return;
	end
	local dist = (hpos - A.pos).Magnitude;

	if A.firing > 0 then
		A.firing = A.firing - dt;
		A.pingt = A.pingt - dt;
		if A.pingt <= 0 then
			A.pingt = 1 / CFG.ping_hz;
			local mk = string.format("mark:%.1f,%.1f,%.1f:0.3", hpos.X, hpos.Y, hpos.Z);
			for _, p in pairs(players.get_all()) do
				if CFG.ping_self or p.name ~= target then
					pcall(p.fire_client, mk);
				end
			end
		end
		return;
	end

	if dist <= CFG.radius and A.ready <= 0 then
		local clear, blocker = los_clear(A.pos, hpos);
		if clear then
			trigger(hpos);
		else
			print("[alarm] in range " .. tostring(math.floor(dist)) .. " but blocked by " .. tostring(blocker));
		end
	end
end);

print("[alarm] ready: shared.al.place() / .target('Name') / .clear() / .set('radius',40)");
