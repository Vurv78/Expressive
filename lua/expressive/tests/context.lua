require("expressive/extension")

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
---@type Type
local Type = include("expressive/core/type.lua")

local tok = Tokenizer.new()
local parser = Parser.new()
local analyzer = Analyzer.new()
local transpiler = Transpiler.new()

local ctx = Context.new()

local DoubleType = Type.new("double")
DoubleType.instanceof = isnumber

ctx:registerType("double", DoubleType)

local IntType = Type.new("int", DoubleType)
ctx:registerType("int", IntType)

local Function = Type.new("function")
Function.instanceof = isfunction

ctx:registerType("function", Function)

ctx:registerConstant("print", Function, function(...)
	print("print fn!")
	print(...)
end)

local tokens = tok:parse(src)
local ast = parser:parse(tokens)
local new_ast = analyzer:process(ctx, ast)
local code = transpiler:process(ctx, new_ast)

print("Generated Lua code!")

file.Write("foo.es.txt", code)