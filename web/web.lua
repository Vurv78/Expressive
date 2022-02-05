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

local Var = require("expressive/base/variable")
local Context = require("expressive/core/context")
local Tokenizer = require("expressive/base/tokenizer")
local Parser = require("expressive/base/parser/mod")
local Analyzer = require("expressive/base/analysis/mod")
local Transpiler = require("expressive/base/transpiler/mod")

local ctx = Context.new()
ctx:registerVar("print", Var.new( Analyzer.makeSignature({"string"}, "void"), print, false ))

---@param code string # Expressive code
function transpile(code)
	local tokenizer, parser, analyzer, transpiler = Tokenizer.new(), Parser.new(), Analyzer.new(), Transpiler.new()

	local tokens = tokenizer:parse(code)
	local ast = parser:parse(tokens)
	local new_ast = analyzer:process(ctx, ast)
	local lua = transpiler:process(ctx, new_ast)

	return lua
end