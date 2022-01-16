local ELib = require("expressive/library")

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local NODE_KINDS = ELib.Parser.KINDS
local Var = Analyzer.Var

local Handlers = {
	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.VarDeclare] = function(self, node)
		-- kw is either "var", "let" or "const"
		local kw, name, type, expr = unpack(node.data)

		local scope = self:getScope()
		if kw == "var" then
			scope = self.global_scope
		end

		local expr_ty = self:typeFromExpr(expr)
		if type then
			if expr_ty then
				assert(type == expr_ty, "Expected " .. type .. " in declaration of '" .. name .. ": " .. type .. "', but got " .. expr_ty)
			end
		end

		-- print(scope, name, ":", type or expr_ty, "=", expr)
		local v, init = scope:lookupOrInit(name, Var.new(type or expr_ty, nil, kw ~= "const"))
		-- temporary
		assert(init, "Variable re-declaration is forbidden")
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.VarModify] = function(self, node)
		local name, how, expr2 = unpack(node.data)

		local scope = self:getScope()
		local var =  assert(scope:lookup(name), "Variable " .. name .. " is not defined")
		assert(var.mutable, "Cannot modify constant variable " .. name)

		if how ~= "++" and how ~= "--" then
			-- "+=", "-=", "/=", "*=", "%=", "="
			local expr2_ty = self:typeFromExpr(expr2)
			if var.type then
				if expr2_ty ~= var.type then
					error("Cannot assign " .. expr2_ty .. " to " .. var.type)
				end
			else
				-- Assume they are the same type.
				var.type = expr2_ty
			end
		end
	end,

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
		local body = unpack(node.data)
		self:pushScope()
			self:firstPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Realm] = function(self, node)
		local realm, body = unpack(node.data)

		self:pushScope()
			self:firstPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.If] = function(self, node)
		local cond, body = unpack(node.data)
		self:pushScope()
			self:firstPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Elseif] = function(self, node)
		local cond, body = unpack(node.data)
		self:pushScope()
			self:firstPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Else] = function(self, node)
		local body = unpack(node.data)
		self:pushScope()
			self:firstPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.While] = function(self, node)
		local cond, body = unpack(node.data)
		self:pushScope()
			self:firstPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Function] = function(self, node)
		local name, args, block = unpack(node.data)
		-- Set function in the outer scope.
		self:getScope():setType(name, "function")

		self:pushScope()
			local scope = self:getScope()

			for _, data in ipairs(args) do
				print(data[1], data[2])
				scope:setType( data[1], data[2] )
			end

			-- NOW handle the block
			self:firstPass(block)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.CallExpr] = function(self, node)
		---@type Node
		local expr = node.data[1]
		---@type table<number, Node>
		local args = node.data[2]

		local ty = self:typeFromExpr(expr)
		assert(ty, "Calling nonexistant value '" .. expr.data[1] .. "'")
		assert(ty == "function", "Cannot call non-function '" .. expr.data[1] .. "'")

		self:firstPass(args)
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Declare] = function(self, node)
		assert(self.configs.AllowDeclare, "Declare statements are not allowed in regular code")
	end
}

--- Runs first pass on the analyzer
---@param ast table<number, Node>
function Analyzer:firstPass(ast)
	if not ast then return end -- Empty block
	for _, node in ipairs(ast) do
		local handler = Handlers[node.kind]
		if handler then
			handler(self, node)
		end
	end
end