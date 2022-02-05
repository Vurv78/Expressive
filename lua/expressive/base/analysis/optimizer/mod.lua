local ELib = require("expressive/library")

local Analyzer = ELib.Analyzer
local Parser = ELib.Parser
local Node = Parser.Node

local NODE_KINDS = Parser.KINDS

local Optimizations = {
	--- Optimizes away cases of if(true), if(!0), if("Foo"), etc.
	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.If] = function(self, data)
		---@type Node
		local cond, block = data[1], data[2]
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
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.VarDeclare] = function(self, data)
		local expr = data[4]
		local opt = self:optimizeNode(expr)
		if opt then
			return Node.new(NODE_KINDS.VarDeclare, { data[1], data[2], data[3], expr })
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.GroupedExpr] = function(self, data)
		return self:optimizeNode(data[1])
	end,

	-- Optimize not operator on bools
	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.UnaryOps] = function(self, data)
		local op, expr = data[1], data[2]

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
	---@param data table<number, any>
	[NODE_KINDS.ArithmeticOps] = function(self, data)
		---@type Node
		local op, left, right = data[1], data[2], data[3]

		if left.kind == NODE_KINDS.Literal and right.kind == NODE_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]

			if left_kind == "number" and right_kind == "number" then
				local left_value, right_value = left.data[2], right.data[2]
				if op == "+" then
					local val = left_value + right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				elseif op == "-" then
					local val = left_value - right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				elseif op == "*" then
					local val = left_value * right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				elseif op == "/" then
					local val = left_value / right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				elseif op == "%" then
					local val = left_value % right_value
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				end
			end
		end
	end
}

---@param node Node
---@return Node? # New optimized node, or nil if no optimization was possible
function Analyzer:optimizeNode(node)
	local handler = Optimizations[node.kind]
	if handler then
		return handler(self, node.data, node)
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
		new[i] = opt or node
	end
	return new
end