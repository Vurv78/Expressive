require("expressive/library"); local ELib = ELib
local Class = ELib.Class

---@enum AtomKind
local KINDS = {
	Whitespace = 1,
	Comment = 2,
	Boolean = 3,
	Keyword = 4,
	Numeric = 5,
	String = 6,
	Operator = 7,
	Grammar = 8,
	Identifier = 9
}

local KINDS_INV = ELib.GetInverted(KINDS)

---@class Atom: Object
---@field kind integer
---@field start_col integer
---@field start_line integer
---@field end_col integer
---@field end_line integer
---@field raw string
local Atom = Class("Atom")

---@param kind integer
---@param start_col integer
---@param start_line integer
---@param end_col integer
---@param end_line integer
---@param raw string
---@return Atom
function Atom.new(kind, start_col, start_line, end_col, end_line, raw)
	local instance = setmetatable({
		kind = kind,
		start_col = start_col,
		start_line = start_line,

		end_col = end_col,
		end_line = end_line,

		raw = raw
	}, Atom)

	---@cast instance Atom

	return instance
end

function Atom:__tostring()
	return string.format("Atom [%s] %s (#%u)", KINDS_INV[self.kind], self.raw and '"' .. self.raw .. '"' or "", self.start_line)
end

---@class OperatorAtom: Atom
---@field op Operator
local OperatorAtom = Class("OperatorAtom", Atom)

function OperatorAtom:__tostring()
	return string.format("OperatorAtom [%s] %s (#%u)", KINDS_INV[self.kind], self.op.char, self.start_line)
end

---@param start_col integer
---@param start_line integer
---@param end_col integer
---@param end_line integer
---@param op Operator
---@return OperatorAtom
function OperatorAtom.new(start_col, start_line, end_col, end_line, op)
	---@diagnostic disable-next-line: return-type-mismatch
	return setmetatable({
		kind = KINDS.Operator,
		start_col = start_col,
		start_line = start_line,

		end_col = end_col,
		end_line = end_line,

		op = op,
		raw = op.op
	}, OperatorAtom)
end

---@class BooleanAtom: Atom
---@field value boolean
local BooleanAtom = Class("BooleanAtom", Atom)

---@param start_col integer
---@param start_line integer
---@param end_col integer
---@param end_line integer
---@param value boolean
---@return BooleanAtom
function BooleanAtom.new(start_col, start_line, end_col, end_line, value)
	---@diagnostic disable-next-line: return-type-mismatch
	return setmetatable({
		kind = KINDS.Boolean,
		start_col = start_col,
		start_line = start_line,

		end_col = end_col,
		end_line = end_line,

		value = value,
		raw = value and "true" or "false"
	}, BooleanAtom)
end

---@class StringAtom: Atom
---@field value string
local StringAtom = Class("StringAtom", Atom)

---@param start_col integer
---@param start_line integer
---@param end_col integer
---@param end_line integer
---@param value string
---@return StringAtom
function StringAtom.new(start_col, start_line, end_col, end_line, value)
	---@diagnostic disable-next-line: return-type-mismatch
	return setmetatable({
		kind = KINDS.String,
		start_col = start_col,
		start_line = start_line,

		end_col = end_col,
		end_line = end_line,

		value = value,

		raw = '"' .. value .. '"'
	}, StringAtom)
end

---@class NumericAtom: Atom
---@field value number
---@field type integer
local NumericAtom = Class("NumericAtom", Atom)

local NumericTypes = {
	Integer = 1,
	Decimal = 2,
	Hexadecimal = 3,
	Octal = 4,
	Binary = 5
}

function NumericAtom:__tostring()
	return string.format("NumericAtom [%s] %s (#%u)", NumericTypes[self.type], self.value, self.start_line)
end

---@param start_col integer
---@param start_line integer
---@param end_col integer
---@param end_line integer
---@param value number
---@param type integer # Type from NumericTypes
---@return NumericAtom
function NumericAtom.new(start_col, start_line, end_col, end_line, value, type)
	---@diagnostic disable-next-line: return-type-mismatch
	return setmetatable({
		kind = KINDS.Numeric,
		start_col = start_col,
		start_line = start_line,

		end_col = end_col,
		end_line = end_line,

		value = value,
		type = type,

		raw = tostring(value)
	}, NumericAtom)
end

---@class CommentAtom: Atom
---@field inner string
---@field type CommentType
local CommentAtom = Class("CommentAtom", Atom)

---@enum CommentType
local CommentType = {
	Line = 1,
	Multiline = 2,
	Documentation = 3
}

---@param start_col integer
---@param start_line integer
---@param end_col integer
---@param end_line integer
---@param type CommentType
---@param inner string
---@return CommentAtom
function CommentAtom.new(start_col, start_line, end_col, end_line, type, inner)
	---@diagnostic disable-next-line: return-type-mismatch
	return setmetatable({
		kind = KINDS.Comment,
		start_col = start_col,
		start_line = start_line,

		end_col = end_col,
		end_line = end_line,

		type = type,
		inner = inner,

		raw = type == CommentType.Multiline
			and ("/*" .. inner .. "*/")
			or ("//" .. inner)
	}, CommentAtom)
end

return {
	Atom = Atom,

	OperatorAtom = OperatorAtom,

	NumericAtom = NumericAtom,
	NumericTypes = NumericTypes,

	BooleanAtom = BooleanAtom,
	StringAtom = StringAtom,

	CommentAtom = CommentAtom,
	CommentType = CommentType,

	KINDS = KINDS
}