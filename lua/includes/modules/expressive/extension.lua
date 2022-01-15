--- # Extension
--- An extension for Expressive  
---
--- Note that ES takes a very different approach to extensions from E2.  
--- There will not be hand holding and backwards compatibility as to keep things simple and clean.  
--- If you want something in ES, just ask for it / pr it -- no reason to make an addon for it.  
--- If you really do, then *be ready to fix potential breaking changes*.
---@class Extension
---@field name string
---@field enabled boolean
---@field enable fun(self: Extension, ctx: Context) # Add this yourself. This is the function called when enabling the extension on the context.
---@field disable fun(self: Extension, ctx: Context) # Add this yourself. This is the function called when disabling the extension on the context.
local Extension = {}
Extension.__index = Extension

function Extension:__tostring()
	return "Extension: (" .. self.name .. ")"
end

---@param name string
---@param enabled boolean # Whether the extension is enabled by default.
---@return Extension
function Extension.new(name, enabled)
	return setmetatable({
		name = name,
		funcs = {},
		types = {},
		enabled = enabled
	}, Extension)
end

return Extension