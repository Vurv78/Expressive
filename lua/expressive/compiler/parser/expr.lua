require("expressive/library"); local ELib = ELib

local Parser = ELib.Parser
local Node = Parser.Node

local is = ELib.Parser.is
local isAnyOf = ELib.Parser.isAnyOf
local isAnyOfKind = ELib.Parser.isAnyOfKind

local ATOM_KINDS = ELib.Lexer.KINDS
local NODE_KINDS = ELib.Parser.KINDS

local Expressions
Expressions = {
	-- Ternary
	---@param self Parser
	---@param atom Atom
	[1] = function(self, atom)
		local expr = Expressions[2](self, atom)

		-- x ?? y
		if self:consumeIf(ATOM_KINDS.Operator, "??") then
			local els = Expressions[1](self, self:consume())
			return Node.new(NODE_KINDS.Ternary, { expr, els })
		elseif self:consumeIf(ATOM_KINDS.Operator, "?") then
			-- cond ? x : y
			local iff = Expressions[1](self, self:consume())
			assert( self:consumeIf(ATOM_KINDS.Grammar, ":"), "Expected : after ternary '?'" )
			local els = Expressions[1](self, self:consume())
			return Node.new(NODE_KINDS.Ternary, { expr, iff, els })
		end

		return expr
	end,

	-- Logical Operators
	---@param self Parser
	---@param atom Atom
	[2] = function(self, atom)
		local left = Expressions[3](self, atom)

		local raw = self:consumeIfAnyOf(ATOM_KINDS.Operator, {"&&", "||"})
		if raw then
			local right = assert( Expressions[1](self, self:consume()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.LogicalOps, { raw, left, right })
		end

		return left
	end,

	-- Bitwise ops
	[3] = function(self, atom)
		local left = Expressions[4](self, atom)

		local raw = self:consumeIfAnyOf(ATOM_KINDS.Operator, {"|", "&"})
		if raw then
			local right = assert( Expressions[1](self, self:consume()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.BitwiseOps, { raw, left, right })
		end

		return left
	end,

	-- Comparison ops
	---@param self Parser
	---@param atom Atom
	[4] = function(self, atom)
		local left = Expressions[5](self, atom)

		local raw = self:consumeIfAnyOf(ATOM_KINDS.Operator, {"==", "!=", ">=", "<=", ">", "<"})
		if raw then
			local right = assert( Expressions[1](self, self:consume()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.ComparisonOps, { raw, left, right })
		end

		return left
	end,

	-- Bit shifting
	---@param self Parser
	---@param atom Atom
	[5] = function(self, atom)
		local left = Expressions[6](self, atom)

		local raw = self:consumeIfAnyOf(ATOM_KINDS.Operator, {"<<", ">>"})
		if raw then
			local right = assert( Expressions[1](self, self:consume()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.BitShiftOps, { raw, left, right })
		end

		return left
	end,

	-- Arithmetic
	---@param self Parser
	---@param atom Atom
	[6] = function(self, atom)
		local left = Expressions[7](self, atom)
		local op = self:consumeIfAnyOf(ATOM_KINDS.Operator, {"+", "-", "*", "%", "/"})

		if op then
			local right = assert( Expressions[1](self, self:consume()), "Expected expression after " .. op )
			return Node.new(NODE_KINDS.ArithmeticOps, { op, left, right })
		end

		return left
	end,

	-- Unary ops
	---@param self Parser
	---@param atom Atom
	[7] = function(self, atom)
		local raw = isAnyOf(atom, ATOM_KINDS.Operator, {"!", "-"})
		if raw then
			local expr = assert( Expressions[1](self, self:consume()), "Expected expression after " .. raw )
			return Node.new(NODE_KINDS.UnaryOps, { raw, expr })
		end

		return Expressions[8](self, atom)
	end,

	--- Call Expr
	---@param self Parser
	---@param atom Atom
	[8] = function(self, atom)
		local expr = Expressions[9](self, atom)
		local args = self:acceptArguments()
		if args then
			return Node.new(NODE_KINDS.CallExpr, { expr, args })
		end
		return expr
	end,

	--- Lambda
	---@param self Parser
	---@param atom Atom
	[9] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "function") then
			local params = assert(self:acceptTypedParameters(), "Expected parameters (foo: int) after lambda definition")
			local block = self:acceptBlock()

			return Node.new(NODE_KINDS.Lambda, { params, block })
		else
			-- Go to previous atom to be able to pop the "(" atom as the next atom
			self:prev()
			local params = self:acceptTypedParameters()
			if params and self:consumeIf(ATOM_KINDS.Operator, "=>") then
				local block = self:acceptBlock()
				return Node.new(NODE_KINDS.Lambda, { params, block })
			else
				-- Undo the prev call, failed to pop atoms
				self:consume()
			end
		end
		return Expressions[10](self, atom)
	end,

	-- Grouped Expression
	---@param self Parser
	---@param atom Atom
	[10] = function(self, atom)
		if is(atom, ATOM_KINDS.Grammar, "(") then
			local expr = Expressions[1](self, self:consume())
			assert( self:consumeIf(ATOM_KINDS.Grammar, ")"), "Expected ) to close grouped expression" )

			return Node.new(NODE_KINDS.GroupedExpr, { expr })
		end

		return Expressions[11](self, atom)
	end,

	-- Indexing with x[y] or x.y
	---@param self Parser
	---@param atom Atom
	[11] = function(self, atom)
		local tbl = Expressions[12](self, atom)
		if self:consumeIf(ATOM_KINDS.Grammar, "[") then
			local key = Expressions[1](self, self:consume())
			assert( self:consumeIf(ATOM_KINDS.Grammar, "]"), "Expected ] to close indexed expression" )

			return Node.new(NODE_KINDS.Index, { "[]", tbl, key })
		end

		if self:consumeIf(ATOM_KINDS.Operator, ".") then
			local key = assert( self:consumeIfAnyOfKind({ATOM_KINDS.Identifier, ATOM_KINDS.Integer}), "Expected identifier or integer after ." )
			return Node.new(NODE_KINDS.Index, { ".", tbl, key })
		end

		return tbl
	end,

	-- Literal array ([1, 2, 3])
	---@param self Parser
	---@param atom Atom
	[12] = function(self, atom)
		if is(atom, ATOM_KINDS.Grammar, "[") then
			local nargs, args = 0, {}
			local arg = Expressions[1](self, self:consume())
			while arg do
				nargs = nargs + 1
				args[nargs] = arg

				if self:consumeIf(ATOM_KINDS.Grammar, "]") then
					break
				end

				if self:consumeIf(ATOM_KINDS.Grammar, ",") then
					arg = Expressions[1](self, self:consume())
				else
					assert( self:consumeIf(ATOM_KINDS.Grammar, "]"), "Expected ] or , after argument" )
					break
				end
			end

			return Node.new(NODE_KINDS.Array, { args })
		end
		return Expressions[13](self, atom)
	end,

	--- Object
	--- Same as typescript / javascript objects, where it is a curly brace delimited
	--- object defined with key and values, like { foo: "bar", baz: "qux" }
	--- ```ts
	--- let x = {
	---    foo: 1,
	---    bar: 2
	--- };
	--- ```
	---@param self Parser
	---@param atom Atom
	[13] = function(self, atom)
		-- { key: value }
		if is(atom, ATOM_KINDS.Grammar, "{") then
			local field = self:acceptIdent()
			if not field then return end
			if not self:consumeIf(ATOM_KINDS.Grammar, ":") then return end

			local exp = Expressions[1](self, self:consume())
			local expr = assert( exp, "Expected expression after field " .. field )

			local fields = {}
			while field do
				assert( not fields[field], "Duplicate field " .. field )
				fields[field] = expr

				if self:consumeIf(ATOM_KINDS.Grammar, "}") then
					break
				end

				if self:consumeIf(ATOM_KINDS.Grammar, ",") then
					field = self:acceptIdent()
					if not field then break end -- Allow trailing comma
					assert( self:consumeIf(ATOM_KINDS.Grammar, ":"), "Expected colon to follow field name" )

					expr = assert( Expressions[1](self, self:consume()), "Expected expression after field " .. field )
				else
					assert( self:consumeIf(ATOM_KINDS.Grammar, "}"), "Expected } or , after argument" )
					break
				end
			end

			return Node.new(NODE_KINDS.Object, { fields })
		end
		return Expressions[14](self, atom)
	end,

	-- Block expression
	---@param self Parser
	---@param atom Atom
	[14] = function(self, atom)
		if is(atom, ATOM_KINDS.Grammar, "{") then
			self.tok_idx = self.tok_idx - 1 -- Move backward to accept block
			local block = self:acceptBlock()

			return Node.new(NODE_KINDS.Block, { block })
		end
		return Expressions[15](self, atom)
	end,

	--- Constructor
	---@param self Parser
	---@param atom Atom
	[15] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "new") then
			local class_name = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected class name after 'new' keyword")
			local args = assert(self:acceptArguments(), "Expected arguments for class constructor")
			return Node.new(NODE_KINDS.Constructor, { class_name.raw, args })
		end
		return Expressions[16](self, atom)
	end,

	--- Literal
	---@param self Parser
	---@param atom Atom
	[16] = function(self, atom)
		local num = isAnyOfKind(atom, {ATOM_KINDS.Decimal, ATOM_KINDS.Hexadecimal, ATOM_KINDS.Integer, ATOM_KINDS.Octal})
		if num then
			---@cast atom NumericAtom
			return Node.new(NODE_KINDS.Literal, { "number", atom.value, atom.value < 0, atom.type })
		elseif is(atom, ATOM_KINDS.String) then
			---@cast atom StringAtom
			return Node.new(NODE_KINDS.Literal, { "string", atom.value })
		elseif is(atom, ATOM_KINDS.Boolean) then
			---@cast atom BooleanAtom
			return Node.new(NODE_KINDS.Literal, { "boolean", atom.value })
		elseif is(atom, ATOM_KINDS.Keyword, "null") then
			return Node.new(NODE_KINDS.Literal, { "null" })
		end

		return Expressions[17](self, atom)
	end,

	--- Identifier (Variable references)
	---@param _self Parser
	---@param atom Atom
	[17] = function(_self, atom)
		if is(atom, ATOM_KINDS.Identifier) then
			return Node.new(NODE_KINDS.Variable, { atom.raw })
		end
	end
}

---@param atom Atom
---@return Node?
function Parser:parseExpression(atom)
	return Expressions[1](self, atom)
end