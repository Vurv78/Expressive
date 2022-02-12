local ELib = require("expressive/library")

local Analyzer = ELib.Analyzer
local Parser = ELib.Parser
local Node = Parser.Node

local NODE_KINDS = Parser.KINDS

local Optimizations
Optimizations = {
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
			return Node.new(NODE_KINDS.VarDeclare, { data[1], data[2], data[3], opt })
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
		---@type string
		local op = data[1]

		---@type Node
		local left, right = self:optimizeNode(data[2]) or data[2], self:optimizeNode(data[3]) or data[3]
		if left.kind == NODE_KINDS.Literal and right.kind == NODE_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]

			if left_kind == right_kind then
				if left_kind == "number" then
					-- Optimize basic number arithmetic at compile time.
					-- TODO: Maybe restrict this to integer literals to avoid precision loss
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
				elseif left_kind == "string" and op == "+" then -- String literal concat
					-- TODO: Maybe string rep with "foo" * 5 being optimized into "foofoofoofoofoo" ? (Don't know if that exists in Typescript.)
					local left_value, right_value = left.data[2], right.data[2]
					return Node.new(NODE_KINDS.Literal, {"string", left_value .. right_value})
				end
			end
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.BitShiftOps] = function(self, data)
		---@type string
		local op = data[1]

		local left, right = self:optimizeNode(data[2]) or data[2], self:optimizeNode(data[3]) or data[3]
		if left.kind == NODE_KINDS.Literal and right.kind == NODE_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]

			if left_kind == right_kind and left_kind == "number" then
				local left_value, right_value = left.data[2], right.data[2]
				if op == ">>" then
					local val = bit.rshift(left_value, right_value)
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				elseif op == "<<" then
					local val = bit.lshift(left_value, right_value)
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				else
					error("Unrecognized bshift operator: " .. op)
				end
			end
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.BitwiseOps] = function(self, data)
		---@type string
		local op = data[1]

		local left, right = self:optimizeNode(data[2]) or data[2], self:optimizeNode(data[3]) or data[3]
		if left.kind == NODE_KINDS.Literal and right.kind == NODE_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]

			if left_kind == right_kind and left_kind == "number" then
				local left_value, right_value = left.data[2], right.data[2]
				if op == "|" then
					local val = bit.bor(left_value, right_value)
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				elseif op == "&" then
					local val = bit.band(left_value, right_value)
					return Node.new(NODE_KINDS.Literal, {"number", val, val < 0, data[4]})
				else
					error("Unrecognized bitwise operator: " .. op)
				end
			end
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.LogicalOps] = function(self, data)
		---@type string
		local op = data[1]

		local left, right = self:optimizeNode(data[2]) or data[2], self:optimizeNode(data[3]) or data[3]
		if left.kind == NODE_KINDS.Literal and right.kind == NODE_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]

			if left_kind == right_kind and left_kind == "boolean" then
				local left_value, right_value = left.data[2], right.data[2]
				if op == "||" then
					local val = left_value or right_value
					return Node.new(NODE_KINDS.Literal, {"boolean", val})
				elseif op == "&&" then
					local val = left_value or right_value
					return Node.new(NODE_KINDS.Literal, {"boolean", val})
				else
					error("Unrecognized logical operator: " .. op)
				end
			end
		end
	end,

	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.ComparisonOps] = function(self, data)
		---@type string
		local op = data[1]

		local left, right = self:optimizeNode(data[2]) or data[2], self:optimizeNode(data[3]) or data[3]
		if left.kind == NODE_KINDS.Literal and right.kind == NODE_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]

			if left_kind == right_kind and left_kind == "number" then
				local left_value, right_value = left.data[2], right.data[2]
				if op == "<=" then
					return Node.new(NODE_KINDS.Literal, {"boolean", left_value <= right_value})
				elseif op == ">=" then
					return Node.new(NODE_KINDS.Literal, {"boolean", left_value >= right_value})
				elseif op == ">" then
					return Node.new(NODE_KINDS.Literal, {"boolean", left_value > right_value})
				elseif op == "<" then
					return Node.new(NODE_KINDS.Literal, {"boolean", left_value < right_value})
				elseif op == "!=" then
					return Node.new(NODE_KINDS.Literal, {"boolean", left_value ~= right_value})
				elseif op == "==" then
					return Node.new(NODE_KINDS.Literal, {"boolean", left_value == right_value})
				else
					error("Unrecognized logical operator: " .. op)
				end
			end
		end
	end,

	-- TODO: Doesn't seem to work.
	---@param self Analyzer
	---@param data table<number, any>
	[NODE_KINDS.Ternary] = function(self, data)
		local cond, left, right = self:optimizeNode(data[1]) or data[1], self:optimizeNode(data[2]) or data[2], data[3]

		if right then
			right = self:optimizeNode(right) or right
			-- cond ? left : right
			if cond.kind == NODE_KINDS.Literal and cond.data[1] == "boolean" then
				if cond.data[2] then
					return left
				else
					return right
				end
			end
		else
			-- cond ?? left
			if cond.kind == NODE_KINDS.Literal then
				local cond_kind = cond.data[1]
				if cond_kind == "boolean" then
					local cond_val = cond.data[2]
					if cond_val then
						return Node.new(NODE_KINDS.Literal, {"boolean", true})
					else
						return left
					end
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
		local out = handler(self, node.data)
		if out then
			return out
		end
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
		--if opt then print("Optimized", node:human(), "to", opt:human()) end
		new[i] = opt or node
	end

	return new
end