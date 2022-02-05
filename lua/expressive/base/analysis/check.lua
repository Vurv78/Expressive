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
	---@param node Node
	[NODE_KINDS.Variable] = function(self, node)
		local name = node.data[1]
		assert( self:getScope():lookup(name), "Variable " .. name .. " is not defined")
	end,


	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Block] = function(self, node)
		local body = node.data[1]
		self:pushScope(SCOPE_KINDS.EXPR_BLOCK)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Realm] = function(self, node)
		local _realm, body = node.data[1], node.data[2]

		self:pushScope(SCOPE_KINDS.STATEMENT)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.If] = function(self, node)
		local _cond, body = node.data[1], node.data[2]
		self:pushScope(SCOPE_KINDS.STATEMENT)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Elseif] = function(self, node)
		local _cond, body = node.data[1], node.data[2]
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Else] = function(self, node)
		local body = unpack(node.data)
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.While] = function(self, node)
		local _cond, body = unpack(node.data)
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Function] = function(self, node)
		self:pushScope()
			self:checkPass( node.data[3] )
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.CallExpr] = function(self, node)
		---@type Node
		local expr = node.data[1]
		---@type table<number, Node>
		local args = node.data[2]

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
	---@param node Node
	[NODE_KINDS.Lambda] = function(self, node)
		local _args, body = unpack(node.data)
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Constructor] = function(self, node)
		local name, args = unpack(node.data)
		local sig = makeSignature(args)
	end
}

--- Runs first pass on the analyzer
---@param ast table<number, Node>
function Analyzer:checkPass(ast)
	if not ast then return end -- Empty block
	for _, node in ipairs(ast) do
		local handler = Handlers[node.kind]
		if handler then
			handler(self, node)
		end
	end
end