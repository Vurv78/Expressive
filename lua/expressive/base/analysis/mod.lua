local ELib = require("expressive/library")
local class = require("voop")

-- Analysis
-- Type checking and whatnot for the output AST.

---@class Analyzer: Object
---@field scopes table<number, Scope>
---@field global_scope Scope
---@field current_scope Scope
---@field types table<TypeSig, Type> # Registered types / classes. Inherits from context types with __index.
---@field configs AnalyzerConfigs
---@field ctx Context
---@field externs table<string, Type> # Extern values retrieved from extensions. Not to be confused with imports
---@field warnings table<number, {start: number, end: number, message: string}>
local Analyzer = class("Analyzer")
ELib.Analyzer = Analyzer

local Var = ELib.Var
---@type Scope
local Scope = include("scope.lua")
Analyzer.Scope = Scope

function Analyzer:reset()
	local global_scope = Scope.new( Scope.KINDS.GLOBAL )
	self.scopes = { [0] = global_scope }
	self.global_scope = global_scope
	self.current_scope = global_scope

	-- Note lack of resetting configs
	self.ctx = nil
	self.types = {}
	self.externs = {}
	self.warnings = {}
end

---@return Analyzer
function Analyzer.new()
	---@type Analyzer
	local instance = setmetatable({}, Analyzer)
	instance:reset()
	return instance
end

--- Creates a new scope derived from the current scope
---@param kind ScopeKind
---@return Scope
function Analyzer:pushScope(kind)
	local scope = Scope.from(self.current_scope, kind)
	self.scopes[#self.scopes + 1] = scope
	self.current_scope = scope
	return scope
end

--- Tries to set the current scope to the parent of the current scope.
--- This will silently fail if attempted on the last / global scope.
function Analyzer:popScope()
	local scope = self:getScope()
	if scope.parent then
		self.current_scope = scope.parent
	end
end

--- Returns the current scope of the Analyzer
--- Will always return a scope, even if it's the global scope.
---@return Scope
function Analyzer:getScope()
	return self.current_scope
end

function Analyzer:setTop()
	self.current_scope = self.global_scope
end

---@class AnalyzerConfigs
local AnalyzerConfigs = {
	--- ### Optimization Levels
	--- * `0` - Disabled.
	--- * `1` - Enabled.
	---
	--- There may be more levels in the future, so this is a number for backwards compatibility.
	Optimize = 1,

	--- ### Strict type checking
	--- Whether to do compile time type checking and errors if types don't match.  
	--- This can be disabled in the case of extensions / running trusted code.  
	--- **Should NOT ever be enabled for chips**
	StrictTyping = true,

	--- ### Undefined variables
	--- Whether to allow the use of undefined variables  
	--- **Should NOT ever be enabled for chips**
	UndefinedVariables = false,

	--- ### Declare statements
	--- Whether to allow declare statements to be used for external function imports.  
	--- For example
	--- ```ts
	--- declare function foo(): void;
	--- ```
	--- **Should NOT ever be enabled for chips**
	AllowDeclare = false
}

--- Processes the given AST, properly assigning scopes and types along the way
---@param ctx Context # Context retrieved from [Context.new]
---@param ast table<number, Node> # AST Retrieved from the [Parser]
---@param configs AnalyzerConfigs? # Optional configs for the analyzer, uses default values if passed nil.
---@return table<number, Node> new_ast # A processed and optimized AST.
function Analyzer:process(ctx, ast, configs)
	configs = configs or AnalyzerConfigs
	self.configs = configs
	self.externs = {}

	--- Throws a C like lua param error if ``ast`` param is not a table.
	assert(ELib.Context:instanceof(ctx), "bad argument #1 to 'Analyzer:process' (Context expected, got " .. type(ctx) .. ")")
	assert(istable(ast), "bad argument #2 to 'Analyzer:process' (table expected, got " .. type(ast) .. ")")
	assert(istable(configs), "bad argument #3 to 'Analyzer:process' (table expected, got " .. type(configs) .. ")")

	self.ctx = ctx
	self.types = setmetatable({}, {
		__index = self.ctx.types
	})

	-- Get initial types.
	self:externPass(ast)

	-- Load variables retrieved from extern pass into global scope
	self:loadContext(ctx)

	self:inferPass(ast)
	self:checkPass(ast)

	-- Optimizing pass. This is where the ast is changed a bit.
	local new_ast = self:optimize(ast)

	if self.configs.StrictTyping then
		for _, scope in pairs(self.scopes) do
			for name, var in pairs(scope.priv) do
				assert(var, "Could not determine type of variable '" .. name .. "'")
			end
		end
	end

	return new_ast
end

---@param ctx Context
function Analyzer:loadContext(ctx)
	for name, const in pairs(ctx.constants) do
		self.global_scope:set(name, Var.new(const.type.name, const.value, false))
	end

	---@param vars table<string, Variable>
	---@param scope Scope
	local function addVars(vars, scope)
		for name, var in pairs(vars) do
			if Var:instanceof(var) then
				scope:set(name, var)
			elseif istable(var) then
				-- Namespace, TODO
				-- Probably want a named scope system.
			else
				error("Invalid variable type: " .. type(var))
			end
		end
	end
	addVars(ctx.variables, self.global_scope)
end

local fmt = string.format
function Analyzer:warn(msg, ...)
	-- TODO: Properly use current node position.
	local err = fmt(msg, ...)
	self.warnings[ #self.warnings + 1 ] = { 1, 1, err }
end

include("util.lua")
include("extern.lua") -- First pass, extern declarations
include("infer.lua") -- Second pass
include("check.lua") -- Third pass, sanity checks
include("optimizer/mod.lua") -- Final pass, Optimizing

---@type fun(self: Analyzer, ast: table<number, Node>)
Analyzer.externPass = Analyzer.externPass

---@type fun(self: Analyzer, ast: table<number, Node>)
Analyzer.inferPass = Analyzer.inferPass

---@type fun(self: Analyzer, ast: table<number, Node>)
Analyzer.checkPass = Analyzer.checkPass

---@type fun(self: Analyzer, ast: table<number, Node>): table<number, Node>
Analyzer.optimize = Analyzer.optimize

---@type fun(self: Analyzer, expr: Node): TypeSig
Analyzer.typeFromExpr = Analyzer.typeFromExpr

--- Gets the return type from a block, searching for the first return statement.
---@type fun(block: table<number, Node>): string
Analyzer.getReturnType = Analyzer.getReturnType

--- Creates a function signature from type params and return type
---@type fun(self: Analyzer, params: table<number, string>, ret: TypeSig)
Analyzer.makeSignature = Analyzer.makeSignature

return Analyzer