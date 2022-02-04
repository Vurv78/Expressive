local ELib = require("expressive/library")

local Analyzer = ELib.Analyzer
local Parser = ELib.Parser
local Node = Parser.Node

local NODE_KINDS = Parser.KINDS

local Optimizations = {
	--- Optimizes away cases of if(true), if(!0), if("Foo"), etc.
	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.If] = function(self, node)
		---@type Node
		local cond, block = unpack(node.data)
		if cond.kind == NODE_KINDS.Literal then
			---@type string
			local literal_kind = cond.data[1]
			if literal_kind == "boolean" and cond.data[2] then
				if cond.data[2] then
					self:warn("Redundant if(true). Optimized into block.")
					return Node.new(NODE_KINDS.Block, block)
				end
				-- Return nothing, this is if(false)
			elseif literal_kind == "string" then
				-- Strings will always be true.
				return Node.new(NODE_KINDS.Block, block)
			elseif literal_kind == "number" then
				if cond.data[2] ~= 0 then
					return Node.new(NODE_KINDS.Block, block)
				end
			end
		end
		return node
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.VarDeclare] = function(self, node)
		local expr = node.data[4]
		local opt = self:optimizeNode(expr)
		if opt then
			return Node.new(NODE_KINDS.VarDeclare, { node.data[1], node.data[2], node.data[3], expr })
		end
	end,

	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.GroupedExpr] = function(self, node)
		return self:optimizeNode(node.data[1])
	end,

	-- Optimize not operator on bools
	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.UnaryOps] = function(self, node)
		local op, expr = node.data[1], node.data[2]

		---@type Node
		local exp = self:optimizeNode(expr) or expr

		if exp.kind == NODE_KINDS.Literal and exp.data[1] == "boolean" then
			if op == "!" then
				return Node.new(NODE_KINDS.Literal, { "boolean", not exp.data[2] })
			else
				-- Other operators not supported
				return exp
			end
		end
	end,

	--- Optimizes away cases of simple arithmetic like (5 + 5) or "Hello" + "World"
	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.ArithmeticOps] = function(self, node)
		---@type Node
		local op, left, right = node.data[1], node.data[2], node.data[3]

		if left.kind == NODE_KINDS.Literal and right.kind == NODE_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]

			if left_kind == "number" and right_kind == "number" then
				local left_value, right_value = left.data[2], right.data[2]
				if op == "+" then
					local val = left_value + right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif op == "-" then
					local val = left_value - right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif op == "*" then
					local val = left_value * right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif op == "/" then
					local val = left_value / right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif op == "%" then
					local val = left_value % right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				end
			end
		end
		return node
	end
}

---@param node Node
---@return Node? # New optimized node, or nil if no optimization was possible
function Analyzer:optimizeNode(node)
	local handler = Optimizations[node.kind]
	if handler then
		return handler(self, node)
	end
end

--- Tries to optimize an ast by cutting down on useless instructions
---@param ast table<number, Node>
---@return table<number, Node> # Optimized AST
function Analyzer:optimize(ast)
	local new = {}
	if not ast then return new end -- Empty block
	for i, node in ipairs(ast) do
		local opt = self:optimizeNode(node)
		if opt then print("Optimized", node:human(), "to", opt:human()) end
		new[#new + 1] = opt or node
	end
	return new
end