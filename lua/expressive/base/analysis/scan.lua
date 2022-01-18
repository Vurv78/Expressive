local ELib = require("expressive/library")

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local NODE_KINDS = ELib.Parser.KINDS

local Var = ELib.Var
local Type = ELib.Type

local ExternHandlers
ExternHandlers = {
	---@param self Analyzer
	---@param name string
	---@param data table
	["namespace"] = function(self, name, data)
		---@type table<number, Node>
		local nodes = data[3]
		for k, node in ipairs(nodes) do
			nodes[k] = ExternHandlers[node[1]](self, node.data)
		end
		-- TODO
		print("namespace nodes", ELib.Inspect(nodes))
		self.externs[name] = nodes
	end,

	--- Primitive type decl
	---@param self Analyzer
	---@param name string
	---@param data table
	["type"] = function(self, name, data)
		self.ctx:registerType(name, Type.new(name))
	end,

	---@param self Analyzer
	---@param name string
	---@param data table
	["var"] = function(self, name, data)
		local mutability = data[3] -- "var" or "const"
		local type = data[4]
		self.ctx:registerVar(name, Var.new(type, nil, mutability))
		-- self.externs[name] = Var.new(type, mutability == "const")
	end,

	---@param self Analyzer
	---@param name string
	---@param data table
	["function"] = function(self, name, data)
		-- Should create a proper function signature with this in the future.
		local params, ret = data[3], data[4]

		-- Cannot modify externs
		local var = Var.new("function", nil, false)
		self.ctx:registerVar(name, var)
	end,
}

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

		local type, var_name = node.data[1], node.data[2]
		local handler = ExternHandlers[type]
		if handler then
			ExternHandlers[type](self, var_name, node.data)
		end
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