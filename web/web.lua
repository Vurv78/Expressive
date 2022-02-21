-- Fengari interface for Expressive.
local paths = {
	"../lua/includes/modules/?.lua",
	"../?.lua",
	"../lua/?.lua",
	"../lua/expressive/compiler/parser/?.lua",
	"../lua/expressive/compiler/analysis/?.lua",
	"../lua/expressive/compiler/analysis/optimizer/?.lua",
	"../lua/expressive/compiler/transpiler/?.lua",
}

package.path = table.concat(paths, ";") .. package.path

--- Patch in ``include`` function that should act just as garry's does. (Granted it caches.)
---@param path string
_G.include = function(path)
	local p = string.match(path, "^(.*)%.lua$")
	return require(p)
end
require("expressive/library")

local _Var = require("expressive/compiler/variable")
local _Namespace = require("expressive/runtime/namespace")
local Context = require("expressive/runtime/context")
local Tokenizer = require("expressive/compiler/tokenizer")
local Parser = require("expressive/compiler/parser/mod")
local Analyzer = require("expressive/compiler/analysis/mod")
local Transpiler = require("expressive/compiler/transpiler/mod")

local ctx = Context.new()
-- ctx:registerVar("print", Var.new( Analyzer.makeSignature({"string"}, "void"), print, false ))

---@type AnalyzerConfigs
local ExtensionConfigs = {
	AllowDeclare = true,
	Optimize = 1,
	StrictTyping = false,
	UndefinedVariables = true
}


--- Prepares the context with the default web bindings.
---@param src string # Contents of web.es.txt given by javascript
function startup(src)
	local tokenizer = Tokenizer.new()
	local parser = Parser.new()
	local analyzer = Analyzer.new()
	-- local transpiler = Transpiler.new() -- Don't need this quite yet. When extensions are more than just declare statements, this will be needed.

	local tokens = tokenizer:parse(src)
	local ast = parser:parse(tokens)
	local _new_ast = analyzer:process(ctx, ast, ExtensionConfigs)
end

---@param code string # Expressive code
function transpile(code)
	local tokenizer, parser, analyzer, transpiler = Tokenizer.new(), Parser.new(), Analyzer.new(), Transpiler.new()

	local tokens = tokenizer:parse(code)
	local ast = parser:parse(tokens)
	local new_ast = analyzer:process(ctx, ast)
	local lua = transpiler:process(ctx, new_ast)

	return lua
end