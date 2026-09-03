local CFG = {
	charges = 3,
	radius = 9,
	base_mags = 1,
	base_spare = 10,
	mag_step = 1,
	shell_step = 5,
	restore_after = 0.6,
	use_cooldown = 1,
	break_sound = "98898191624884",
	destructible = true,
};

local SHOTGUNS = { MP133 = true, Remington870 = true, ["Saiga-12"] = true, M1014 = true, SPAS12 = true };
local C = { pos = nil, left = 0, level = {}, part = nil };

local function bump(player)
	local wok, w = pcall(player.get_weapon_data_from_character, "primary");
	if not wok or type(w) ~= "table" or not w.client_data or not w.client_data.name then
		return false, "could not read primary";
	end
	local wname = tostring(w.client_data.name);
	local isshotgun = SHOTGUNS[wname] == true;
	local step = isshotgun and CFG.shell_step or CFG.mag_step;
	local nm2 = player.name;
	C.level[nm2] = (C.level[nm2] or 0) + 1;
	local base = isshotgun and CFG.base_spare or CFG.base_mags;
	local target = base + (step * C.level[nm2]);
	local keys = isshotgun and { "plr_spare_rounds" } or { "plr_magazines", "plr_drum_magazines" };
	for _, key in ipairs(keys) do
		pcall(function()
			sharedvars[key] = target;
		end);
	end
	print("[c5] " .. wname .. " (" .. (isshotgun and "shotgun" or "mag") .. ") use " .. tostring(C.level[nm2]) .. " -> " .. tostring(target));
	local sok = pcall(player.set_weapon, "primary", w.client_data.name, w.client_data.setup);
	time.delay(CFG.restore_after, function()
		pcall(function()
			sharedvars.plr_magazines = CFG.base_mags;
		end);
		pcall(function()
			sharedvars.plr_spare_rounds = CFG.base_spare;
		end);
	end);
	return sok, w.client_data.name;
end

shared.c5 = {};

shared.c5.spawn = function()
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return "no position";
	end
	if C.part then
		pcall(function()
			C.part.destroy();
		end);
	end
	local cok, part = pcall(create_instance, "Part");
	if not cok or not part then
		return "could not create crate";
	end
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
	sp("Color", function()
		part.Color = Color3.fromRGB(75, 85, 60);
	end);
	sp("Material", function()
		part.Material = Enum.Material.Metal;
	end);
	sp("Density", function()
		part.CustomPhysicalProperties = PhysicalProperties.new(0.33, 0.5, 0.3);
	end);
	if CFG.destructible then
		sp("tag", function()
			part.add_tag("voxel_destructible");
		end);
	end
	sp("Name", function()
		part.Name = "ammo_crate";
	end);
	sp("Position", function()
		part.Position = pos + Vector3.new(0, 2, 0);
	end);
	sp("Anchored", function()
		part.Anchored = false;
	end);
	sp("Parent", function()
		part.Parent = get_map_root();
	end);
	C.part = part;
	C.pos = pos;
	C.left = CFG.charges;
	C.level = {};
	for _, pl in pairs(players.get_all()) do
		pcall(pl.fire_client, string.format("crate:%.1f,%.1f,%.1f:%d", pos.X, pos.Y, pos.Z, CFG.radius));
	end
	print("[c5] crate spawned" .. (bad ~= "" and (" FAILED: " .. bad) or ""));
	return "crate spawned with " .. tostring(C.left) .. " charges - walk up and press F";
end

local LASTUSE = 0;

shared.c5.use = function(who)
	local name = who or sharedvars.vip_owner;
	if tick() - LASTUSE < CFG.use_cooldown then
		return "crate on cooldown";
	end
	LASTUSE = tick();
	local p = players.get(name);
	if not p then
		return "no player";
	end
	if not C.pos then
		return "no crate";
	end
	if C.left <= 0 then
		pcall(p.fire_client, "note:CRATE EMPTY");
		return "crate empty";
	end
	local ok, pos = pcall(p.get_position);
	if ok and pos and (pos - C.pos).Magnitude > CFG.radius then
		return "too far";
	end
	C.left = C.left - 1;
	local sok, nm = bump(p);
	pcall(p.fire_client, "note:AMMO RESUPPLIED  (" .. tostring(C.left) .. " left)");
	if C.left <= 0 then
		for _, pl in pairs(players.get_all()) do
			pcall(pl.fire_client, "crateoff");
		end
		time.delay(1, function()
			if C.part then
				pcall(function()
					C.part.destroy();
				end);
				C.part = nil;
			end
		end);
	end
	return "used, " .. tostring(C.left) .. " left (" .. tostring(nm) .. ")";
end

shared.c5.clear = function()
	if C.part then
		pcall(function()
			C.part.destroy();
		end);
	end
	C.part = nil;
	C.pos = nil;
	for _, pl in pairs(players.get_all()) do
		pcall(pl.fire_client, "crateoff");
	end
	return "crate cleared";
end

local WATCH = 0;
time.heartbeat("crate_watch", function(dt)
	if not C.part then
		return;
	end
	WATCH = WATCH - dt;
	if WATCH > 0 then
		return;
	end
	WATCH = 0.5;
	local ok = pcall(function()
		return C.part.Position;
	end);
	if ok then
		return;
	end
	print("[c5] crate destroyed");
	local pos = C.pos;
	C.part = nil;
	C.pos = nil;
	C.left = 0;
	for _, pl in pairs(players.get_all()) do
		pcall(pl.fire_client, "crateoff");
		if pos and CFG.break_sound ~= "" then
			pcall(pl.fire_client, string.format("sfx:%s:%.1f,%.1f,%.1f", CFG.break_sound, pos.X, pos.Y, pos.Z));
		end
	end
end);

shared.c5.base = function(mags, shells)
	CFG.base_mags = tonumber(mags) or 1;
	CFG.base_spare = tonumber(shells) or 10;
	pcall(function()
		sharedvars.plr_magazines = CFG.base_mags;
	end);
	pcall(function()
		sharedvars.plr_spare_rounds = CFG.base_spare;
	end);
	pcall(function()
		sharedvars.plr_drum_magazines = CFG.base_mags;
	end);
	return "base set: mags=" .. tostring(CFG.base_mags) .. " shells=" .. tostring(CFG.base_spare) .. " - RESPAWN to apply";
end

shared.c5.vars = function()
	for _, k in ipairs({ "plr_magazines", "plr_spare_rounds", "plr_drum_magazines" }) do
		print("   " .. k .. " = " .. tostring(sharedvars[k]));
	end
	return "current ammo sharedvars printed";
end

shared.c5.status = function()
	return "crate=" .. tostring(C.pos ~= nil) .. " charges=" .. tostring(C.left);
end

on_client_event:Connect(function(player, args)
	local a = args;
	if type(args) == "table" then
		for _, v in pairs(args) do
			if type(v) == "string" then
				a = v;
				break;
			end
		end
	end
	if a ~= "crate_use" then
		return;
	end
	local nm = player;
	if type(player) == "table" and player.name then
		nm = player.name;
	end
	print("[c5] " .. tostring(nm) .. " -> " .. tostring(shared.c5.use(nm)));
end);

print("[c5] ready: shared.c5.spawn() / .use() / .status() / .clear()");
