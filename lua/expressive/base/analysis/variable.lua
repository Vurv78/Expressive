local ELib = require("expressive/library")

---@alias TypeSig "int"|"double"|"string"|"boolean"|"null"|string

---@class Variable
---@field type TypeSig? Type of the variable if known. May be nil temporarily in between analyzing stages.
---@field value any? Optional known value of the variable, for optimizations sake
---@field mutable boolean Is the variable mutable? Default true
local Var = {}
Var.__index = Var

function Var:__tostring()
	return "Variable (" .. (self.type or "unknown") .. ")"
end

---@param type TypeSig
---@param value any? Optional value, if known.
---@param mutable boolean? Is the variable mutable? Default true
function Var.new(type, value, mutable)
	return setmetatable({
		type = type,
		value = value,
		mutable = mutable or true
	}, Var)
end

ELib.Analyzer.Var = Var

return Var