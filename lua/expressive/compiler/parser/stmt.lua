require("expressive/library"); local ELib = ELib

local Lexer = ELib.Lexer
local Parser = ELib.Parser
local Node = Parser.Node

local is = Parser.is
local isAnyOf = Parser.isAnyOf

local ATOM_KINDS = Lexer.KINDS
local NODE_KINDS = Parser.KINDS

local ExportStmts = {
	NODE_KINDS.Class,
	NODE_KINDS.Function,
	NODE_KINDS.VarDeclare,
	NODE_KINDS.Delegate,
	NODE_KINDS.Declare
}

---@type table<ParserKind, fun(self: Parser, atom: Atom)>
local Statements
Statements = {
	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.If] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "if") then
			local cond = assert( self:acceptCondition(), "Expected condition after 'if'" )
			local body = self:acceptBlock()

			return { cond, body }
		end
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Elseif] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "elseif") then
			assert( self:lastNodeWith(NODE_KINDS.If), "Expected if statement before elseif" )
			local cond = assert( self:acceptCondition(), "Expected condition after 'elseif'" )
			local block = assert( self:acceptBlock(), "Expected block after 'elseif'" )

			return { cond, block }
		end
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Else] = function(self, atom)
		-- TODO: Also needs to account for elseif
		if is(atom, ATOM_KINDS.Keyword, "else") then
			assert( self:lastNodeAnyOfKind({NODE_KINDS.If, NODE_KINDS.Elseif}), "Expected if or elseif statement before else" )

			local body = self:acceptBlock()
			return { body }
		end
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.While] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "while") then
			local cond = assert( self:acceptCondition(), "Expected condition after 'while'" )
			local body = self:acceptBlock()

			return { cond, body }
		end
	end,

	--- For loop.
	--- Example:
	--- for(int foo = 0; foo < 10; foo++) {
	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.For] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "for") then
			assert( self:consumeIf(ATOM_KINDS.Grammar, "("), "Expected ( in for statement" )
			local kw = assert( self:consumeIfAnyOf(ATOM_KINDS.Keyword, {"let", "const", "var"}), "Expected keyword to start for loop (for (let x...))" )
			local vname = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected variable name in for loop (for (let x = ...))" ).raw
			assert( self:consumeIf(ATOM_KINDS.Operator, "="), "Expected = in for loop (for (let x = 5...))" )
			local start_expr = assert( self:parseExpression(self:consume()), "Expected expression in for loop (for (let x = 5; x > 5; x++) {})" )
			assert( self:consumeIf(ATOM_KINDS.Grammar, ";"), "Expected ; in for loop, after set expression (for (let x = 5; ...))" )
			local cond = assert( self:parseExpression(self:consume()), "Expected condition in for loop (for (let x = 5; x > 5; ...))" )
			assert( self:consumeIf(ATOM_KINDS.Grammar, ";"), "Expected ; in for loop, after condition expression (for (let x = 5; x > 5; ...) {})" )
			local inc = assert( self:parseStatement(self:consume()), "Expected increment statement in for loop (for (let x = 5; x > 5; x++) {})" )
			assert( self:consumeIf(ATOM_KINDS.Grammar, ")"), "Expected ) to close for statement" )

			local block = assert( self:acceptBlock(), "Expected block after for statement" )

			return { kw, vname, start_expr, cond, inc, block }
		end
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Try] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "try") then
			local block = assert( self:acceptBlock(), "Expected block after try statement" )
			assert( self:consumeIf(ATOM_KINDS.Keyword, "catch"), "Expected catch after try statement" )
			assert( self:consumeIf(ATOM_KINDS.Grammar, "("), "Expected (variable) after catch" )
			local vname = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected variable name in catch statement" ).raw
			assert( self:consumeIf(ATOM_KINDS.Grammar, ":"), "Expected : after variable name in catch statement, to denote type" )
			local ty = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected type in catch statement" )
			assert( self:consumeIf(ATOM_KINDS.Grammar, ")"), "Expected ) to close catch statement" )
			local catch_block = assert( self:acceptBlock(), "Expected block after catch statement" )

			return { block, vname, ty, catch_block }
		end
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Realm] = function(self, atom)
		local realm = isAnyOf(atom, ATOM_KINDS.Keyword, {"server", "client"})
		if realm then
			local block = assert( self:acceptBlock(), "Expected block after realm statement" )
			return { realm, block }
		end
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.VarDeclare] = function(self, atom)
		local assign_kw = isAnyOf(atom, ATOM_KINDS.Keyword, {"var", "let", "const"})
		if assign_kw then
			local vname = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected variable name in variable declaration, got " .. ELib.Inspect(self:peek()) ).raw
			local ty = nil -- Type for the analyzer to infer, or else error if it could not.
			if self:consumeIf(ATOM_KINDS.Grammar, ":") then
				ty = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected type after : in variable declaration, got " .. self:consume().raw ).raw
			end
			assert( self:consumeIf(ATOM_KINDS.Operator, "="), "Expected = in variable declaration" )
			local expr = assert( self:parseExpression(self:consume()), "Expected expression in variable declaration" )

			-- Check that number precision is correct, if explicit type is given.
			-- So you can't just do var foo: int = 5.2143;
			if ty and expr.kind == NODE_KINDS.Literal and expr.data[1] == "number" then
				assert(ty == expr.data[4], "Expected type " .. ty .. " for variable " .. vname .. ", got " .. expr.data[4])
			end

			return { assign_kw, vname, ty, expr }
		end
	end,

	--- (self) or otherwise, modify a variable
	--- For example Var += 5 or Var++
	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.VarModify] = function(self, atom)
		if is(atom, ATOM_KINDS.Identifier) then
			local op = self:consumeIfAnyOf(ATOM_KINDS.Operator, {"+=", "-=", "/=", "*=", "%=", "="})
			if op then
				local expr = assert( self:parseExpression(self:consume()), "Expected expression after " .. op )
				return { atom.raw, op, expr }
			end

			op = self:consumeIfAnyOf(ATOM_KINDS.Operator, {"++", "--"})
			if op then
				return { atom.raw, op }
			end
		end
	end,

	---@param _self Parser
	---@param _atom Atom
	[NODE_KINDS.Delegate] = function(_self, _atom)
		-- TODO: Delegates
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Class] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "class") then
			local name = assert( self:consumeIf(ATOM_KINDS.Identifier), "Expected class name after class keyword" )
			local data = assert( self:acceptClassBlock(), "Expected left curly bracket ({) to begin class definition" )

			return { name.raw, data }
		end
	end,

	---@param _self Parser
	---@param _atom Atom
	[NODE_KINDS.Interface] = function(_self, _atom)
		-- TODO: Implement interfaces
	end,

	--- Function definition
	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Function] = function(self, atom)
		local name = self:consumeIf(ATOM_KINDS.Identifier)
		if is(atom, ATOM_KINDS.Keyword, "function") and name then
			local name = name.raw
			local params = assert(self:acceptTypedParameters(), "Expected function parameters after function declaration")
			local block = self:acceptBlock()

			return {name, params, block}
		end
	end,

	--- Either break, return or continue
	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Escape] = function(self, atom)
		local kw = isAnyOf(atom, ATOM_KINDS.Keyword, {"break", "continue"})
		if kw then
			return { kw }
		end

		if is(atom, ATOM_KINDS.Keyword, "return") then
			-- Optional return value
			local expr = self:parseExpression( self:consume() )
			return { "return", expr }
		end
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Declare] = function(self, atom)
		return self:acceptDeclare(atom, false)
	end,

	---@param self Parser
	---@param atom Atom
	[NODE_KINDS.Export] = function(self, atom)
		if is(atom, ATOM_KINDS.Keyword, "export") then
			-- TODO: A function that auto calls Node.new etc for you when calling other stmts in a statement.
			local next = self:consume()
			for _, kind in ipairs(ExportStmts) do
				local data = Statements[kind](self, next)
				if data then
					return { Node.new(kind, data) }
				end
			end
			error("Invalid export statement, got " .. tostring(next))
		end
	end,
}

--- Tries to parse a statement. This will error if it finds a malformed statement, so pcall!
---@param atom Atom
---@return Node? # Returned node if successfully parsed a statement.
function Parser:parseStatement(atom)
	for kind, stmt in ipairs(Statements) do
		local data = stmt(self, atom)
		if data then
			return Node.new(kind, data)
		end
	end
end