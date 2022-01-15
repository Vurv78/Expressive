local src = file.Read("es.txt", "DATA")

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

local ctx = Context.new()
local tokens = tok:parse(src)
local ast = parser:parse(tokens)
local new_ast = analyzer:process(ctx, ast)
local code = transpiler:process(ctx, new_ast)

print("Generated Lua code!")

file.Write("foo.es.txt", code)