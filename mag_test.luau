local KEYS = { "plr_magazines", "plr_spare_rounds", "plr_drum_magazines" };

local function show()
	print("[mtest] current values:");
	for _, k in ipairs(KEYS) do
		local ok, v = pcall(function()
			return sharedvars[k];
		end);
		print("   " .. k .. " = " .. tostring(ok and v or "?"));
	end
end

local ORIGINAL = {};
for _, k in ipairs(KEYS) do
	local ok, v = pcall(function()
		return sharedvars[k];
	end);
	if ok then
		ORIGINAL[k] = v;
	end
end

shared.mtest = {};

shared.mtest.show = function()
	show();
	return "printed";
end

shared.mtest.set = function(key, value)
	local n = tonumber(value);
	if n == nil then
		return "usage: shared.mtest.set('plr_magazines', 1)";
	end
	local ok, err = pcall(function()
		sharedvars[key] = n;
	end);
	print("[mtest] " .. tostring(key) .. " = " .. tostring(n) .. " ok=" .. tostring(ok) .. " " .. tostring(err));
	return "set " .. tostring(key) .. " to " .. tostring(n) .. " - respawn to see the effect";
end

shared.mtest.mags = function(n)
	shared.mtest.set("plr_magazines", n or 1);
	return "magazines set - respawn to apply";
end

shared.mtest.spare = function(n)
	shared.mtest.set("plr_spare_rounds", n or 0);
	return "spare rounds set - respawn to apply";
end

shared.mtest.restore = function()
	for k, v in pairs(ORIGINAL) do
		pcall(function()
			sharedvars[k] = v;
		end);
		print("[mtest] restored " .. k .. " = " .. tostring(v));
	end
	return "originals restored";
end

show();
print("[mtest] ready: shared.mtest.mags(1) / .spare(0) / .show() / .restore()");
