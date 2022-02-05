local ELib = require("expressive/library")

local Parser = ELib.Parser
local Node = Parser.Node

local isToken = ELib.Parser.isToken
local isAnyOf = ELib.Parser.isAnyOf
local isAnyOfKind = ELib.Parser.isAnyOfKind

local TOKEN_KINDS = ELib.Tokenizer.KINDS
local NODE_KINDS = ELib.Parser.KINDS

-- Inferred types from lexer number formats.
-- Do not ever assume uint as that'd get pretty annoying
local NumFormats = {
	[TOKEN_KINDS.Octal] = "int",
	[TOKEN_KINDS.Decimal] = "double",
	[TOKEN_KINDS.Hexadecimal] = "int",
	[TOKEN_KINDS.Integer] = "int",
}

local Expressions
Expressions = {
	-- Ternary
	---@param self Parser
	---@param token Token
	[1] = function(self, token)
		local expr = Expressions[2](self, token)

		-- x ?? y
		if self:popToken(TOKEN_KINDS.Operator, "??") then
			local els = Expressions[2](self, self:nextToken())
			return Node.new(NODE_KINDS.Ternary, { expr, els })
		elseif self:popToken(TOKEN_KINDS.Operator, "?") then
			-- cond ? x : y
			local iff = Expressions[2](self, self:nextToken())
			assert( self:popToken(TOKEN_KINDS.Grammar, ":"), "Expected : after ternary '?'" )
			local els = Expressions[2](self, self:nextToken())
			return Node.new(NODE_KINDS.Ternary, { expr, iff, els })
		end

		return expr
	end,

	-- Logical Operators
	---@param self Parser
	---@param token Token
	[2] = function(self, token)
		local left = Expressions[3](self, token)

		local raw = self:popAnyOf(TOKEN_KINDS.Operator, {"&&", "||"})
		if raw then
			local right = assert( Expressions[3](self, self:nextToken()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.LogicalOps, { raw, left, right })
		end

		return left
	end,

	-- Bitwise ops
	[3] = function(self, token)
		local left = Expressions[4](self, token)

		local raw = self:popAnyOf(TOKEN_KINDS.Operator, {"|", "&"})
		if raw then
			local right = assert( Expressions[4](self, self:nextToken()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.BitwiseOps, { raw, left, right })
		end

		return left
	end,

	-- Comparison ops
	---@param self Parser
	---@param token Token
	[4] = function(self, token)
		local left = Expressions[5](self, token)

		local raw = self:popAnyOf(TOKEN_KINDS.Operator, {"==", "!=", ">=", "<=", ">", "<"})
		if raw then
			local right = assert( Expressions[5](self, self:nextToken()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.ComparisonOps, { raw, left, right })
		end

		return left
	end,

	-- Bit shifting
	---@param self Parser
	---@param token Token
	[5] = function(self, token)
		local left = Expressions[6](self, token)

		local raw = self:popAnyOf(TOKEN_KINDS.Operator, {"<<", ">>"})
		if raw then
			local right = assert( Expressions[6](self, self:nextToken()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.BitShiftOps, { raw, left, right })
		end

		return left
	end,

	-- Arithmetic
	---@param self Parser
	---@param token Token
	[6] = function(self, token)
		local left = Expressions[7](self, token)

		local raw = self:popAnyOf(TOKEN_KINDS.Operator, {"+", "-", "*", "%", "/"})
		if raw then
			local right = assert( Expressions[7](self, self:nextToken()), "Expected expression after " .. raw )
			local first = Node.new(NODE_KINDS.ArithmeticOps, { raw, left, right })
			local last = first

			while true do
				raw = self:popAnyOf(TOKEN_KINDS.Operator, {"+", "-", "*", "%", "/"})
				if not raw then break end
				right = assert( Expressions[7](self, self:nextToken()), "Expected expression after " .. raw )

				-- Arithmetic ops will have 4th data slot for a reference to the next arith op.
				local current = Node.new(NODE_KINDS.ArithmeticOps, { raw, last, right })
				last.data[4] = current
				last = current
			end
			return first
		end
		return left
	end,

	-- Unary ops
	---@param self Parser
	---@param token Token
	[7] = function(self, token)
		-- Todo: Think of a name of something for popAnyOf that uses a given or the current token.
		local raw = isAnyOf(token, TOKEN_KINDS.Operator, {"!", "$", "~"})
		if raw then
			local expr = assert( Expressions[8](self, self:nextToken()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.UnaryOps, { raw, expr })
		end

		return Expressions[8](self, token)
	end,

	--- Call Expr
	---@param self Parser
	---@param token Token
	[8] = function(self, token)
		local expr = Expressions[9](self, token)
		local args = self:acceptArguments()
		if args then
			return Node.new(NODE_KINDS.CallExpr, { expr, args })
		end
		return expr
	end,

	-- Grouped Expression
	---@param self Parser
	---@param token Token
	[9] = function(self, token)
		if isToken(token, TOKEN_KINDS.Grammar, "(") then
			local expr = Expressions[1](self, self:nextToken())
			assert( self:popToken(TOKEN_KINDS.Grammar, ")"), "Expected ) to close grouped expression" )

			return Node.new(NODE_KINDS.GroupedExpr, { expr })
		end

		return Expressions[10](self, token)
	end,

	-- Indexing with x[y] or x.y
	---@param self Parser
	---@param token Token
	[10] = function(self, token)
		local tbl = Expressions[11](self, token)
		if self:popToken(TOKEN_KINDS.Grammar, "[") then
			local key = Expressions[1](self, self:nextToken())
			assert( self:popToken(TOKEN_KINDS.Grammar, "]"), "Expected ] to close indexed expression" )

			return Node.new(NODE_KINDS.Index, { "[]", tbl, key })
		end

		if self:popToken(TOKEN_KINDS.Operator, ".") then
			local key = assert( self:popAnyOfKind({TOKEN_KINDS.Identifier, TOKEN_KINDS.Integer}), "Expected identifier or integer after ." )
			return Node.new(NODE_KINDS.Index, { ".", tbl, key })
		end

		return tbl
	end,

	-- Literal array ([1, 2, 3])
	---@param self Parser
	---@param token Token
	[11] = function(self, token)
		if isToken(token, TOKEN_KINDS.Grammar, "[") then
			local nargs, args = 0, {}
			local arg = Expressions[1](self, self:nextToken())
			while arg do
				nargs = nargs + 1
				args[nargs] = arg

				if self:popToken(TOKEN_KINDS.Grammar, "]") then
					break
				end

				if self:popToken(TOKEN_KINDS.Grammar, ",") then
					arg = Expressions[1](self, self:nextToken())
				else
					assert( self:popToken(TOKEN_KINDS.Grammar, "]"), "Expected ] or , after argument" )
					break
				end
			end

			return Node.new(NODE_KINDS.Array, { args })
		end
		return Expressions[12](self, token)
	end,

	-- Block expression
	---@param self Parser
	---@param token Token
	[12] = function(self, token)
		if isToken(token, TOKEN_KINDS.Grammar, "{") then
			self.tok_idx = self.tok_idx - 1 -- Move backward to accept block
			local block = self:acceptBlock()

			return Node.new(NODE_KINDS.Block, { block })
		end
		return Expressions[13](self, token)
	end,

	--- Lambda
	---@param self Parser
	---@param token Token
	[13] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "function") then
			local params = self:acceptTypedParameters("Expected parameters (foo: int) after lambda definition")
			local block = self:acceptBlock()

			return Node.new(NODE_KINDS.Lambda, { params, block })
		end
		return Expressions[14](self, token)
	end,

	--- Constructor
	---@param self Parser
	---@param token Token
	[14] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "new") then
			local class_name = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected class name after 'new' keyword")
			local args = assert(self:acceptArguments(), "Expected arguments for class constructor")
			return Node.new(NODE_KINDS.Constructor, { class_name.raw, args })
		end
		return Expressions[15](self, token)
	end,

	--- Literal
	---@param self Parser
	---@param token Token
	[15] = function(self, token)
		local num = isAnyOfKind(token, {TOKEN_KINDS.Decimal, TOKEN_KINDS.Hexadecimal, TOKEN_KINDS.Integer, TOKEN_KINDS.Octal})
		if num then
			return Node.new(NODE_KINDS.Literal, { "number", token.value, token.negative, NumFormats[num] })
		elseif isToken(token, TOKEN_KINDS.String) then
			return Node.new(NODE_KINDS.Literal, { "string", token.value })
		elseif isToken(token, TOKEN_KINDS.Boolean) then
			return Node.new(NODE_KINDS.Literal, { "boolean", token.value })
		elseif isToken(token, TOKEN_KINDS.Keyword, "null") then
			return Node.new(NODE_KINDS.Literal, { "null" })
		end

		return Expressions[16](self, token)
	end,

	--- Identifier (Variable references)
	---@param self Parser
	---@param token Token
	[16] = function(self, token)
		if isToken(token, TOKEN_KINDS.Identifier) then
			return Node.new(NODE_KINDS.Variable, { token.raw })
		end
	end
}

---@param tok Token
---@return Node?
function Parser:parseExpression(tok)
	return Expressions[1](self, tok)
end