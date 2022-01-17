--- TODO: This should adapt to different addon names, using the value fetched from autorun
local src = file.Read("expressive/examples/core.es.txt", "LUA")
local ELib = require("expressive/library")
require("expressive/startup")

---@type Context
local Context = include("expressive/core/context.lua")
---@type Tokenizer
local Tokenizer = include("expressive/base/tokenizer.lua")
---@type Parser
local Parser = include("expressive/base/parser/mod.lua")
---@type Analyzer
local Analyzer = include("expressive/base/analysis/mod.lua")
---@type Transpiler
local Transpiler = include("expressive/base/transpiler/mod.lua")

---@type Ast
local Ast = include("expressive/base/ast.lua")

local tok = Tokenizer.new()
local parser = Parser.new()
local analyzer = Analyzer.new()
local transpiler = Transpiler.new()

local tokens = tok:parse(src)
local ast = parser:parse(tokens)
local new_ast = analyzer:process(ELib.ExtensionCtx, ast, {
	AllowDeclare = true,
	StrictTyping = false
})
local code = transpiler:process(ELib.ExtensionCtx, new_ast)

print("Generated Lua code!")
print(code)