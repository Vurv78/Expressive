local ELib = require("expressive/library")
require("expressive/startup")

---@class Validator
---@field editor any
local Validator = {}
Validator.__index = Validator

--- Validates given code and returns true and transpiled code if successful
---@return boolean
---@return string?
function Validator:Validate(code, move_to, export_compiled)
	if not code or code == "" then
		self:Throw("No code submitted")
		return false
	end

	self.editor.validation_bar:SetBGColor(Color(100, 200, 100))
	self.editor.validation_bar:SetText("Validating...")

	local Tokenizer = ELib.Tokenizer.new()
	local ok, tokens = pcall(Tokenizer.parse, Tokenizer, code)
	if not ok then
		return self:Throw(tokens, true)
	end

	local Parser = ELib.Parser.new()
	local ok, ast = pcall(Parser.parse, Parser, tokens)
	if not ok then
		return self:Throw(ast, true)
	end

	local ctx = ELib.DefaultCtx

	local Analyzer = ELib.Analyzer.new()
	local ok, ast = pcall(Analyzer.process, Analyzer, ctx, ast)
	if not ok then
		return self:Throw(ast, true)
	end

	local Transpiler = ELib.Transpiler.new()
	local ok, code = pcall(Transpiler.process, Transpiler, ctx, ast)
	if not ok then
		return self:Throw(code, true)
	end

	self.editor.validation_bar:SetBGColor(Color(100, 200, 100))
	self.editor.validation_bar:SetText("Validation Successful!")

	print("pcall", ok, code)
	return true, code
end

function Validator:Throw(msg, move_to)
	self.editor.validation_bar:SetBGColor(Color(255, 100, 100))
	self.editor.validation_bar:SetText(msg)
	self.editor.console:ErrorLn(msg)
end

return function(editor)
	return setmetatable({
		editor = editor
	}, Validator)
end