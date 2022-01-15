local ELib = require("expressive/library")
-- Analysis
-- Type checking and whatnot for the output Expression4 AST.
local PARSER_KINDS = ELib.Parser.KINDS

---@class Analyzer
---@field scopes table<number, Scope>
---@field global_scope Scope
---@field current_scope Scope
---@field configs AnalyzerConfigs
local Analyzer = {}
Analyzer.__index = Analyzer
ELib.Analyzer = Analyzer

---@type Variable
local Var = include("variable.lua")
---@type Scope
local Scope = include("scope.lua")

---@param env table # Table of environment data: like function signatures with their return types.
function Analyzer.new(env)
	local global_scope = Scope.new()
	return setmetatable({
		env = env,
		scopes = { [0] = global_scope },
		global_scope = global_scope,
		current_scope = global_scope
	}, Analyzer)
end

--- Creates a new scope derived from the current scope
---@return Scope
function Analyzer:pushScope()
	local scope = Scope.from(self.current_scope)
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

local Handlers = {}

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
---@param ctx Context
---@param configs AnalyzerConfigs? # Optional configs for the analyzer, uses default values if passed nil.
---@param ast table<number, Node>
---@return table<number, Node> # A processed and optimized AST.
function Analyzer:process(ctx, configs, ast)
	local configs = configs or AnalyzerConfigs
	self.configs = configs

	self:loadContext(ctx)
	-- Get initial types.
	self:firstPass(ast)
	-- Optimizing pass. This is where the ast is changed a bit.
	local new_ast = self:optimize(ast)

	for id, scope in pairs(self.scopes) do
		for name, var in pairs(scope.priv) do
			if not var.type then
				error("Could not determine type of variable '" .. name .. "'")
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
end

include("infer.lua")
include("scan.lua")
include("optimizer/mod.lua")

---@type fun(self: Analyzer, ast: table<number, Node>): table<number, Node>
Analyzer.optimize = Analyzer.optimize

---@type fun(self: Analyzer, ast: table<number, Node>)
Analyzer.firstPass = Analyzer.firstPass

---@type fun(self: Analyzer, expr: Node)
Analyzer.typeFromExpr = Analyzer.typeFromExpr

return Analyzer