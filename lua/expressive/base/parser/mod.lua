local ELib = require("expressive/library")
local class = require("voop")

---@type TokenKinds
local TOKEN_KINDS = ELib.Tokenizer.KINDS
local TOKEN_KINDS_INV = ELib.Tokenizer.KINDS_INV

---@class Parser: Object
---@field tok_idx number Index of the current token
---@field tokens table<number, Token>
---@field node_idx number Index of the current node
---@field nodes table<number, Node>
local Parser = class("Parser")
ELib.Parser = Parser

function Parser:reset()
	self.tok_idx = 0
	self.nodes = {}
	self.node_idx = 0
end

---@return Parser
function Parser.new()
	---@type Parser
	local instance = setmetatable({}, Parser)
	instance:reset()
	return instance
end

--- Creates a control flow statement e.g. if, while, for, etc.
---@param name string # Name of the statement
---@param desc string # Human description of the statement, for debugging.
---@return table
local function Control(name, desc)
	return { name = name, udata = { desc = desc, type = "stmt", decl = false } }
end

--- Creates a declaration statement e.g. "var x = 1"
---@param name string # Name of the statement
---@param desc string # Human description of the statement, for debugging.
---@return table
local function Declare(name, desc)
	return { name = name, udata = { desc = desc, type = "stmt", decl = true } }
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
---@field Export number
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
---@field Constructor number
---@field Literal number
---@field Variable number
local KINDS, KINDS_UDATA = ELib.MakeEnum {
	--- Statements
	Control("If", "if statement"), -- if (true) {}
	Control("Elseif", "elseif statement"), -- if (true) {} elseif (true) {}
	Control("Else", "else statement"), -- if (true) {} else {}
	Control("While", "while loop"), -- while (true) {}
	Control("For", "for loop"), -- for(let foo = 5; foo < 5; foo++) {}
	Control("Try", "try"), -- try {} catch (e: int) {}
	Control("Realm", "realm block"), -- Set realm for block
	Declare("VarDeclare", "variable declaration"), -- var Foo = 5;
	Declare("VarModify", "variable modification"), -- Foo += 5;
	Declare("Delegate", "delegate"),
	Declare("Class", "class definition"), -- class Main {}
	Declare("Interface", "interface definition"), -- interface Main {}
	Declare("Function", "function definition"), -- function foo(): number {}
	Control("Escape", "return, break or continue"), -- Either return Var?, break or continue.
	Declare("Declare", "extern declaration"), -- declare function foo(): number
	Declare("Export", "export modifier"), -- export declare var foo: number

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
	Expr("Constructor", "new expression"), -- new Foo()
	Expr("Literal", "literal value"), -- 5, "foo", true, false, nil
	Expr("Variable", "variable") -- foo
}

local KINDS_INV = ELib.GetInverted(KINDS)

Parser.KINDS = KINDS
Parser.KINDS_INV = KINDS_INV

---@type table<number, {type: string}>
Parser.KINDS_UDATA = KINDS_UDATA

---@class Node: Object
---@field kind ParserKinds
---@field data table
local Node = class("Node")
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

---@return boolean # Whether the node is a declaration. E.g. "var x = 1"
function Node:isDeclaration()
	return KINDS_UDATA[self.kind].decl
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

	self:reset()
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

	repeat
		local node = self:next()
		nodes[#nodes + 1] = node
	until not node

	return nodes
end

---@return Node?
function Parser:next()
	if not self:hasTokens() then
		return nil
	end

	local tok = self:nextToken()
	---@type Node?
	local res = self:parseStatement(tok) or self:parseExpression(tok)

	if res then
		-- Expect ; after declaration statements.
		if res:isExpression() or res:isDeclaration() then
			assert(self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ; after " .. res:human())
		end
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

	local nodes, node_idx = {}, 0
	repeat
		node_idx = node_idx + 1
		local node = self:next()
		nodes[node_idx] = node

		if self:popToken(TOKEN_KINDS.Grammar, "}") then
			return nodes
		end
	until not node

	error("Right curly bracket (}) missing, to close block")
end

---@return string
function Parser:acceptType()
	--- TODO: This needs to properly create a type struct, which stores whether it is variadic, array, etc.
	local ty = self:popToken(TOKEN_KINDS.Identifier)
	if ty then
		if self:popToken(TOKEN_KINDS.Grammar, "[") then
			assert( self:popToken(TOKEN_KINDS.Grammar, "]"), "Expected ] to complete array type (int[])" )
			return ty.raw
		end
		return ty.raw
	end
end

--- Returns a table in the format of { { [1] = name, [2] = type } ... }, with both fields being strings
---@return table<number, table<number, string>>
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

			args[#args + 1] = { arg.raw, ty }

			if not self:popToken(TOKEN_KINDS.Grammar, ",") then
				assert( self:popToken(TOKEN_KINDS.Grammar, ")"), "Expected ) to end function parameters" )
				break
			end
		end
	end
	return args
end

--- Returns a table of arguments, like (bar, foo, baz, 55, "qux", 500.0 + 291.2 / 5.0)
function Parser:acceptArguments()
	if self:popToken(TOKEN_KINDS.Grammar, "(") then
		local nargs, args = 1, {}
		local arg = self:parseExpression(self:nextToken())
		while arg do
			args[nargs] = arg
			nargs = nargs + 1

			if self:popToken(TOKEN_KINDS.Grammar, ")") then
				break
			end

			if self:popToken(TOKEN_KINDS.Grammar, ",") then
				arg = self:parseExpression(self:nextToken())
			else
				assert( self:popToken(TOKEN_KINDS.Grammar, ")"), "Expected ) or , after argument in call expr" )
				break
			end
		end

		return args
	end
end

include("stmt.lua")
include("expr.lua")
include("declare.lua")
include("class.lua")

---@type fun(self: Parser, tok: Token): Node?
Parser.parseExpression = Parser.parseExpression

---@type fun(self: Parser, tok: Token): Node?
Parser.parseStatement = Parser.parseStatement

---@type fun(self: Parser, tok: Token): Node?
Parser.acceptDeclare = Parser.acceptDeclare

---@type fun(self: Parser, tok: Token): Node?
Parser.acceptClassBlock = Parser.acceptClassBlock

return Parser