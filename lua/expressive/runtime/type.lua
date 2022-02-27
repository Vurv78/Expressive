local ELib = require("expressive/library")
local class = require("voop")

--- A type for Expression4
---@class Type: Object
---@field name string
---@field extends Type?
---@field data ClassData?
---@field typeof fun(x: any): boolean # Function that returns true if x is an instance of this type.
local Type = class("Type")

function Type:__tostring()
	if self.extends then
		return "Type: " .. self.name .. " extends " .. tostring(self.extends)
	else
		return "Type: " .. self.name
	end
end

--- Creates a new type, to be registered in an extension
---@param name string
---@param extends Type? Optional type that this extends.
---@param data ClassData? Optional data for the type.
---@return Type
function Type.new(name, extends, data)
	-- TODO: This getmetatable method of checking may be bad for extending an already extended [Type].
	if extends then assert( getmetatable(extends) == Type, "Extended type should be a Type object, not a " .. type(extends) ) end
	return setmetatable({
		name = name,
		extends = extends,
		data = data,
		__metatable = Type,
		__index = extends or Type
	}, extends or Type)
end

--- Asserts that a [Type] struct is completely ready to be used by E4.
--- Used internally.
function Type:isReady()
	return self.typeof ~= nil
end

ELib.Type = Type

return Type