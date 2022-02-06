local ELib = require("expressive/library")

local Tokenizer = ELib.Tokenizer
local Parser = ELib.Parser
local Node = Parser.Node

local isToken = Parser.isToken
local isAnyOf = Parser.isAnyOf

local TOKEN_KINDS = Tokenizer.KINDS
local NODE_KINDS = Parser.KINDS

---@type table<number, fun(self: Parser, token: Token)>
local Statements
Statements = {
	---@param self Parser
	---@param token Token
	[NODE_KINDS.If] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "if") then
			local cond = assert( self:acceptCondition(), "Expected condition after 'if'" )
			local body = self:acceptBlock()

			return { cond, body }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Elseif] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "elseif") then
			assert( self:lastNodeWith(NODE_KINDS.If), "Expected if statement before elseif" )
			local cond = assert( self:acceptCondition(), "Expected condition after 'elseif'" )
			local block = assert( self:acceptBlock(), "Expected block after 'elseif'" )

			return { cond, block }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Else] = function(self, token)
		-- TODO: Also needs to account for elseif
		if isToken(token, TOKEN_KINDS.Keyword, "else") then
			assert( self:lastNodeAnyOfKind({NODE_KINDS.If, NODE_KINDS.Elseif}), "Expected if or elseif statement before else" )

			local body = self:acceptBlock()
			return { body }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.While] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "while") then
			local cond = assert( self:acceptCondition(), "Expected condition after 'while'" )
			local body = self:acceptBlock()

			return { cond, body }
		end
	end,

	--- For loop.
	--- Example:
	--- for(int foo = 0; foo < 10; foo++) {
	---@param self Parser
	---@param token Token
	[NODE_KINDS.For] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "for") then
			assert( self:popToken(TOKEN_KINDS.Grammar, "("), "Expected ( in for statement" )
			local kw = assert( self:popAnyOf(TOKEN_KINDS.Keyword, {"let", "const", "var"}), "Expected keyword to start for loop (for (let x...))" )
			local vname = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected variable name in for loop (for (let x = ...))" ).raw
			assert( self:popToken(TOKEN_KINDS.Operator, "="), "Expected = in for loop (for (let x = 5...))" )
			local start_expr = assert( self:parseExpression(self:nextToken()), "Expected expression in for loop (for (let x = 5; x > 5; x++) {})" )
			assert( self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ; in for loop, after set expression (for (let x = 5; ...))" )
			local cond = assert( self:parseExpression(self:nextToken()), "Expected condition in for loop (for (let x = 5; x > 5; ...))" )
			assert( self:popToken(TOKEN_KINDS.Grammar, ";"), "Expected ; in for loop, after condition expression (for (let x = 5; x > 5; ...) {})" )
			local inc = assert( self:parseStatement(self:nextToken()), "Expected increment statement in for loop (for (let x = 5; x > 5; x++) {})" )
			assert( self:popToken(TOKEN_KINDS.Grammar, ")"), "Expected ) to close for statement" )

			local block = assert( self:acceptBlock(), "Expected block after for statement" )

			return { kw, vname, start_expr, cond, inc, block }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Try] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "try") then
			local block = assert( self:acceptBlock(), "Expected block after try statement" )
			assert( self:popToken(TOKEN_KINDS.Keyword, "catch"), "Expected catch after try statement" )
			assert( self:popToken(TOKEN_KINDS.Grammar, "("), "Expected (variable) after catch" )
			local vname = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected variable name in catch statement" ).raw
			assert( self:popToken(TOKEN_KINDS.Grammar, ":"), "Expected : after variable name in catch statement, to denote type" )
			local ty = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected type in catch statement" )
			assert( self:popToken(TOKEN_KINDS.Grammar, ")"), "Expected ) to close catch statement" )
			local catch_block = assert( self:acceptBlock(), "Expected block after catch statement" )

			return { block, vname, ty, catch_block }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Realm] = function(self, token)
		local realm = isAnyOf(token, TOKEN_KINDS.Keyword, {"server", "client"})
		if realm then
			local block = assert( self:acceptBlock(), "Expected block after realm statement" )
			return { realm, block }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.VarDeclare] = function(self, token)
		local assign_kw = isAnyOf(token, TOKEN_KINDS.Keyword, {"var", "let", "const"})
		if assign_kw then
			local vname = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected variable name in variable declaration, got " .. ELib.Inspect(self:peek()) ).raw
			local ty = nil -- Type for the analyzer to infer, or else error if it could not.
			if self:popToken(TOKEN_KINDS.Grammar, ":") then
				ty = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected type after : in variable declaration, got " .. self:nextToken().raw ).raw
			end
			assert( self:popToken(TOKEN_KINDS.Operator, "="), "Expected = in variable declaration" )
			local expr = assert( self:parseExpression(self:nextToken()), "Expected expression in variable declaration" )

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
	---@param token Token
	[NODE_KINDS.VarModify] = function(self, token)
		if isToken(token, TOKEN_KINDS.Identifier) then
			local op = self:popAnyOf(TOKEN_KINDS.Operator, {"+=", "-=", "/=", "*=", "%=", "="})
			if op then
				local expr = assert( self:parseExpression(self:nextToken()), "Expected expression after " .. op )
				return { token.raw, op, expr }
			end

			op = self:popAnyOf(TOKEN_KINDS.Operator, {"++", "--"})
			if op then
				return { token.raw, op }
			end
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Delegate] = function(self, token)
		-- todo
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Class] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "class") then
			local name = assert( self:popToken(TOKEN_KINDS.Identifier), "Expected class name after class keyword" )
			local data = assert( self:acceptClassBlock(), "Expected left curly bracket ({) to begin class definition" )

			return { name.raw, data }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Interface] = function(self, token)

	end,

	--- Function definition
	---@param self Parser
	---@param token Token
	[NODE_KINDS.Function] = function(self, token)
		local name = self:popToken(TOKEN_KINDS.Identifier)
		if isToken(token, TOKEN_KINDS.Keyword, "function") and name then
			name = name.raw
			local params = assert(self:acceptTypedParameters(), "Expected function parameters after function declaration")
			local block = self:acceptBlock()

			return {name, params, block}
		end
		-- Could be a lambda.
	end,

	--- Either break, return or continue
	---@param self Parser
	---@param token Token
	[NODE_KINDS.Escape] = function(self, token)
		local kw = isAnyOf(token, TOKEN_KINDS.Keyword, {"break", "continue"})
		if kw then
			return { kw }
		end

		if isToken(token, TOKEN_KINDS.Keyword, "return") then
			-- Optional return value
			local expr = self:parseExpression( self:nextToken() )
			return { "return", expr }
		end
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Declare] = function(self, token)
		return self:acceptDeclare(token, false)
	end,

	---@param self Parser
	---@param token Token
	[NODE_KINDS.Export] = function(self, token)
		if isToken(token, TOKEN_KINDS.Keyword, "export") then
			-- TODO: A function that auto calls Node.new etc for you when calling other stmts in a statement.
			local data = Statements[NODE_KINDS.VarDeclare](self, self:nextToken())

			if data then
				-- Only accepts export var foo = 5; for now.
				return { Node.new(NODE_KINDS.VarDeclare, data) }
			end
		end
	end,
}

--- Tries to parse a statement. This will error if it finds a malformed statement, so pcall!
---@param tok Token
---@return Node? # Returned node if successfully parsed a statement.
function Parser:parseStatement(tok)
	for kind, stmt in ipairs(Statements) do
		local data = stmt(self, tok)
		if data then
			return Node.new(kind, data)
		end
	end
end