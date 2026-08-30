local CFG = {
	map_name = "nuristan_voxel",
	map_time = 0,
	lighting_preset = "darkworld",
	round_seconds = 360,
	intermission_seconds = 12,
	min_players = 2,
	hunter_speed = 100,
	disable_ac_movement = true,
	disable_ac_airtime = true,
	infinite_stamina = true,
	climb_boost = true,
	latch_max_seconds = 8,
	latch_cooldown = 6,
	vault_height = 12,
	vault_reach = 8,
	vault_time = 0.35,
	grace_seconds = 10,
	hunter_jump = 3.0,
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
	teamkill = true,
	autostart = true,
	shove_lethal = true,
	shove_torso = 100,
	shove_limb = 70,
	shove_headshot = 200,
	shove_distance = 8,
	markers_off = true,
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
	hunter_throwable = "nothing",
	min_round_seconds = 5,
	spawn_window_seconds = 25,
	zero_debounce = 1,
	knife_code = "d3w8-0253-nf4h-48h9-32zd-2qn2-zf73-wb5q",
	knife_slot = "primary",
	knife_mode = "raw",
	solo_test = false,
	force_equip = false,
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
		{ slot = "primary", code = "" },
		{ slot = "secondary", code = "" },
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

local function set_weapon_logged(p, slot, name, data)
	local ok, err;
	if data == nil then
		ok, err = pcall(p.set_weapon, slot, name);
	else
		ok, err = pcall(p.set_weapon, slot, name, data);
	end
	if ok then
		print("[hidden] set_weapon " .. tostring(slot) .. "=" .. tostring(name) .. " -> OK");
	else
		warn("[hidden] set_weapon " .. tostring(slot) .. "=" .. tostring(name) .. " -> FAILED: " .. tostring(err));
	end
	return ok, err;
end

local function report_setup(setup)
	if type(setup) ~= "table" then
		warn("[hidden] setup is not a table");
		return false;
	end
	print("[hidden] setup.status = " .. tostring(setup.status));
	local ok, st = pcall(weapons.get_setup_status, setup.data);
	if ok then
		print("[hidden] get_setup_status = " .. tostring(st));
	else
		warn("[hidden] get_setup_status errored: " .. tostring(st));
	end
	return setup.status == "_";
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
	latched = false,
	latch_pos = nil,
	latch_time = 0,
	latch_ready = 0,
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
		if entry.code == "nothing" then
			set_weapon_logged(p, entry.slot, "nothing");
		elseif entry.code and entry.code ~= "" then
			local ok, setup = pcall(weapons.get_setup_from_code, entry.code);
			if ok and type(setup) == "table" and setup.status == "_" then
				report_setup(setup);
				set_weapon_logged(p, entry.slot, setup.data.weapon, setup.data.data);
			else
				warn("[hidden] bad setup code for " .. entry.slot .. " - slot left alone");
			end
		end
	end
end

local KNIFE_JSON = "{\"map\":[{\"id\":1884104663,\"attributes\":[],\"attached\":[{\"id\":2"
	.. "376278431,\"attributes\":[],\"attached\":[]}]}],\"tape\":[],\"stickers"
	.. "\":[],\"preferences\":{\"optics\":[],\"laser\":false,\"firemode\":\"fa"
	.. "be75fb-d04b-4dd8-a8c6-0905bddf05a0\",\"mounting\":true,\"flashlight\":"
	.. "false}}";

local function build_knife_setup(p, mode)
	if mode == "raw" then
		return CFG.hunter_knife, KNIFE_JSON, "raw-json";
	end
	if mode == "code" and CFG.knife_code ~= "" then
		local ok, setup = pcall(weapons.get_setup_from_code, CFG.knife_code);
		if ok and type(setup) == "table" and setup.status == "_" then
			warn("[hidden] NOTE: code data is base64, set_weapon wants JSON - this will likely fail");
			return setup.data.weapon, setup.data.data, "code";
		end
		warn("[hidden] knife code did not decode");
	end
	return nil, nil, "none";
end

local function arm_hunter(p)


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
	time.delay(1.2, function()
		for _, slot in ipairs({ "primary", "secondary" }) do
			set_weapon_logged(p, slot, "nothing");
		end
		if CFG.knife_mode ~= "none" then
			local kw, kd, src = build_knife_setup(p, CFG.knife_mode);
			if kw then
				print("[hidden] post-spawn knife " .. tostring(kw) .. " via " .. tostring(src));
				local ok = set_weapon_logged(p, CFG.knife_slot, kw, kd);
				if ok and CFG.force_equip then
					time.delay(0.5, function()
						local eok, eerr = pcall(p.equip_weapon, CFG.knife_slot, true);
						print("[hidden] equip_weapon ok=" .. tostring(eok) .. " err=" .. tostring(eerr));
					end);
				end
			end
		end
	end);

	time.delay(2.5, function()
		for _, slot in ipairs({ "primary", "secondary" }) do
			local ok, w = pcall(p.get_weapon_data_from_character, slot);
			local nm = "empty";
			if ok and type(w) == "table" and w.client_data and w.client_data.name then
				nm = tostring(w.client_data.name);
			end
			print("[hidden] after spawn " .. slot .. " = " .. nm);
		end
	end);
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
	try(p.refill_ammo);
end

local function broadcast_role(p)
	local role = "survivor";
	if is_hunter(p.name) then
		role = "hunter";
	end
	local ok, err = pcall(p.fire_client, { event = "hidden_role", role = role });
	print("[hidden] fire_client " .. tostring(p.name) .. " role=" .. role .. " ok=" .. tostring(ok) .. " err=" .. tostring(err));
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
	if CFG.disable_ac_movement then
		set_var("ac_movement", false);
	end
	if CFG.disable_ac_airtime then
		set_var("ac_airtime_kill", false);
	end
	if CFG.climb_boost then
		set_var("plr_vault_height", CFG.vault_height);
		set_var("plr_vault_frontal_detection_length", CFG.vault_reach);
		set_var("plr_vault_top_detection_length", CFG.vault_reach);
		set_var("plr_vault_max_vault_time", CFG.vault_time);
		set_var("plr_vault_stamina_drain", 0);
		set_var("plr_vault_barrier_height_reduction", 0);
	end
	if CFG.infinite_stamina then
		set_var("plr_max_stamina", 1000);
		set_var("plr_stamina_regen", 100);
		set_var("plr_stamina_run_drain", 0);
		set_var("plr_stamina_jump_drain", 0);
	end
	print("[hidden] ac_movement=" .. tostring(sharedvars.ac_movement) .. " ac_airtime_kill=" .. tostring(sharedvars.ac_airtime_kill));
	set_var("gm_disable_loadout_editing", CFG.disable_loadout_editing);
	set_var("gm_match_time_minutes", 120);
	set_var("sv_map_voting", false);
	set_var("sv_bot_auto_spawning_enabled", false);
	set_var("plr_pvp", true);
	set_var("plr_team_kill", CFG.teamkill);
	set_var("chat_tips_enabled", false);
	pcall(chat.set_join_message, "THE HIDDEN - one hunter, no lights, one life. EQUIP A KNIFE IN YOUR LOADOUT - you will need it if you are picked.");
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

	local hp = find_player(state.hunter);
	if hp then
		for _, slot in ipairs({ "primary", "secondary" }) do
			set_weapon_logged(hp, slot, "nothing");
		end

		if CFG.knife_mode ~= "none" then
			local kw, kd, src = build_knife_setup(hp, CFG.knife_mode);
			if kw then
				print("[hidden] knife source = " .. tostring(src) .. ", weapon = " .. tostring(kw));
				set_weapon_logged(hp, CFG.knife_slot, kw, kd);
			else
				warn("[hidden] no knife setup for mode " .. tostring(CFG.knife_mode));
			end
		end

		time.delay(2.5, function()
			for _, slot in ipairs({ "primary", "secondary" }) do
				local ok, w = pcall(hp.get_weapon_data_from_character, slot);
				local nm = "empty";
				if ok and type(w) == "table" and w.client_data and w.client_data.name then
					nm = tostring(w.client_data.name);
				end
				print("[hidden] hunter " .. slot .. " = " .. nm);
			end
		end);
	end

	if LOADOUT.survivor_enabled then
		for _, sp in pairs(roster) do
			if not is_hunter(sp.name) then
				apply_loadout(sp, LOADOUT.survivor);
			end
		end
	end
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
	state.latched = false;
	state.latch_pos = nil;
	state.latch_ready = 0;
	announce(string.format("ROUND %d - the Hidden is among you.", state.round_number), Color3.fromRGB(200, 40, 40));
	notify("Lights out. One life. Kill the Hidden or survive the clock.");
	notify("Hidden: your guns are gone. Use your knife.");
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
	if state.latch_ready > 0 then
		state.latch_ready = state.latch_ready - dt;
	end
	if state.latched and state.latch_pos and hunter_player then
		state.latch_time = state.latch_time + dt;
		if state.latch_time >= CFG.latch_max_seconds then
			state.latched = false;
			state.latch_ready = CFG.latch_cooldown;
			notify("The Hidden drops.");
		else
			pcall(hunter_player.set_position, state.latch_pos);
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
	if CFG.solo_test then
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
			if not CFG.solo_test then
				print("[hidden] end reason: hunter killed");
				end_round("SURVIVORS WIN - the Hidden is down.", Color3.fromRGB(80, 200, 120));
			end
			return;
		end
		if position then
			drop_flare(position, CFG.flare_lifetime);
		end
		lightning_flash();
		play_sound(CFG.kill_sound_id, position);
		local remaining = #alive_survivors();
		if remaining == 0 then
			if not CFG.solo_test then
				print("[hidden] end reason: last survivor killed");
				end_round("THE HIDDEN WINS - everyone is dead.", Color3.fromRGB(200, 40, 40));
			end
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

table.insert(
	connections,
	on_client_event:Connect(function(player, args)
		local ptype = type(player);
		local name = player;
		if ptype == "table" and player.name then
			name = player.name;
		end
		local ev = "?";
		if type(args) == "table" and args.event then
			ev = tostring(args.event);
		end
		print("[hidden] CLIENT EVENT from=" .. tostring(name) .. " (" .. ptype .. ") event=" .. ev .. " hunter=" .. tostring(state.hunter));
		if type(args) ~= "table" or not state.running then
			return;
		end
		if name ~= state.hunter then
			print("[hidden] ignored - sender is not the hunter");
			return;
		end

		if args.event == "screech" then
			local res = commands_ref.screech("", name);
			print("[hidden] screech by " .. tostring(name) .. ": " .. tostring(res));
		elseif args.event == "latch" then
			local p = find_player(name);
			if not p then
				return;
			end
			if args.on and state.latch_ready <= 0 then
				local ok, pos = pcall(p.get_position);
				if ok and pos then
					state.latched = true;
					state.latch_pos = pos;
					state.latch_time = 0;
					print("[hidden] latched at " .. tostring(pos));
				end
			else
				state.latched = false;
				state.latch_ready = CFG.latch_cooldown;
				print("[hidden] unlatched");
			end
		end
	end)
);

local commands = {};
commands_ref = commands;

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

commands.hsolo = function()
	CFG.solo_test = not CFG.solo_test;
	if CFG.solo_test then
		CFG.min_players = 1;
		state.next_hunter = sharedvars.vip_owner;
		print("[hidden] SOLO TEST ON - you are the Hidden, rounds will not end");
		if state.phase == "live" then
			end_round("Solo test mode - restarting.", Color3.fromRGB(180, 180, 180));
		end
	else
		CFG.min_players = 2;
		print("[hidden] solo test off");
	end
	return "solo_test = " .. tostring(CFG.solo_test);
end

commands.htestgun = function(arg)
	local code = nil;
	if arg then
		code = arg:match("%S+");
	end
	if not code then
		return "usage: htestgun <setup code>";
	end
	local p = find_player(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, setup = pcall(weapons.get_setup_from_code, code);
	if not ok or type(setup) ~= "table" then
		return "lookup failed";
	end
	if setup.status ~= "_" then
		return "invalid code, status=" .. tostring(setup.status);
	end
	report_setup(setup);
	set_weapon_logged(p, "primary", setup.data.weapon, setup.data.data);
	time.delay(1.5, function()
		local rok, w = pcall(p.get_weapon_data_from_character, "primary");
		local nm = "empty";
		if rok and type(w) == "table" and w.client_data and w.client_data.name then
			nm = tostring(w.client_data.name);
		end
		print("[hidden] primary now reads: " .. nm);
	end);
	return "sent " .. tostring(setup.data.weapon);
end

commands.hloadcode = function(arg)
	local slot, code = nil, nil;
	if arg then
		slot, code = arg:match("^%s*(%S+)%s+(%S+)");
	end
	if not slot then
		return "usage: hloadcode <primary|secondary> <code or 'nothing'>";
	end
	for _, entry in ipairs(LOADOUT.survivor) do
		if entry.slot == slot then
			entry.code = code;
			return slot .. " code set (applies next round)";
		end
	end
	return "unknown slot: " .. slot;
end

commands.hfix = function(arg)
	local name = nil;
	if arg then
		name = arg:match("%S+");
	end
	local targets = {};
	if name then
		local p = find_player(name);
		if not p then
			return "no player: " .. name;
		end
		table.insert(targets, p);
	else
		for _, p in pairs(all_players()) do
			table.insert(targets, p);
		end
	end
	for _, p in ipairs(targets) do
		task.spawn(function()
			pcall(p.set_camera_mode, "Default");
			pcall(p.respawn);
		end);
	end
	return "respawned " .. tostring(#targets) .. " player(s) to rebuild camera";
end

commands.hcode = function(arg)
	local code = nil;
	if arg then
		code = arg:match("%S+");
	end
	if not code then
		return "usage: hcode <setup code>";
	end
	local ok, setup = pcall(weapons.get_setup_from_code, code);
	if not ok or type(setup) ~= "table" then
		return "lookup failed";
	end
	if setup.status ~= "_" then
		return "invalid code, status=" .. tostring(setup.status);
	end
	CFG.knife_code = code;
	local w = "?";
	if setup.data and setup.data.weapon then
		w = tostring(setup.data.weapon);
	end
	print("[hidden] knife_code saved, weapon=" .. w);
	return "knife_code saved, weapon=" .. w .. " (applies next round)";
end

commands.hknife = function(arg)
	local mode = nil;
	if arg then
		mode = arg:match("%S+");
	end
	mode = mode or CFG.knife_mode;
	local p = find_player(state.hunter);
	if not p then
		return "no hunter in play";
	end
	local kw, kd, src = build_knife_setup(p, mode);
	if not kw then
		return "mode '" .. mode .. "' produced no setup";
	end
	print("[hidden] hknife source = " .. tostring(src) .. ", weapon = " .. tostring(kw));
	print("[hidden] hknife data = " .. string.sub(tostring(kd), 1, 120));
	local ok, err = set_weapon_logged(p, CFG.knife_slot, kw, kd);
	return "set_weapon ok=" .. tostring(ok) .. " err=" .. tostring(err);
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
do
	local ok, setup = pcall(weapons.get_setup_from_code, CFG.knife_code);
	if ok and type(setup) == "table" and setup.status == "_" then
		report_setup(setup);
		print("[hidden] knife code valid, weapon=" .. tostring(setup.data and setup.data.weapon));
	else
		local st = "?";
		if type(setup) == "table" then
			st = tostring(setup.status);
		end
		warn("[hidden] knife code did NOT validate, status=" .. st);
	end
end
print("[hidden] host is: " .. tostring(sharedvars.vip_owner));

if CFG.autostart then
	time.delay(2, function()
		local ok, res = pcall(commands.hstart);
		print("[hidden] autostart: " .. tostring(ok and res or res));
	end);
end
