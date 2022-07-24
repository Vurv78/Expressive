--- Parse the internals of a class Foo {} block.
require("expressive/library"); local ELib = ELib
local Parser = ELib.Parser

local is = ELib.Parser.is
local isAnyOf = ELib.Parser.isAnyOf

local ATOM_KINDS = ELib.Lexer.KINDS

---@class ClassData
---@field constructor { args: table<number, string[]>, body: Node[] } # Constructor of the class
---@field fields table<string, TypeSig> # Field names and their types on the class.
---@field static_fields table<string, TypeSig> # Static field names and their types on the class.

---@type table<string, fun(self: Parser, data: ClassData, atom: Atom): boolean?>
local Handlers = {
	---@param self Parser
	---@param _data ClassData
	---@param atom Atom
	["constructor"] = function(self, _data, atom)
		if is(atom, ATOM_KINDS.Keyword, "constructor") then
			local args = assert(self:acceptTypedParameters(), "Expected typed parameters for constructor")
			local body = self:acceptBlock()

			self.constructor = { args = args, body = body }
			return true
		end
	end,

	---@param self Parser
	---@param _data ClassData
	---@param atom Atom
	["static_block"] = function(self, _data, atom)
		if is(atom, ATOM_KINDS.Keyword, "static") then
			assert(not self:consumeIf(ATOM_KINDS.Grammar, "{"), "Static blocks are not supported")
		end
	end,

	["get"] = function(_self, _data, atom)
		assert( not is(atom, ATOM_KINDS.Keyword, "get"), "Getters are not implemented")
	end,

	["set"] = function(_self, _data, atom)
		assert( not is(atom, ATOM_KINDS.Keyword, "set"), "Setters are not implemented")
	end,

	--- ```ts
	--- 	public static foo: int;
	--- 	private bar: string;
	--- 	baz: boolean;
	--- ```
	---@param self Parser
	---@param data ClassData
	---@param atom Atom
	["field"] = function(self, data, atom)
		-- Do this first, to prevent modifier order mismatch with a proper error message.
		local is_static = is(atom, ATOM_KINDS.Keyword, "static")
		if is_static then
			atom = assert( self:consume(), "Expected field name after 'static' modifier")
		end

		local modifier = isAnyOf(atom, ATOM_KINDS.Keyword, {"public", "private", "protected"})
		if modifier then
			assert(not is_static, "Visibility modifier '" .. modifier .. "' must precede static")
			atom = self:consume_unchecked()
		end

		if not is_static then
			is_static = is(atom, ATOM_KINDS.Keyword, "static")
			if is_static then
				atom = self:consume_unchecked()
			end
		end

		if is(atom, ATOM_KINDS.Identifier) then
			local name = atom.raw
			assert(self:consumeIf(ATOM_KINDS.Grammar, ":"), "Expected ':' after field name")
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
---@return ClassData?
function Parser:acceptClassBlock()
	if self:consumeIf(ATOM_KINDS.Grammar, "{") then
		---@type ClassData
		local data = {}
		while not self:consumeIf(ATOM_KINDS.Grammar, "}") do
			local atom, matched = self:consume(), false
			if atom then
				for _, handler in pairs(Handlers) do
					matched = handler(self, data, atom)
					if matched then
						print("Matched", _, handler)
						break
					end
				end
				if matched then
					assert(self:consumeIf(ATOM_KINDS.Grammar, ";"), "Expected ; after " .. matched:human())
				else
					error("Unexpected atom '" .. tostring(atom) .. "' in class block")
				end
			end
		end

		return data
	end
end