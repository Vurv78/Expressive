local ELib = require("expressive/library")
local class = require("voop")

--- "int", "double", "boolean", "void" etc.
---@alias TypeSig string

---@class Variable : Object
---@field type TypeSig? Type of the variable if known. May be nil temporarily in between analyzing stages.
---@field value any? Optional known value of the variable, for optimizations sake
---@field mutable boolean Is the variable mutable? Default true
local Var = class("Variable")

---@param type TypeSig
---@param value any? Optional value, if known.
---@param mutable boolean? Is the variable mutable? Default true
---@return Variable
function Var.new(type, value, mutable)
	if mutable == nil then
		mutable = true
	end

	return setmetatable({
		type = type,
		value = value,
		mutable = mutable
	}, Var)
end

function Var:__tostring()
	return "Variable (" .. (self.type or "unknown") .. ")"
end

ELib.Var = Var

return Var