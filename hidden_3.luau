local CFG = {
	map_name = "nuristan",
	map_time = 1200,
	lighting_preset = "darkworld",
	round_seconds = 360,
	intermission_seconds = 12,
	min_players = 2,
	hunter_speed = 100,
	hunter_jump = 1.6,
	hunter_health = 130,
	hunter_anim_speed = 1.5,
	hunter_heal_per_kill = 35,
	hunter_weapon = "auto",
	survivor_speed = 0,
	survivor_health = 100,
	survivor_lastman_speed = 0,
	sweep_seconds = 40,
	sweep_lastman_seconds = 12,
	flare_lifetime = 6,
	teamkill = false,
};

if not is_private_server() and not is_studio() then
	warn("[hidden] VIP server or studio only");
	return;
end

if shared.hidden_gamemode and shared.hidden_gamemode.cleanup then
	pcall(shared.hidden_gamemode.cleanup);
	print("[hidden] unloaded previous instance");
end

local function try(fn, ...)
	if type(fn) ~= "function" then
		return false, nil;
	end
	local ok, res = pcall(fn, ...);
	if not ok then
		warn("[hidden] call failed: " .. tostring(res));
	end
	return ok, res;
end

local function all_players()
	if players and players.get_all then
		local ok, res = pcall(players.get_all);
		if ok and type(res) == "table" then
			return res;
		end
	end
	if get_players then
		local ok, res = pcall(get_players);
		if ok and type(res) == "table" then
			return res;
		end
	end
	return {};
end

local function find_player(name)
	if not name then
		return nil;
	end
	if players and players.get then
		local ok, res = pcall(players.get, name);
		if ok and res then
			return res;
		end
	end
	if get_player then
		local ok, res = pcall(get_player, name);
		if ok and res then
			return res;
		end
	end
	for _, p in pairs(all_players()) do
		if p.name == name then
			return p;
		end
	end
	return nil;
end

local warned_vars = {};

local function set_var(name, value)
	if sharedvars_descriptions and sharedvars_descriptions[name] == nil then
		if not warned_vars[name] then
			warned_vars[name] = true;
			warn("[hidden] no such sharedvar, skipping: " .. name);
		end
		return false;
	end
	local ok = pcall(function()
		sharedvars[name] = value;
	end);
	return ok;
end

local function announce(text, color)
	pcall(chat.send_announcement, text, color or Color3.fromRGB(220, 60, 60));
end

local function notify(text)
	if chat.send_ingame_notification then
		pcall(chat.send_ingame_notification, text);
	else
		announce(text);
	end
end

local function set_spawn_reason(text)
	if chat and chat.set_spawning_disabled_reason then
		pcall(chat.set_spawning_disabled_reason, text);
	elseif set_spawning_disabled_reason then
		pcall(set_spawning_disabled_reason, text);
	end
end

local function weapon_list()
	local out = {};
	if config and config.weapon_names then
		for _, n in pairs(config.weapon_names) do
			table.insert(out, n);
		end
	end
	return out;
end

local function pick_hunter_weapon()
	local names = weapon_list();
	if #names == 0 then
		return nil;
	end
	local melee = { "knife", "bayonet", "machete", "karambit", "blade", "melee", "hatchet", "axe" };
	for _, keyword in ipairs(melee) do
		for _, n in ipairs(names) do
			if string.find(string.lower(n), keyword) then
				return n;
			end
		end
	end
	local backup = { "spas", "m1014", "680", "saiga", "mp5", "vector", "glock", "m9", "deagle" };
	for _, keyword in ipairs(backup) do
		for _, n in ipairs(names) do
			if string.find(string.lower(n), keyword) then
				return n;
			end
		end
	end
	return nil;
end

local RESOLVED_WEAPON = nil;

local state = {
	running = false,
	phase = "idle",
	hunter = nil,
	dead = {},
	been_hunter = {},
	next_hunter = nil,
	timer = 0,
	sweep_timer = 0,
	positions = {},
	round_number = 0,
};

local connections = {};
local heartbeat_conn = nil;
local accumulator = 0;

local function is_hunter(name)
	return state.hunter ~= nil and name == state.hunter;
end

local function arm_hunter(p)
	if not RESOLVED_WEAPON then
		warn("[hidden] no hunter weapon resolved, run -hguns then -hset hunter_weapon <name>");
		return false;
	end
	local ok = pcall(p.set_weapon, "melee", RESOLVED_WEAPON, "[]");
	if ok then
		pcall(p.equip_weapon, "melee", true);
		return true;
	end
	ok = pcall(p.set_weapon, "primary", RESOLVED_WEAPON, "[]");
	if ok then
		pcall(p.equip_weapon, "primary", true);
	end
	return ok;
end

local function apply_hunter(p)
	try(p.set_team, "attacker");
	if CFG.hunter_speed > 0 then
		try(p.set_speed, CFG.hunter_speed);
	end
	try(p.set_jump_multiplier, CFG.hunter_jump);
	try(p.set_health, CFG.hunter_health);
	try(p.set_animation_speed, CFG.hunter_anim_speed);
	try(p.set_camera_mode, "Default");
	pcall(p.set_weapon, "primary", "nothing");
	pcall(p.set_weapon, "secondary", "nothing");
	pcall(p.set_weapon, "throwable1", "nothing");
	pcall(p.set_weapon, "throwable2", "nothing");
	arm_hunter(p);
end

local function apply_survivor(p)
	try(p.set_team, "defender");
	if CFG.survivor_speed > 0 then
		try(p.set_speed, CFG.survivor_speed);
	end
	try(p.set_jump_multiplier, 1);
	try(p.set_health, CFG.survivor_health);
	try(p.set_animation_speed, 1);
	try(p.set_camera_mode, "Default");
	try(p.refill_ammo);
end

local function apply_role(name)
	local p = find_player(name);
	if not p then
		return;
	end
	if is_hunter(name) then
		apply_hunter(p);
	else
		apply_survivor(p);
	end
end

local function freeze_dead(p)
	try(p.set_camera_mode, "Freecam");
	try(p.set_speed, 0);
end

local function report_matching_vars(keyword)
	if not sharedvars_descriptions then
		return 0;
	end
	local count = 0;
	for name in pairs(sharedvars_descriptions) do
		if string.find(string.lower(name), keyword) then
			print("   " .. name .. " = " .. tostring(sharedvars[name]));
			count = count + 1;
		end
	end
	return count;
end

local function setup_world()
	try(map.set_map, CFG.map_name);
	try(map.set_time, CFG.map_time);
	if config and config.lighting_presets and not config.lighting_presets[CFG.lighting_preset] then
		warn("[hidden] preset not found: " .. tostring(CFG.lighting_preset));
		print("[hidden] available presets:");
		for name in pairs(config.lighting_presets) do
			print("   " .. name);
		end
	end
	try(map.set_preset, CFG.lighting_preset);
	print("[hidden] fog-related sharedvars:");
	if report_matching_vars("fog") == 0 then
		print("   none found, run your -fog command manually after -hstart");
	end
	print("[hidden] night-vision sharedvars:");
	if report_matching_vars("nv") == 0 then
		print("   none found");
	end
	set_var("plr_pvp", true);
	set_var("plr_team_kill", CFG.teamkill);
	set_var("chat_tips_enabled", false);
	pcall(chat.set_join_message, "THE HIDDEN - one hunter, no lights, one life.");
end

local function drop_flare(position, lifetime, color)
	if not position then
		return;
	end
	local ok, part = pcall(create_instance, "Part");
	if not ok or not part then
		return;
	end
	pcall(function()
		part.Name = "hidden_flare";
		part.Anchored = true;
		part.CanCollide = false;
		part.CastShadow = false;
		part.Size = Vector3.new(0.8, 0.8, 0.8);
		part.Transparency = 0.3;
		part.Material = Enum.Material.Neon;
		part.Color = color or Color3.fromRGB(255, 90, 40);
		part.Position = position + Vector3.new(0, 2, 0);
		part.Parent = get_map_root();
	end);
	local lok, light = pcall(create_instance, "PointLight");
	if lok and light then
		pcall(function()
			light.Color = color or Color3.fromRGB(255, 90, 40);
			light.Brightness = 4;
			light.Range = 30;
			light.Parent = part;
		end);
	end
	time.delay(lifetime or CFG.flare_lifetime, function()
		pcall(function()
			part.destroy();
		end);
	end);
end

local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" };

local function bearing_from(origin, target)
	local delta = target - origin;
	local angle = math.deg(math.atan2(delta.X, -delta.Z));
	if angle < 0 then
		angle = angle + 360;
	end
	local index = math.floor((angle + 22.5) / 45) % 8 + 1;
	return COMPASS[index], delta.Magnitude;
end

local function alive_survivors()
	local out = {};
	for _, p in pairs(all_players()) do
		if not is_hunter(p.name) and not state.dead[p.name] then
			local ok, alive = pcall(p.is_alive);
			if ok and alive then
				table.insert(out, p);
			end
		end
	end
	return out;
end

local function radar_sweep()
	local hunter_pos = state.positions[state.hunter];
	local survivors = alive_survivors();
	if not hunter_pos or #survivors == 0 then
		return;
	end
	local sum = Vector3.new(0, 0, 0);
	local count = 0;
	for _, p in ipairs(survivors) do
		local pos = state.positions[p.name];
		if pos then
			sum = sum + pos;
			count = count + 1;
		end
	end
	if count == 0 then
		return;
	end
	local dir, dist = bearing_from(sum / count, hunter_pos);
	notify(string.format("SWEEP - contact bearing %s, %dm out", dir, math.floor(dist / 3)));
	if #survivors == 1 then
		drop_flare(hunter_pos, 3, Color3.fromRGB(80, 200, 255));
	end
end

local function choose_hunter()
	local candidates = {};
	for _, p in pairs(all_players()) do
		table.insert(candidates, p.name);
	end
	if #candidates == 0 then
		return nil;
	end
	if state.next_hunter and find_player(state.next_hunter) then
		local pick = state.next_hunter;
		state.next_hunter = nil;
		return pick;
	end
	local fresh = {};
	for _, name in ipairs(candidates) do
		if not state.been_hunter[name] then
			table.insert(fresh, name);
		end
	end
	if #fresh == 0 then
		state.been_hunter = {};
		fresh = candidates;
	end
	return fresh[math.random(1, #fresh)];
end

local end_round;

local function start_round()
	local roster = all_players();
	if #roster < CFG.min_players then
		state.phase = "idle";
		state.timer = 5;
		return;
	end
	state.round_number = state.round_number + 1;
	state.hunter = choose_hunter();
	state.been_hunter[state.hunter] = true;
	state.dead = {};
	state.positions = {};
	state.timer = CFG.round_seconds;
	state.sweep_timer = CFG.sweep_seconds;
	state.phase = "live";
	set_var("sv_spawning_enabled", true);
	set_spawn_reason("");
	for _, p in pairs(roster) do
		task.spawn(function()
			try(p.set_camera_mode, "Default");
			try(p.respawn);
		end);
	end
	time.delay(1.5, function()
		for _, p in pairs(all_players()) do
			apply_role(p.name);
		end
	end);
	announce(string.format("ROUND %d - the Hidden is among you.", state.round_number), Color3.fromRGB(200, 40, 40));
	notify("Lights out. One life. Kill the Hidden or survive the clock.");
end

end_round = function(reason, color)
	if state.phase ~= "live" then
		return;
	end
	state.phase = "intermission";
	state.timer = CFG.intermission_seconds;
	announce(reason, color or Color3.fromRGB(240, 200, 60));
	announce("The Hidden was " .. tostring(state.hunter), Color3.fromRGB(180, 180, 180));
	set_var("sv_spawning_enabled", false);
	set_spawn_reason("Intermission - next round starting shortly");
	for _, p in pairs(all_players()) do
		try(p.set_camera_mode, "Default");
	end
end

local function refresh_positions()
	for _, p in pairs(all_players()) do
		local ok, pos = pcall(p.get_position);
		if ok and pos then
			state.positions[p.name] = pos;
		end
	end
end

local function tick(dt)
	if not state.running then
		return;
	end
	refresh_positions();
	state.timer = state.timer - dt;
	if state.phase == "idle" or state.phase == "intermission" then
		if state.timer <= 0 then
			start_round();
		end
		return;
	end
	local survivors = alive_survivors();
	local hunter_player = find_player(state.hunter);
	local hunter_alive = false;
	if hunter_player then
		local ok, alive = pcall(hunter_player.is_alive);
		hunter_alive = ok and alive;
	end
	if #survivors == 1 and CFG.survivor_lastman_speed > 0 then
		try(survivors[1].set_speed, CFG.survivor_lastman_speed);
	end
	state.sweep_timer = state.sweep_timer - dt;
	if state.sweep_timer <= 0 then
		if #survivors == 1 then
			state.sweep_timer = CFG.sweep_lastman_seconds;
		else
			state.sweep_timer = CFG.sweep_seconds;
		end
		radar_sweep();
	end
	if state.timer <= 30 and state.timer + dt > 30 then
		notify("30 seconds. Hold out.");
	end
	if not hunter_alive and state.dead[state.hunter] then
		end_round("SURVIVORS WIN - the Hidden is down.", Color3.fromRGB(80, 200, 120));
	elseif #survivors == 0 then
		end_round("THE HIDDEN WINS - everyone is dead.", Color3.fromRGB(200, 40, 40));
	elseif state.timer <= 0 then
		end_round("SURVIVORS WIN - they made it to dawn.", Color3.fromRGB(80, 200, 120));
	end
end

local function parse_death(...)
	local args = { ... };
	local name = nil;
	if type(args[1]) == "string" then
		name = args[1];
	end
	local position = nil;
	local killer = nil;
	for i = 2, #args do
		local v = args[i];
		if typeof and typeof(v) == "Vector3" then
			position = v;
		elseif type(v) == "table" then
			killer = v;
		end
	end
	return name, position, killer;
end

local function killer_name(killer_data)
	if type(killer_data) ~= "table" then
		return nil;
	end
	for _, key in ipairs({ "name", "killer", "killer_name", "player", "source" }) do
		local v = killer_data[key];
		if type(v) == "string" and find_player(v) then
			return v;
		end
	end
	return nil;
end

table.insert(
	connections,
	on_player_died:Connect(function(...)
		if not state.running or state.phase ~= "live" then
			return;
		end
		local name, position, killer_data = parse_death(...);
		if not name then
			return;
		end
		state.dead[name] = true;
		position = position or state.positions[name];
		local p = find_player(name);
		if p then
			freeze_dead(p);
		end
		if is_hunter(name) then
			local by = killer_name(killer_data);
			if by and by ~= name then
				state.next_hunter = by;
				announce(by .. " killed the Hidden.", Color3.fromRGB(80, 200, 120));
			end
			return;
		end
		if position then
			drop_flare(position, CFG.flare_lifetime);
		end
		local remaining = #alive_survivors();
		if remaining == 1 then
			notify("One survivor left.");
		elseif remaining > 1 then
			notify(string.format("%d survivors remain.", remaining));
		end
		local hunter_player = find_player(state.hunter);
		if hunter_player and CFG.hunter_heal_per_kill > 0 then
			local ok, hp = pcall(hunter_player.get_health);
			if ok and hp then
				local healed = hp + CFG.hunter_heal_per_kill;
				if healed > CFG.hunter_health then
					healed = CFG.hunter_health;
				end
				try(hunter_player.set_health, healed);
			end
		end
	end)
);

table.insert(
	connections,
	on_player_spawned:Connect(function(name)
		if not state.running then
			return;
		end
		time.delay(0.3, function()
			if state.phase == "live" then
				apply_role(name);
			end
		end);
	end)
);

table.insert(
	connections,
	on_player_joined:Connect(function(name)
		if not state.running then
			return;
		end
		if state.phase == "live" then
			state.dead[name] = true;
			time.delay(2, function()
				local p = find_player(name);
				if p then
					freeze_dead(p);
				end
			end);
		end
	end)
);

table.insert(
	connections,
	on_player_left:Connect(function(name)
		state.dead[name] = nil;
		state.positions[name] = nil;
		if state.running and state.phase == "live" and is_hunter(name) then
			end_round("The Hidden disconnected. Round void.", Color3.fromRGB(180, 180, 180));
		end
	end)
);

local commands = {};

commands.hstart = function()
	if state.running then
		return "already running";
	end
	RESOLVED_WEAPON = CFG.hunter_weapon;
	if RESOLVED_WEAPON == "auto" then
		RESOLVED_WEAPON = pick_hunter_weapon();
	end
	print("[hidden] hunter weapon: " .. tostring(RESOLVED_WEAPON));
	state.running = true;
	setup_world();
	state.phase = "intermission";
	state.timer = 8;
	return "starting on " .. CFG.map_name;
end

commands.hstop = function()
	state.running = false;
	state.phase = "idle";
	state.hunter = nil;
	set_var("sv_spawning_enabled", true);
	set_spawn_reason("");
	for _, p in pairs(all_players()) do
		try(p.set_camera_mode, "Default");
		try(p.set_jump_multiplier, 1);
		try(p.set_animation_speed, 1);
	end
	return "stopped";
end

commands.hnext = function()
	if state.phase == "live" then
		end_round("Round ended by host.", Color3.fromRGB(180, 180, 180));
		return "round ended";
	end
	return "no live round";
end

commands.hhunter = function(arg)
	local name = nil;
	if arg then
		name = arg:match("^%s*(.-)%s*$");
	end
	if not name or name == "" then
		return "usage: -hhunter <name>";
	end
	if not find_player(name) then
		return "no such player: " .. name;
	end
	state.next_hunter = name;
	return name .. " is the Hidden next round";
end

commands.hstatus = function()
	return string.format(
		"phase=%s round=%d hunter=%s timer=%ds survivors=%d weapon=%s",
		state.phase,
		state.round_number,
		tostring(state.hunter),
		math.max(0, math.floor(state.timer)),
		#alive_survivors(),
		tostring(RESOLVED_WEAPON)
	);
end

commands.hguns = function()
	local names = weapon_list();
	if #names == 0 then
		return "config.weapon_names unavailable";
	end
	print("[hidden] weapons in this build:");
	for _, n in ipairs(names) do
		print("   " .. n);
	end
	return string.format("%d weapons printed to server console", #names);
end

commands.hset = function(arg)
	local key = nil;
	local value = nil;
	if arg then
		key, value = arg:match("^%s*(%S+)%s+(.+)%s*$");
	end
	if not key then
		return "usage: -hset <key> <value>";
	end
	if CFG[key] == nil then
		return "unknown key: " .. key;
	end
	local current = CFG[key];
	if type(current) == "number" then
		local n = tonumber(value);
		if not n then
			return "expected a number";
		end
		CFG[key] = n;
	elseif type(current) == "boolean" then
		CFG[key] = (value == "true" or value == "1");
	else
		CFG[key] = value;
		if key == "hunter_weapon" then
			RESOLVED_WEAPON = value;
		end
	end
	return key .. " = " .. tostring(CFG[key]);
end

commands.hhelp = function()
	return "-hstart -hstop -hnext -hhunter <name> -hstatus -hguns -hset <key> <value>";
end

table.insert(
	connections,
	chat.player_chatted:Connect(function(sender, channel, content)
		if content:sub(1, 1) ~= "-" then
			return;
		end
		local word = content:split(" ")[1]:sub(2);
		local handler = commands[word];
		if not handler then
			return;
		end
		local owner = sharedvars.vip_owner;
		if owner and sender ~= owner and not is_studio() then
			announce("host only.");
			return;
		end
		local rest = content:sub(#word + 3, -1);
		local ok, result = pcall(handler, rest);
		announce(ok and tostring(result) or ("error: " .. tostring(result)));
	end)
);

heartbeat_conn = time.heartbeat("hidden_gamemode", function(dt)
	accumulator = accumulator + dt;
	if accumulator < 0.2 then
		return;
	end
	local step = accumulator;
	accumulator = 0;
	local ok, err = pcall(tick, step);
	if not ok then
		warn("[hidden] tick error: " .. tostring(err));
	end
end);

local function cleanup()
	state.running = false;
	if heartbeat_conn then
		pcall(function()
			heartbeat_conn:Disconnect();
		end);
	end
	for _, c in pairs(connections) do
		pcall(function()
			c:Disconnect();
		end);
	end
	connections = {};
	shared.hidden_gamemode = nil;
end

shared.hidden_gamemode = { cleanup = cleanup, state = state, config = CFG };

pcall(gamemode.force_set_gamemode, "none");

print("[hidden] loaded. map=" .. CFG.map_name .. " time=" .. tostring(CFG.map_time) .. " preset=" .. CFG.lighting_preset);
print("[hidden] type -hstart in chat to begin, -hhelp for commands");
print("[hidden] host is: " .. tostring(sharedvars.vip_owner));
