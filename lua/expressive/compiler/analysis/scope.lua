require("expressive/library"); local ELib = ELib
local Class = ELib.Class

local Var = ELib.Var

---@enum ScopeKind
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
---@field index integer
---@field depth integer
---@field kind integer
local Scope = Class("Scope")
Scope.KINDS = KINDS

local counter = 0

--- Creates a new scope.
---@see `Scope.KINDS`
---@param kind ScopeKind
---@param index integer
---@param depth integer
---@return Scope
function Scope.new(kind, index, depth)
	counter = counter + 1
	return setmetatable({
		priv = {},
		kind = kind,
		index = index,
		depth = depth or 0,
	}, Scope)
end

--- Derives a new scope from a previous one.
---@param parent Scope
---@param kind ScopeKind
---@param index integer
---@return Scope
function Scope.from(parent, kind, index)
	local scope = Scope.new(kind, index, parent.depth + 1)
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
---@param init Variable
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

	self:set(name, init)
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
---@param var Variable
function Scope:set(name, var)
	self.priv[name] = var
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