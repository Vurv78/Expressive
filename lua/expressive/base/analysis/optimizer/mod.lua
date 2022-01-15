local ELib = require("expressive/library")

local Analyzer = ELib.Analyzer
local Parser = ELib.Parser
local Node = Parser.Node

local PARSER_KINDS = Parser.KINDS

local Optimizations = {
	--- Optimizes away cases of if(true), if(!0), if("Foo"), etc.
	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.If] = function(self, node)
		---@type Node
		local cond, block = unpack(node.data)
		if cond.kind == PARSER_KINDS.Literal then
			---@type string
			local literal_kind = cond.data[1]
			if literal_kind == "boolean" and cond.data[2] then
				if cond.data[2] then
					return Node.new(PARSER_KINDS.Block, block)
				end
				-- Return nothing, this is if(false)
			elseif literal_kind == "string" then
				-- Strings will always be true.
				return Node.new(PARSER_KINDS.Block, block)
			elseif literal_kind == "number" then
				if cond.data[2] ~= 0 then
					return Node.new(PARSER_KINDS.Block, block)
				end
			end
		end
		return node
	end,

	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.VarDeclare] = function(self, node)
		local kw, name, ty, expr = unpack(node.data)
		return node
	end,

	--- Optimizes away cases of simple arithmetic like (5 + 5) or "Hello" + "World"
	---@param self Analyzer
	---@param node Node
	[PARSER_KINDS.ArithmeticOps] = function(self, node)
		---@type Node
		local left, right = unpack(node.data)

		if left.kind == PARSER_KINDS.Literal and right.kind == PARSER_KINDS.Literal then
			local left_kind, right_kind = left.data[1], right.data[1]
			if left_kind == "number" and right_kind == "number" then
				local left_value, right_value = left.data[2], right.data[2]
				if node.data[1] == "+" then
					local val = left_value + right_value
					return Node.new(PARSER_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif node.data[1] == "-" then
					local val = left_value - right_value
					return Node.new(PARSER_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif node.data[1] == "*" then
					local val = left_value * right_value
					return Node.new(PARSER_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif node.data[1] == "/" then
					local val = left_value / right_value
					return Node.new(PARSER_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				elseif node.data[1] == "%" then
					local val = left_value % right_value
					return Node.new(PARSER_KINDS.Literal, {"number", val, val < 0, node.data[4]})
				end
			end
		end
		return node
	end
}

--- Tries to optimize an ast by cutting down on useless instructions
---@param ast table<number, Node>
---@return table<number, Node> # Optimized AST
function Analyzer:optimize(ast)
	local new = {}
	if not ast then return new end -- Empty block
	for i, node in ipairs(ast) do
		local handler = Optimizations[node.kind]
		if handler then
			local old = node
			node = handler(self, node)
			if node ~= old then
				print("Optimized away: ", old)
			end
		end
		table.insert(new, node)
	end
	return new
end