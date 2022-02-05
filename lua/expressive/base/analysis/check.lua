local ELib = require("expressive/library")

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local NODE_KINDS = ELib.Parser.KINDS
local SCOPE_KINDS = Analyzer.Scope.KINDS

local makeSignature = ELib.Analyzer.makeSignature

local Handlers = {
	-- Scan for variable references
	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Variable] = function(self, data)
		local name = data[1]
		assert( self:getScope():lookup(name), "Variable " .. name .. " is not defined")
	end,


	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Block] = function(self, data)
		local body = data[1]
		self:pushScope(SCOPE_KINDS.EXPR_BLOCK)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Realm] = function(self, data)
		-- TODO: Use a different scope for server/client.
		local body = data[2]

		self:pushScope(SCOPE_KINDS.STATEMENT)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.If] = function(self, data)
		local _cond, body = data[1], data[2]
		self:pushScope(SCOPE_KINDS.STATEMENT)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Elseif] = function(self, data)
		local _cond, body = data[1], data[2]
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Else] = function(self, data)
		local body = data[1]
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.While] = function(self, data)
		local body = data[2]
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Function] = function(self, data)
		self:pushScope()
			self:checkPass( data[3] )
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.CallExpr] = function(self, data)
		---@type Node
		local expr = data[1]
		---@type table<number, Node>
		local args = data[2]

		-- if not self.configs.UndefinedVariables then
			local ty = self:typeFromExpr(expr)
			assert(ty, "Calling nonexistant value '" .. expr.data[1] .. "'")
			assert(string.sub(ty, 1, 8) == "function", "Cannot call non-function '" .. expr.data[1] .. "'")
		-- end

		self:checkPass(args)
		local type_args = {}
		for k, arg in ipairs(args) do
			type_args[k] = self:typeFromExpr(arg)
		end

		type_args = table.concat(type_args, ",")
		local fn_args = string.match(ty, "^function%((.*)%)")

		assert(type_args == fn_args, "Function '" .. expr.data[1] .. "' expects arguments (" .. fn_args .. ") but got (" .. type_args .. ")")
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Lambda] = function(self, data)
		-- Todo: Define the lambda arguments in the scope so they can be used
		local args, body = data[1], data[2]
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Constructor] = function(self, data)
		local name, args, body = data[1], data[2], data[3]
		local sig = makeSignature(args, self:getReturnType(body))

		-- TODO: Define in scope
	end
}

--- Runs first pass on the analyzer
---@param ast table<number, Node>
function Analyzer:checkPass(ast)
	if not ast then return end -- Empty block
	for _, node in ipairs(ast) do
		local handler = Handlers[node.kind]
		if handler then
			handler(self, node.data)
		end
	end
end