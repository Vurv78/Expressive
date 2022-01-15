local ELib = require("expressive/library")

local Parser = ELib.Parser
local Node = Parser.Node

local isToken = ELib.Parser.isToken
local isAnyOf = ELib.Parser.isAnyOf
local isAnyOfKind = ELib.Parser.isAnyOfKind

local TOKEN_KINDS = ELib.Tokenizer.KINDS
local PARSER_KINDS = ELib.Parser.KINDS

local Declarations = {
	--- ### Function declaration
	--- ```ts
	--- declare function foo(bar: number): number;
	--- ```
	---@param self Parser
	---@param token Token
	function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "function") then
			local name = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected function after 'function'" )
			local params = self:acceptTypedParameters("Expected typed parameters after function name")
			return Node.new(PARSER_KINDS.Declare, {"function", name, params})
		end
	end,

	--- ### Variable declaration
	--- ```ts
	--- declare var foo: number;
	--- ```
	---@param self Parser
	---@param token Token
	function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "var") then
			local name = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected variable name after 'var' in declare statement" )
			assert( self:popToken(TOKEN_KINDS.Operator, ":"), "Expected ':' after variable name in declare statement" )
			local ty = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected type after ':' in declare statement" )
			return Node.new(PARSER_KINDS.Declare, { "var", name, ty })
		end
	end,

	--- Differs from typescript. This declares a primitive type.
	--- ```ts
	---	declare type number;
	--- ```
	---@param self Parser
	---@param token Token
	function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "type") then
			local name = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected type name (foo) after 'type'" )
			return Node.new(PARSER_KINDS.Declare, { "type", name })
		end
	end,
}

---@param tok Token
---@return Node?
function Parser:parseExtern(tok)
	if isToken(tok, TOKEN_KINDS.Keyword, "declare") then
		return Declarations[1](self, self:nextToken())
	end
end