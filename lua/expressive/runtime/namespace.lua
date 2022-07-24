require("expressive/library"); local ELib = ELib
local Class = ELib.Class

---@class Namespace: Object
---@field name string
---@field super Namespace? # Reference to parent namespace
---@field variables table<string, Variable>
---@field namespaces table<string, Namespace>
---@field types table<TypeSig, Type>
local Namespace = Class("Namespace")

function Namespace:__tostring()
	if self.super then
		return "Namespace: " .. self.name .. " extends " .. tostring(self.super)
	else
		return "Namespace: " .. self.name
	end
end

--- Creates a new namespace
---@param name string
---@param super Namespace
---@return Namespace
function Namespace.new(name, super)
	return setmetatable({
		name = name,
		super = super,
		variables = {},
		namespaces = {},
		types = {}
	}, Namespace)
end

--- Registers a variable to the namespace, at the given name.
---@param name string
---@param var Variable
function Namespace:registerVar(name, var)
	self.variables[name] = var
end

--- Registers a given type into the namespace.
---@param name string
---@param type Type
function Namespace:registerType(name, type)
	self.types[name] = type
end

ELib.Namespace = Namespace
return Namespace