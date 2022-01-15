local ELib = require("expressive/library")

local Var = ELib.Analyzer.Var

---@class Scope
---@field priv table<string, Variable>
---@field parent Scope?
---@field index number
local Scope = {}
Scope.__index = Scope

local counter = 0

--- Creates a new scope.
---@return Scope
function Scope.new()
	counter = counter + 1
	return setmetatable({
		priv = {},
		index = counter
	}, Scope)
end

--- Derives a new scope from a previous one.
---@return Scope
function Scope.from(parent)
	local scope = Scope.new()
	scope.parent = parent
	scope.priv = setmetatable({}, {
		__index = parent.priv
	})
	return scope
end

function Scope:__tostring()
	if self.parent then
		return "Scope #" .. self.index .. " @(" .. tostring(self.parent) .. ")"
	else
		return "Scope #" .. self.index
	end
end

--- Tries to find a variable 'name'
---@return Variable?
function Scope:lookup(name)
	return self.priv[name]
end

--- Like Scope:lookup(name), but if the variable doesn't exist, creates it.
---@param name string
---@param init Variable?
---@return Variable
---@return boolean # If the variable was created.
function Scope:lookupOrInit(name, init)
	local var = self:lookup(name)
	if var then
		if not var.type then
			var.type = init.type
		end
		return var, false
	end

	self:set(name, init or Var.new())
	return self:lookup(name), true
end

--- Sets the result of the scope, in case of expression blocks
---@param result TypeSig?
function Scope:setResult(result)
	self.result = result
end

---@param name string
---@param var Variable? Optional variable. If not given, type will not be set.
function Scope:set(name, var)
	self.priv[name] = var or Var.new()
end

---@param name string
---@param ty TypeSig
function Scope:setType(name, ty)
	if not self:lookup(name) then
		self:set(name, Var.new(ty))
	else
		self.priv[name].type = ty
	end
end

ELib.Analyzer.Scope = Scope
return Scope