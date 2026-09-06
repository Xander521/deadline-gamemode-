local A = {};
local ctx = nil;

local alarms = {};
local crate = { pos = nil, left = 0, tick = 0, useat = 0, part = nil };

local CFG = {
	sound = "512957450",
	radius = 20,
	uses = 2,
	max_alarms = 3,
	spacing = 25,
	cooldown = 20,
	ping_seconds = 4,
	crate_charges = 3,
	crate_radius = 9,
	crate_shells = 10,
	crate_mag_step = 1,
};

A.config = CFG;

local function register_commands()
	local gm = shared.hidden_gamemode;
	if not gm or not gm.commands then
		return false;
	end
	local cmds = gm.commands;

	cmds.hdim = function(arg)
		local f = tonumber(arg) or 0.1;
		local n = A.dim(f);
		return "dimmed " .. tostring(n) .. " lights to " .. tostring(f * 100) .. "%";
	end

	cmds.hmap = function(arg)
		if not arg then
			return "usage: hmap('comm_ballistic')";
		end
		local ok, err = pcall(map.set_map, tostring(arg));
		print("[abil] set_map('" .. tostring(arg) .. "') ok=" .. tostring(ok) .. " err=" .. tostring(err));
		return "set_map ok=" .. tostring(ok);
	end

	cmds.hmaps2 = function()
		local ok, list = pcall(map.get_maps);
		if not ok or type(list) ~= "table" then
			return "get_maps failed";
		end
		local n = 0;
		for k, v in pairs(list) do
			n = n + 1;
			print("   key=" .. tostring(k) .. "   value=" .. string.sub(tostring(v), 1, 40));
		end
		return tostring(n) .. " maps printed";
	end

	cmds.hburst = function(arg)
		local secs = tonumber(arg) or 3;
		local gm2 = shared.hidden_gamemode;
		local st = gm2 and gm2.state;
		if not st or not st.hunter then
			return "no hunter";
		end
		local p = ctx.find_player(st.hunter);
		if not p then
			return "hunter not found";
		end
		A.burst_until = tick() + secs;
		A.burst_target = st.hunter;
		pcall(p.set_speed, A.burst_speed);
		pcall(p.fire_client, "note:BURST");
		return "burst " .. tostring(secs) .. "s at speed " .. tostring(A.burst_speed);
	end

	print("[abil] registered hdim / hmap / hmaps2 / hburst");
	return true;
end

A.burst_speed = 120;
A.burst_seconds = 3;
A.burst_until = 0;
A.burst_target = nil;

A.start_burst = function(name)
	local p = ctx.find_player(name);
	if not p then
		return;
	end
	A.burst_until = tick() + A.burst_seconds;
	A.burst_target = name;
	pcall(p.set_speed, A.burst_speed);
	pcall(p.fire_client, "note:BURST");
end

A.init = function(c)
	ctx = c;
	register_commands();
	return A;
end

local function kill_crate_part()
	if crate.part then
		pcall(function()
			crate.part.destroy();
		end);
		crate.part = nil;
	end
end

A.reset = function()
	alarms = {};
	kill_crate_part();
	crate.pos = nil;
	crate.left = 0;
	for _, pl in pairs(ctx.all_players()) do
		pcall(pl.fire_client, "almoff");
		pcall(pl.fire_client, "crateoff");
	end
end

local function los(from, to)
	local dir = to - from;
	local dist = dir.Magnitude;
	if dist < 1 then
		return true;
	end
	local params = query.create_raycast_params();
	pcall(function()
		params.filter_type(Enum.RaycastFilterType.Exclude);
	end);
	local layer = 0;
	while layer < 5 do
		layer = layer + 1;
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
				return false;
			end
			return true;
		end
		pcall(function()
			params.add_to_filter({ inst });
		end);
	end
	return true;
end

A.place_alarm = function(name, enforce)
	local p = ctx.find_player(name);
	if not p then
		return "no player";
	end
	if enforce and ctx.class_of(name) ~= "hunter" then
		pcall(p.fire_client, "note:only the HUNTER class can place alarms");
		return "not hunter";
	end
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return "no position";
	end
	local live, mine = 0, 0;
	for _, a in ipairs(alarms) do
		if not a.dead then
			live = live + 1;
			if a.owner == name then
				mine = mine + 1;
			end
			if (a.pos - pos).Magnitude < CFG.spacing then
				pcall(p.fire_client, "note:too close to another alarm");
				return "too close";
			end
		end
	end
	if live >= CFG.max_alarms then
		pcall(p.fire_client, "note:alarm limit reached");
		return "limit";
	end
	if enforce and mine >= 1 then
		pcall(p.fire_client, "note:you already placed an alarm");
		return "already placed";
	end
	table.insert(alarms, { pos = pos, owner = name, uses = CFG.uses, ready = 0, ping = 0, pingt = 0, dead = false });
	pcall(p.fire_client, string.format("alm:%.1f,%.1f,%.1f", pos.X, pos.Y, pos.Z));
	return "alarm placed";
end

A.place_crate = function(name, enforce)
	local p = ctx.find_player(name);
	if not p then
		return "no player";
	end
	if enforce and ctx.class_of(name) ~= "support" then
		pcall(p.fire_client, "note:only SUPPORT can place a crate");
		return "not support";
	end
	if crate.pos and crate.left > 0 then
		pcall(p.fire_client, "note:a crate is already out");
		return "already out";
	end
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return "no position";
	end
	kill_crate_part();
	local cok, part = pcall(create_instance, "Part");
	if cok and part then
		local bad = "";
		local function sp(k, f)
			local o = pcall(f);
			if not o then
				bad = bad .. k .. " ";
			end
		end
		sp("Size", function()
			part.Size = Vector3.new(3, 2, 2);
		end);
		sp("Name", function()
			part.Name = "ammo_crate";
		end);
		sp("Color", function()
			part.Color = Color3.fromRGB(75, 85, 60);
		end);
		sp("Material", function()
			part.Material = Enum.Material.Metal;
		end);
		sp("Position", function()
			part.Position = pos + Vector3.new(0, 2, 0);
		end);
		sp("Anchored", function()
			part.Anchored = false;
		end);
		sp("Density", function()
			part.CustomPhysicalProperties = PhysicalProperties.new(0.33, 0.5, 0.3);
		end);
		sp("Parent", function()
			part.Parent = get_map_root();
		end);
		sp("NetOwner", function()
			part.set_network_owner(nil);
		end);
		crate.part = part;
		print("[abil] crate part created" .. (bad ~= "" and (" FAILED: " .. bad) or ""));
	else
		print("[abil] could not create the crate part");
	end
	crate.pos = pos;
	crate.left = CFG.crate_charges;
	crate.tick = 0;
	for _, pl in pairs(ctx.all_players()) do
		pcall(pl.fire_client, string.format("crate:%.1f,%.1f,%.1f:%d:%d", pos.X, pos.Y, pos.Z, CFG.crate_radius, CFG.crate_charges));
	end
	return "crate placed";
end

A.use_crate = function(name)
	local p = ctx.find_player(name);
	if not p then
		print("[abil] crate use: no player " .. tostring(name));
		return;
	end
	if not crate.pos or crate.left <= 0 then
		print("[abil] crate use: no crate or empty");
		return;
	end
	if tick() - crate.useat < 1 then
		return;
	end
	local ok, pos = pcall(p.get_position);
	if ok and pos and (pos - crate.pos).Magnitude > CFG.crate_radius then
		print("[abil] crate use: too far (" .. tostring(math.floor((pos - crate.pos).Magnitude)) .. ")");
		return;
	end
	crate.useat = tick();
	crate.left = crate.left - 1;
	local wok, w = pcall(p.get_weapon_data_from_character, "primary");
	if wok and type(w) == "table" and w.client_data and w.client_data.name then
		pcall(function()
			sharedvars.plr_spare_rounds = CFG.crate_shells;
		end);
		local bok, before = pcall(function()
			return sharedvars.plr_magazines;
		end);
		if bok and type(before) == "number" then
			pcall(function()
				sharedvars.plr_magazines = before + CFG.crate_mag_step;
			end);
		end
		pcall(p.set_weapon, "primary", w.client_data.name, w.client_data.setup);
	end
	pcall(p.fire_client, "note:RESUPPLIED  (" .. tostring(crate.left) .. " left)");
	if crate.pos and crate.left > 0 then
		local upd = string.format("cratepos:%.1f,%.1f,%.1f:%d", crate.pos.X, crate.pos.Y, crate.pos.Z, crate.left);
		for _, pl in pairs(ctx.all_players()) do
			pcall(pl.fire_client, upd);
		end
	end
	if crate.left <= 0 then
		kill_crate_part();
		crate.pos = nil;
		for _, pl in pairs(ctx.all_players()) do
			pcall(pl.fire_client, "crateoff");
		end
	end
end

A.tick = function(dt, hunter_pos, hunter_name)
	if A.burst_until > 0 then
		if tick() < A.burst_until then
			local bp = ctx.find_player(A.burst_target);
			if bp then
				pcall(bp.set_speed, A.burst_speed);
			end
		else
			A.burst_until = 0;
			A.burst_target = nil;
		end
	end
	for _, al in ipairs(alarms) do
		if not al.dead then
			if al.ready > 0 then
				al.ready = al.ready - dt;
			end
			if al.ping > 0 then
				al.ping = al.ping - dt;
				al.pingt = al.pingt - dt;
				if al.pingt <= 0 and hunter_pos then
					al.pingt = 0.2;
					local mk = string.format("mark:%.1f,%.1f,%.1f:0.3", hunter_pos.X, hunter_pos.Y, hunter_pos.Z);
					for _, pl in pairs(ctx.all_players()) do
						if pl.name ~= hunter_name then
							pcall(pl.fire_client, mk);
						end
					end
				end
				if al.ping <= 0 and al.uses <= 0 then
					al.dead = true;
					local op = ctx.find_player(al.owner);
					if op then
						pcall(op.fire_client, "almoff");
					end
				end
			elseif al.uses > 0 and al.ready <= 0 and hunter_pos then
				if (hunter_pos - al.pos).Magnitude <= CFG.radius and los(al.pos, hunter_pos) then
					al.uses = al.uses - 1;
					al.ready = CFG.cooldown;
					al.ping = CFG.ping_seconds;
					al.pingt = 0;
					local payload = string.format("sfx:%s:%.1f,%.1f,%.1f", CFG.sound, al.pos.X, al.pos.Y, al.pos.Z);
					for _, pl in pairs(ctx.all_players()) do
						pcall(pl.fire_client, payload);
					end
					if ctx.flare then
						ctx.flare(al.pos, 4);
					end
					print("[abil] alarm triggered, uses left " .. tostring(al.uses));
				end
			end
		end
	end

	if crate.pos and crate.left > 0 then
		crate.tick = crate.tick - dt;
		if crate.tick <= 0 then
			crate.tick = 0.5;
			if crate.part then
				local pok, ppos = pcall(function()
					return crate.part.Position;
				end);
				if pok and ppos then
					crate.pos = ppos;
				end
			end
			local msg = string.format("cratepos:%.1f,%.1f,%.1f:%d", crate.pos.X, crate.pos.Y, crate.pos.Z, crate.left);
			for _, pl in pairs(ctx.all_players()) do
				pcall(pl.fire_client, msg);
			end
		end
	end
end

A.status = function()
	local live = 0;
	for _, a in ipairs(alarms) do
		if not a.dead then
			live = live + 1;
		end
	end
	return "alarms=" .. tostring(live) .. " crate=" .. tostring(crate.pos ~= nil) .. " charges=" .. tostring(crate.left);
end

local LIGHT_ORIG = {};

A.dim = function(factor)
	local f = tonumber(factor) or 0.1;
	local root = get_map_root();
	if not root then
		return 0;
	end
	local ok, all = pcall(function()
		return root.get_descendants();
	end);
	if not ok or type(all) ~= "table" then
		return 0;
	end
	local n = 0;
	for _, inst in ipairs(all) do
		local kinds = { "PointLight", "SpotLight", "SurfaceLight" };
		for _, k in ipairs(kinds) do
			local is = false;
			pcall(function()
				is = inst.is_a(k);
			end);
			if is then
				local bok, b = pcall(function()
					return inst.Brightness;
				end);
				if bok and type(b) == "number" then
					if LIGHT_ORIG[inst] == nil then
						LIGHT_ORIG[inst] = b;
					end
					if pcall(function()
						inst.Brightness = LIGHT_ORIG[inst] * f;
					end) then
						n = n + 1;
					end
				end
			end
		end
	end
	print("[abil] dimmed " .. tostring(n) .. " lights to " .. tostring(f * 100) .. "%");
	return n;
end

return A;
