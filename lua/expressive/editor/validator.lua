local ELib = require("expressive/library")
local class = require("voop")
require("expressive/startup")

---@class Validator: Object
---@field editor any
local Validator = class("Validator")

--- Validates given code and returns true and transpiled code if successful
---@return boolean
---@return string? # Lua code generated if successfully validated.
function Validator:Validate(code, move_to, export_compiled)
	if not code or code == "" then
		self:Throw("No code submitted")
		return false
	end

	self.editor.validation_bar:SetBGColor(Color(100, 200, 100))
	self.editor.validation_bar:SetText("Validating...")

	local function xpcaller(msg)
		print("xpcaller", msg)
		return {msg, debug.traceback(msg)}
	end

	local ok, data = xpcall(function()
		local Tokenizer = ELib.Tokenizer.new()
		local tokens = Tokenizer:parse(code)

		local Parser = ELib.Parser.new()
		local ast = Parser:parse(tokens)

		local Analyzer = ELib.Analyzer.new()
		ast = Analyzer:process(ELib.ExtensionCtx, ast)

		local Transpiler = ELib.Transpiler.new()
		return Transpiler:process(ELib.ExtensionCtx, ast)
	end, xpcaller)

	if not ok then
		local msg, traceback = data[1], data[2]
		return self:Throw("Failed to compile: " .. msg, traceback, true)
	end

	self.editor.validation_bar:SetBGColor(Color(100, 200, 100))
	self.editor.validation_bar:SetText("Validation Successful!")

	return true, data
end

--- Throws a validation error (puts traceback in console, error message on validation bar.)
---@param msg string
---@param traceback string
---@param move_to boolean
function Validator:Throw(msg, traceback, move_to)
	self.editor.validation_bar:SetBGColor(Color(255, 100, 100))
	self.editor.validation_bar:SetText(msg)
	self.editor.console:ErrorLn(traceback or msg)
end

return function(editor)
	return setmetatable({
		editor = editor
	}, Validator)
end