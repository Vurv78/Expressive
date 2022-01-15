local ExpressiveEditor = ExpressiveEditor

do
	local function add(path, client_only)
		AddCSLuaFile(path)
		if not client_only or CLIENT then
			include(path)
		end
	end

	print("SYPER: INCLUDING")

	ExpressiveEditor.include = add
	add("lib.lua")
	add("filetype.lua")
	add("token.lua")
	add("lexer.lua")
	add("mode.lua")
	add("settings.lua")
	add("ide/ide.lua")
end

----------------------------------------
-- Create default dir
if not file.Exists("syper", "DATA") then
	file.CreateDir("syper")
end