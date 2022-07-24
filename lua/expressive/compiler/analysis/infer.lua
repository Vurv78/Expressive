require("expressive/library"); local ELib = ELib

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local makeSignature = ELib.Analyzer.makeSignature
local NODE_KINDS = ELib.Parser.KINDS

local Var = ELib.Var
local Type = ELib.Type

local Handlers = {
	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.VarDeclare] = function(self, data)
		-- kw is either "var", "let" or "const"
		local kw, name, type, expr = data[1], data[2], data[3], data[4]

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
	---@param data table<number, any>
	[NODE_KINDS.VarModify] = function(self, data)
		local name, how, expr2 = data[1], data[2], data[3]

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
	---@param data table<number, any>
	[NODE_KINDS.Block] = function(self, data)
		local body = data[1]
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Realm] = function(self, data)
		local body = data[2]

		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.If] = function(self, data)
		local body = data[2]
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Elseif] = function(self, data)
		local body = data[2]
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Else] = function(self, data)
		local body = data[1]
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.While] = function(self, data)
		local body = data[2]
		self:pushScope()
			self:inferPass(body)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Function] = function(self, data)
		local name, args, block = data[1], data[2], data[3]

		local scope = self:getScope()
		local v = scope:lookup(name)
		if v then
			error("Cannot overwrite variable " .. name .. ":" .. v.type .. " with function")
		end

		---@type table<number, string>
		local param_types = {}
		for k, paramdata in ipairs(args) do param_types[k] = paramdata[2] end

		-- Set function in the outer scope.
		self:getScope():setType(name, makeSignature(param_types, self:getReturnType(block)))

		self:pushScope()
			scope = self:getScope()

			for _, dat in ipairs(args) do
				scope:setType( dat[1], dat[2] )
			end

			-- NOW handle the block
			self:inferPass(block)
		self:popScope()
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.CallExpr] = function(self, data)
		---@type table<number, Node>
		local args = data[2]
		self:inferPass(args)
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Class] = function(self, data)
		local name, class_data = data[1], data[2]
		assert(not self.types[name], "Class " .. name .. " is already defined")
		self.types[name] = Type.new(name, nil, class_data)
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Lambda] = function(self, data)
		local params, block = data[1], data[2]

		self:pushScope()
			local scope = self:getScope()
			for _, v in ipairs(params) do
				scope:setType(v[1], v[2])
			end
			self:inferPass(block)
		self:popScope()
	end
}

--- Runs first pass on the analyzer
---@param ast table<number, Node>
function Analyzer:inferPass(ast)
	if not ast then return end -- Empty block
	for _, node in ipairs(ast) do
		local handler = Handlers[node.kind]
		if handler then
			handler(self, node.data)
		end
	end
end