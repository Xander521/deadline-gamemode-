local L = {};
local ORIGINAL = {};
local KINDS = { "PointLight", "SpotLight", "SurfaceLight" };

local function walk()
	local root = get_map_root();
	if not root then
		return nil;
	end
	local ok, all = pcall(function()
		return root.get_descendants();
	end);
	if not ok or type(all) ~= "table" then
		return nil;
	end
	return all;
end

L.dim = function(factor)
	local f = tonumber(factor) or 0.1;
	local all = walk();
	if not all then
		return 0;
	end
	local n = 0;
	for _, inst in ipairs(all) do
		for _, k in ipairs(KINDS) do
			local is = false;
			pcall(function()
				is = inst.is_a(k);
			end);
			if is then
				local bok, b = pcall(function()
					return inst.Brightness;
				end);
				if bok and type(b) == "number" then
					if ORIGINAL[inst] == nil then
						ORIGINAL[inst] = b;
					end
					if pcall(function()
						inst.Brightness = ORIGINAL[inst] * f;
					end) then
						n = n + 1;
					end
				end
			end
		end
	end
	print("[lights] dimmed " .. tostring(n) .. " lights to " .. tostring(f * 100) .. "%");
	return n;
end

L.restore = function()
	local n = 0;
	for inst, b in pairs(ORIGINAL) do
		if pcall(function()
			inst.Brightness = b;
		end) then
			n = n + 1;
		end
	end
	ORIGINAL = {};
	return n;
end

return L;
