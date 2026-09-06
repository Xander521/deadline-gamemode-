shared.zt3 = {};

local function dump(t, label, depth, pad, budget)
	if depth <= 0 or budget.n <= 0 then
		return;
	end
	if type(t) ~= "table" then
		print(pad .. label .. " = " .. string.sub(tostring(t), 1, 60) .. "  (" .. type(t) .. ")");
		budget.n = budget.n - 1;
		return;
	end
	print(pad .. label .. "  {table}");
	budget.n = budget.n - 1;
	for k, v in pairs(t) do
		if budget.n <= 0 then
			return;
		end
		if type(v) == "table" then
			dump(v, tostring(k), depth - 1, pad .. "   ", budget);
		else
			print(pad .. "   " .. tostring(k) .. " = " .. string.sub(tostring(v), 1, 50));
			budget.n = budget.n - 1;
		end
	end
end

shared.zt3.maplist = function()
	local ok, mc = pcall(function()
		return config.maps.MAP_CONFIGURATION;
	end);
	if not ok or type(mc) ~= "table" then
		return "MAP_CONFIGURATION unavailable: " .. tostring(mc);
	end
	local n = 0;
	for k in pairs(mc) do
		n = n + 1;
		print("   " .. tostring(k));
	end
	print("[zt3] " .. tostring(n) .. " map configs");
	return "map keys printed";
end

shared.zt3.mapcfg = function(name)
	local ok, mc = pcall(function()
		return config.maps.MAP_CONFIGURATION;
	end);
	if not ok or type(mc) ~= "table" then
		return "MAP_CONFIGURATION unavailable";
	end
	local key = tostring(name or "shipment");
	local entry = mc[key];
	if not entry then
		print("[zt3] no exact key '" .. key .. "', looking for a partial match");
		for k, v in pairs(mc) do
			if string.find(string.lower(tostring(k)), string.lower(key), 1, true) then
				entry = v;
				key = tostring(k);
				break;
			end
		end
	end
	if not entry then
		return "no config for " .. tostring(name);
	end
	dump(entry, key, 3, "  ", { n = 120 });
	return "config for " .. key .. " printed";
end

shared.zt3.mapkeys = function()
	local ok, m = pcall(function()
		return config.maps;
	end);
	if not ok or type(m) ~= "table" then
		return "config.maps unavailable";
	end
	for k, v in pairs(m) do
		print("   config.maps." .. tostring(k) .. "  (" .. type(v) .. ")");
	end
	local ok2, g = pcall(function()
		return config;
	end);
	if ok2 and type(g) == "table" then
		local out = "";
		for k in pairs(g) do
			out = out .. tostring(k) .. " ";
		end
		print("[zt3] config keys: " .. out);
	end
	return "keys printed";
end

print("[zt3] ready: shared.zt3.mapkeys() / .maplist() / .mapcfg('shipment')");
