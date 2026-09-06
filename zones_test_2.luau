shared.zt2 = {};

local function nameof(i)
	local n = "?";
	pcall(function()
		n = tostring(i.Name);
	end);
	return n;
end

shared.zt2.tree = function(depth)
	local d = tonumber(depth) or 2;
	local root = get_map_root();
	if not root then
		return "no map root";
	end
	local shown = 0;

	local function walk(node, level, pad)
		if level > d or shown > 120 then
			return;
		end
		local ok, kids = pcall(function()
			return node.get_children();
		end);
		if not ok or type(kids) ~= "table" then
			return;
		end
		for _, c in ipairs(kids) do
			shown = shown + 1;
			if shown > 120 then
				return;
			end
			local gok, g = pcall(function()
				return c.get_children();
			end);
			local cc = 0;
			if gok and type(g) == "table" then
				cc = #g;
			end
			print(pad .. nameof(c) .. "  (" .. tostring(cc) .. " children)");
			walk(c, level + 1, pad .. "   ");
		end
	end

	print("[zt2] map root children:");
	walk(root, 1, "  ");
	print("[zt2] " .. tostring(shown) .. " nodes shown");
	return "tree printed";
end

shared.zt2.alltags = function()
	local ok, list = pcall(tags.get_tags);
	if ok and type(list) == "table" then
		local n = 0;
		for _, t in pairs(list) do
			n = n + 1;
			local ok2, tagged = pcall(tags.get_tagged, tostring(t));
			local c = 0;
			if ok2 and type(tagged) == "table" then
				c = #tagged;
			end
			print("   " .. tostring(t) .. "  -> " .. tostring(c) .. " instances");
		end
		print("[zt2] " .. tostring(n) .. " tags in use");
		return "tags printed";
	end
	print("[zt2] tags.get_tags unavailable, trying known names");
	for _, t in ipairs({ "ceasefire", "defender_ceasefire", "attacker_ceasefire", "spawn", "spawn_zone", "spawnzone", "restricted", "no_build", "bg_sound_part", "molotov_fire" }) do
		local ok2, tagged = pcall(tags.get_tagged, t);
		local c = 0;
		if ok2 and type(tagged) == "table" then
			c = #tagged;
		end
		print("   " .. t .. " -> " .. tostring(c));
	end
	return "known tags printed";
end

shared.zt2.find = function(needle)
	local pat = string.lower(tostring(needle or "spawn"));
	local root = get_map_root();
	local ok, all = pcall(function()
		return root.get_descendants();
	end);
	if not ok or type(all) ~= "table" then
		return "no descendants";
	end
	local hits = 0;
	for _, inst in ipairs(all) do
		local n = string.lower(nameof(inst));
		if string.find(n, pat, 1, true) then
			hits = hits + 1;
			if hits <= 25 then
				local par = "?";
				pcall(function()
					par = tostring(inst.Parent.Name);
				end);
				print("   " .. nameof(inst) .. "   parent=" .. par);
			end
		end
	end
	print("[zt2] " .. tostring(hits) .. " of " .. tostring(#all) .. " descendants match '" .. pat .. "'");
	return "search done";
end

print("[zt2] ready: shared.zt2.tree(2) / shared.zt2.alltags() / shared.zt2.find('spawn')");
