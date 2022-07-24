require("expressive/library"); local ELib = ELib

local Import, Class = ELib.Import, ELib.Class

local i = Import("atom", true)

local KINDS,
	Atom,
	OperatorAtom,
	NumericAtom,
	NumericTypes,
	BooleanAtom,
	StringAtom = i.KINDS, i.Atom, i.OperatorAtom, i.NumericAtom, i.NumericTypes, i.BooleanAtom, i.StringAtom

---@class Lexer: Object
---@field column integer
---@field line integer
---@field pos integer
---@field code string
local Lexer = Class("Lexer")
ELib.Lexer = Lexer


Lexer.KINDS = KINDS
Lexer.KINDS_INV = ELib.GetInverted(KINDS)

---@return Lexer
function Lexer.new()
	local instance = setmetatable({}, Lexer)
	---@cast instance Lexer

	instance:reset()
	return instance
end

function Lexer:reset()
	self.column = 1
	self.line = 1
	self.pos = 0
	self.code = nil
end

function Lexer:peek()
	return string.sub(self.code, self.pos + 1, self.pos + 1)
end

---@return string? # Character or nil if reached eof
function Lexer:take()
	assert(self.code, "Lexer internal called before :lex()")

	self.pos = self.pos + 1
	local c = string.sub(self.code, self.pos, self.pos)

	print(":take", c, #self.code, self.pos)

	if c == "\n" then
		self.column = 1
		self.line = self.line + 1
	else
		self.column = self.column + 1
	end

	return c ~= "" and c
end

---@param str string # Initial string to drain
---@param cond fun(s: string): boolean
function Lexer:drain(str, cond)
	local buf, pos = { str }, 2

	while cond(self:peek()) do
		buf[pos] = self:take()
		pos = pos + 1
	end

	return table.concat(buf)
end

---@param c string
local function is_whitespace(c)
	return c == " " or c == "\t" or c == "\n" or c == "\r"
end

---@param c string
local function is_numeric(c)
	if c == nil then return false end

	return c >= "0" and c <= "9"
end

local function is_alphanumeric(c)
	if c == nil then return false end

	return (c >= "a" and c <= "z") or
		(c >= "A" and c <= "Z") or
		(c >= "0" and c <= "9") or
		c == "_"
end

---@param c string
local function is_grammar(c)
	return ELib.Grammar[c]
end

---@param c string
local function is_operator(c)
	return ELib.Operator[c]
end

---@return Atom? # Atom or nil in case reached eof
function Lexer:next()
	local char = self:take()
	if not char then return end -- eof

	local start_col, start_line = self.column, self.line

	if is_whitespace(char) then
		return Atom.new(
			KINDS.Whitespace,
			start_col,
			start_line,
			self.column,
			self.line,
			self:drain(char, is_whitespace)
		)
	elseif is_numeric(char) then
		if char == "0" then
			if self:peek() == "b" then
				error("unimplemented: binary")
			elseif self:peek() == "x" then
				error("unimplemented: hexadecimal")
			elseif self:peek() == "o" then
				error("unimplemented: octal")
			end
		end

		local nums = self:drain(char, is_numeric)
		if self:peek() == "." then
			self:take()

			nums = nums .. self:drain(char, is_numeric)
			return NumericAtom.new(
				start_col,
				start_line,
				self.column,
				self.line,

				assert( tonumber(nums), "Invalid number!" ),
				NumericTypes.Decimal
			)
		else
			return NumericAtom.new(
				start_col,
				start_line,
				self.column,
				self.line,

				assert( tonumber(nums), "Invalid number!" ),
				NumericTypes.Integer
			)
		end
	elseif is_alphanumeric(char) then
		local word = self:drain(char, is_alphanumeric)

		if word == "false" or word == "true" then
			return BooleanAtom.new(start_col, start_line, self.column, self.line, word == "true")
		end

		return Atom.new(
			ELib.Keywords[word] and KINDS.Keyword or KINDS.Identifier,
			start_col,
			start_line,
			self.column,
			self.line,
			word
		)
	elseif is_grammar(char) then
		return Atom.new(
			KINDS.Grammar,
			start_col,
			start_line,
			self.column,
			self.line,
			char
		)
	elseif is_operator(char) then
		local operator = self:drain(char, is_operator)
		local op = assert(ELib.Operator[operator], "Invalid operator: " .. operator)

		return OperatorAtom.new(
			start_col,
			start_line,
			self.column,
			self.line,
			op
		)
	elseif char == '"' then
		local buf = ""

		local function check(c)
			return c and c ~= "\\" and c ~= "\"" and c ~= "\n"
		end

		while true do
			buf = buf .. self:drain("", check)

			local peek = self:peek()
			if peek == "\\" then
				self:take()

				local n = self:take()
				if n == nil then
					error("Invalid escape: (reached eof)")
				elseif n == "\\" then
					buf = buf .. "\\"
				elseif n == '"' then
					buf = buf .. '"'
				elseif n == "\n" then
					buf = buf .. "\n"
				elseif n == "\r" then
					buf = buf .. "\n"
					if self:peek() == "\n" then
						self:next()
					end
				elseif n == "r" then
					buf = buf .. "\r"
				elseif n == "n" then
					buf = buf .. "\n"
				elseif n == "t" then
					buf = buf .. "\t"
				elseif n == "b" then
					buf = buf .. "\b"
				elseif n == "x" then
					error("Unimplemented: \\x escapes")
				else
					error("Invalid escape: (\\" .. self:take() .. ")")
				end
			elseif peek == "\n" then
				error("String ran off eol (escape with \\)")
			elseif peek == nil then
				error("Unfinished string (eof)")
			else
				self:take()
				break
			end
		end

		return StringAtom.new(
			start_col,
			start_line,
			self.column,
			self.line,
			buf
		);
	elseif char ~= nil then
		error("Unrecognized character: (" .. char .. ")")
	end
end

---@param code string
---@return Atom[]
function Lexer:lex(code)
	assert(code, "bad argument #1 to lex, expected string, got nil")

	self.code = code
	local out, nout = {}, 1

	while true do
		local atom = self:next()
		if not atom then return out end

		if atom.kind ~= KINDS.Whitespace then
			out[nout] = atom
			nout = nout + 1
		end
	end
end

return Lexer