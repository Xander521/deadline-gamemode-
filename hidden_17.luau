local CFG = {
	map_name = "nuristan_voxel",
	map_time = 0,
	lighting_preset = "darkworld",
	round_seconds = 360,
	intermission_seconds = 12,
	min_players = 2,
	hunter_speed = 100,
	grace_seconds = 10,
	hunter_jump = 1.6,
	hunter_health_start = 75,
	hunter_health_max = 200,
	hunter_anim_speed = 1.5,
	hunter_heal_per_kill = 40,
	screech_speed = 0.45,
	screech_stagger = 2,
	hunter_knife = "M9",
	survivor_speed = 1,
	survivor_health = 100,
	survivor_lastman_speed = 1.15,
	sweep_seconds = 40,
	sweep_lastman_seconds = 12,
	flare_lifetime = 6,
	teamkill = false,
	autostart = true,
	shove_lethal = true,
	shove_torso = 100,
	shove_limb = 70,
	shove_headshot = 200,
	shove_distance = 8,
	markers_off = false,
	freeze_daycycle = true,
	harmless_bots = true,
	health_regen = 0,
	kill_sound_id = "",
	disable_nvg = false,
	fall_damage = false,
	nv_color_r = 1,
	nv_color_g = 1.5,
	nv_color_b = 2.5,
	nvg_dof_distance = 10,
	voxel_bullet_radius = 1,
	hunter_throwable = "M84",
	min_round_seconds = 5,
	spawn_window_seconds = 25,
	zero_debounce = 1,
	knife_code = "",
	knife_slot = "throwable1",
	force_equip = true,
	debug = true,
	disable_loadout_editing = true,
	screech_cooldown = 45,
	decoy_bots = 0,
	lightning_preset = "fullbright",
	lightning_time = 0.35,
};

local LOADOUT = {
	survivor_enabled = false,
	survivor = {
		{ slot = "primary", weapon = "MP5", code = "" },
		{ slot = "secondary", weapon = "Makarov", code = "" },
		{ slot = "throwable1", weapon = "nothing", code = "" },
		{ slot = "throwable2", weapon = "nothing", code = "" },
	},
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
	local knives = { "M9", "M11_EOD", "IZHEVSK_AKM_TYPE1", "IZHEVSK_AKM_TYPE2" };
	for _, want in ipairs(knives) do
		for _, n in ipairs(names) do
			if n == want then
				return n;
			end
		end
	end
	return nil;
end

local function suppress_gamemode()
	pcall(gamemode.force_set_gamemode, "none");
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
	grace = 0,
	applied = {},
	speed_timer = 0,
	debug_timer = 0,
	zero_time = 0,
	spawn_closed = false,
	elapsed = 0,
	screech_ready = 0,
	seen_alive = false,
	lastman_applied = false,
};

local connections = {};
local heartbeat_conn = nil;
local accumulator = 0;

local function is_hunter(name)
	return state.hunter ~= nil and name == state.hunter;
end

local function apply_loadout(p, entries)
	for _, entry in ipairs(entries) do
		if entry.weapon == "nothing" then
			pcall(p.set_weapon, entry.slot, "nothing");
		elseif entry.code and entry.code ~= "" then
			local ok, setup = pcall(weapons.get_setup_from_code, entry.code);
			if ok and setup and setup.status == "_" then
				pcall(p.set_weapon, entry.slot, entry.weapon, setup.data.data);
			else
				warn("[hidden] bad setup code for " .. entry.slot .. ", using empty setup");
				pcall(p.set_weapon, entry.slot, entry.weapon, "[]");
			end
		else
			pcall(p.set_weapon, entry.slot, entry.weapon, "[]");
		end
	end
end

local KNIVES = { M9 = true, M11_EOD = true, IZHEVSK_AKM_TYPE1 = true, IZHEVSK_AKM_TYPE2 = true };

local SLOTS = { "primary", "secondary", "throwable1", "throwable2" };

local function knife_from_loadout(p)
	for i = 0, 4 do
		for _, slot in ipairs(SLOTS) do
			local ok, data = pcall(p.get_weapon_from_loadout, i, slot);
			if ok and data and data.weapon and KNIVES[data.weapon] then
				return data.weapon, data.data;
			end
		end
	end
	return nil, nil;
end

local function arm_hunter(p)
	local kw, kd = nil, nil;
	for _, slot in ipairs({ "throwable1", "throwable2" }) do
		local ok, w = pcall(p.get_weapon_data_from_character, slot);
		if ok and type(w) == "table" and w.client_data and KNIVES[w.client_data.name] then
			kw, kd = w.client_data.name, w.client_data.setup;
			print("[hidden] knife from character: " .. tostring(kw));
			break;
		end
	end
	if not kw then
		kw, kd = knife_from_loadout(p);
		if kw then
			print("[hidden] knife from loadout: " .. tostring(kw));
		end
	end
	if kw then
		pcall(p.set_weapon, CFG.knife_slot, kw, kd);
	elseif CFG.knife_code ~= "" then
		local ok, setup = pcall(weapons.get_setup_from_code, CFG.knife_code);
		if ok and setup and setup.status == "_" then
			pcall(p.set_weapon, CFG.knife_slot, setup.data.weapon, setup.data.data);
			print("[hidden] knife from code: " .. tostring(setup.data.weapon));
		else
			warn("[hidden] knife_code invalid");
		end
	elseif RESOLVED_WEAPON and RESOLVED_WEAPON ~= "nothing" then
		pcall(p.set_weapon, CFG.knife_slot, RESOLVED_WEAPON, "[]");
		warn("[hidden] no knife in loadout and no knife_code set - bare knife may not equip");
	end
	if CFG.hunter_throwable ~= "nothing" then
		pcall(p.set_weapon, "throwable2", CFG.hunter_throwable, "[]");
	end

	time.delay(0.6, function()
		if CFG.knife_slot ~= "primary" then
			pcall(p.set_weapon, "primary", "nothing");
		end
		if CFG.knife_slot ~= "secondary" then
			pcall(p.set_weapon, "secondary", "nothing");
		end
		if CFG.force_equip then
			pcall(p.equip_weapon, CFG.knife_slot);
			local ok, slot = pcall(p.get_active_slot);
			print("[hidden] active slot after equip: " .. tostring(ok and slot or "?"));
		end
	end);
	return true;
end

local function apply_hunter(p)
	try(p.set_team, "attacker");
	if CFG.hunter_speed > 0 then
		try(p.set_speed, CFG.hunter_speed);
	end
	try(p.set_jump_multiplier, CFG.hunter_jump);
	try(p.set_health, CFG.hunter_health_start);
	try(p.set_animation_speed, CFG.hunter_anim_speed);
	pcall(p.set_weapon, "primary", "nothing");
	pcall(p.set_weapon, "secondary", "nothing");
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
	if LOADOUT.survivor_enabled then
		apply_loadout(p, LOADOUT.survivor);
	end
	try(p.refill_ammo);
end

local function broadcast_role(p)
	local role = "survivor";
	if is_hunter(p.name) then
		role = "hunter";
	end
	pcall(p.fire_client, { event = "hidden_role", role = role });
end

local function apply_role(name)
	if state.applied[name] then
		return;
	end
	local p = find_player(name);
	if not p then
		return;
	end
	state.applied[name] = true;
	if is_hunter(name) then
		apply_hunter(p);
	else
		apply_survivor(p);
	end
	broadcast_role(p);
end

local function freeze_dead(p)
	return;
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
	suppress_gamemode();
	time.delay(1, suppress_gamemode);
	time.delay(3, suppress_gamemode);
	time.delay(6, suppress_gamemode);
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
	set_var("plr_disable_nvg", CFG.disable_nvg);
	set_var("plr_fall_damage", CFG.fall_damage);
	set_var("plr_default_nvg_dof_distance", CFG.nvg_dof_distance);
	pcall(function()
		sharedvars.plr_nv_color = Color3.new(CFG.nv_color_r, CFG.nv_color_g, CFG.nv_color_b);
	end);
	set_var("voxel_bullet_destruction_radius", CFG.voxel_bullet_radius);
	print("[hidden] voxel parts on map: " .. tostring(#tags.get_tagged("voxel_destructible")));
	if CFG.shove_lethal then
		set_var("plr_shove_melee_torso_damage", CFG.shove_torso);
		set_var("plr_shove_melee_limb_damage", CFG.shove_limb);
		set_var("plr_shove_melee_headshot_damage", CFG.shove_headshot);
		set_var("plr_shove_torso_damage", CFG.shove_torso);
		set_var("plr_shove_limb_damage", CFG.shove_limb);
		set_var("plr_shove_headshot_damage", CFG.shove_headshot);
		set_var("plr_shove_distance", CFG.shove_distance);
	end
	if CFG.markers_off then
		set_var("plr_enable_markers", false);
		set_var("gm_objective_markers", false);
	end
	if CFG.freeze_daycycle then
		set_var("sv_day_cycle_speed", 0);
	end
	if CFG.harmless_bots then
		set_var("bot_hit_chance", 0);
		set_var("bot_headshot_chance", 0);
	end
	set_var("plr_health_regen_sec", CFG.health_regen);
	set_var("gm_disable_loadout_editing", CFG.disable_loadout_editing);
	set_var("gm_match_time_minutes", 120);
	set_var("sv_map_voting", false);
	set_var("sv_bot_auto_spawning_enabled", false);
	set_var("plr_pvp", true);
	set_var("plr_team_kill", CFG.teamkill);
	set_var("chat_tips_enabled", false);
	pcall(chat.set_join_message, "THE HIDDEN - one hunter, no lights, one life.");
end

local function play_sound(id, position)
	if id == "" then
		return;
	end
	local ok, snd = pcall(create_instance, "Sound");
	if not ok or not snd then
		return;
	end
	pcall(function()
		snd.SoundId = "rbxassetid://" .. tostring(id);
		snd.Volume = 1;
		snd.RollOffMaxDistance = 200;
		snd.Parent = get_map_root();
	end);
	pcall(snd.play);
	time.delay(8, function()
		pcall(function()
			snd.destroy();
		end);
	end);
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

local function is_bot(p)
	local ok, b = pcall(p.is_bot);
	return ok and b;
end

local function lightning_flash()
	if CFG.lightning_preset == "" then
		return;
	end
	pcall(map.set_preset, CFG.lightning_preset);
	time.delay(CFG.lightning_time, function()
		pcall(map.set_preset, CFG.lighting_preset);
	end);
end

local function alive_survivors()
	local out = {};
	for _, p in pairs(all_players()) do
		if not is_hunter(p.name) and not state.dead[p.name] and not is_bot(p) then
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
		if not is_bot(p) then
			table.insert(candidates, p.name);
		end
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
	local roster = {};
	for _, p in pairs(all_players()) do
		if not is_bot(p) then
			table.insert(roster, p);
		end
	end
	pcall(players.reset_ragdolls);
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
	state.grace = CFG.grace_seconds;
	state.applied = {};
	state.zero_time = 0;
	state.spawn_closed = false;
	state.elapsed = 0;
	state.seen_alive = false;
	state.lastman_applied = false;
	state.phase = "live";
	suppress_gamemode();
	set_var("sv_spawning_enabled", true);
	set_spawn_reason("");
	for _, p in pairs(roster) do
		task.spawn(function()
			try(p.set_camera_mode, "Default");
			try(p.set_speed, CFG.survivor_speed);
		end);
	end
	time.delay(0.5, function()
		for _, p in pairs(all_players()) do
			task.spawn(function()
				try(p.respawn);
			end);
		end
	end);

	time.delay(1.5, function()
		for _, p in pairs(all_players()) do
			apply_role(p.name);
		end
	end);
	for i = 1, CFG.decoy_bots do
		pcall(spawning.bot);
	end
	state.screech_ready = 0;
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
		try(p.set_speed, CFG.survivor_speed);
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
	state.elapsed = state.elapsed + dt;
	if CFG.debug then
		state.debug_timer = state.debug_timer - dt;
		if state.debug_timer <= 0 then
			state.debug_timer = 1;
			local parts = "";
			for _, pl in pairs(all_players()) do
				local aok, alive = pcall(pl.is_alive);
				local bok, bot = pcall(pl.is_bot);
				parts = parts
					.. string.format(
						"%s[hunter=%s dead=%s bot=%s alive=%s] ",
						tostring(pl.name),
						tostring(is_hunter(pl.name)),
						tostring(state.dead[pl.name] and true or false),
						tostring(bok and bot),
						tostring(aok and alive)
					);
			end
			print("[hidden] t=" .. tostring(math.floor(state.elapsed)) .. " survivors=" .. tostring(#survivors) .. " | " .. parts);
		end
	end
	if #survivors > 0 then
		state.seen_alive = true;
	end
	if state.grace > 0 then
		state.grace = state.grace - dt;
		if state.grace <= 0 then
			state.dead = {};
			state.zero_time = 0;
			print("[hidden] grace over - death tracking now active");
		end
		return;
	end
	if not state.spawn_closed and state.seen_alive and state.elapsed >= CFG.spawn_window_seconds then
		state.spawn_closed = true;
		set_var("sv_spawning_enabled", false);
		set_spawn_reason("One life per round - wait for the next round");
		print("[hidden] spawn window closed, survivors alive: " .. tostring(#survivors));
	end
	if #survivors == 0 and state.seen_alive then
		state.zero_time = state.zero_time + dt;
	else
		state.zero_time = 0;
	end
	if #survivors == 1 and not state.lastman_applied and CFG.survivor_lastman_speed > 0 then
		state.lastman_applied = true;
		try(survivors[1].set_speed, CFG.survivor_lastman_speed);
	end
	if hunter_player and hunter_alive then
		state.speed_timer = state.speed_timer - dt;
		if state.speed_timer <= 0 then
			state.speed_timer = 1;
			try(hunter_player.set_speed, CFG.hunter_speed);
			try(hunter_player.set_jump_multiplier, CFG.hunter_jump);
		end
	end
	if state.screech_ready > 0 then
		state.screech_ready = state.screech_ready - dt;
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
	if state.timer > (CFG.round_seconds - CFG.min_round_seconds) then
		return;
	end
	if not hunter_alive and state.dead[state.hunter] then
		print("[hidden] end reason: hunter dead");
		end_round("SURVIVORS WIN - the Hidden is down.", Color3.fromRGB(80, 200, 120));
	elseif #survivors == 0 and state.seen_alive and state.zero_time >= CFG.zero_debounce then
		print("[hidden] end reason: zero survivors for " .. tostring(math.floor(state.zero_time)) .. "s");
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
		if state.grace > 0 then
			return;
		end
		local name, position, killer_data = parse_death(...);
		if not name then
			return;
		end
		state.dead[name] = true;
		local dtype = "unknown";
		if type(killer_data) == "table" and killer_data.type then
			dtype = tostring(killer_data.type);
		end
		print("[hidden] DIED: " .. tostring(name) .. " type=" .. dtype);
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
			print("[hidden] end reason: hunter killed");
			end_round("SURVIVORS WIN - the Hidden is down.", Color3.fromRGB(80, 200, 120));
			return;
		end
		if position then
			drop_flare(position, CFG.flare_lifetime);
		end
		lightning_flash();
		play_sound(CFG.kill_sound_id, position);
		local remaining = #alive_survivors();
		if remaining == 0 then
			print("[hidden] end reason: last survivor killed");
			end_round("THE HIDDEN WINS - everyone is dead.", Color3.fromRGB(200, 40, 40));
			return;
		elseif remaining == 1 then
			notify("One survivor left.");
		else
			notify(string.format("%d survivors remain.", remaining));
		end
		local hunter_player = find_player(state.hunter);
		if hunter_player and CFG.hunter_heal_per_kill > 0 then
			local ok, hp = pcall(hunter_player.get_health);
			if ok and hp then
				local healed = hp + CFG.hunter_heal_per_kill;
				if healed > CFG.hunter_health_max then
					healed = CFG.hunter_health_max;
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
	RESOLVED_WEAPON = CFG.hunter_knife;
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
		try(p.set_speed, CFG.survivor_speed);
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
		if key == "hunter_knife" then
			RESOLVED_WEAPON = value;
		end
	end
	return key .. " = " .. tostring(CFG[key]);
end

commands.screech = function(arg, sender)
	if state.phase ~= "live" then
		return "no live round";
	end
	if state.screech_ready > 0 then
		return string.format("screech on cooldown, %ds", math.ceil(state.screech_ready));
	end
	state.screech_ready = CFG.screech_cooldown;
	local marked = 0;
	for _, p in ipairs(alive_survivors()) do
		local pos = state.positions[p.name];
		if pos then
			drop_flare(pos, 4, Color3.fromRGB(255, 40, 40));
			marked = marked + 1;
		end
	end
	for _, p in ipairs(alive_survivors()) do
		try(p.set_speed, CFG.screech_speed);
	end
	time.delay(CFG.screech_stagger, function()
		for _, p in pairs(all_players()) do
			if not is_hunter(p.name) and not state.dead[p.name] then
				try(p.set_speed, CFG.survivor_speed);
			end
		end
	end);
	lightning_flash();
	notify("SCREECH - it knows where you are. MOVE.");
	return string.format("marked %d survivors", marked);
end

commands.hprobe = function()
	local names = { "hitbox", "Detail_Player", "fix_raycastfilters_humanoidrootpart", "player_ladder", "walls" };
	for _, t in ipairs(names) do
		local ok, res = pcall(tags.get_tagged, t);
		local count = 0;
		if ok and type(res) == "table" then
			count = #res;
		end
		print("[hidden] tag " .. t .. " -> " .. tostring(count) .. " instances");
		if count > 0 then
			local first = res[1];
			local keys = "";
			for k in pairs(first) do
				keys = keys .. tostring(k) .. " ";
			end
			print("   first instance keys: " .. keys);
		end
	end
	return "probe printed to console";
end

commands.hknife = function(arg)
	local slot, name = nil, nil;
	if arg then
		slot, name = arg:match("^%s*(%S+)%s+(%S+)");
	end
	slot = slot or CFG.knife_slot;
	name = name or CFG.hunter_knife;
	local p = find_player(state.hunter);
	if not p then
		return "no hunter";
	end
	pcall(p.set_weapon, slot, name, "[]");
	time.delay(0.5, function()
		pcall(p.equip_weapon, slot);
		local ok, active = pcall(p.get_active_slot);
		print("[hidden] tried " .. slot .. "=" .. name .. " -> active slot: " .. tostring(ok and active or "?"));
	end);
	return "trying " .. name .. " in " .. slot;
end

commands.hdump = function(arg)
	local name = nil;
	if arg then
		name = arg:match("%S+");
	end
	name = name or state.hunter;
	local p = find_player(name);
	if not p then
		return "no player: " .. tostring(name);
	end
	print("[hidden] loadout dump for " .. tostring(name));
	for i = 0, 4 do
		for _, slot in ipairs(SLOTS) do
			local ok, d = pcall(p.get_weapon_from_loadout, i, slot);
			if ok and type(d) == "table" and d.weapon then
				print("   loadout " .. tostring(i) .. " / " .. slot .. " = " .. tostring(d.weapon));
			end
		end
	end
	for _, slot in ipairs(SLOTS) do
		local ok, d = pcall(p.get_weapon_data_from_character, slot);
		if ok and type(d) == "table" and d.client_data then
			print("   equipped " .. slot .. " = " .. tostring(d.client_data.name));
		end
	end
	return "dump printed to console";
end

commands.hdebug = function()
	CFG.debug = not CFG.debug;
	return "debug census: " .. tostring(CFG.debug);
end

commands.hsound = function(arg)
	local id = nil;
	if arg then
		id = arg:match("%d+");
	end
	if not id then
		return "usage: hsound <assetid>";
	end
	play_sound(id, nil);
	return "played " .. id;
end

commands.hpresets = function()
	if not (config and config.lighting_presets) then
		return "no presets available";
	end
	print("[hidden] lighting presets:");
	for name in pairs(config.lighting_presets) do
		print("   " .. name);
	end
	return "presets printed to console";
end

commands.hloadout = function(arg)
	if arg and arg:match("%S") then
		LOADOUT.survivor_enabled = (arg:match("^%s*(%S+)") == "on");
	else
		LOADOUT.survivor_enabled = not LOADOUT.survivor_enabled;
	end
	return "survivor fixed loadout: " .. tostring(LOADOUT.survivor_enabled);
end

commands.hhelp = function()
	return "-hstart -hstop -hnext -hhunter <name> -hstatus -hguns -hloadout on/off -hset <key> <value>";
end

table.insert(
	connections,
	chat.player_chatted:Connect(function(sender, channel, content)
		print("[hidden] chat from " .. tostring(sender) .. ": " .. tostring(content));
		local first = content:sub(1, 1);
		if first ~= "-" and first ~= "!" then
			return;
		end
		local word = content:split(" ")[1]:sub(2);
		local handler = commands[word];
		if not handler then
			return;
		end
		local owner = sharedvars.vip_owner;
		local allowed = true;
		if word == "screech" then
			if sender ~= state.hunter then
				return;
			end
		elseif owner and not is_studio() then
			allowed = (string.lower(tostring(sender)) == string.lower(tostring(owner)));
		end
		if not allowed then
			print("[hidden] rejected: sender=" .. tostring(sender) .. " owner=" .. tostring(owner));
			announce("host only.");
			return;
		end
		local rest = content:sub(#word + 3, -1);
		local ok, result = pcall(handler, rest, sender);
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

shared.hidden_gamemode = { cleanup = cleanup, state = state, config = CFG, commands = commands, loadout = LOADOUT };

pcall(gamemode.force_set_gamemode, "none");

print("[hidden] loaded. map=" .. CFG.map_name .. " time=" .. tostring(CFG.map_time) .. " preset=" .. CFG.lighting_preset);
print("[hidden] chat: -hstart   console: shared.hidden_gamemode.commands.hstart()");
print("[hidden] host is: " .. tostring(sharedvars.vip_owner));

if CFG.autostart then
	time.delay(2, function()
		local ok, res = pcall(commands.hstart);
		print("[hidden] autostart: " .. tostring(ok and res or res));
	end);
end
