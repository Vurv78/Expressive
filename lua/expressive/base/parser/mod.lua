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

---@param name string # Name of the statement
---@param desc string # Human description of the statement, for debugging.
---@return table
local function Stmt(name, desc)
	return { name = name, udata = { desc = desc, type = "stmt" } }
end

---@param name string # Name of the statement
---@param desc string # Human description of the statement, for debugging.
---@return table
local function Expr(name, desc)
	return { name = name, udata = { desc = desc, type = "expr" } }
end

---@class ParserKinds
---@field If number
---@field Elseif number
---@field Else number
---@field While number
---@field For number
---@field Try number
---@field Realm number
---@field VarDeclare number
---@field VarModify number
---@field Delegate number
---@field Class number
---@field Interface number
---@field Function number
---@field Escape number
---@field Declare number
---@field Ternary number
---@field LogicalOps number
---@field BitwiseOps number
---@field ComparisonOps number
---@field BitShiftOps number
---@field ArithmeticOps number
---@field UnaryOps number
---@field CallExpr number
---@field GroupedExpr number
---@field Index number
---@field Array number
---@field Block number
---@field Lambda number
---@field Literal number
---@field Variable number
local KINDS, KINDS_UDATA = ELib.MakeEnum {
	--- Statements
	Stmt("If", "if statement"), -- if (true) {}
	Stmt("Elseif", "elseif statement"), -- if (true) {} elseif (true) {}
	Stmt("Else", "else statement"), -- if (true) {} else {}
	Stmt("While", "while loop"), -- while (true) {}
	Stmt("For", "for loop"), -- for(let foo = 5; foo < 5; foo++) {}
	Stmt("Try", "try"), -- try {} catch (e: int) {}
	Stmt("Realm", "realm block"), -- Set realm for block
	Stmt("VarDeclare", "variable declaration"), -- var Foo = 5;
	Stmt("VarModify", "variable modification"), -- Foo += 5;
	Stmt("Delegate", "delegate"),
	Stmt("Class", "class definition"), -- class Main {}
	Stmt("Interface", "interface definition"), -- interface Main {}
	Stmt("Function", "function definition"), -- function foo(): number {}
	Stmt("Escape", "return, break or continue"), -- Either return Var?, break or continue.
	Stmt("Declare", "extern declaration"), -- declare function foo(): number

	--- Expressions
	Expr("Ternary", "ternary operation"), -- a ? b : c (a ?? b)
	Expr("LogicalOps", "logical operation"), -- || &&
	Expr("BitwiseOps", "binary operation"), -- | ^ &
	Expr("ComparisonOps", "comparison"), -- == != > >= < <=
	Expr("BitShiftOps", "bit shift operation"), -- << >>
	Expr("ArithmeticOps", "arithmetic"), -- + - / * %
	Expr("UnaryOps", "unary operation"), -- ! # ~ $
	Expr("CallExpr", "call"), -- foo()
	Expr("GroupedExpr", "grouped expression"), -- (x + y)
	Expr("Index", "index"), -- x.y or x[y]
	Expr("Array", "array literal"), -- [1, 2, 3]
	Expr("Block", "block"), -- { ... }
	Expr("Lambda", "lambda / closure"), -- function(x...) { ... }
	Expr("Literal", "literal value"), -- 5, "foo", true, false, nil
	Expr("Variable", "variable") -- foo
}

local KINDS_INV = ELib.GetInverted(KINDS)

Parser.KINDS = KINDS
Parser.KINDS_INV = KINDS_INV

---@type table<number, {type: string}>
Parser.KINDS_UDATA = KINDS_UDATA

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
	local udata = KINDS_UDATA[self.kind]
	return udata.desc
end

---@return boolean # Whether the node is an expression node.
function Node:isExpression()
	return KINDS_UDATA[self.kind].type == "expr"
end

---@return boolean # Whether the node is a statement node.
function Node:isStatement()
	return KINDS_UDATA[self.kind].type == "stmt"
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
		nodes[#nodes + 1] = node
		-- assert(node, "Expected ; after statement")

		print(node)
		if node:isStatement() then
			self:popToken(TOKEN_KINDS.Grammar, ";")
		end

		if self:popToken(TOKEN_KINDS.Grammar, "}") then
			return nodes
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

	if res then
		assert(self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ; after " .. res:human())
		return res
	else
		error("Unexpected token " .. TOKEN_KINDS_INV[tok.kind] .. " '" .. tok.raw .. "'")
	end
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
		-- assert(node, "Expected ; after statement")

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