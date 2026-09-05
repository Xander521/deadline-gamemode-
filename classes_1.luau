-- Class definitions. Weapon names must match entries in guns_2.luau.
local C = {};

C.order = { "assault", "hunter", "support" };

C.assault = {
	label = "ASSAULT",
	mags = 1,
	shells = 10,
	ping = false,
	alarm = false,
	crate = false,
};

C.hunter = {
	label = "HUNTER",
	mags = 1,
	shells = 10,
	ping = true,
	alarm = true,
	crate = false,
};

C.support = {
	label = "SUPPORT",
	mags = 1,
	shells = 10,
	ping = false,
	alarm = false,
	crate = true,
};

-- how many of each limited class are allowed, given the survivor count
C.caps = function(survivors)
	local extra = math.floor(survivors / 5);
	return {
		hunter = 1 + extra,
		support = 1 + extra,
	};
end

return C;
