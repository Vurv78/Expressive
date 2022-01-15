local ELib = require("expressive/library")

---@type TokenKinds
local TOKEN_KINDS = ELib.Tokenizer.KINDS
local TOKEN_KINDS_INV = ELib.Tokenizer.KINDS_INV

---@class Parser
---@field tok_idx number Index of the current token
---@field tokens table<number, Token>
---@field node_idx number Index of the current node
---@field nodes table<number, Node>
local Parser = {}
Parser.__index = Parser
ELib.Parser = Parser

function Parser.new()
	return setmetatable({
		tok_idx = 0, -- Current token position
		node_idx = 0, -- Current node position
		nodes = {},
	}, Parser)
end

---@class ParserKinds
local KINDS = {
	--- Statements
	If = 1, -- if (true) {}
	Elseif = 2, -- if (true) {} elseif (true) {}
	Else = 3, -- if (true) {} else {}
	While = 4, -- while (true) {}
	For = 5, -- for(let foo = 5; foo < 5; foo++) {}
	Try = 6, -- try {} catch (e: int) {}
	Realm = 7, -- Set realm for block
	VarDeclare = 8, -- var Foo = 5;
	VarModify = 9, -- Foo += 5;
	Delegate = 10,
	Class = 11, -- class Main {}
	Interface = 12, -- interface Main {}
	Function = 13, -- function foo(): number {}
	Escape = 14, -- Either return Var?, break or continue.
	Declare = 15, -- declare function foo(): number

	--- Expressions
	Ternary = 16, -- a ? b : c (a ?? b)
	LogicalOps = 17, -- || &&
	BitwiseOps = 18, -- | ^ &
	ComparisonOps = 19, -- == != > >= < <=
	BitShiftOps = 20, -- << >>
	ArithmeticOps = 21, -- + - / * %
	UnaryOps = 22, -- ! # ~ $
	CallExpr = 23, -- foo()
	GroupedExpr = 24, -- (x + y)
	Index = 25, -- x.y or x[y]
	Array = 26, -- [1, 2, 3]
	Block = 27, -- { ... }
	Lambda = 28, -- function(x...) { ... }
	Literal = 29, -- 5, "foo", true, false, nil
	Variable = 30 -- foo
}

local KINDS_INV = ELib.GetInverted(KINDS)

Parser.KINDS = KINDS
Parser.KINDS_INV = KINDS_INV

---@class Node
---@field kind ParserKinds
---@field data table
local Node = {}
Node.__index = Node
Parser.Node = Node

function Node:__tostring()
	return string.format("Node \"%s\" (#%u)", KINDS_INV[self.kind], #self.data)
end

--- Returns a human friendly string description of the node, for error handling.
---@return string
function Node:human()
	if self:isStatement() then
		return string.format("%s statement", KINDS_INV[self.kind])
	else
		return string.format("%s expression", KINDS_INV[self.kind])
	end
end

---@return boolean # Whether the node is an expression node.
function Node:isExpression()
	return self.kind > KINDS.Declare
end

---@return boolean # Whether the node is a statement node.
function Node:isStatement()
	return self.kind <= KINDS.Declare
end

---@param kind ParserKinds
---@param data table
function Node.new(kind, data)
	return setmetatable({
		kind = kind,
		data = data
	}, Node)
end

--- Parses a stream of tokens into an abstract syntax tree (AST)
---@param tokens table<number, Token> # Tokens retrieved from the [Tokenizer]
---@return table<number, Node>
function Parser:parse(tokens)
	assert(istable(tokens), "bad argument #1 to 'Parser:parse' (table expected, got " .. type(tokens) .. ")")
	self.tokens = tokens

	local ok, res = pcall(self.root, self)
	if not ok then
		local tok = self.tokens[self.tok_idx]
		error("Parser error: [" .. res .. "] at line " .. tok.line .. " char " .. tok.startchar, 0)
	end
	return res
end

function Parser:hasTokens()
	return self.tok_idx < #self.tokens
end

function Parser:root()
	local nodes = {}
	self.nodes = nodes
	local node = self:next()

	while node do
		self.node_idx = self.node_idx + 1
		nodes[self.node_idx] = node

		--self:popToken(TOKEN_KINDS.Grammar, ";")
		if node:isStatement() then
			assert(self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ; after statement")
		else
			self:popToken(TOKEN_KINDS.Grammar, ";")
		end
		node = self:next()
	end

	return nodes
end

---@return Node?
function Parser:next()
	if not self:hasTokens() then
		return nil
	end

	local tok = self:nextToken()
	local res = self:parseStatement(tok) or self:parseExpression(tok)

	return assert(res, "Unexpected token " .. TOKEN_KINDS_INV[tok.kind] .. " '" .. tok.raw .. "'")
end

--- Shifts the parser to the next token.
--- Not to be confused with [Parser:next()], which tries to create another node
---@return Token?
function Parser:nextToken()
	self.tok_idx = self.tok_idx + 1
	return self.tokens[ self.tok_idx ]
end

---@return Token?
function Parser:peek()
	return self.tokens[ self.tok_idx + 1 ]
end

---@return Token?
function Parser:peekBack()
	return self.tokens[ self.tok_idx - 1 ]
end

--- Accepts a condition, delimited by parenthesis
---@return Node? # Expression node
function Parser:acceptCondition()
	assert( self:popToken(TOKEN_KINDS.Grammar, "("), "Expected ( in condition" )
	local exp = self:parseExpression( self:nextToken() )
	assert( self:popToken(TOKEN_KINDS.Grammar, ")"), "Expected ) to close condition" )

	return exp
end

---@return Node?
function Parser:lastNode()
	return self.nodes[ self.node_idx ]
end

--- Returns the last node with the given metadata (assuming it exists and fits the given kind and value)
---@param kind ParserKinds
---@param value string?
---@return Node
function Parser:lastNodeWith(kind, value)
	local last = self:lastNode()
	if not last then return end

	if value ~= nil  then
		return (last.kind == kind and last.raw == value) and last
	else
		return (last.kind == kind) and last
	end
end

--- Returns the last node with the given metadata (assuming it exists and fits the given kind and value)
---@param kind table<number, ParserKinds>
---@return boolean
function Parser:lastNodeAnyOfKind(kind)
	local last = self:lastNode()
	if not last then return end

	for _, k in ipairs(kind) do
		if last.kind == k then
			return true
		end
	end
	return false
end

--- Returns if a given token is of kind 'kind' and has an inner value
---@param token Token
---@param kind TokenKinds
---@param value string? # Optional value to match against
---@return boolean
local function isToken(token, kind, value)
	if not token then return false end

	if value ~= nil then
		return token.kind == kind and token.raw == value
	else
		return token.kind == kind
	end
end

--- Like isToken, but accepts an array of values rather than just one
---@param token Token?
---@param kind TokenKinds
---@param values table<number, string>
---@return string # The raw value from 'values' that matched.
local function isAnyOf(token, kind, values)
	-- Todo: Maybe we shouldn't check for nil here.
	if not token or token.kind ~= kind then return false end

	for _, val in ipairs(values) do
		if token.raw == val then return val end
	end
end

--- Like isAnyOf, but for the kind instead of values.
---@param token Token?
---@param kinds table<number, TokenKinds>
---@return TokenKinds? # The [TokenKinds] that matched.
local function isAnyOfKind(token, kinds)
	for _, kind in ipairs(kinds) do
		if isToken(token, kind, nil) then return kind end
	end
end

Parser.isToken = isToken
Parser.isAnyOf = isAnyOf
Parser.isAnyOfKind = isAnyOfKind

--- Like isToken, but peeks ahead, uses that as the token, skips if it matches it.
---@param kind TokenKinds
---@param value string? # Optional value to match against
---@return Token? # The token that matched
function Parser:popToken(kind, value)
	local token = self:peek()
	if isToken(token, kind, value) then
		return self:nextToken()
	end
end

--- Same as isAnyOf, but skips if it matches it.
---@param kind TokenKinds
---@param values table<number, string> # Values to match against
---@return string? # Raw value that matched from 'values'
function Parser:popAnyOf(kind, values)
	local ret = isAnyOf(self:peek(), kind, values)
	if ret then
		self.tok_idx = self.tok_idx + 1
		return ret
	end
end

--- Same as isAnyOfKind, but skips if it matches it.
---@param kinds table<number, TokenKinds>
---@return Token? # The token that matched
function Parser:popAnyOfKind(kinds)
	local token = self:peek()
	if isAnyOfKind(token, kinds) then
		return self:nextToken()
	end
end


--- Accepts a block, or throws an error if it couldn't.
---@return table<number, Node>
function Parser:acceptBlock()
	assert( self:popToken(TOKEN_KINDS.Grammar, "{"), "Expected { in block" )

	-- Empty block
	if self:popToken(TOKEN_KINDS.Grammar, "}") then
		return {}
	end

	local nodes = {}
	local node = self:next()

	while node do
		nodes[#nodes + 1] = node
		assert(node:isStatement() or self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ; after statement")

		if self:popToken(TOKEN_KINDS.Grammar, "}") then
			return nodes
		end

		node = self:next()
	end

	error("Right curly bracket (}) missing, to close block")
end

---@return string
function Parser:acceptType()
	local ty = self:popToken(TOKEN_KINDS.Identifier)
	if ty then
		if self:popToken(TOKEN_KINDS.Grammar, "[") then
			assert( self:popToken(TOKEN_KINDS.Grammar, "]"), "Expected ] to complete array type (int[])" )
			return ty
		end
		return ty
	end
end

function Parser:acceptTypedParameters(msg)
	assert(self:popToken(TOKEN_KINDS.Grammar, "("), msg)
	local args = {}

	if not self:popToken(TOKEN_KINDS.Grammar, ")") then
		local arg, ty
		while self:hasTokens() do
			arg = self:popToken(TOKEN_KINDS.Identifier)
			if not arg then break end

			assert( self:popToken(TOKEN_KINDS.Grammar, ":"), "Expected : after argument to begin type" )
			ty = assert( self:acceptType(), "Expected type after : in function parameter" )

			args[#args+1] = { arg.raw, ty }

			if not self:popToken(TOKEN_KINDS.Grammar, ",") then
				assert( self:popToken(TOKEN_KINDS.Grammar, ")"), "Expected ) to end function parameters" )
				break
			end
		end
	end
	return args
end

include("stmt.lua")
include("expr.lua")
include("declare.lua")

---@type fun(tok: Token): Node?
Parser.parseExpression = Parser.parseExpression

---@type fun(tok: Token): Node?
Parser.parseStatement = Parser.parseStatement

---@type fun(tok: Token): Node?
Parser.acceptDeclare = Parser.acceptDeclare

return Parser