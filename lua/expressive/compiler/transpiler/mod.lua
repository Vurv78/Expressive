-- ES -> Lua Transpiler
local ELib = require("expressive/library")
local class = require("voop")

local Parser = ELib.Parser
local Tokenizer = ELib.Tokenizer

local TOKEN_KINDS = Tokenizer.KINDS
local NODE_KINDS = Parser.KINDS

local function fmt(...)
	return string.format(...)
end

---@class Transpiler
---@field current number
---@field nodes table<number, Node> # Mini-ASTs or the global ast, that are from code blocks
---@field ast table<number, Node> # The AST generated by the parser.
local Transpiler = class("Transpiler")

---@return Transpiler
function Transpiler.new()
	return setmetatable({}, Transpiler)
end

local VarModifications = {
	["+="] = function(self, name, expr2)
		return fmt("%s = %s + %s", name, name, self:transpile(expr2))
	end,
	["-="] = function(self, name, expr2)
		return fmt("%s = %s - %s", name, name, self:transpile(expr2))
	end,
	["*="] = function(self, name, expr2)
		return fmt("%s = %s * %s", name, name, self:transpile(expr2))
	end,
	["/="] = function(self, name, expr2)
		return fmt("%s = %s / %s", name, name, self:transpile(expr2))
	end,
	["%="] = function(self, name, expr2)
		return fmt("%s = %s %% %s", name, name, self:transpile(expr2))
	end,
	["^="] = function(self, name, expr2)
		return fmt("%s = %s ^ %s", name, name, self:transpile(expr2))
	end,
	["="] = function(self, name, expr2)
		return fmt("%s = %s", name, self:transpile(expr2))
	end,
	["++"] = function(_self, name)
		return fmt("%s = %s + 1", name, name)
	end,
	["--"] = function(_self, name)
		return fmt("%s = %s - 1", name, name)
	end
}

local function NO_OUTPUT() return "" end

local Transpilers = {
	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Block] = function(self, data)
		local block = data[1]
		self:pushScope()
		local res = self:transpileAst(block, true)
		self:popScope()
		return fmt("(function()\n\t%s\nend)()", res)
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.VarDeclare] = function(self, data)
		local kw, name, expr = data[1], data[2], data[4]
		if kw == "var" then
			return fmt("%s = %s", name, self:transpile(expr))
		else
			return fmt("local %s = %s", name, self:transpile(expr))
		end
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.VarModify] = function(self, data)
		local name, how, expr2 = data[1], data[2], data[3]
		return VarModifications[how](self, name, expr2)
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Variable] = function(_self, data)
		return data[1]
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.UnaryOps] = function(self, data)
		local op, expr = data[1], data[2]
		if op == "!" then
			return fmt("not %s", self:transpile(expr))
		elseif op == "-" then
			return fmt("-%s", self:transpile(expr))
		else
			error("Unsupported unary operator: " .. op)
		end
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.ArithmeticOps] = function(self, data)
		local op, expr1, expr2 = data[1], data[2], data[3]
		return fmt("%s %s %s", self:transpile(expr1), op, self:transpile(expr2))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Array] = function(self, data)
		local args = data[1]
		local res = {}
		for i, v in ipairs(args) do
			res[i] = self:transpile(v)
		end
		return fmt("{%s}", table.concat(res, ", "))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Object] = function(self, data)
		local fields = data[1]
		local buf, nbuf = {}, 1
		for key, val in pairs(fields) do
			buf[nbuf] = fmt("[\"%s\"] = %s", key, self:transpile(val))
			nbuf = nbuf + 1
		end
		return fmt("{%s}", table.concat(buf, ", "))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.CallExpr] = function(self, data)
		local fn_expr, args = data[1], data[2]
		for i, v in ipairs(args) do
			args[i] = self:transpile(v)
		end
		return fmt("%s(%s)", self:transpile(fn_expr), table.concat(args, ", "))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.While] = function(self, data)
		local cond, block = data[1], data[2]
		return fmt("while %s do\n\t%s\nend", self:transpile(cond), self:transpileAst(block))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Index] = function(self, data)
		---@type string
		local method = data[1]
		---@type Node
		local tbl = data[2]
		---@type Token|Node
		local key  = data[3] -- A token if it's a literal (x.0 or x.y), a node if it's a variable (x[y])

		if method == "[]" then
			-- Runtime indices
			return fmt("%s[%s]", self:transpile(tbl), self:transpile(key))
		elseif method == "." then
			-- Static indices
			if Parser.isToken(key, TOKEN_KINDS.Integer) then
				return fmt("%s[%i]" , self:transpile(tbl), key.value)
			else
				return fmt("%s.%s", self:transpile(tbl), key.raw)
			end
		end
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.ComparisonOps] = function(self, data)
		local op, expr1, expr2 = data[1], data[2], data[3]
		if op == "!=" then op = "~=" end
		return fmt("%s %s %s", self:transpile(expr1), op, self:transpile(expr2))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.GroupedExpr] = function(self, data)
		local expr = data[1]
		return fmt("(%s)", self:transpile(expr))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Escape] = function(self, data)
		local method, ret = data[1], data[2]
		if method == "return" then
			return fmt("return %s", self:transpile(ret))
		else
			-- continue or break
			return method
		end
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.If] = function(self, data)
		local cond, block = data[1], data[2]

		local next = self:peek()
		if next and next.kind == NODE_KINDS.Else or next.kind == NODE_KINDS.Elseif then
			return fmt("if %s then %s", self:transpile(cond), self:transpileAst(block))
		end

		return fmt("if %s then %s end", self:transpile(cond), self:transpile(block))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Elseif] = function(self, data)
		local cond, block = data[1], data[2]
		local next = self:peek()
		if next and next.kind == NODE_KINDS.Else or next.kind == NODE_KINDS.Elseif then
			return fmt("elseif %s then %s", self:transpile(cond), self:transpileAst(block))
		end

		return fmt("elseif %s then %s end", self:transpile(cond), self:transpileAst(block))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Else] = function(self, data)
		local block = data[1]
		return fmt("else %s end", self:transpileAst(block))
	end,

	---@param self Tokenizer
	---@param data table<number, any>
	[NODE_KINDS.Literal] = function(_self, data)
		---@type "number"|"string"|"boolean"|"null"
		local type = data[1]

		if type == "number" then
			return tostring(data[2])
		elseif type == "string" then
			return fmt("%q", data[2])
		elseif type == "boolean" then
			return data[2] and "true" or "false"
		elseif type == "null" then
			return "nil"
		end
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Function] = function(self, data)
		-- TODO: 'name' here will be an expr in the future for lambdas.
		local name, args, block = data[1], data[2], data[3]

		-- Array of { [1] = name, [2] = type_name }
		---@type table<number, string>
		local argnames = {}
		for k, arg in ipairs(args) do
			argnames[k] = arg[1]
		end
		return fmt("local function %s(%s)\n\t%s\nend", name, table.concat(argnames, ", "), self:transpileAst(block, true))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Lambda] = function(self, data)
		local args, block = data[1], data[2]

		-- Array of { [1] = name, [2] = type_name }
		---@type table<number, string>

		local argnames = {}
		for k, arg in ipairs(args) do
			argnames[k] = arg[1]
		end
		return fmt("function(%s)\n\t%s\nend", table.concat(argnames, ", "), self:transpileAst(block, true))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.For] = function(self, data)
		local varname, start, cond, step, block = data[2], data[3], data[4], data[5], data[6]
		--[[
			$kw $varname = $start
			while $cond do
				$block
				$step
			end
		]]
		self:pushScope()
			block = self:transpileAst(block, true)
		self:popScope()

		return fmt(
			"local %s = %s\nwhile %s do\n\t%s\n\t%s\nend",
			varname,
			self:transpile(start),
			self:transpile(cond),
			block,
			self:transpile(step)
		)
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Try] = function(self, data)
		local try_block, catch_var, catch_block = data[1], data[2], data[4]
		--[[
			xpcall(function()
				$try_block
			end, function($catch_var)
				$catch_block
			end)
		]]
		self:pushScope()
			try_block = self:transpileAst(try_block, true)
		self:popScope()

		self:pushScope()
			catch_block = self:transpileAst(catch_block, true)
		self:popScope()

		return fmt(
			"xpcall(function()\n\t%s\nend, function(%s)\n\t%s\nend)",
			try_block,
			catch_var,
			catch_block
		)
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Declare] = function(_self, data)
		-- kind is "var", "function", "type" or "namespace"
		local kind, name = data[1], data[2]
		return fmt("-- declare %s as %s", name, kind)
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Realm] = function(self, data)
		local name, block = data[1], data[2]
		return fmt("if %s then\n\t%s\nend", string.upper(name), self:transpileAst(block, true))
	end,

	[NODE_KINDS.Class] = NO_OUTPUT,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Constructor] = function(self, data)
		local name, args = data[1], data[2]
		for i, v in ipairs(args) do
			args[i] = self:transpile(v)
		end
		return fmt("%s(%s)", name, table.concat(args, ", "))
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Export] = function(self, data)
		local inner = data[1]
		return fmt("-- exported..\n%s", self:transpile(inner))
	end,

	-- TODO: These could all be lookup tables, but not sure if it's worth it.

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.BitwiseOps] = function(self, data)
		local op, expr1, expr2 = data[1], data[2], data[3]
		if op == "&" then
			return fmt("bit.band(%s, %s)", self:transpile(expr1), self:transpile(expr2))
		elseif op == "|" then
			return fmt("bit.bor(%s, %s)", self:transpile(expr1), self:transpile(expr2))
		else
			error("Unsupported bitwise op: " .. op)
		end
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.BitShiftOps] = function(self, data)
		local op, expr1, expr2 = data[1], data[2], data[3]
		if op == "<<" then
			return fmt("bit.lshift(%s, %s)", self:transpile(expr1), self:transpile(expr2))
		elseif op == ">>" then
			return fmt("bit.rshift(%s, %s)", self:transpile(expr1), self:transpile(expr2))
		else
			error("Unsupported bit shift op: " .. op)
		end
	end,

	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.LogicalOps] = function(self, data)
		local op, expr1, expr2 = data[1], data[2], data[3]
		if op == "&&" then
			return fmt("(%s and %s)", self:transpile(expr1), self:transpile(expr2))
		elseif op == "||" then
			return fmt("(%s or %s)", self:transpile(expr1), self:transpile(expr2))
		else
			error("Unsupported logical op: " .. op)
		end
	end,

	-- TODO: This is unsound. It should use a function like https://wiki.facepunch.com/gmod/Global.Either
	---@param self Transpiler
	---@param data table<number, any>
	[NODE_KINDS.Ternary] = function(self, data)
		local cond_if, lhs, rhs = data[1], data[2], data[3]
		if rhs then
			-- x ? y : z
			return fmt("%s and %s or %s", self:transpile(cond_if), self:transpile(lhs), self:transpile(rhs))
		else
			-- x ?? y
			return fmt("%s or %s", self:transpile(cond_if), self:transpile(lhs))
		end
	end
}

function Transpiler:pushScope()
	-- TODO: Transpiler scopes?
end

function Transpiler:popScope()
	-- TODO: Transpiler scopes?
end

---@return Node?
function Transpiler:peek()
	return self.nodes[self.current + 1]
end

---@param node Node
---@return string?
function Transpiler:transpile(node)
	local handler = Transpilers[node.kind]
	if handler then
		return handler(self, node.data)
	end

	if not node.kind then
		print( debug.traceback() )
	end
	ErrorNoHalt("ES: !!! Unimplemented Transpile target: ", Parser.KINDS_INV[node.kind] or node.kind, "\n")
	return ""
end

---@param ast table<number, Node>
---@param indent boolean
---@return string
function Transpiler:transpileAst(ast, indent)
	local ret = {}
	if not ast then return "" end -- Empty block

	self.nodes = ast
	for i, node in ipairs(ast) do
		self.current = i
		if indent then
			ret[i] = string.gsub(self:transpile(node), "\n", "\n\t")
		else
			ret[i] = self:transpile(node)
		end
	end
	return table.concat(ret, indent and "\n\t" or "\n")
end

--- Transpiles ES code into Lua.
--- Get the ast from the [Analyzer].
---@param ctx Context # Context retrieved from [Context.new]
---@param ast table<number, Node> # AST retrieved from the [Analyzer] or [Parser]
---@return string
function Transpiler:process(ctx, ast)
	assert(ELib.Context:instanceof(ctx), "bad argument #1 to 'Transpiler:process' (Context expected, got " .. type(ctx) .. ")")
	assert(type(ast) == "table", "bad argument #2 to 'Transpiler:process' (table expected, got " .. type(ast) .. ")")

	self.ctx = ctx
	self.ast = ast

	return self:transpileAst(ast)
end

ELib.Transpiler = Transpiler

return Transpiler