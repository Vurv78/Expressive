local Context, Lexer, Parser, Analyzer, Transpiler
local function _start(std_src)
	-- Fengari interface for Expressive.
	local paths = {
		"../lua/includes/modules/?.lua",
		"../?.lua",
		"../lua/?.lua",
		"../lua/expressive/compiler/lexer/?.lua",
		"../lua/expressive/compiler/parser/?.lua",
		"../lua/expressive/compiler/analysis/?.lua",
		"../lua/expressive/compiler/analysis/optimizer/?.lua",
		"../lua/expressive/compiler/transpiler/?.lua",
	}

	package.path = table.concat(paths, ";") .. package.path

	do
		--- Patch in ``include`` function that should act just as garry's does. (Granted it caches.)
		---@param path string
		_G.include = function(path)
			local p = path:match("^(.*)%.lua$", 0)
			return require(p)
		end

		_G.ErrorNoHalt = function(...)
			local tbl = {}
			for i = 1, select("#", ...) do
				tbl[i] = tostring(select(i, ...))
			end

			error( table.concat(tbl, "") )
		end
	end

	require("expressive/library"); local ELib = ELib
	local Import = ELib.Import

	do
		local _Var = Import("expressive/compiler/variable")
		local _Ast = Import("expressive/compiler/ast")
		local _Namespace = Import("expressive/runtime/namespace")
	end

	do
		local _Context = Import("expressive/runtime/context")
		local _Lexer = Import("expressive/compiler/lexer/mod")
		local _Parser = Import("expressive/compiler/parser/mod")
		local _Analyzer = Import("expressive/compiler/analysis/mod")
		local _Transpiler = Import("expressive/compiler/transpiler/mod")

		---@type AnalyzerConfigs
		local Configs =
		{
			AllowDeclare = true,
			Optimize = 1,
			StrictTyping = false,
			UndefinedVariables = true
		}

		do
			-- Create a context, and load all of the declarations from web std into the Context.
			Context = _Context.new()
			-- ctx:registerVar("print", Var.new( Analyzer.makeSignature({"string"}, "void"), print, false ))

			Lexer = _Lexer.new()
			Parser = _Parser.new()
			Analyzer = _Analyzer.new()
			Transpiler = _Transpiler.new() -- Don't need this quite yet. When extensions are more than just declare statements, this will be needed.

			local atoms = Lexer:lex(std_src)
			local ast = Parser:parse(atoms)
			local _new_ast = Analyzer:process(Context, ast, Configs)
		end
	end
end

---@param web_std string # Standard library decls for the web (web.es.txt)
function Startup(web_std)
	return xpcall(_start, debug.traceback, web_std)
end

---@param code string # Expressive code
function Transpile(code)
	Lexer:reset()
	Parser:reset()
	Analyzer:reset()

	local ok, ret = xpcall(function()
		local atoms = Lexer:lex(code)
		print("Transpile atoms", atoms, #atoms)

		for k, v in ipairs( atoms ) do print(k, v) end
		local ast = Parser:parse(atoms)
		local new_ast = Analyzer:process(Context, ast)
		local lua = Transpiler:process(Context, new_ast)

		return lua
	end, debug.traceback)

	assert(ok, ret)

	return ret
end