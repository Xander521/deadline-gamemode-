local CFG = { base_mags = 1, charges = 3, restore_after = 0.6, map = "test_ascendance" };

local STATE = { level = {}, used = 0 };

local AmmoCrate = {};
AmmoCrate.__index = AmmoCrate;

function AmmoCrate.new(instance)
	return setmetatable({ instance = instance }, AmmoCrate);
end

function AmmoCrate:interact(player)
	if STATE.used >= CFG.charges then
		pcall(player.fire_client, "note:AMMO CRATE EMPTY");
		print("[c3] crate empty, refused " .. tostring(player.name));
		return;
	end

	local wok, w = pcall(player.get_weapon_data_from_character, "primary");
	if not wok or type(w) ~= "table" or not w.client_data or not w.client_data.name then
		print("[c3] could not read primary for " .. tostring(player.name));
		return;
	end

	local nm = player.name;
	local want = (STATE.level[nm] or CFG.base_mags) + 1;
	STATE.level[nm] = want;
	STATE.used = STATE.used + 1;

	pcall(function()
		sharedvars.plr_magazines = want;
	end);
	local sok = pcall(player.set_weapon, "primary", w.client_data.name, w.client_data.setup);
	print("[c3] " .. nm .. " -> " .. tostring(want) .. " mags, regave " .. tostring(w.client_data.name) .. " ok=" .. tostring(sok));

	time.delay(CFG.restore_after, function()
		pcall(function()
			sharedvars.plr_magazines = CFG.base_mags;
		end);
	end);

	pcall(player.fire_client, "note:AMMO  " .. tostring(want) .. " mags  (" .. tostring(CFG.charges - STATE.used) .. " left)");
end

register_interactable("ammo_refill", AmmoCrate);
register_interactable("capture_refill", AmmoCrate);
register_interactable("hidden_crate", AmmoCrate);

shared.c3 = {};

shared.c3.reset = function()
	STATE.level = {};
	STATE.used = 0;
	pcall(function()
		sharedvars.plr_magazines = CFG.base_mags;
	end);
	return "charges and magazine levels reset";
end

shared.c3.status = function()
	return "used=" .. tostring(STATE.used) .. "/" .. tostring(CFG.charges)
		.. " plr_magazines=" .. tostring(sharedvars.plr_magazines);
end

shared.c3.base = function(n)
	CFG.base_mags = tonumber(n) or 1;
	pcall(function()
		sharedvars.plr_magazines = CFG.base_mags;
	end);
	return "base mags = " .. tostring(CFG.base_mags);
end

shared.c3.spawn = function()
	local p = players.get(sharedvars.vip_owner);
	if not p then
		return "host not found";
	end
	local ok, pos = pcall(p.get_position);
	if not ok or not pos then
		return "no position";
	end
	local mok, mdl = pcall(create_instance, "Model");
	local pok, part = pcall(create_instance, "Part");
	if not mok or not pok then
		return "could not create model/part";
	end
	local bad = "";
	local function sp(k, f)
		local o = pcall(f);
		if not o then
			bad = bad .. k .. " ";
		end
	end
	sp("Anchored", function()
		part.Anchored = true;
	end);
	sp("Size", function()
		part.Size = Vector3.new(3, 2, 2);
	end);
	sp("Color", function()
		part.Color = Color3.fromRGB(70, 80, 60);
	end);
	sp("Position", function()
		part.Position = pos + Vector3.new(0, 1, 0);
	end);
	sp("Name", function()
		part.Name = "hidden_ammo_crate";
	end);
	sp("PartParent", function()
		part.Parent = mdl;
	end);
	sp("Primary", function()
		mdl.PrimaryPart = part;
	end);
	sp("attr", function()
		mdl.set_attribute("interactable_type", "hidden_crate");
	end);
	local aok, att = pcall(create_instance, "Attachment");
	if aok and att then
		sp("attName", function()
			att.Name = "display_point";
		end);
		sp("attParent", function()
			att.Parent = part;
		end);
	end
	sp("ModelParent", function()
		mdl.Parent = get_map_root();
	end);
	print("[c3] crate spawned" .. (bad ~= "" and (" FAILED: " .. bad) or ""));
	return "crate spawned - walk up and hold F";
end

print("[c3] registered ammo_refill / capture_refill / hidden_crate");
print("[c3] IMPORTANT: reload the map for interactables to bind - map.set_map(\"" .. CFG.map .. "\")");
print("[c3] then: shared.c3.base(1) / .spawn() / .status() / .reset()");
