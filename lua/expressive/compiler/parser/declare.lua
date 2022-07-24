require("expressive/library"); local ELib = ELib

local Parser = ELib.Parser

local is = ELib.Parser.is
local isAnyOf = ELib.Parser.isAnyOf

local ATOM_KINDS = ELib.Lexer.KINDS

local Declarations
Declarations = {
	--- ### Function declaration
	--- ```ts
	--- declare function foo(bar: number): number;
	--- ```
	---@param self Parser
	---@param atom Atom
	function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "function") then
			local name = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected function after 'function'" )
			local params = assert(self:acceptTypedParameters(), "Expected typed parameters after function name")
			assert(self:consumeIf(ATOM_KINDS.Grammar, ":"), "Expected : to precede return type of declared function")
			local ret_type = assert( self:acceptType(), "Expected return type after :, got " .. self:peek().raw )

			return {"function", name.raw, params, ret_type}
		end
	end,

	--- ### Variable declaration
	--- ```ts
	--- declare var foo: number;
	--- ```
	---@param self Parser
	---@param atom Atom
	function(self, atom)
		local kind = isAnyOf(atom, ATOM_KINDS.Keyword, {"var", "const"})
		if kind then
			local name = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected variable name after 'var' in declare statement" )
			assert( self:consumeIf(ATOM_KINDS.Grammar, ":"), "Expected ':' after variable name in declare statement" )
			local ty = assert( self:acceptType(), "Expected type after ':' in declare statement" )
			return {"var", name.raw, kind, ty}
		end
	end,

	--- ### Primitive Type Declaration
	--- Differs from typescript. This declares a primitive type.
	--- ```ts
	---	declare type number;
	--- ```
	---@param self Parser
	---@param atom Atom
	function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "type") then
			local name = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected type name (foo) after 'type'" )
			return {"type", name.raw}
		end
	end,

	--- ### Namespace declaration
	--- ```ts
	--- declare namespace foo {
	---		var bar: number;
	---		namespace inner {
	---			var baz: number;
	---		}
	--- }
	--- ```
	---@param self Parser
	---@param atom Atom
	function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "namespace") then
			local name = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected namespace name after 'namespace'" )
			assert( self:consumeIf(ATOM_KINDS.Grammar, "{"), "Expected '{' after namespace name" )

			local nodes = {}
			local node = self:acceptDeclare( self:consume(), true )

			while node do
				-- Discard, it was a declaration node.
				--self:consume()

				nodes[#nodes + 1] = node
				assert(self:consumeIf(ATOM_KINDS.Grammar, ";"), "Expected ';' after declare statement")

				if self:consumeIf(ATOM_KINDS.Grammar, "}") then
					break
				end

				node = self:acceptDeclare( self:consume_unchecked(), true )
			end

			return { "namespace", name.raw, nodes }
		end
	end
}

--- Parses a declare statement from the given atom, assuming it is a "declare" keyword.
--- This is to be used internally with [Parser:parseStatement], which is why this returns the data, instead of a [Node].
---@param atom Atom
---@param ignore_kw boolean # Whether to skip needing a 'declare' keyword at the start of this.
---@return table? # Custom arguments for each different kind of declaration
function Parser:acceptDeclare(atom, ignore_kw)
	if ignore_kw then
		for _, handler in ipairs(Declarations) do
			local data = handler(self, atom)
			if data then
				return data
			end
		end

		error("Invalid declare statement, expected [var, const, function, type, namespace] but got " .. atom.raw)
	elseif is(atom, ATOM_KINDS.Keyword, "declare") then
		atom = self:consume()
		for _, handler in ipairs(Declarations) do
			local data = handler(self, atom)
			if data then
				return data
			end
		end

		error("Invalid declare statement, expected [var, const, function, type, namespace] but got " .. atom.raw)
	end
end