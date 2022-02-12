local ELib = require("expressive/library")
local class = require("voop")

local Var = ELib.Var

---@alias ScopeKind "1|2|3|4|5"
---@class ScopeKinds
local KINDS = {
	---```ts
	--- 	function foo() {};
	--- ```
	FUNCTION = 1,
	--- ```ts
	--- 	function() {};
	--- ```
	LAMBDA = 2,
	--- ```ts
	---		{
	---
	---		};
	--- ```
	EXPR_BLOCK = 3,

	--- Non-returning type of block
	--- the type you'd see in if statements and whatever.
	--- ```ts
	--- if (true) { ... }
	--- ```
	STATEMENT = 4,

	--- Global, Non-returning scope.
	GLOBAL = 5,
}

---@class Scope: Object
---@field priv table<string, Variable>
---@field parent Scope?
---@field index number
---@field kind number
local Scope = class("Scope")
Scope.KINDS = KINDS

local counter = 0

--- Creates a new scope.
---@see `Scope.KINDS`
---@param kind ScopeKind 1 | 2 | 3 | 4 | 5
---@return Scope
function Scope.new(kind)
	counter = counter + 1
	return setmetatable({
		priv = {},
		kind = kind,
		index = counter
	}, Scope)
end

--- Derives a new scope from a previous one.
---@param parent Scope
---@param kind ScopeKind
---@return Scope
function Scope.from(parent, kind)
	local scope = Scope.new(kind)
	scope.parent = parent
	scope.priv = setmetatable({}, {
		__index = parent.priv
	})
	return scope
end

function Scope:__tostring()
	if self.parent then
		return "Scope k" .. self.kind .. " #" .. self.index .. " @(" .. tostring(self.parent) .. ")"
	else
		return "Scope k" .. self.kind .. "#" .. self.index
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
---@param result string?
function Scope:setResult(result)
	self.result = result
end

---@return string?
function Scope:getResult()
	return self.result
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