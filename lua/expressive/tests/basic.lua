require("expressive/library"); local ELib = ELib
local Import = ELib.Import

--- TODO: This should adapt to different addon names, using the value fetched from autorun
local src = file.Read("expressive/examples/helloworld.es.txt", "LUA")

local Lexer = Import("expressive/compiler/lexer/mod", false)
local Parser = Import("expressive/compiler/parser/mod", false)
local Analyzer = Import("expressive/compiler/analysis/mod", false)
local Transpiler = Import("expressive/compiler/transpiler/mod", false)

local lexer = Lexer.new()
local parser = Parser.new()
local analyzer = Analyzer.new()
local transpiler = Transpiler.new()

local atoms = lexer:lex(src)
local ast = parser:parse(atoms)
local new_ast = analyzer:process(ELib.ExtensionCtx, ast)
local code = transpiler:process(ELib.ExtensionCtx, new_ast)

MsgN("Generated Lua code!")
MsgN(code)