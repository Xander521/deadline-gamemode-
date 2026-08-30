local role = "survivor";
local latched = false;

on_server_event:Connect(function(args)
	if type(args) == "table" and args.event == "hidden_role" then
		role = args.role or "survivor";
		print("[hidden-client] role = " .. role);
	end
end);

framework.on_spawned:Connect(function()
	time.delay(0.5, function()
		pcall(framework.character.set_nv_enabled, role == "hunter");
	end);
end);

time.heartbeat("hidden_nv_guard", function()
	if role == "hunter" then
		return;
	end
	local ok, on = pcall(framework.character.is_nv_enabled);
	if ok and on then
		pcall(framework.character.set_nv_enabled, false);
	end
end);

local binds = InputGroup.new();

binds:bind_key(function()
	if role ~= "hunter" then
		return;
	end
	fire_server({ event = "screech" });
end, InputType.Began, false, Enum.KeyCode.F);

binds:bind_key(function()
	if role ~= "hunter" then
		return;
	end
	latched = not latched;
	fire_server({ event = "latch", on = latched });
end, InputType.Began, false, Enum.KeyCode.G);

print("[hidden-client] loaded. F = screech, G = wall latch (hunter only)");
