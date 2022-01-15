local ELib = require("expressive/library")

-- typeFromExpression(node)
local Analyzer = ELib.Analyzer
local PARSER_KINDS = ELib.Parser.KINDS

local function mergeExprs()

end

local Infer = {
	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.Literal] = function(self, node)
		-- Either "int", "string", "boolean" or "null"
		local ty = node.data[1]
		if ty == "number" then
			return node.data[4] -- Specific number type -- either "int" or "double"
		end
		return ty
	end,

	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.Block] = function(self, node)
		---@type Node
		local last_node = node.data[1][#node.data[1]]
		if last_node:isExpression() then
			return self:typeFromExpr(last_node)
		end
	end,

	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.ArithmeticOps] = function(self, node)
		local op, lhs, rhs = unpack(node.data)
		if lhs.kind == rhs.kind and rhs.kind == PARSER_KINDS.Literal then
			local lhs_ty = self:typeFromExpr(lhs)
			local rhs_ty = self:typeFromExpr(rhs)
			if lhs_ty == rhs_ty then
				return lhs_ty
			end
		end
	end,

	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.Array] = function(self, node)
		local nodes = unpack(node.data)

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
	---@param node Node
	[PARSER_KINDS.Variable] = function(self, node)
		local name = unpack(node.data)
		local var = self:getScope():lookup(name)

		if var then
			return var.type
		end
	end,

	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.Lambda] = function(self, node)
		-- TODO
		return "function"
	end,

	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.Ternary] = function(self, node)
		local expr, iff, els = unpack(node.data)
		if els ~= nil then
			-- cond ? x : y

			if iff.kind == els.kind and els.kind == PARSER_KINDS.Literal then
				local iff_ty = self:typeFromExpr(iff)
				local els_ty = self:typeFromExpr(els)
				if iff_ty == els_ty then
					return iff_ty
				end
			end
		else
			-- x ?? y
			if expr.kind == iff.kind and iff.kind == PARSER_KINDS.Literal then
				local iff_ty = self:typeFromExpr(expr)
				local expr_ty = self:typeFromExpr(iff)
				if expr_ty == expr_ty then
					return iff_ty
				end
			end
		end
	end,

	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.LogicalOps] = function(self, node)

	end
}

---@param node Node # Parsing node to get type from
---@return string?
function Analyzer:typeFromExpr(node)
	local handler = Infer[node.kind]
	if handler then
		local out = handler(self, node)
		if out then
			return out
		end
	end
end