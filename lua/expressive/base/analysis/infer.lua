local ELib = require("expressive/library")

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local makeSignature = ELib.Analyzer.makeSignature
local NODE_KINDS = ELib.Parser.KINDS

local Var = ELib.Var
local Type = ELib.Type

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
		if type and expr_ty then
			assert(type == expr_ty, "Expected " .. type .. " in declaration of '" .. name .. ": " .. type .. "', but got " .. expr_ty)
		end

		local _, init = scope:lookupOrInit(name, Var.new(type or expr_ty, nil, kw ~= "const"))
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

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Block] = function(self, node)
		local body = unpack(node.data)
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Realm] = function(self, node)
		local _realm, body = unpack(node.data)

		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.If] = function(self, node)
		local _cond, body = unpack(node.data)
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Elseif] = function(self, node)
		local _cond, body = unpack(node.data)
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Else] = function(self, node)
		local body = unpack(node.data)
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.While] = function(self, node)
		local _cond, body = unpack(node.data)
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Function] = function(self, node)
		local name, args, block = unpack(node.data)

		---@type table<number, string>
		local param_types = {}
		for k, v in ipairs(args) do param_types[k] = v[2] end

		-- Set function in the outer scope.
		self:getScope():setType(name, makeSignature(param_types, self:getReturnType(block)))

		self:pushScope()
			local scope = self:getScope()

			for _, data in ipairs(args) do
				scope:setType( data[1], data[2] )
			end

			-- NOW handle the block
			self:inferPass(block)
		self:popScope()
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.CallExpr] = function(self, node)
		---@type table<number, Node>
		local args = node.data[2]
		self:inferPass(args)
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Class] = function(self, node)
		local name, data = unpack(node.data)
		assert(not self.types[name], "Class " .. name .. " is already defined")
		self.types[name] = Type.new(name, nil, data)
	end
}

--- Runs first pass on the analyzer
---@param ast table<number, Node>
function Analyzer:inferPass(ast)
	if not ast then return end -- Empty block
	for _, node in ipairs(ast) do
		local handler = Handlers[node.kind]
		if handler then
			handler(self, node)
		end
	end
end