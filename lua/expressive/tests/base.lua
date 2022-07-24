--- TODO: This should adapt to different addon names, using the value fetched from autorun
local src = file.Read("expressive/examples/helloworld.es.txt", "LUA")

---@type Context
local Context = include("expressive/runtime/context.lua")
---@type Lexer
local Lexer = include("expressive/compiler/lexer/mod.lua")
---@type Parser
local Parser = include("expressive/compiler/parser/mod.lua")
---@type Analyzer
local Analyzer = include("expressive/compiler/analysis/mod.lua")
---@type Transpiler
local Transpiler = include("expressive/compiler/transpiler/mod.lua")

---@type Ast
local _Ast = include("expressive/compiler/ast.lua")

local lexer = Lexer.new()
local parser = Parser.new()
local analyzer = Analyzer.new()
local transpiler = Transpiler.new()

local ctx = Context.new()
local atoms = lexer:lex(src)
local ast = parser:parse(atoms)
local new_ast = analyzer:process(ctx, ast)
local code = transpiler:process(ctx, new_ast)

MsgN("Generated Lua code!")
MsgN(code)