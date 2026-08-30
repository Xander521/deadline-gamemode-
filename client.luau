local role = "survivor";

on_server_event:Connect(function(args)
	if type(args) == "table" and args.event == "hidden_role" then
		role = args.role or "survivor";
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

print("[hidden-client] loaded");
