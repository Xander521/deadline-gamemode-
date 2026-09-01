local CFG = {
	map_name = "nuristan_voxel",
	map_time = 0,
	lighting_preset = "darkworld",
	round_seconds = 360,
	intermission_seconds = 12,
	min_players = 2,
	hunter_speed = 85,
	disable_ac_movement = true,
	disable_ac_airtime = true,
	infinite_stamina = true,
	climb_boost = false,
	shimmer = false,
	shimmer_size = 3.5,
	shimmer_min_move = 0.25,
	shimmer_max_move = 2.5,
	shimmer_min_transparency = 0.7,
	shimmer_height = 2.5,
	flares = false,
	sweeps = false,
	rotate_maps = true,
	random_start_map = true,
	map_list = "test_office,test_homestead,test_crossroad,test_complex_night,shipment,sandstorm7v7,nabolag,misc_backrooms,delivery,test_nuristan",
	rounds_per_map = 2,
	map_change_pause = 25,
	latch_enabled = true,
	screech_flash = false,
	screech_sfx = "122669453642437",
	amb_rumble = "9112795583",
	amb_rumble_vol = 0.5,
	amb_drone = "96882374244117",
	amb_drone_vol = 0.35,
	amb_heartbeat = "9043365842",
	radio_cooldown = 25,
	pounce_force = 2200,
	take_ownership = false,
	pounce_use_impulse = false,
	ownership_return = 1.5,
	pounce_lift = 900,
	pounce_distance = 30,
	pounce_up = 6,
	pounce_cooldown = 12,
	latch_max_seconds = 30,
	latch_warn_at = 5,
	latch_cooldown = 10,
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
	screech_stagger = 3,
	screech_reveal = 8,
	death_ignore_seconds = 4,
	spawn_grace = 15,
	hunter_knife = "M9",
	survivor_speed = 0.8,
	survivor_health = 125,
	survivor_lastman_speed = 1.15,
	sweep_seconds = 40,
	sweep_lastman_seconds = 12,
	flare_lifetime = 6,
	teamkill = true,
	ceasefire_off = true,
	silence_map_ambience = true,
	guns_url = "https://raw.githubusercontent.com/Xander521/deadline-gamemode-/main/guns.luau",
	random_loadouts = true,
	strip_survivor_throwables = true,
	strip_hunter_throwable2 = true,
	hunter_hp_min = 75,
	hunter_hp_max = 200,
	hunter_hp_full_at = 6,
	reveal_on_kill = 3,
	ping_cooldown = 45,
	ping_reveal_range = 30,
	ping_reveal_time = 2,
	ping_sfx = "",
	streak_threshold = 3,
	streak_penalty = 0.2,
	streak_penalty_max = 0.4,
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
	test_abilities = true,
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

local MAP_TIMES = {
	test_office = 360,
	test_homestead = 240,
	test_crossroad = 360,
	test_complex_night = 240,
	shipment = 480,
	sandstorm7v7 = 360,
	nabolag = 360,
	misc_backrooms = 180,
	delivery = 360,
	test_nuristan = 480,
};

local MAP_ROUNDS = {
	misc_backrooms = 2,
	test_nuristan = 2,
};

local MAP_KEEPS_LIGHTS = {
	test_homestead = true,
	test_complex_night = true,
};

local function rounds_for(mapname)
	return MAP_ROUNDS[mapname] or 6;
end

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
local VAULT_KEYS = {
	"plr_vault_height",
	"plr_vault_frontal_detection_length",
	"plr_vault_top_detection_length",
	"plr_vault_max_vault_time",
	"plr_vault_stamina_drain",
	"plr_vault_barrier_height_reduction",
};
local VAULT_DEFAULTS = {};
for _, k in ipairs(VAULT_KEYS) do
	local ok, v = pcall(function()
		return sharedvars[k];
	end);
	if ok then
		VAULT_DEFAULTS[k] = v;
	end
end

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
	loadout = {},
	wins_hunter = 0,
	wins_survivors = 0,
	hunter_hp = 75,
	streak = 0,
	ping_ready = {},
	map_index = 0,
	rounds_on_map = 0,
	grace = 0,
	applied = {},
	latched = false,
	latch_pos = nil,
	latch_player = nil,
	latch_time = 0,
	latch_ready = 0,
	latch_warned = false,
	stagger = 0,
	radio_ready = 0,
	shimmer_part = nil,
	shimmer_last = nil,
	pounce_ready = 0,
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

local GUNS = nil;

local function load_guns()
	if GUNS then
		return GUNS;
	end
	local ok, g = pcall(require, CFG.guns_url);
	if ok and type(g) == "table" and g.primary and g.secondary then
		GUNS = g;
		print("[hidden] guns loaded: " .. tostring(#g.primary) .. " primaries, " .. tostring(#g.secondary) .. " secondaries");
	else
		warn("[hidden] could not load guns: " .. tostring(g));
	end
	return GUNS;
end

local function verify_slot(p, slot, wanted)
	local ok, w = pcall(p.get_weapon_data_from_character, slot);
	if ok and type(w) == "table" and w.client_data and w.client_data.name then
		return tostring(w.client_data.name) == tostring(wanted), tostring(w.client_data.name);
	end
	return false, "?";
end

local function give_gun(p, slot, entry, attempt, round)
	attempt = attempt or 1;
	round = round or state.round_number;
	if is_hunter(p.name) then
		print("[hidden] skipping gun for hunter " .. tostring(p.name));
		return;
	end
	set_weapon_logged(p, slot, entry.name, entry.data);
	time.delay(1.4, function()
		if round ~= state.round_number then
			print("[hidden] dropping stale gun retry for " .. tostring(p.name));
			return;
		end
		if is_hunter(p.name) then
			print("[hidden] " .. tostring(p.name) .. " is now the hunter, aborting gun retry");
			return;
		end
		local good, got = verify_slot(p, slot, entry.name);
		if good then
			return;
		end
		if attempt >= 3 then
			warn("[hidden] " .. tostring(p.name) .. " " .. slot .. " stuck as '" .. got .. "', wanted " .. entry.name);
			return;
		end
		print("[hidden] " .. tostring(p.name) .. " " .. slot .. " is '" .. got .. "', retry " .. tostring(attempt + 1));
		give_gun(p, slot, entry, attempt + 1, round);
	end);
end

local function apply_survivor_guns(p)
	if not CFG.random_loadouts then
		return;
	end
	local g = load_guns();
	if not g then
		return;
	end
	local pr = g.primary[math.random(1, #g.primary)];
	local se = g.secondary[math.random(1, #g.secondary)];
	state.loadout[p.name] = { pr, se };
	give_gun(p, "primary", pr);
	give_gun(p, "secondary", se);
	print("[hidden] " .. tostring(p.name) .. " -> " .. pr.label .. " + " .. se.label);
	if CFG.strip_survivor_throwables then
		pcall(p.set_weapon, "throwable1", "nothing");
		pcall(p.set_weapon, "throwable2", "nothing");
	end
end

local function hunter_start_hp(count)
	local base;
	if count <= 2 then
		base = CFG.hunter_hp_min;
	elseif count >= CFG.hunter_hp_full_at then
		base = CFG.hunter_hp_max;
	else
		local span = CFG.hunter_hp_full_at - 2;
		local frac = (count - 2) / span;
		base = CFG.hunter_hp_min + (CFG.hunter_hp_max - CFG.hunter_hp_min) * frac;
	end
	if state.streak >= CFG.streak_threshold then
		local extra = (state.streak - CFG.streak_threshold) * CFG.streak_penalty;
		local cut = CFG.streak_penalty + extra;
		if cut > CFG.streak_penalty_max then
			cut = CFG.streak_penalty_max;
		end
		base = base * (1 - cut);
		announce(
			string.format("The Hidden has won %d in a row - handicapped %d%%", state.streak, math.floor(cut * 100)),
			Color3.fromRGB(120, 180, 255)
		);
	end
	return math.floor(base);
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
	try(p.set_health, state.hunter_hp);
	try(p.set_animation_speed, CFG.hunter_anim_speed);
	time.delay(1.6, function()
		local rok, w = pcall(p.get_weapon_data_from_character, CFG.knife_slot);
		local cur = "";
		if rok and type(w) == "table" and w.client_data and w.client_data.name then
			cur = tostring(w.client_data.name);
		end
		if cur == tostring(CFG.hunter_knife) then
			print("[hidden] knife already correct (" .. cur .. "), no reapply");
			return;
		end
		print("[hidden] slot holds '" .. cur .. "', reapplying knife");
		time.delay(2, function()
			local r2, w2 = pcall(p.get_weapon_data_from_character, CFG.knife_slot);
			local c2 = "";
			if r2 and type(w2) == "table" and w2.client_data and w2.client_data.name then
				c2 = tostring(w2.client_data.name);
			end
			if c2 ~= tostring(CFG.hunter_knife) then
				print("[hidden] knife still wrong (" .. c2 .. "), third attempt");
				local kw2, kd2 = build_knife_setup(p, CFG.knife_mode);
				if kw2 then
					set_weapon_logged(p, CFG.knife_slot, kw2, kd2);
				end
			end
		end);
		for _, slot in ipairs({ "primary", "secondary" }) do
			set_weapon_logged(p, slot, "nothing");
		end
		if CFG.knife_mode ~= "none" then
			local kw, kd, src = build_knife_setup(p, CFG.knife_mode);
			if kw then
				set_weapon_logged(p, CFG.knife_slot, kw, kd);
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
	local want = state.loadout[p.name];
	if want then
		time.delay(1.6, function()
			local g1 = verify_slot(p, "primary", want[1].name);
			local g2 = verify_slot(p, "secondary", want[2].name);
			if not g1 then
				give_gun(p, "primary", want[1]);
			end
			if not g2 then
				give_gun(p, "secondary", want[2]);
			end
			if CFG.strip_survivor_throwables then
				pcall(p.set_weapon, "throwable1", "nothing");
				pcall(p.set_weapon, "throwable2", "nothing");
			end
		end);
	end
	try(p.refill_ammo);
end

local function broadcast_role(p)
	local role = "survivor";
	if is_hunter(p.name) then
		role = "hunter";
	end
	local ok, err = pcall(p.fire_client, role);
	local hp = find_player(state.hunter);
	if hp then
		local iok, hid = pcall(function()
			return hp.player_id;
		end);
		if iok and hid then
			pcall(p.fire_client, "h:" .. tostring(hid));
		end
	end
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

local function hush(inst)
	local isnd = false;
	pcall(function()
		isnd = inst.is_a("Sound");
	end);
	if not isnd then
		return false;
	end
	local a = pcall(function()
		inst.Volume = 0;
	end);
	local b = pcall(function()
		inst.stop();
	end);
	local c = pcall(function()
		inst.Playing = false;
	end);
	return a or b or c;
end

local function sweep_map_sounds(verbose, apply)
	local root = get_map_root();
	if not root then
		return 0, 0;
	end
	local ok, all = pcall(function()
		return root.get_descendants();
	end);
	if not ok or type(all) ~= "table" then
		return 0, 0;
	end
	local found, hushed = 0, 0;
	if verbose then
		print("[hidden] descendants scanned: " .. tostring(#all));
		local ok2, probe = pcall(create_instance, "Sound");
		if ok2 and probe then
			local iok, isr = pcall(function()
				return probe.is_a("Sound");
			end);
			print("[hidden] is_a sanity check on a new Sound: ok=" .. tostring(iok) .. " result=" .. tostring(isr));
			pcall(function()
				probe.destroy();
			end);
		else
			print("[hidden] could not create a Sound to sanity-check");
		end
		local nparts, nother = 0, 0;
		for _, inst in ipairs(all) do
			local bp = false;
			pcall(function()
				bp = inst.is_a("BasePart");
			end);
			if bp then
				nparts = nparts + 1;
			else
				nother = nother + 1;
			end
		end
		print("[hidden] baseparts=" .. tostring(nparts) .. " other=" .. tostring(nother));
	end
	for _, inst in ipairs(all) do
		local isnd = false;
		pcall(function()
			isnd = inst.is_a("Sound");
		end);
		if isnd then
			found = found + 1;
			local nm, vol, playing, looped = "?", "?", "?", "?";
			pcall(function()
				nm = tostring(inst.Name);
			end);
			pcall(function()
				vol = tostring(inst.Volume);
			end);
			pcall(function()
				playing = tostring(inst.Playing);
			end);
			pcall(function()
				looped = tostring(inst.Looped);
			end);
			if verbose and found <= 30 then
				print("   sound: " .. nm .. " vol=" .. vol .. " playing=" .. playing .. " looped=" .. looped);
			end
			if apply then
				local a = pcall(function()
					inst.Volume = 0;
				end);
				local b = pcall(function()
					inst.stop();
				end);
				if a or b then
					hushed = hushed + 1;
				end
			end
		end
	end
	print("[hidden] map sounds found=" .. tostring(found) .. " hushed=" .. tostring(hushed));
	return hushed, found;
end

local function silence_map_sounds(verbose)
	local total, hushed = 0, 0;
	for _, tg in ipairs({ "bg_sound_part", "sound_alarm", "fire" }) do
		local ok, list = pcall(tags.get_tagged, tg);
		if ok and type(list) == "table" then
			for _, inst in ipairs(list) do
				total = total + 1;
				if verbose then
					local nm = "?";
					pcall(function()
						nm = tostring(inst.Name);
					end);
					print("[hidden] tagged " .. tg .. ": " .. nm);
				end
				if hush(inst) then
					hushed = hushed + 1;
				end
				local dok, desc = pcall(function()
					return inst.get_descendants();
				end);
				if dok and type(desc) == "table" then
					for _, d in ipairs(desc) do
						if verbose then
							local dn = "?";
							pcall(function()
								dn = tostring(d.Name);
							end);
							print("   child: " .. dn);
						end
						if hush(d) then
							hushed = hushed + 1;
						end
					end
				end
			end
		end
	end
	print("[hidden] map ambience: hushed " .. tostring(hushed) .. " sounds under " .. tostring(total) .. " tagged parts");
	return hushed, total;
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
	if not MAP_KEEPS_LIGHTS[CFG.map_name] then
		local kok, kerr = pcall(function()
			map.kill_map_lights();
		end);
		print("[hidden] kill_map_lights ok=" .. tostring(kok) .. " " .. tostring(kerr));
	else
		print("[hidden] " .. tostring(CFG.map_name) .. " keeps its own lights");
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
	else
		for _, k in ipairs(VAULT_KEYS) do
			if VAULT_DEFAULTS[k] ~= nil then
				set_var(k, VAULT_DEFAULTS[k]);
			end
		end
	end
	set_var("plr_jump_multiplier", 1);
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

	if CFG.silence_map_ambience then
		sweep_map_sounds(false, true);
		time.delay(4, function()
			sweep_map_sounds(false, true);
		end);
	end
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

local function send_ambience(p)
	if CFG.amb_rumble ~= "" then
		pcall(p.fire_client, "loop:" .. CFG.amb_rumble .. ":" .. tostring(CFG.amb_rumble_vol));
	end
	if CFG.amb_drone ~= "" then
		pcall(p.fire_client, "loop:" .. CFG.amb_drone .. ":" .. tostring(CFG.amb_drone_vol));
	end
	if CFG.amb_heartbeat ~= "" then
		pcall(p.fire_client, "hbloop:" .. CFG.amb_heartbeat);
	end
end

local function drop_flare(position, lifetime, color, force)
	if CFG.flares ~= true and not force then
		return;
	end
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
	time.delay(0.07, function()
		pcall(map.set_preset, CFG.lighting_preset);
	end);
	time.delay(0.16, function()
		pcall(map.set_preset, CFG.lightning_preset);
	end);
	time.delay(0.16 + CFG.lightning_time, function()
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
local clear_shimmer;
local update_shimmer;

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
	if CFG.ceasefire_off then
		set_var("plr_ceasefire", true);
		time.delay(CFG.spawn_grace, function()
			set_var("plr_ceasefire", false);
			notify("Grace over.");
		end);
	end

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

	state.hunter_hp = hunter_start_hp(#roster);
	print("[hidden] " .. tostring(#roster) .. " players -> hunter starts at " .. tostring(state.hunter_hp) .. " hp");
	state.loadout = {};
	state.ping_ready = {};
	for _, sp in pairs(roster) do
		if not is_hunter(sp.name) then
			apply_survivor_guns(sp);
		elseif CFG.strip_hunter_throwable2 then
			pcall(sp.set_weapon, "throwable2", "nothing");
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
	for _, ap in pairs(all_players()) do
		send_ambience(ap);
	end
	announce(
		string.format(
			"ROUND %d of %d  |  %s  |  Hidden %d - %d Survivors",
			state.rounds_on_map + 1,
			rounds_for(CFG.map_name),
			CFG.map_name,
			state.wins_hunter,
			state.wins_survivors
		),
		Color3.fromRGB(200, 40, 40)
	);
	notify("Lights out. One life. Kill the Hidden or survive the clock.");
	time.delay(3, function()
		local hp2 = find_player(state.hunter);
		if not hp2 then
			return;
		end
		local iok, hid = pcall(function()
			return hp2.player_id;
		end);
		if not iok or not hid then
			return;
		end
		for _, pl in pairs(all_players()) do
			pcall(pl.fire_client, "h:" .. tostring(hid));
		end
		print("[hidden] broadcast hunter player_id " .. tostring(hid));
	end);
	notify("Hidden: your guns are gone. Use your knife.");
end


local function round_time_for(mapname)
	local t = MAP_TIMES[mapname];
	if t then
		return t;
	end
	return CFG.round_seconds;
end

local function split_maps()
	local out = {};
	for token in string.gmatch(CFG.map_list, "[^,%s]+") do
		table.insert(out, token);
	end
	return out;
end

local function rotate_map()
	local maps = split_maps();
	if #maps == 0 then
		return false;
	end
	state.map_index = state.map_index + 1;
	if state.map_index > #maps then
		state.map_index = 1;
	end
	local nextmap = maps[state.map_index];
	CFG.map_name = nextmap;
	CFG.round_seconds = round_time_for(nextmap);
	announce("Next map: " .. nextmap .. " (" .. tostring(math.floor(CFG.round_seconds / 60)) .. " min rounds)", Color3.fromRGB(120, 180, 255));
	try(map.set_map, nextmap);
	time.delay(2, function()
		suppress_gamemode();
		setup_world();
	end);
	time.delay(5, suppress_gamemode);
	time.delay(9, function()
		suppress_gamemode();
		setup_world();
	end);
	print("[hidden] rotated to map " .. nextmap);
	return true;
end

end_round = function(reason, color)
	if state.phase ~= "live" then
		return;
	end
	state.phase = "intermission";
	state.timer = CFG.intermission_seconds;
	state.rounds_on_map = state.rounds_on_map + 1;
	if CFG.rotate_maps and state.rounds_on_map >= rounds_for(CFG.map_name) then
		state.rounds_on_map = 0;
		if rotate_map() then
			state.timer = CFG.map_change_pause;
		end
	end
	state.latched = false;
	state.latch_player = nil;
	state.stagger = 0;
	if clear_shimmer then
		clear_shimmer();
	end
	announce(reason, color or Color3.fromRGB(240, 200, 60));
	announce("The Hidden was " .. tostring(state.hunter), Color3.fromRGB(180, 180, 180));
	set_var("sv_spawning_enabled", false);
	set_spawn_reason("Intermission - next round starting shortly");
	for _, p in pairs(all_players()) do
		try(p.set_camera_mode, "Default");
		try(p.set_speed, CFG.survivor_speed);
	end
end

update_shimmer = function(hunter_pos)
	if not CFG.shimmer then
		return;
	end
	if not hunter_pos then
		return;
	end

	if not state.shimmer_part then
		local ok, part = pcall(create_instance, "Part");
		if not ok or not part then
			return;
		end
		pcall(function()
			part.Name = "hidden_shimmer";
			part.Anchored = true;
			part.CanCollide = false;
			part.CastShadow = false;
			part.Material = Enum.Material.Glass;
			part.Color = Color3.fromRGB(180, 200, 220);
			part.Size = Vector3.new(CFG.shimmer_size, CFG.shimmer_size * 1.6, CFG.shimmer_size);
			part.Transparency = 1;
			part.Parent = get_map_root();
		end);
		state.shimmer_part = part;
	end

	local moved = 0;
	if state.shimmer_last then
		moved = (hunter_pos - state.shimmer_last).Magnitude;
	end
	state.shimmer_last = hunter_pos;

	local t = 1;
	if moved > CFG.shimmer_min_move then
		local span = CFG.shimmer_max_move - CFG.shimmer_min_move;
		local frac = (moved - CFG.shimmer_min_move) / span;
		if frac > 1 then
			frac = 1;
		end
		t = 1 - ((1 - CFG.shimmer_min_transparency) * frac);
	end

	pcall(function()
		state.shimmer_part.Position = hunter_pos + Vector3.new(0, CFG.shimmer_height, 0);
		state.shimmer_part.Transparency = t;
	end);
end

clear_shimmer = function()
	if state.shimmer_part then
		pcall(function()
			state.shimmer_part.destroy();
		end);
		state.shimmer_part = nil;
		state.shimmer_last = nil;
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
	if state.pounce_ready > 0 then
		state.pounce_ready = state.pounce_ready - dt;
	end
	if state.radio_ready > 0 then
		state.radio_ready = state.radio_ready - dt;
	end
	for nm, v in pairs(state.ping_ready) do
		if v > 0 then
			state.ping_ready[nm] = v - dt;
		end
	end
	if state.latched then
		state.latch_time = state.latch_time + dt;
		local remain = CFG.latch_max_seconds - state.latch_time;
		if state.latch_player and state.latch_pos then
			pcall(state.latch_player.set_position, state.latch_pos);
		end
		if not state.latch_warned and remain <= CFG.latch_warn_at then
			state.latch_warned = true;
			if state.latch_player then
				pcall(state.latch_player.fire_client, "note:dropping in " .. tostring(CFG.latch_warn_at) .. "s");
			end
		end
		if state.latch_time >= CFG.latch_max_seconds then
			state.latched = false;
			state.latch_player = nil;
			state.latch_ready = CFG.latch_cooldown;
			if hunter_player then
				try(hunter_player.set_speed, CFG.hunter_speed);
			end
			notify("The Hidden drops.");
		end
	end
	if state.screech_ready > 0 then
		state.screech_ready = state.screech_ready - dt;
	end
	if state.stagger > 0 then
		state.stagger = state.stagger - dt;
		for _, sp in ipairs(alive_survivors()) do
			try(sp.set_speed, CFG.screech_speed);
		end
		if state.stagger <= 0 then
			for _, sp in ipairs(alive_survivors()) do
				try(sp.set_speed, CFG.survivor_speed);
			end
		end
	end
	update_shimmer(state.positions[state.hunter]);
	state.sweep_timer = state.sweep_timer - dt;
	if state.sweep_timer <= 0 and CFG.sweeps == true then
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
		local since = CFG.grace_seconds - state.grace;
		if state.grace > 0 and since < CFG.death_ignore_seconds then
			return;
		end
		local name, position, killer_data = parse_death(...);
		if not name then
			return;
		end
		if state.latched and name == state.hunter then
			state.latched = false;
			state.latch_player = nil;
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
					state.wins_survivors = state.wins_survivors + 1;
			state.streak = 0;
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
		if CFG.reveal_on_kill > 0 then
			for _, pl in pairs(all_players()) do
				pcall(pl.fire_client, "reveal:" .. tostring(CFG.reveal_on_kill));
			end
		end
		local remaining = #alive_survivors();
		if remaining == 0 then
			if not CFG.solo_test then
					state.wins_hunter = state.wins_hunter + 1;
				state.streak = state.streak + 1;
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
				if healed > CFG.hunter_hp_max then
					healed = CFG.hunter_hp_max;
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
			print("[hidden] event ignored - gamemode not running (use hstart)");
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
		local ev = nil;
		local atype = type(args);
		print("[hidden] RAW args type=" .. atype .. " value=" .. string.sub(tostring(args), 1, 80));
		if atype == "table" then
			for k, v in pairs(args) do
				print("   arg[" .. tostring(k) .. "] = (" .. type(v) .. ") " .. string.sub(tostring(v), 1, 60));
				if type(v) == "string" and not ev then
					ev = v;
				end
			end
			if args.event then
				ev = tostring(args.event);
			end
		elseif atype == "string" then
			ev = args;
		end
		if not ev then
			ev = "?";
		end
		print("[hidden] CLIENT EVENT from=" .. tostring(name) .. " (" .. ptype .. ") event=" .. ev .. " hunter=" .. tostring(state.hunter));
		local testing = false;
		if
			CFG.test_abilities
			and not state.running
			and tostring(name) == tostring(sharedvars.vip_owner)
		then
			testing = true;
		end
		local ev0 = ev;
		if state.running and state.phase == "live" and name ~= state.hunter and ev0 ~= "ping" then
			print("[hidden] ability blocked - " .. tostring(name) .. " is not the hunter");
			return;
		end
		if not state.running and not testing then
			print("[hidden] ignored - gamemode not running (use hstart)");
			return;
		end
		if name ~= state.hunter and not testing then
			print("[hidden] ignored - sender is not the hunter");
			return;
		end

		local ev2 = ev;
		if type(ev2) == "string" and string.sub(ev2, 1, 7) == "pounce:" then
			if state.pounce_ready > 0 then
				print("[hidden] pounce on cooldown " .. tostring(math.ceil(state.pounce_ready)) .. "s");
				return;
			end
			local p = find_player(name);
			if not p then
				return;
			end
			local dx, dy, dz = string.match(ev2, "pounce:([^,]+),([^,]+),([^,]+)");
			dx, dy, dz = tonumber(dx), tonumber(dy), tonumber(dz);
			if not dx then
				print("[hidden] bad pounce payload: " .. tostring(ev2));
				return;
			end
			local ok, pos = pcall(p.get_position);
			if not ok or not pos then
				return;
			end
			local dir = Vector3.new(dx, dy, dz);
			state.pounce_ready = CFG.pounce_cooldown;
			local moved = false;
			if not moved then
				local dist = CFG.pounce_distance;
				local rok, hit = pcall(query.raycast, pos, dir * dist);
				if rok and type(hit) == "table" and hit.position then
					local hd = (hit.position - pos).Magnitude;
					if hd < dist then
						dist = hd - 3;
					end
				end
				if dist < 2 then
					dist = 2;
				end
				local target = pos + (dir * dist) + Vector3.new(0, CFG.pounce_up, 0);
				local sok, serr = pcall(p.set_position, target);
				print("[hidden] pounce teleport dist=" .. tostring(dist) .. " ok=" .. tostring(sok) .. " err=" .. tostring(serr));
			end
		elseif ev2 == "ping" then
			if state.phase ~= "live" then
				return;
			end
			if is_hunter(name) then
				return;
			end
			local ready = state.ping_ready[name] or 0;
			if ready > 0 then
				pcall(find_player(name).fire_client, "note:ping ready in " .. tostring(math.ceil(ready)) .. "s");
				return;
			end
			local me = find_player(name);
			local hpos = state.positions[state.hunter];
			local mypos = state.positions[name];
			if not me or not hpos or not mypos then
				return;
			end
			state.ping_ready[name] = CFG.ping_cooldown;
			local dir, dist = bearing_from(mypos, hpos);
			pcall(me.fire_client, string.format("note:CONTACT %s  %dm", dir, math.floor(dist / 3)));
			if dist <= CFG.ping_reveal_range then
				pcall(me.fire_client, "flash:" .. tostring(CFG.ping_reveal_time));
				print("[hidden] ping close contact (" .. tostring(math.floor(dist)) .. " studs) - revealing");
			end
			if CFG.ping_sfx ~= "" then
				pcall(me.fire_client, "sfx:" .. CFG.ping_sfx);
			end
			print("[hidden] ping by " .. tostring(name) .. " -> " .. dir);
		elseif ev2 == "radio" then
			if state.radio_ready and state.radio_ready > 0 then
				print("[hidden] radio on cooldown " .. tostring(math.ceil(state.radio_ready)) .. "s");
				return;
			end
			state.radio_ready = CFG.radio_cooldown;
			local rp = find_player(name);
			local payload = "sfx:1359426178";
			if rp then
				local pok, ppos = pcall(rp.get_position);
				if pok and ppos then
					payload = string.format("sfx:1359426178:%.1f,%.1f,%.1f", ppos.X, ppos.Y, ppos.Z);
				end
			end
			for _, pl in pairs(all_players()) do
				pcall(pl.fire_client, payload);
			end
			print("[hidden] radio by " .. tostring(name) .. " -> " .. payload);
		elseif ev2 == "screech" then
			local res = commands_ref.screech("", name);
			print("[hidden] screech by " .. tostring(name) .. ": " .. tostring(res));
		elseif ev2 == "latch_toggle" or ev2 == "latch" or ev2 == "latch_on" or ev2 == "latch_off" then
			local p = find_player(name);
			if not p then
				return;
			end
			if not CFG.latch_enabled then
				return;
			end
			local want_on = not state.latched;
			if ev2 == "latch_on" then
				want_on = true;
			elseif ev2 == "latch_off" then
				want_on = false;
			end
			if want_on and state.latch_ready <= 0 then
				local ok, pos = pcall(p.get_position);
				if ok and pos then
					state.latched = true;
					state.latch_pos = pos;
					state.latch_player = p;
					state.latch_time = 0;
					state.latch_warned = false;
					print("[hidden] latched at " .. tostring(pos));
				end
			else
				state.latched = false;
				state.latch_player = nil;
				state.latch_ready = CFG.latch_cooldown;
				if is_hunter(name) then
					try(p.set_speed, CFG.hunter_speed);
				else
					try(p.set_speed, CFG.survivor_speed);
				end
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
	CFG.round_seconds = round_time_for(CFG.map_name);
	if CFG.random_start_map then
		local maps = split_maps();
		if #maps > 0 then
			state.map_index = math.random(1, #maps);
			CFG.map_name = maps[state.map_index];
			print("[hidden] random starting map: " .. CFG.map_name);
		end
	end
	state.rounds_on_map = 0;
	CFG.round_seconds = round_time_for(CFG.map_name);
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
		if not CFG.test_abilities then
			return "no live round";
		end
		local me = find_player(sender or state.hunter or sharedvars.vip_owner);
		if me then
			local ok, pos = pcall(me.get_position);
			if ok and pos then
				drop_flare(pos, 4, Color3.fromRGB(255, 40, 40), true);
			end
		end
		lightning_flash();
		notify("SCREECH (test)");
		return "test screech fired";
	end
	if state.screech_ready > 0 then
		return string.format("screech on cooldown, %ds", math.ceil(state.screech_ready));
	end
	state.screech_ready = CFG.screech_cooldown;
	local marked = 0;
	for _, p in ipairs(alive_survivors()) do
		local pos = state.positions[p.name];
		if pos then
			marked = marked + 1;
		end
	end
	state.stagger = CFG.screech_stagger;
	local hp3 = find_player(state.hunter);
	if hp3 then
		pcall(hp3.fire_client, "hlall:" .. tostring(CFG.screech_reveal));
	end
	if CFG.screech_flash then
		lightning_flash();
	end
	if CFG.screech_sfx ~= "" then
		local spayload = "sfx:" .. CFG.screech_sfx;
		if hunter_pos then
			spayload = string.format("sfx:%s:%.1f,%.1f,%.1f", CFG.screech_sfx, hunter_pos.X, hunter_pos.Y, hunter_pos.Z);
		end
		for _, sp in ipairs(alive_survivors()) do
			pcall(sp.fire_client, spayload);
		end
	end
	notify("SCREECH - it knows where you are. MOVE.");
	return string.format("marked %d survivors", marked);
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

commands.hlatch = function()
	local p = find_player(state.hunter);
	if not p then
		return "no hunter in play";
	end
	if state.latched then
		state.latched = false;
		state.latch_player = nil;
		state.latch_ready = CFG.latch_cooldown;
		try(p.set_speed, CFG.hunter_speed);
		return "unlatched";
	end
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return "could not read hunter position";
	end
	state.latched = true;
	state.latch_pos = pos;
	state.latch_player = p;
	state.latch_time = 0;
	state.latch_warned = false;
	return "latched at " .. tostring(pos);
end

local PART_TAGS = { "fix_raycastfilters_humanoidrootpart", "hitbox" };

local function in_workspace(inst)
	local ok, res = pcall(function()
		return inst.is_in_workspace();
	end);
	if ok then
		return res and true or false;
	end
	return false;
end

local function hrp_for(p, verbose)
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return nil;
	end
	local best, bestd = nil, 25;
	for _, tg in ipairs(PART_TAGS) do
		local lok, list = pcall(tags.get_tagged, tg);
		if lok and type(list) == "table" then
			for i, inst in ipairs(list) do
				local iw = in_workspace(inst);
				local pok, ipos = pcall(function()
					return inst.Position;
				end);
				local d = -1;
				if pok and ipos then
					d = (ipos - pos).Magnitude;
				end
				if verbose then
					print("   " .. tg .. "[" .. tostring(i) .. "] in_workspace=" .. tostring(iw) .. " dist=" .. tostring(d));
				end
				if iw and pok and ipos and d >= 0 and d < bestd then
					best, bestd = inst, d;
				end
			end
		end
	end
	return best, bestd;
end

local function impulse_player(p, vec)
	local hrp = hrp_for(p);
	if not hrp then
		return false, "no humanoid_root_part";
	end
	if CFG.take_ownership then
		local sok, serr = pcall(function()
			hrp.set_network_owner(nil);
		end);
		print("[hidden] set_network_owner(nil) ok=" .. tostring(sok) .. " err=" .. tostring(serr));
	end
	local ok, err = pcall(function()
		hrp.apply_impulse(vec);
	end);
	if CFG.take_ownership then
		time.delay(CFG.ownership_return, function()
			pcall(function()
				hrp.set_network_owner(p.name);
			end);
		end);
	end
	return ok, err;
end


commands.hvis = function()
	local hp = find_player(state.hunter);
	if not hp then
		return "no hunter in play";
	end
	local iok, hid = pcall(function()
		return hp.player_id;
	end);
	if not iok or not hid then
		return "could not read player_id";
	end
	local sent = 0;
	for _, pl in pairs(all_players()) do
		local ok = pcall(pl.fire_client, "h:" .. tostring(hid));
		if ok then
			sent = sent + 1;
		end
		print("[hidden] sent h:" .. tostring(hid) .. " to " .. tostring(pl.name) .. " ok=" .. tostring(ok));
	end
	return "hunter=" .. tostring(state.hunter) .. " player_id=" .. tostring(hid) .. " sent to " .. tostring(sent);
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

commands.hmapcheck = function()
	local valid = {};
	local ok = pcall(function()
		for nm in pairs(map.get_maps()) do
			valid[nm] = true;
		end
	end);
	if not ok then
		pcall(function()
			for nm in map.get_maps() do
				valid[nm] = true;
			end
		end);
	end
	local count = 0;
	for _ in pairs(valid) do
		count = count + 1;
	end
	if count == 0 then
		return "map.get_maps() returned nothing usable";
	end
	print("[hidden] " .. tostring(count) .. " maps known to the game");
	local good, bad = "", "";
	for _, m in ipairs(split_maps()) do
		if valid[m] then
			good = good .. m .. " ";
		else
			bad = bad .. m .. " ";
		end
	end
	print("[hidden] names map.get_maps() reports:");
	local line = "";
	for nm in pairs(valid) do
		line = line .. nm .. ", ";
		if string.len(line) > 80 then
			print("   " .. line);
			line = "";
		end
	end
	if line ~= "" then
		print("   " .. line);
	end
	return "get_maps reported " .. tostring(count) .. " names (set_map may accept others)";
end

commands.hquiet = function(arg)
	local apply = true;
	if arg and arg:match("list") then
		apply = false;
	end
	local hushed, found = sweep_map_sounds(true, apply);
	return "found " .. tostring(found) .. " sounds, hushed " .. tostring(hushed);
end

commands.hamb = function()
	local sent = 0;
	for _, pl in pairs(all_players()) do
		send_ambience(pl);
		sent = sent + 1;
	end
	return "ambience pushed to " .. tostring(sent) .. " clients";
end

commands.hsfx = function(arg)
	local id = "1359426178";
	if arg and arg:match("%d+") then
		id = arg:match("%d+");
	end
	print("[hidden] hsfx sending id " .. id);
	local sent = 0;
	for _, pl in pairs(all_players()) do
		local ok = pcall(pl.fire_client, "sfx:" .. id);
		if ok then
			sent = sent + 1;
		end
	end
	return "sent sfx " .. id .. " to " .. tostring(sent) .. " clients";
end

commands.hgive = function(arg)
	local g = load_guns();
	if not g then
		return "guns not loaded";
	end
	local target = sharedvars.vip_owner;
	local p = find_player(target);
	if not p then
		return "host not found";
	end

	local slot, idx = nil, nil;
	if arg then
		slot, idx = arg:match("^%s*(%a+)%s*(%d*)");
	end

	if not slot or slot == "" then
		local pr = g.primary[math.random(1, #g.primary)];
		local se = g.secondary[math.random(1, #g.secondary)];
		give_gun(p, "primary", pr);
		give_gun(p, "secondary", se);
		pcall(p.set_weapon, "throwable1", "nothing");
		pcall(p.set_weapon, "throwable2", "nothing");
		return "gave " .. pr.label .. " + " .. se.label;
	end

	local list = g.primary;
	local sname = "primary";
	if string.sub(string.lower(slot), 1, 1) == "s" then
		list = g.secondary;
		sname = "secondary";
	end
	local i = tonumber(idx) or 1;
	if i < 1 or i > #list then
		return sname .. " index must be 1-" .. tostring(#list);
	end
	give_gun(p, sname, list[i]);
	return "gave " .. sname .. " " .. tostring(i) .. ": " .. list[i].name .. " (" .. list[i].label .. ")";
end

commands.hguns2 = function()
	local g = load_guns();
	if not g then
		return "guns not loaded";
	end
	for _, e in ipairs(g.primary) do
		print("   primary: " .. e.name .. " (" .. e.label .. ")");
	end
	for _, e in ipairs(g.secondary) do
		print("   secondary: " .. e.name .. " (" .. e.label .. ")");
	end
	return tostring(#g.primary) .. " primaries, " .. tostring(#g.secondary) .. " secondaries";
end

commands.hmaptime = function(arg)
	local mapname, secs = nil, nil;
	if arg then
		mapname, secs = arg:match("^%s*(%S+)%s+(%d+)");
	end
	if not mapname then
		print("[hidden] map round times:");
		for k, v in pairs(MAP_TIMES) do
			print("   " .. k .. " = " .. tostring(v) .. "s");
		end
		return "current map " .. CFG.map_name .. " = " .. tostring(CFG.round_seconds) .. "s";
	end
	MAP_TIMES[mapname] = tonumber(secs);
	if mapname == CFG.map_name then
		CFG.round_seconds = tonumber(secs);
	end
	return mapname .. " = " .. secs .. "s";
end

commands.hmaps = function(arg)
	if arg and arg:match("%S") then
		CFG.map_list = arg:match("^%s*(.-)%s*$");
		state.map_index = 0;
		return "map_list = " .. CFG.map_list;
	end
	local maps = {};
	if config and config.maps then
		for name in pairs(config.maps) do
			table.insert(maps, name);
		end
		table.sort(maps);
		print("[hidden] maps available in this build:");
		local line = "";
		for _, m in ipairs(maps) do
			line = line .. m .. ", ";
			if string.len(line) > 80 then
				print("   " .. line);
				line = "";
			end
		end
		if line ~= "" then
			print("   " .. line);
		end
	end
	return "rotation=" .. tostring(CFG.rotate_maps) .. " list=" .. CFG.map_list;
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

for cname, cfn in pairs(commands) do
	local original = cfn;
	commands[cname] = function(...)
		local ok, res = pcall(original, ...);
		if ok then
			print("[hidden] " .. tostring(cname) .. " -> " .. tostring(res));
		else
			warn("[hidden] " .. tostring(cname) .. " ERROR: " .. tostring(res));
		end
		return res;
	end;
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
