local ELib = require("expressive/library")
local class = require("voop")

---@class TypeData
---@field fields table<string, Type>?

---@class FunctionData : TypeData
---@field return_type Type
---@field params table<string, Type>

---@class TypeFlags
local TypeFlags = {
	None = 0,
	Array = 1,
	Optional = 2,
	Generic = 4,
	Variadic = 8,
	Function = 16,
	Enum = 32, -- x | y | z
}

---@class TypeKind
local TypeKind = {
	Class = 1,
	Interface = 2,
	Object = 3,
	Primitive = 4,
	Alias = 5
}

--- A type for Expression4
---@class Type: Object
---@field ref string|Type|table<number, Type>
---@field id integer
---@field extends Type?
---@field kind TypeKind
---@field data TypeData?
---@field flags TypeFlags
---@field fields table<string, Type>?
local Type = class("Type")

Type.FLAGS = TypeFlags
Type.KINDS = TypeKind

function Type:__tostring()
	if self.extends then
		return "Type: " .. self:display() .. " extends " .. tostring(self.extends)
	else
		return "Type: " .. self:display()
	end
end

---@param flag TypeFlags
function Type:hasFlag(flag)
	return bit.band(self.flags, flag) ~= 0
end

---@return string
function Type:display()
	local ref
	if self:hasFlag(TypeFlags.Generic) then
		ref = "T"
	else
		if Type:instanceof(self.ref) then
			ref = self.ref:display()
		elseif istable(self.ref) then
			local tbl = {}
			for r in ipairs(self.ref) do
				tbl[r] = r:display()
			end
			ref = table.concat(tbl, "|")
		else
			ref = self.ref
		end
	end

	-- These flags can't be combined.
	if self:hasFlag(TypeFlags.Array) then
		return ref .. "[]"
	else
		return ref
	end
end

--- Creates a new type, to be registered in an extension
---@param kind TypeKind
---@param flags TypeFlags
---@param ref string # Referenced type in type. For example, in a type that defines array[], ref would be 'array' and assume it exists.
---@param extends Type? Optional type that this extends.
---@return Type
---@return TypeData | ClassData | FunctionData
function Type.new(kind, flags, extends)
	-- TODO: This getmetatable method of checking may be bad for extending an already extended [Type].
	if extends then assert( getmetatable(extends) == Type, "Extended type should be a Type object, not a " .. type(extends) ) end
	local data = {}
	return setmetatable({
		extends = extends,
		data = data,
		kind = kind,
		flags = flags or 0,
		__metatable = Type,
		__index = extends or Type
	}, extends or Type), data
end

function Type:isArray()
	return bit.band( self.flags, TypeFlags.Array ) ~= 0
end

-- These are types that will be used by the compiler, so they NEED to exist in the first place.
Type.DOUBLE = Type.new(TypeKind.Primitive)
Type.INT = Type.new(TypeKind.Primitive, TypeFlags.None)
Type.STRING = Type.new(TypeKind.Primitive)
Type.BOOL = Type.new(TypeKind.Primitive)

-- Nothing type.
Type.VOID = Type.new(TypeKind.Primitive)

-- Generic function type, no specified params or return.
-- Should only be used by extern definitions for varargs or something.
Type.FUNCTION = Type.new(TypeKind.Primitive)

ELib.Type = Type

return Type