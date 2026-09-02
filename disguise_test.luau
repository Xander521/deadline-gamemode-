local G = require("https://raw.githubusercontent.com/Xander521/deadline-gamemode-/main/guns_2.luau");

local me = sharedvars.vip_owner;
local p = players.get(me);
if not p then
	warn("[dtest] host not found");
	return;
end

local function give(entry, label)
	local ok, err = pcall(p.set_weapon, "secondary", entry.name, entry.data);
	print("[dtest] " .. label .. " -> " .. entry.name .. " ok=" .. tostring(ok) .. " err=" .. tostring(err));
	time.delay(1.5, function()
		local rok, w = pcall(p.get_weapon_data_from_character, "secondary");
		local got = "?";
		if rok and type(w) == "table" and w.client_data and w.client_data.name then
			got = tostring(w.client_data.name);
		end
		print("[dtest] secondary now reads: " .. got);
	end);
end

shared.dtest = {
	nomag_tt33 = function()
		if not G.disguise_alt then
			return "guns_2 has no disguise_alt entry";
		end
		give(G.disguise_alt, "TT33 no magazine");
		return "sent TT33 without magazine - try firing it";
	end,
	nomag_edc = function()
		if not G.disguise then
			return "guns_2 has no disguise entry";
		end
		give(G.disguise, "EDC_X9 no magazine");
		return "sent EDC_X9 without magazine - try firing it";
	end,
	normal = function()
		for _, e in ipairs(G.secondary) do
			if e.name == "TT33" then
				give(e, "TT33 with magazine");
				return "sent normal TT33 - should fire";
			end
		end
		return "TT33 not found in secondaries";
	end,
	clear = function()
		pcall(p.set_weapon, "secondary", "nothing");
		return "secondary cleared";
	end,
	slot = function()
		local ok, sl = pcall(p.get_active_slot);
		return "active slot: " .. tostring(ok and sl or "?");
	end,
};

print("[dtest] ready. shared.dtest.nomag_tt33() / .nomag_edc() / .normal() / .clear() / .slot()");
