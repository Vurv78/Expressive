require("expressive/library"); local ELib = ELib
local Class = ELib.Class

local ATOM_KINDS = ELib.Lexer.KINDS
local ATOM_KINDS_INV = ELib.Lexer.KINDS_INV

---@class Parser: Object
---@field atom_idx number Index of the current atom
---@field atoms Atom[]
---@field node_idx number Index of the current node
---@field nodes Node[]
local Parser = Class("Parser")
ELib.Parser = Parser

function Parser:reset()
	self.atom_idx = 0
	self.nodes = {}
	self.node_idx = 0
end

---@return Parser
function Parser.new()
	local instance = setmetatable({}, Parser)

	---@cast instance Parser
	instance:reset()

	return instance
end

---@alias ParserKindData { desc: string, type: "stmt"|"expr", decl: boolean }

--- Creates a control flow statement e.g. if, while, for, etc.
---@param desc string # Human description of the statement, for debugging.
---@return ParserKindData
local function Control(desc)
	return { desc = desc, type = "stmt", decl = false }
end

--- Creates a declaration statement e.g. "var x = 1"
---@param desc string # Human description of the statement, for debugging.
---@return ParserKindData
local function Declare(desc)
	return { desc = desc, type = "stmt", decl = true }
end

---@param desc string # Human description of the statement, for debugging.
---@return ParserKindData
local function Expr(desc)
	return { desc = desc, type = "expr", decl = false }
end

---@enum ParserKind
local KINDS = {
	If = 1,
	While = 2,
	For = 3,
	Try = 4,
	Realm = 5,
	VarDeclare = 6,
	VarModify = 7,
	Delegate = 8,
	Class = 9,
	Interface = 10,
	Function = 11,
	Escape = 12,
	Declare = 13,
	Export = 14,

	Ternary = 15,
	LogicalOps = 16,
	BitwiseOps = 17,
	ComparisonOps = 18,
	BitShiftOps = 19,
	ArithmeticOps = 20,
	UnaryOps = 21,
	CallExpr = 22,
	GroupedExpr = 23,
	Index = 24,
	Array = 25,
	Object = 26,
	Block = 27,
	Lambda = 28,
	Constructor = 29,
	Literal = 30,
	Variable = 31
}

local KINDS_UDATA = {
	--- Statements
	[KINDS.If] = Control("if statement"), -- if (true) {} elseif (false) {} else {}
	[KINDS.While] = Control("while loop"), -- while (true) {}
	[KINDS.For] = Control("for loop"), -- for(let foo = 5; foo < 5; foo++) {}
	[KINDS.Try] = Control("try"), -- try {} catch (e: int) {}
	[KINDS.Realm] = Control("realm block"), -- Set realm for block
	[KINDS.VarDeclare] = Declare("variable declaration"), -- var Foo = 5;
	[KINDS.VarModify] = Declare("variable modification"), -- Foo += 5;
	[KINDS.Delegate] = Declare("delegate"),
	[KINDS.Class] = Declare("class definition"), -- class Main {}
	[KINDS.Interface] = Declare("interface definition"), -- interface Main {}
	[KINDS.Function] = Declare("function definition"), -- function foo(): number {}
	[KINDS.Escape] = Control("return, break or continue"), -- Either return Var?, break or continue.
	[KINDS.Declare] = Declare("extern declaration"), -- declare function foo(): number
	[KINDS.Export] = Declare("export modifier"), -- export declare var foo: number

	--- Expressions
	[KINDS.Ternary] = Expr("ternary operation"), -- a ? b : c (a ?? b)
	[KINDS.LogicalOps] = Expr("logical operation"), -- || &&
	[KINDS.BitwiseOps] = Expr("binary operation"), -- | ^ &
	[KINDS.ComparisonOps] = Expr("comparison"), -- == != > >= < <=
	[KINDS.BitShiftOps] = Expr("bit shift operation"), -- << >>
	[KINDS.ArithmeticOps] = Expr("arithmetic"), -- + - / * %
	[KINDS.UnaryOps] = Expr("unary operation"), -- ! -
	[KINDS.CallExpr] = Expr("call"), -- foo()
	[KINDS.GroupedExpr] = Expr("grouped expression"), -- (x + y)
	[KINDS.Index] = Expr("index"), -- x.y or x[y]
	[KINDS.Array] = Expr("array literal"), -- [1, 2, 3]
	[KINDS.Object] = Expr("literal object"), -- { foo: 5, bar: "hello" }
	[KINDS.Block] = Expr("block"), -- { ... }
	[KINDS.Lambda] = Expr("lambda / closure"), -- function(x...) { ... }
	[KINDS.Constructor] = Expr("new expression"), -- new Foo()
	[KINDS.Literal] = Expr("literal value"), -- 5, "foo", true, false, nil
	[KINDS.Variable] = Expr("variable") -- foo
}

local KINDS_INV = ELib.GetInverted(KINDS)

Parser.KINDS = KINDS
Parser.KINDS_INV = KINDS_INV

---@type table<ParserKind, ParserKindData>
Parser.KINDS_UDATA = KINDS_UDATA

---@class Node: Object
---@field kind ParserKind
---@field data table
local Node = Class("Node")
Parser.Node = Node

function Node:__tostring()
	return string.format("Node \"%s\" (#%u)", ELib.Parser.KINDS_INV[self.kind], #self.data)
end

--- Returns a human friendly string description of the node, for error handling.
---@return string
function Node:human()
	return ELib.Parser.KINDS_UDATA[self.kind].desc
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

---@param kind ParserKind
---@param data table
function Node.new(kind, data)
	return setmetatable({
		kind = kind,
		data = data
	}, Node)
end

--- Parses a stream of atoms into an abstract syntax tree (AST)
---@param atoms Atom[] # Atoms retrieved from the [Lexer]
---@return Ast
function Parser:parse(atoms)
	assert(type(atoms) == "table", "bad argument #1 to 'Parser:parse' (table expected, got " .. type(atoms) .. ")")

	self:reset()
	self.atoms = atoms

	local ok, res = pcall(self.root, self)
	if not ok then
		local atom = self.atoms[self.atom_idx]
		error("Parser error: [" .. res .. "] at line " .. atom.start_line .. " char " .. atom.start_col, 0)
	end
	return ELib.Ast.new(res)
end

function Parser:hasAtoms()
	return self.atom_idx < #self.atoms
end

function Parser:root()
	local nodes = {}
	self.nodes = nodes

	repeat
		local node = self:next(true)
		nodes[#nodes + 1] = node
	until not node

	return nodes
end

---@param top boolean # Whether this is being parsed on top level (not inside an expr)
---@return Node?
function Parser:next(top)
	if not self:hasAtoms() then
		return nil
	end

	local atom = self:consume()

	-- hasAtom assures that there is another available atom to consume.
	---@cast atom Atom

	---@type Node?
	local res = self:parseStatement(atom) or self:parseExpression(atom)

	if res then
		-- Expect ; after declaration statements.
		if ( res:isExpression() or res:isDeclaration() ) then
			--assert(
				self:consumeIf(ATOM_KINDS.Grammar, ";")
			--, "Expected ; after " .. res:human())
		end
		return res
	else
		print(debug.traceback())
		error("Unexpected atom " .. ATOM_KINDS_INV[atom.kind] .. " '" .. atom.raw .. "'")
	end
end

--- Consumes the next atom in the atom stream.
---@nodiscard
---@return Atom?
function Parser:consume()
	self.atom_idx = self.atom_idx + 1
	return self.atoms[ self.atom_idx ]
end

--- Consumes the next atom in the atom stream.
--- # Safety
--- Must only be used when sure that you won't reach eof.
--- Either by [Parser.hasAtoms] or a [Parser.is] check
---@nodiscard
---@return Atom
function Parser:consume_unchecked()
	self.atom_idx = self.atom_idx + 1
	return self.atoms[ self.atom_idx ]
end

--- Inverse of [Parser:consume()].
function Parser:prev()
	self.atom_idx = self.atom_idx - 1
	return self.atoms[ self.atom_idx ]
end

---@nodiscard
---@return Atom?
function Parser:peek()
	return self.atoms[ self.atom_idx + 1 ]
end

---@return Atom?
function Parser:peekBack()
	return self.atoms[ self.atom_idx - 1 ]
end

--- Accepts a condition, delimited by parenthesis
---@return Node? # Expression node
function Parser:acceptCondition()
	assert( self:consumeIf(ATOM_KINDS.Grammar, "("), "Expected ( in condition" )
	local exp = self:parseExpression( assert( self:consume(), "Expected condition, got <eof>") )
	assert( self:consumeIf(ATOM_KINDS.Grammar, ")"), "Expected ) to close condition" )

	return exp
end

--- Accepts an identifier and returns it as a string.
---@return string
function Parser:acceptIdent()
	local atom = self:consumeIf(ATOM_KINDS.Identifier)
	return atom and atom.raw
end

---@return Node?
function Parser:lastNode()
	return self.nodes[ self.node_idx ]
end

--- Returns the last node with the given metadata (assuming it exists and fits the given kind and value)
---@param kind ParserKind
---@param value string?
---@return Node?
function Parser:lastNodeWith(kind, value)
	local last = self:lastNode()
	if not last then return end

	if value ~= nil then
		return (last.kind == kind and last.raw == value) and last
	else
		return (last.kind == kind) and last
	end
end

--- Returns the last node with the given metadata (assuming it exists and fits the given kind and value)
---@param kind ParserKind[]
---@return boolean
function Parser:lastNodeAnyOfKind(kind)
	local last = self:lastNode()
	if not last then return false end

	for _, k in ipairs(kind) do
		if last.kind == k then
			return true
		end
	end
	return false
end

--- Returns if a given atom is of kind 'kind' and has an inner value
---@param atom Atom?
---@param kind AtomKind
---@param value string? # Optional value to match against
---@return boolean
local function is(atom, kind, value)
	if atom == nil then return false end

	if value ~= nil then
		return atom.kind == kind and atom.raw == value
	else
		return atom.kind == kind
	end
end

--- Like is, but accepts an array of values rather than just one
---@param atom Atom?
---@param kind AtomKind
---@param values string[]
---@return string? # The raw value from 'values' that matched.
local function isAnyOf(atom, kind, values)
	if not atom or atom.kind ~= kind then return false end

	for _, val in ipairs(values) do
		if atom.raw == val then return val end
	end
end

--- Like isAnyOf, but for the kind instead of values.
---@param atom Atom?
---@param kinds AtomKind[]
---@return AtomKind?
local function isAnyOfKind(atom, kinds)
	for _, kind in ipairs(kinds) do
		if is(atom, kind, nil) then return kind end
	end
end

Parser.is = is
Parser.isAnyOf = isAnyOf
Parser.isAnyOfKind = isAnyOfKind

--- Like :consume, but peeks ahead, uses that as the atom, skips if it matches it.
---@param kind AtomKind
---@param value string? # Optional value to match against
---@return Atom? # The atom that matched
function Parser:consumeIf(kind, value)
	local atom = self:peek()
	if is(atom, kind, value) then
		return self:consume()
	end
end

--- Same as isAnyOf, but skips if it matches it.
---@param kind AtomKind
---@param values string[] # Values to match against
---@return string? # Raw value that matched from 'values'
function Parser:consumeIfAnyOf(kind, values)
	local ret = isAnyOf(self:peek(), kind, values)
	if ret then
		self.atom_idx = self.atom_idx + 1
		return ret
	end
end

--- Same as isAnyOfKind, but skips if it matches it.
---@param kinds AtomKind[]
---@return Atom? # The atom that matched
function Parser:consumeIfAnyOfKind(kinds)
	local atom = self:peek()
	if isAnyOfKind(atom, kinds) then
		return self:consume()
	end
end


--- Accepts a block, or throws an error if it couldn't.
---@return Ast
function Parser:acceptBlock()
	assert( self:consumeIf(ATOM_KINDS.Grammar, "{"), "Expected { in block" )

	local nodes, node_idx = ELib.Ast.new({}), 0

	-- Empty block
	if self:consumeIf(ATOM_KINDS.Grammar, "}") then
		return nodes
	end

	repeat
		node_idx = node_idx + 1
		local node = self:next(false)
		nodes[node_idx] = node

		if self:consumeIf(ATOM_KINDS.Grammar, "}") then
			return nodes
		end
	until not node

	error("Right curly bracket (}) missing, to close block")
end

---@return string?
function Parser:acceptType()
	--- TODO: This needs to properly create a type struct, which stores whether it is variadic, array, etc.
	local ty = self:consumeIf(ATOM_KINDS.Identifier)
	if ty then
		if self:consumeIf(ATOM_KINDS.Grammar, "[") then
			assert( self:consumeIf(ATOM_KINDS.Grammar, "]"), "Expected ] to complete array type (int[])" )
			return ty.raw
		end
		return ty.raw
	else
		local params = self:acceptTypes()
		if params then
			assert( self:consumeIf(ATOM_KINDS.Operator, "=>"), "Expected => to complete function signature" )
			local ret = assert( self:acceptType(), "Expected type to follow function signature arrow" )

			return "function(" .. table.concat(params, ",") .. ":" .. ret
		end
	end
end

--- Returns a table in the format of { { [1] = name, [2] = type } ... }, with both fields being strings
---@return table<number, string[]>?
function Parser:acceptTypes()
	if not self:consumeIf(ATOM_KINDS.Grammar, "(") then return end

	local args = {}

	if not self:consumeIf(ATOM_KINDS.Grammar, ")") then
		local arg, ty
		while self:hasAtoms() do
			arg = self:acceptType()
			if not arg then break end

			args[#args + 1] = ty

			if not self:consumeIf(ATOM_KINDS.Grammar, ",") then
				assert( self:consumeIf(ATOM_KINDS.Grammar, ")"), "Expected ) to end function parameters" )
				break
			end
		end
	end
	return args
end

--- Returns a table in the format of { { [1] = name, [2] = type } ... }, with both fields being strings
---@return table<number, string[]>?
function Parser:acceptTypedParameters()
	if not self:consumeIf(ATOM_KINDS.Grammar, "(") then return end
	local args = {}
	if self:consumeIf(ATOM_KINDS.Grammar, ")") then return args end

	local arg, ty
	while self:hasAtoms() do
		arg = self:consumeIf(ATOM_KINDS.Identifier)
		if not arg then break end

		-- "Expected : after argument to begin type" )

		if self:consumeIf(ATOM_KINDS.Grammar, ":") then
			ty = assert(self:acceptType(), "Expected type after : in function parameter")
			args[#args + 1] = { arg.raw, ty }
		end

		if not self:consumeIf(ATOM_KINDS.Grammar, ",") then
			assert( self:consumeIf(ATOM_KINDS.Grammar, ")"), "Expected ) to end function parameters" )
			return args
		end
	end
end

--- Returns a table of arguments, like (bar, foo, baz, 55, "qux", 500.0 + 291.2 / 5.0)
function Parser:acceptArguments()
	if self:consumeIf(ATOM_KINDS.Grammar, "(") then
		local nargs, args = 1, {}
		local arg = self:parseExpression(self:consume())
		while arg do
			args[nargs] = arg
			nargs = nargs + 1

			if self:consumeIf(ATOM_KINDS.Grammar, ")") then
				break
			end

			if self:consumeIf(ATOM_KINDS.Grammar, ",") then
				arg = self:parseExpression(self:consume())
			else
				assert( self:consumeIf(ATOM_KINDS.Grammar, ")"), "Expected ) or , after argument in call expr" )
				break
			end
		end

		return args
	end
end

-- Cannot be relative for fengari / native lua
include("stmt.lua")
include("expr.lua")
include("declare.lua")
include("class.lua")

---@type fun(self: Parser, atom: Atom): Node?
Parser.parseExpression = Parser.parseExpression

---@type fun(self: Parser, atom: Atom): Node?
Parser.parseStatement = Parser.parseStatement

---@type fun(self: Parser, atom: Atom, ignore_kw: boolean): Node?
Parser.acceptDeclare = Parser.acceptDeclare

---@type fun(self: Parser): Node?
Parser.acceptClassBlock = Parser.acceptClassBlock

return Parser