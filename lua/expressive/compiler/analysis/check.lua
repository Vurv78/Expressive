require("expressive/library"); local ELib = ELib

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local NODE_KINDS = ELib.Parser.KINDS
local SCOPE_KINDS = Analyzer.Scope.KINDS

local makeSignature = ELib.Analyzer.makeSignature

local Handlers = {
	-- Scan for variable references
	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.Variable] = function(self, data)
		local name = data[1]
		assert( self:getScope():lookup(name), "Variable " .. name .. " is not defined")
	end,

	-- Scan for function calls
	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.VarDeclare] = function(self, data)
		local expr = data[4]
		self:check(expr)
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.Block] = function(self, data)
		local body = data[1]
		self:pushScope(SCOPE_KINDS.EXPR_BLOCK)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.Realm] = function(self, data)
		-- TODO: Use a different scope for server/client.
		local body = data[2]

		self:pushScope(SCOPE_KINDS.STATEMENT)
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.If] = function(self, data)
		local _cond, body, elses = data[1], data[2], data[3]

		self:pushScope(SCOPE_KINDS.STATEMENT)
			self:checkPass(body)
		self:popScope()

		for _, case in ipairs(elses) do
			self:pushScope(SCOPE_KINDS.STATEMENT)
				self:checkPass(case[2])
			self:popScope()
		end
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.While] = function(self, data)
		local body = data[2]
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.Function] = function(self, data)
		self:pushScope()
			self:checkPass( data[3] )
		self:popScope()
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.CallExpr] = function(self, data)
		---@type Node
		local expr = data[1]
		---@type Node[]
		local args = data[2]

		self:check(expr)

		-- if not self.configs.UndefinedVariables then
			local ty = self:typeFromExpr(expr)

			assert(ty, "Calling nonexistant value '" .. expr.data[1] .. "'")
			assert(string.sub(ty, 1, 8) == "function", "Cannot call non-function '" .. expr.data[1] .. "'")
		-- end

		self:checkPass(args)
		local type_args = {}
		for k, arg in ipairs(args) do
			for k2, v in pairs(arg) do print(k2, v) end
			type_args[k] = self:typeFromExpr(arg)
		end

		local type_args_str = table.concat(type_args, ",")
		local fn_args = string.match(ty, "^function%((.*)%)")

		assert(type_args_str == fn_args, "Function '" .. expr.data[1] .. "' expects arguments (" .. fn_args .. ") but got (" .. type_args_str .. ")")
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.Lambda] = function(self, data)
		-- TODO: Define the lambda arguments in the scope so they can be used
		local _args, body = data[1], data[2]
		self:pushScope()
			self:checkPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.Constructor] = function(self, data)
		local _name, args, body = data[1], data[2], data[3]
		local _sig = makeSignature(args, self:getReturnType(body))

		-- TODO: Define in scope
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.ArithmeticOps] = function(self, data)
		local op, lhs, rhs = data[1], data[2], data[3]
		local lhs_t, rhs_t = self:typeFromExpr(lhs), self:typeFromExpr(rhs)

		assert(lhs_t, "Couldn't infer type for " .. lhs:human())
		assert(rhs_t, "Couldn't infer type for " .. rhs:human())

		assert(lhs_t == "double" or lhs_t == "int", "Cannot use " .. lhs_t .. " in arithmetic operation (lhs)")
		assert(rhs_t == "double" or rhs_t == "int", "Cannot use " .. rhs_t .. " in arithmetic operation (rhs)")

		assert(lhs_t == rhs_t, "Cannot perform " .. op .. " operation on two differently sized numeric types")
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.ComparisonOps] = function(self, data)
		local op, lhs, rhs = data[1], data[2], data[3]
		local lhs_t, rhs_t = self:typeFromExpr(lhs), self:typeFromExpr(rhs)

		assert(lhs_t, "Couldn't infer type for " .. lhs:human())
		assert(rhs_t, "Couldn't infer type for " .. rhs:human())

		assert(lhs_t == "double" or lhs_t == "int", "Cannot use " .. lhs_t .. " in comparison operation (lhs)")
		assert(rhs_t == "double" or rhs_t == "int", "Cannot use " .. rhs_t .. " in comparison operation (rhs)")

		assert(lhs_t == rhs_t, "Cannot perform " .. op .. " operation on two differently sized numeric types")
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.BitShiftOps] = function(self, data)
		local op, lhs, rhs = data[1], data[2], data[3]
		local lhs_t, rhs_t = self:typeFromExpr(lhs), self:typeFromExpr(rhs)

		assert(lhs_t, "Couldn't infer type for " .. lhs:human())
		assert(rhs_t, "Couldn't infer type for " .. rhs:human())

		assert(lhs_t == "double" or lhs_t == "int", "Cannot use " .. lhs_t .. " in bitshift operation (lhs)")
		assert(rhs_t == "double" or rhs_t == "int", "Cannot use " .. rhs_t .. " in bitshift operation (rhs)")

		assert(lhs_t == rhs_t, "Cannot perform " .. op .. " operation on two differently sized numeric types")
	end,

	---@param self Analyzer
	---@param data any[]
	[NODE_KINDS.BitwiseOps] = function(self, data)
		local op, lhs, rhs = data[1], data[2], data[3]
		local lhs_t, rhs_t = self:typeFromExpr(lhs), self:typeFromExpr(rhs)

		assert(lhs_t, "Couldn't infer type for " .. lhs:human())
		assert(rhs_t, "Couldn't infer type for " .. rhs:human())

		assert(lhs_t == "double" or lhs_t == "int", "Cannot use " .. lhs_t .. " in bitwise operation (lhs)")
		assert(rhs_t == "double" or rhs_t == "int", "Cannot use " .. rhs_t .. " in bitwise operation (rhs)")

		assert(lhs_t == rhs_t, "Cannot perform " .. op .. " operation on two differently sized numeric types")
	end,
}

--- Like Analyzer:checkPass, but for a single node.
---@param node Node
function Analyzer:check(node)
	local handler = Handlers[node.kind]
	if handler then
		handler(self, node.data)
	end
end

--- Runs first pass on the analyzer
---@param ast Node[]
function Analyzer:checkPass(ast)
	if not ast then return end -- Empty block
	for _, node in ipairs(ast) do
		self:check(node)
	end
end