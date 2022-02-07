-- Fengari interface for Expressive.
local paths = {
	"../lua/includes/modules/?.lua",
	"../?.lua",
	"../lua/?.lua",
	"../lua/expressive/base/parser/?.lua",
	"../lua/expressive/base/analysis/?.lua",
	"../lua/expressive/base/analysis/optimizer/?.lua",
	"../lua/expressive/base/transpiler/?.lua",
}

package.path = table.concat(paths, ";") .. package.path

---@param path string
function include(path)
	local p = string.match(path, "^(.*)%.lua$")
	return require(p)
end
require("expressive/library")

local _Var = require("expressive/base/variable")
local _Namespace = require("expressive/core/namespace")
local Context = require("expressive/core/context")
local Tokenizer = require("expressive/base/tokenizer")
local Parser = require("expressive/base/parser/mod")
local Analyzer = require("expressive/base/analysis/mod")
local Transpiler = require("expressive/base/transpiler/mod")

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