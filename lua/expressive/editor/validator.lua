local ELib = require("expressive/library")
local class = require("voop")
require("expressive/startup")

---@class Validator: Object
---@field editor any
local Validator = class("Validator")

local rgb = Color
local C_WARN = rgb(200, 200, 50)
local C_ERROR = rgb(255, 100, 100)
local C_SUCCESS = rgb(100, 200, 100)

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
		return {msg, debug.traceback(msg)}
	end

	local ok, data, warnings = xpcall(function()
		local Tokenizer = ELib.Tokenizer.new()
		local tokens = Tokenizer:parse(code)

		local Parser = ELib.Parser.new()
		local ast = Parser:parse(tokens)

		local Analyzer = ELib.Analyzer.new()
		ast = Analyzer:process(ELib.ExtensionCtx, ast)

		local Transpiler = ELib.Transpiler.new()
		return Transpiler:process(ELib.ExtensionCtx, ast), Analyzer.warnings
	end, xpcaller)

	if ok then
		if #warnings > 0 then
			for i = 1, #warnings do
				self:Warn( warnings[i][3] )
			end
			self.editor.validation_bar:SetBGColor(C_WARN)
			self.editor.validation_bar:SetText("Successfully validated with %u warnings")
		else
			-- Validated, no warnings.
			self.editor.validation_bar:SetBGColor(C_SUCCESS)
			self.editor.validation_bar:SetText("Validation Successful!")
		end
	else
		local msg, traceback = data[1], data[2]
		return self:Throw("Failed to compile: " .. msg, traceback, true)
	end

	return true, data
end

--- Throws a validation error (puts traceback in console, error message on validation bar.)
---@param msg string
---@param traceback string
---@param move_to boolean
function Validator:Throw(msg, traceback, move_to)
	self.editor.validation_bar:SetBGColor(C_ERROR)
	self.editor.validation_bar:SetText(msg)
	self.editor.console:ErrorLn(traceback or msg)
end

--- Puts a warning in the editor's console.
function Validator:Warn(msg, traceback)
	self.editor.console:WarnLn(traceback or msg)
end

return function(editor)
	return setmetatable({
		editor = editor
	}, Validator)
end