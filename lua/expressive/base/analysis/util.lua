local ELib = require("expressive/library")
local Analyzer = ELib.Analyzer
local NODE_KINDS = ELib.Parser.KINDS

--- Creates a signature for a function.
--- Note that closures (lambdas) and functions are treated the same.
--- ## Example
--- ### IN:
--- ```lua
--- 	makeSignature({"number", "number", "int"}, "number")
--- ```
--- ### OUT:
--- ```text
---		function(number,number,int):number
--- ```
---@param params table<number, Node>
---@param ret string
---@return string
local function makeSignature(params, ret)
	return "function(" .. table.concat(params, ",") .. "):" .. ret
end

Analyzer.makeSignature = makeSignature

--- Gets the return type from a block, searching for the first return statement.
-- If no statement is found, returns "void"
---@param block table<number, Node>
---@return TypeSig
function Analyzer:getReturnType(block)
	for _, node in ipairs(block) do
		if node.kind == NODE_KINDS.Escape and node.data[1] == "return" then
			return self:typeFromExpr(node.data[2])
		end
	end
	return "void"
end

local Infer = {
	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Literal] = function(_self, data)
		-- Either "int", "string", "boolean" or "null"
		local ty = data[1]
		if ty == "number" then
			return data[4] -- Specific number type -- either "int" or "double"
		end
		return ty
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Block] = function(self, data)
		---@type Node
		local last_node = data[1][#data[1]]
		if last_node:isExpression() then
			return self:typeFromExpr(last_node)
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.ArithmeticOps] = function(self, data)
		local lhs, rhs = data[2], data[3]
		if lhs.kind == rhs.kind and rhs.kind == NODE_KINDS.Literal then
			local lhs_ty = self:typeFromExpr(lhs)
			local rhs_ty = self:typeFromExpr(rhs)
			if lhs_ty == rhs_ty then
				return lhs_ty
			end
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Array] = function(self, data)
		local nodes = data[1]

		local n_nodes = #nodes
		if n_nodes == 0 then
			-- Empty array. Can't guess type here.
			return
		end

		local expected_ty = self:typeFromExpr(nodes[1])
		for k = 2, n_nodes do
			local node_ty = self:typeFromExpr(nodes[k])
			assert(node_ty == expected_ty, "Array elements must be of the same type. Expected " .. expected_ty .. ", got " .. node_ty .. " at arg " .. k)
		end
		-- temp. Maybe it should be ty[] as in typescript.
		return "array[" .. expected_ty .. "]"
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Variable] = function(self, data)
		local name = data[1]
		local var = self:getScope():lookup(name)

		if var then
			return var.type
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Lambda] = function(self, data)
		local params, block = data[1], data[2]

		-- Extract types from params
		local ptypes = {}
		for k, v in ipairs(params) do
			ptypes[k] = v[2]
		end
		return makeSignature(ptypes, assert(self:getReturnType(block), "Couldn't determine return type of lambda"))
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Ternary] = function(self, data)
		local expr, iff, els = data[1], data[2], data[3]
		if els ~= nil then
			-- cond ? x : y

			if iff.kind == els.kind and els.kind == NODE_KINDS.Literal then
				local iff_ty = self:typeFromExpr(iff)
				local els_ty = self:typeFromExpr(els)
				if iff_ty == els_ty then
					return iff_ty
				end
			end
		else
			-- x ?? y
			if expr.kind == iff.kind and iff.kind == NODE_KINDS.Literal then
				local iff_ty = self:typeFromExpr(expr)
				local expr_ty = self:typeFromExpr(iff)
				if expr_ty == expr_ty then
					return iff_ty
				end
			end
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.LogicalOps] = function(_self, _data)
		-- TODO: Logical Ops
	end,

	--- x.y or x[y]. This only applies to arrays right now, so can just return the type of the array.
	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Index] = function(self, data)
		local kind, tbl, field = data[1], data[2], data[3]

		if kind == "." then
			-- First 'tbl' is parsed as a variable.
			local lib, var_name = tbl.data[1], field.raw
			local namespace = self.ctx.namespaces[lib]

			---@type Variable
			if namespace then
				local var = assert(namespace.variables[var_name], "Cannot find field " .. var_name .. " in namespace " .. lib)
				return var.type
			else
				local v = self:getScope():lookup(lib)
				assert( v, "Cannot find array " .. lib)
				return v.type
			end
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.CallExpr] = function(self, data)
		-- TODO: Overloads
		local expr = data[1]
		local ty = self:typeFromExpr(expr)
		return string.match(ty, "^[^:]+:(.+)")
	end
}

---@param node Node # Parsing node to get type from
---@return string?
function ELib.Analyzer:typeFromExpr(node)
	local handler = Infer[node.kind]
	if handler then
		local out = handler(self, node.data)
		if out then
			return out
		end
	end
end