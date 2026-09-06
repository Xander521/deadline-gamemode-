shared.zt6 = {};

local WORDS = { "spawn", "zone", "ceasefire", "bound", "team", "restrict", "area", "region", "volume" };

local function matches(s)
	local low = string.lower(tostring(s));
	for _, w in ipairs(WORDS) do
		if string.find(low, w, 1, true) then
			return true;
		end
	end
	return false;
end

shared.zt6.search = function(mapname)
	local ok, mc = pcall(function()
		return config.maps.MAP_CONFIGURATION;
	end);
	if not ok or type(mc) ~= "table" then
		return "MAP_CONFIGURATION unavailable";
	end

	local target = mc;
	local label = "ALL MAPS";
	if mapname then
		local key = tostring(mapname);
		if mc[key] then
			target = mc[key];
			label = key;
		else
			for k, v in pairs(mc) do
				if string.find(string.lower(tostring(k)), string.lower(key), 1, true) then
					target = v;
					label = tostring(k);
					break;
				end
			end
		end
	end

	print("[zt6] searching " .. label .. " for spawn/zone/ceasefire keys");
	local hits = 0;
	local budget = 4000;

	local function walk(t, path, depth)
		if depth <= 0 or budget <= 0 then
			return;
		end
		for k, v in pairs(t) do
			budget = budget - 1;
			if budget <= 0 then
				return;
			end
			local here = path .. "." .. tostring(k);
			if matches(k) then
				hits = hits + 1;
				if hits <= 40 then
					print("   " .. here .. "  (" .. type(v) .. ")" .. (type(v) ~= "table" and (" = " .. string.sub(tostring(v), 1, 40)) or ""));
				end
			end
			if type(v) == "table" then
				walk(v, here, depth - 1);
			elseif type(v) == "string" and matches(v) then
				hits = hits + 1;
				if hits <= 40 then
					print("   " .. here .. " = " .. string.sub(tostring(v), 1, 50));
				end
			end
		end
	end

	walk(target, label, 5);
	print("[zt6] " .. tostring(hits) .. " matches");
	return "search done";
end

shared.zt6.top = function(mapname)
	local ok, mc = pcall(function()
		return config.maps.MAP_CONFIGURATION;
	end);
	if not ok then
		return "unavailable";
	end
	local key = tostring(mapname or "shipment");
	local entry = mc[key];
	if not entry then
		for k, v in pairs(mc) do
			if string.find(string.lower(tostring(k)), string.lower(key), 1, true) then
				entry = v;
				key = tostring(k);
				break;
			end
		end
	end
	if not entry then
		return "no config for " .. key;
	end
	for k, v in pairs(entry) do
		local extra = "";
		if type(v) == "table" then
			local c = 0;
			for _ in pairs(v) do
				c = c + 1;
			end
			extra = " (" .. tostring(c) .. " entries)";
		else
			extra = " = " .. string.sub(tostring(v), 1, 40);
		end
		print("   " .. tostring(k) .. "  [" .. type(v) .. "]" .. extra);
	end
	return "top level of " .. key .. " printed";
end

print("[zt6] ready: shared.zt6.top('shipment') / shared.zt6.search('shipment')");
