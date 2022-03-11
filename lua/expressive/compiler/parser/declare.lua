local ELib = require("expressive/library")

local Parser = ELib.Parser

local isToken = ELib.Parser.isToken
local isAnyOf = ELib.Parser.isAnyOf

local TOKEN_KINDS = ELib.Tokenizer.KINDS

local Declarations
Declarations = {
	--- ### Function declaration
	--- ```ts
	--- declare function foo(bar: number): number;
	--- ```
	---@param self Parser
	---@param token Token
	function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "function") then
			local name = assert( self:acceptIdent(), "Expected function name after 'function'" )
			local params = assert(self:acceptTypedParameters(), "Expected typed parameters after function name")
			assert(self:popToken(TOKEN_KINDS.Grammar, ":"), "Expected : to precede return type of declared function")
			local ret_type = assert( self:acceptType(), "Expected return type after :, got " .. self:peek().raw )

			return {"function", name, params, ret_type}
		end
	end,

	--- ### Variable declaration
	--- ```ts
	--- declare var foo: number;
	--- ```
	---@param self Parser
	---@param token Token
	function(self, token)
		local kind = isAnyOf(token, TOKEN_KINDS.Keyword, {"var", "const"})
		if kind then
			local name = assert( self:acceptIdent(), "Expected variable name after 'var' in declare statement" )
			assert( self:popToken(TOKEN_KINDS.Grammar, ":"), "Expected ':' after variable name in declare statement" )
			local ty = assert( self:acceptType(), "Expected type after ':' in declare statement" )
			return {"var", name, kind, ty}
		end
	end,

	--- ### Primitive Type Declaration
	--- Differs from typescript. This declares a primitive type.
	--- ```ts
	---	declare type number;
	--- ```
	---@param self Parser
	---@param token Token
	function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "type") then
			local name = assert( self:acceptIdent(), "Expected type name (foo) after 'type'" )
			return {"type", name}
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
	---@param token Token
	function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "namespace") then
			local name = assert( self:acceptIdent(), "Expected namespace name after 'namespace'" )
			assert( self:popToken(TOKEN_KINDS.Grammar, "{"), "Expected '{' after namespace name" )
			local nodes = {}
			-- Use :peek as to not harm the current tokens for error handling if an improper node is given in the namespace body

			local node = self:acceptDeclare( self:nextToken(), true )

			while node do
				-- Discard, it was a declaration node.
				--self:nextToken()

				nodes[#nodes + 1] = node
				assert(self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ';' after declare statement")

				if self:popToken(TOKEN_KINDS.Grammar, "}") then
					break
				end

				node = self:acceptDeclare( self:nextToken(), true )
			end

			return { "namespace", name, nodes }
		end
	end
}

--- Parses a declare statement from the given token, assuming it is a "declare" keyword.
--- This is to be used internally with [Parser:parseStatement], which is why this returns the data, instead of a [Node].
---@param tok Token
---@param ignore_kw boolean # Whether to skip needing a 'declare' keyword at the start of this.
---@return table # Custom arguments for each different kind of declaration
function Parser:acceptDeclare(tok, ignore_kw)
	if ignore_kw then
		for _, handler in ipairs(Declarations) do
			local data = handler(self, tok)
			if data then
				return data
			end
		end
		error("Invalid declare statement, expected [var, const, function, type, namespace] but got " .. tok.raw)
	elseif isToken(tok, TOKEN_KINDS.Keyword, "declare") then
		tok = self:nextToken()
		for _, handler in ipairs(Declarations) do
			local data = handler(self, tok)
			if data then
				return data
			end
		end
		error("Invalid declare statement, expected [var, const, function, type, namespace] but got " .. tok.raw)
	end
end