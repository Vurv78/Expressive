--- This file fixes the require() function to properly return and take values (for lua.)
-- If you want it to fix C modules as well use danielga's https://github.com/danielga/gmod_require
-- Feel free to put this in any of your addons.

-- https://github.com/Facepunch/garrysmod/pull/1868
---@param name string
local function moduleExists( name )
	local realm = CLIENT and "cl" or "sv"
	local arch = jit.arch == "x86" and "32" or "64"
	local ops = system.IsWindows() and "win" or ( system.IsOSX() and "osx" or "linux" )
	if ops == "osx" or (ops == "linux" and arch == "32") then
		arch = ""
	end

	local f = string.format( "lua/bin/gm%s_%s_%s%s.dll", realm, name, ops, arch )

	return file.Exists( f, "GAME" )
end

local package = package
-- package.loaded is super polluted in gmod for... no reason?
-- woop.
package.required = package.required or {}
package.loading = package.loading or {} -- Packages being loaded to avoid recursion

-- Override require to allow it to return items.
-- Garry ruining lua as always..
local _require = _G.require
_G.require = function(name, ...)
	if moduleExists(name) then
		return _require(name, ...)
	elseif package.required[name] then
		-- Already loaded before
		return unpack(package.required[name])
	elseif package.loading[name] then
		-- nil
		return true
	else
		-- expressive/startup
		local path = "includes/modules/" .. name .. ".lua"
		if file.Exists(path, "LUA") then
			local fn = CompileFile(path)
			package.loading[name] = true

			local rets = { pcall(fn, ...) }
			local success = table.remove(rets, 1)

			package.loading[name] = nil
			package.required[name] = rets
			if not success then
				ErrorNoHalt("Error loading module " .. name .. ": " .. rets[1] .. "\n")
			end
			return unpack(rets)
		else
			ErrorNoHalt("Tried to require nonexistant module: " .. name)
		end
	end
end