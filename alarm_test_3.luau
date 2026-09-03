local CFG = {
	sound = "512957450",
	radius = 20,
	duration = 2,
	repeats = 2,
	ping_seconds = 4,
	ping_hz = 5,
	uses = 2,
	max_alarms = 3,
	min_spacing = 25,
	require_los = true,
	cooldown = 20,
	ping_self = true,
};

local ALARMS = {};
local TARGET = nil;

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

local function fire(al, hunter_pos)
	al.uses = al.uses - 1;
	al.ready = CFG.cooldown;
	al.ping = CFG.ping_seconds;
	al.pingt = 0;

	local payload = string.format("sfx:%s:%.1f,%.1f,%.1f", CFG.sound, al.pos.X, al.pos.Y, al.pos.Z);
	for r = 1, CFG.repeats do
		time.delay((r - 1) * CFG.duration, function()
			for _, p in pairs(players.get_all()) do
				pcall(p.fire_client, payload);
			end
		end);
	end
	light_burst(al.pos, CFG.duration * CFG.repeats);
	print("[alarm] TRIGGERED, uses left " .. tostring(al.uses));

	if al.uses <= 0 then
		time.delay(CFG.ping_seconds + 0.5, function()
			if al.owner then
				local op = players.get(al.owner);
				if op then
					pcall(op.fire_client, "almoff");
				end
			end
			al.dead = true;
			print("[alarm] alarm spent and removed");
		end);
	end
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
	local live = 0;
	for _, a in ipairs(ALARMS) do
		if not a.dead then
			live = live + 1;
			if (a.pos - pos).Magnitude < CFG.min_spacing then
				return "too close to another alarm (" .. tostring(math.floor((a.pos - pos).Magnitude)) .. " studs, need " .. tostring(CFG.min_spacing) .. ")";
			end
		end
	end
	if live >= CFG.max_alarms then
		return "alarm limit reached (" .. tostring(CFG.max_alarms) .. ")";
	end
	table.insert(ALARMS, { pos = pos, owner = sharedvars.vip_owner, uses = CFG.uses, ready = 0, ping = 0, pingt = 0, dead = false });
	pcall(p.fire_client, string.format("alm:%.1f,%.1f,%.1f", pos.X, pos.Y, pos.Z));
	return "alarm placed (" .. tostring(live + 1) .. "/" .. tostring(CFG.max_alarms) .. ", " .. tostring(CFG.uses) .. " uses)";
end

shared.al.self = function()
	TARGET = sharedvars.vip_owner;
	return "watching YOU";
end

shared.al.target = function(who)
	TARGET = who;
	return "watching " .. tostring(who);
end

shared.al.clear = function()
	ALARMS = {};
	for _, p in pairs(players.get_all()) do
		pcall(p.fire_client, "almoff");
	end
	return "all alarms cleared";
end

shared.al.status = function()
	local live = 0;
	for _, a in ipairs(ALARMS) do
		if not a.dead then
			live = live + 1;
		end
	end
	return "alarms live=" .. tostring(live) .. " target=" .. tostring(TARGET);
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

time.heartbeat("alarm_test3", function(dt)
	local target = TARGET;
	if not target then
		return;
	end
	local tp = players.get(target);
	if not tp then
		return;
	end
	local ok, hpos = pcall(tp.get_position);
	if not ok or not hpos then
		return;
	end

	for _, al in ipairs(ALARMS) do
		if not al.dead then
			if al.ready > 0 then
				al.ready = al.ready - dt;
			end
			if al.ping > 0 then
				al.ping = al.ping - dt;
				al.pingt = al.pingt - dt;
				if al.pingt <= 0 then
					al.pingt = 1 / CFG.ping_hz;
					local mk = string.format("mark:%.1f,%.1f,%.1f:0.3", hpos.X, hpos.Y, hpos.Z);
					for _, p in pairs(players.get_all()) do
						if CFG.ping_self or p.name ~= target then
							pcall(p.fire_client, mk);
						end
					end
				end
			elseif al.uses > 0 and al.ready <= 0 then
				local d = (hpos - al.pos).Magnitude;
				if d <= CFG.radius then
					local clear, blocker = los_clear(al.pos, hpos);
					if clear then
						fire(al, hpos);
					else
						print("[alarm] in range but blocked by " .. tostring(blocker));
					end
				end
			end
		end
	end
end);

print("[alarm] ready: .place() / .self() / .target('Name') / .status() / .clear() / .set('radius',20)");
