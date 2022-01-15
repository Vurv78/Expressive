local ELib = require("expressive/library")
local Keywords = ELib.Keywords

---@class Tokenizer
---@field input string
---@field pos number
---@field line number
---@field startchar number # 'pos', but reset for each line
---@field endchar number
local Tokenizer = {}
Tokenizer.__index = Tokenizer
ELib.Tokenizer = Tokenizer

---@return Tokenizer
function Tokenizer.new()
	return setmetatable({
		pos = 0,
		line = 1,
		startchar = 0,
		endchar = 0
	}, Tokenizer)
end

---@class TokenKinds
local KINDS = {
	Newline = 1,
	Whitespace = 2,
	Comment = 3,
	MComment = 4,
	Boolean = 5,
	Keyword = 6,
	Decimal = 7,
	Integer = 8,
	Hexadecimal = 9,
	Octal = 10,
	String = 11,
	Operator = 12,
	Grammar = 13,
	Identifier = 14
}

local KINDS_INV = ELib.GetInverted(KINDS)

Tokenizer.KINDS = KINDS
Tokenizer.KINDS_INV = KINDS_INV

---@class Token
---@field kind number
---@field value any? # Value of the token if it can immediately be determined. This would be for literals (numbers, strings, bools)
---@field data table # Misc lexed data from the tokens
---@field raw string? # Raw string of the token. Useful for grouped tokens like Grammar. Alias of data.raw
---@field line number
---@field startchar number
---@field endchar number
local Token = {}
Token.__index = Token

function Token:__tostring()
	return string.format("Token [%s] %s (#%u)", KINDS_INV[self.kind], self.raw and '"' .. self.raw .. '"' or "", self.line)
end

---@type table<number, fun(self: Token, str: string, pos: number)>
local Matchers = {
	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Newline] = function(self, str, pos)
		local start, ed = string.find(str, "^\n+", pos)
		if start then
			self.line = self.line + (ed - start + 1)
			self.startchar = 0
			self.endchar = 0
			return start, ed
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Whitespace] = function(self, str, pos)
		local start, ed = string.find(str, "^[ \t\r]+", pos)
		return start, ed
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Comment] = function(self, str, pos)
		local start, ed, _message = string.find(str, "^//([^\n\r]+)", pos)
		if start then
			-- For now, don't return anything. In the future these could be used for intellisense / autocomplete / whatever.
			self.line = self.line + 1
			self.startchar = 0
			self.endchar = 0
			return start, ed -- , { message }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.MComment] = function(self, str, pos)
		local start, ed, message = string.find(str, "^/%*(.-)%*/", pos)
		if start then
			self.line = self.line + ( (ed - start + 1)  - #string.gsub(message, '\n', '') )
			self.startchar = 0
			self.endchar = 0
			return start, ed  -- , { message = message }
		end
	end,

	---@param _self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Boolean] = function(_self, str, pos)
		local start, ed, value = string.find(str, "^%f[%w_](%l+)%f[^%w_]", pos)
		if value == "true" then
			return start, ed, { value = true }
		elseif value == "false" then
			return start, ed, { value = false }
		end
	end,

	---@param _self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Keyword] = function(_self, str, pos)
		local start, ed, kw = string.find(str, "^%f[%w_](%l+)%f[^%w_]", pos)
		if Keywords[kw] then
			return start, ed, { raw = kw }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Decimal] = function(self, str, pos)
		local start, ed, full, sign = string.find(str, "^(([-+]?)([0-9]+%.[0-9]+))", pos)
		if start then
			return start, ed, { value = tonumber(full), negative = sign == '-' }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Integer] = function(self, str, pos)
		local start, ed, full, sign = string.find(str, "^(([-+]?)[0-9]+)", pos)
		if start then
			return start, ed, { value = tonumber(full), negative = sign == '-' }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Hexadecimal] = function(self, str, pos)
		local start, ed, full, sign = string.find(str, "^(([-+]?)0x[%x]+)", pos)
		if start then
			return start, ed, { value = tonumber(full), negative = sign == '-' }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Octal] = function(self, str, pos)
		local start, ed, full, sign = string.find(str, "^(([-+]?)0b[01]+)", pos)
		if start then
			return start, ed, { value = tonumber(full, 2), negative = sign == '-' }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.String] = function(self, str, pos)
		-- Escapes are not recognized in [[]] strings (so no need for \\)
		local exp, matches = [[^"(.-)(\-)"]], {}
		local matched = false

		local start, endpos, inner, escapes = pos, nil, nil, nil
		repeat
			start, endpos, inner, escapes = string.find(str, exp, start)

			if escapes then
				local len = #escapes
				inner = inner .. string.sub(escapes, 1, len / 2)
				if len % 2 == 0 then
					-- Unescaped end of quote.
					matched = true
				else
					inner = inner .. '"'
				end
			else
				-- No escape characters found, this is the end of the string
				matched = true
			end
			matches[#matches + 1] = inner
		until matched

		if start then
			return start, endpos, { value = table.concat(matches) }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Operator] = function(self, str, pos)
		-- += -= /= %= *= >= <= == != &= ^= |=
		local op = string.match(str, "^[+%-/%*><=!^|]=", pos)
		if op then
			return pos, pos + 1, { raw = op }
		end

		-- << >> ++ -- ??
		op = string.match(str, "^[><+?-]+", pos)
		if op and #op == 2 then
			return pos, pos + 1, { raw = op }
		end

		-- = ^ * / % $ # @ ! + - > < ? .
		op = string.match(str, "^[=^*/%%$#@!+%-<>?.]", pos)
		if op then
			return pos, pos, { raw = op }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Grammar] = function(self, str, pos)
		local char = string.match(str, "^[{}()%[%]:;,]", pos)
		if char then
			-- ``pos`` is actually already self.pos + 1 since string.find/match is awful and 1 based. amazing
			return pos, pos, { raw = char }
		end
	end,

	---@param self Tokenizer
	---@param str string
	---@param pos number
	[KINDS.Identifier] = function(self, str, pos)
		local start, ed, name = string.find(str, "^([%a_][%w_]*)", pos)
		return start, ed, { raw = name }
	end
}

Tokenizer.Matchers = Matchers

--- Tokenizes a string into an array (sequential table) of tokens.
---@param input string # Expressive source code to tokenize
---@return table<number, Token>
function Tokenizer:parse(input)
	assert(isstring(input), "bad argument #1 to 'Tokenizer:parse' (string expected, got " .. type(input) .. ")")

	self.input = input

	local tokens, ntokens = {}, 0
	local caught, token = self:next()

	while caught do
		if token then
			ntokens = ntokens + 1
			tokens[ntokens] = token
		end
		caught, token = self:next()
	end

	return tokens
end

--- # Safety
--- This will throw an error with invalid syntax, so make sure to pcall.
---@return boolean caught @ Whether the tokenizer caught something. This applies to everything, even stuff without data
---@return Token? tok @ Table with token id and value
function Tokenizer:next()
	local input = self.input
	if self.pos == #input then return end
	for id, tok in ipairs(Matchers) do
		local start, ending, token = tok(self, input, self.pos + 1)
		if start then
			-- Char + Len
			local old = self.startchar
			self.startchar = self.startchar + (ending - start + 1)
			if token then
				-- Use given data as the token
				token.kind = id
				token.line = self.line
				token.startchar = old + 1
				token.endchar = self.startchar
				if token.raw then
					assert(token.raw == string.sub(input, start, ending), "Tokenizer:next() - Token raw data does not match")
				else
					token.raw = string.sub(input, start, ending)
				end
				setmetatable(token, Token)
			end
			assert(self.pos < ending, "Tokenizer:next() - Invalid ending position (" .. ending .. "), at kind '" .. KINDS_INV[id] .. "'")

			self.pos = ending

			return true, token
		end
	end

	error("Could not parse token: [" .. string.sub(self.input, self.pos, self.pos + 5) .. "] at line " .. self.line .. " char " .. self.startchar)
end

return Tokenizer