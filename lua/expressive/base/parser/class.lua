--- Parse the internals of a class Foo {} block.
local ELib = require("expressive/library")
local Parser = ELib.Parser

local isToken = ELib.Parser.isToken
local isAnyOf = ELib.Parser.isAnyOf

local TOKEN_KINDS = ELib.Tokenizer.KINDS
local NODE_KINDS_UDATA = ELib.Parser.KINDS_UDATA

---@class ClassData
---@field constructor { args: table<number, table<number, string>>, body: table<number, Node> } # Constructor of the class
---@field fields table<string, TypeSig> # Field names and their types on the class.
---@field static_fields table<string, TypeSig> # Static field names and their types on the class.

local Handlers = {
	---@param self Parser
	---@param data ClassData
	---@param token Token
	["constructor"] = function(self, data, token)
		if isToken(token, TOKEN_KINDS.Keyword, "constructor") then
			local args = self:acceptTypedParameters()
			local body = self:acceptBlock()

			self.constructor = { args = args, body = body }
			return true
		end
	end,

	---@param self Parser
	---@param data ClassData
	---@param token Token
	["static_block"] = function(self, data, token)
		if isToken(token, TOKEN_KINDS.Keyword, "static") then
			assert(not self:popToken(TOKEN_KINDS.Grammar, "{"), "Static blocks are not supported")
		end
	end,

	["get"] = function(self, data, token)
		assert( not isToken(token, TOKEN_KINDS.Keyword, "get"), "Getters are not implemented")
	end,

	["set"] = function(self, data, token)
		assert( not isToken(token, TOKEN_KINDS.Keyword, "set"), "Setters are not implemented")
	end,

	--- ```ts
	--- 	public static foo: int;
	--- 	private bar: string;
	--- 	baz: boolean;
	--- ```
	---@param self Parser
	---@param data ClassData
	---@param token Token
	["field"] = function(self, data, token)
		-- Do this first, to prevent modifier order mismatch with a proper error message.
		local is_static = isToken(token, TOKEN_KINDS.Keyword, "static")
		if is_static then
			token = self:nextToken()
		end

		local modifier = isAnyOf(token, TOKEN_KINDS.Keyword, {"public", "private", "protected"})
		if modifier then
			assert(not is_static, "Visibility modifier must precede static: '" .. modifier .. "'")
			token = self:nextToken()
		end

		if not is_static then
			is_static = isToken(token, TOKEN_KINDS.Keyword, "static")
			if is_static then
				token = self:nextToken()
			end
		end

		if isToken(token, TOKEN_KINDS.Identifier) then
			local name = token.raw
			assert(self:popToken(TOKEN_KINDS.Grammar, ":"), "Expected ':' after field name")
			local ty = assert(self:acceptType(), "Expected type after ':' in field declaration")

			if data.fields[name] or data.static_fields[name] then
				error("Duplicate field name: " .. name)
			end

			if is_static then
				data.static_fields[name] = ty
			else
				data.fields[name] = ty
			end

			return true
		end
	end
}

--- Accepts the block after the class Name in a class declaration.
--- ```ts
--- class Foo {
--- 	...
--- }
--- ```
---@return ClassData
function Parser:acceptClassBlock()
	if self:popToken(TOKEN_KINDS.Grammar, "{") then
		---@type ClassData
		local data = {}
		while not self:popToken(TOKEN_KINDS.Grammar, "}") do
			local token, matched = self:nextToken(), false
			if token then
				for _, handler in pairs(Handlers) do
					matched = handler(self, token)
					if matched then
						print("Matched", _, handler)
						break
					end
				end
				if matched then
					assert(self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ; after " .. matched:human())
				else
					error("Unexpected token '" .. tostring(token) .. "' in class block")
				end
			end
		end

		return data
	end
end