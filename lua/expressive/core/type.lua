local ELib = require("expressive/library")

--- A type for Expression4
---@class Type
---@field name string
---@field instanceof fun(x: any): boolean # Function that returns true if x is an instance of this type.
local Type = {}
Type.__index = Type

--- Creates a new type, to be registered in an extension
---@param name string
---@param extends Type? Optional type that this extends.
---@return Type
function Type.new(name, extends)
	-- TODO: This getmetatable method of checking may be bad for extending an already extended [Type].
	if extends then assert( getmetatable(extends) == Type, "Extended type should be a Type object, not a " .. type(extends) ) end
	return setmetatable({
		name = name,
		extends = extends,
		__metatable = Type,
		__index = extends or Type
	}, extends or Type)
end

function Type:__tostring()
	return "Type: (" .. self.name .. ")"
end

--- Asserts that a [Type] struct is completely ready to be used by E4.
--- Used internally.
function Type:isReady()
	return self.instanceof ~= nil
end

ELib.Type = Type

return Type