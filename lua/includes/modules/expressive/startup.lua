local ELib = require("expressive/library")

if CLIENT then
	include("expressive/editor.lua")
	include("expressive/editor/database.lua")
end

---@type AnalyzerConfigs
local ExtensionConfigs = {
	AllowDeclare = true,
	Optimize = 1,
	StrictTyping = false,
	UndefinedVariables = true
}

local function reload()
	---@type Variable
	local Var = include("expressive/base/variable.lua")
	---@type Type
	local Type = include("expressive/core/type.lua")

	---@type Tokenizer
	local Tokenizer = include("expressive/base/tokenizer.lua")
	---@type Parser
	local Parser = include("expressive/base/parser/mod.lua")
	---@type Analyzer
	local Analyzer = include("expressive/base/analysis/mod.lua")
	---@type Transpiler
	local Transpiler = include("expressive/base/transpiler/mod.lua")

	include("expressive/base/ast.lua")
	include("expressive/instance.lua")

	---@type Context
	local Context = include("expressive/core/context.lua")

	local DefaultCtx = Context.new()
	ELib.DefaultCtx = DefaultCtx

	local ExtensionCtx = Context.new()
	ELib.ExtensionCtx = ExtensionCtx

	local extensions = {}

	---@type table<number, string>
	local files = file.Find("expressive/core/extensions/*.es.txt", "LUA")

	print("<< Loading Expressive Extensions >>")
	for _, file_name in ipairs(files) do
		local src = file.Read("expressive/core/extensions/" .. file_name, "LUA")

		local ok, res = pcall(function()
			local tokenizer = Tokenizer.new()
			local parser = Parser.new()
			local analyzer = Analyzer.new()
			local transpiler = Transpiler.new()
			local analyzer = Analyzer.new()

			local tokens = tokenizer:parse(src)
			local ast = parser:parse(tokens)
			local new_ast = analyzer:process(ExtensionCtx, ast, ExtensionConfigs)
		end)

		if not ok then
			ErrorNoHalt("Failed to load extension " .. file_name .. " {\n\t>> " .. string.gsub(res, "\n", "\n\t>>") .. "\n}\n")
		else
			print("Loaded extension " .. file_name)
		end

		--[[local ok, res = pcall(include, "expressive/core/extensions/" .. file)
		if not ok then
			ErrorNoHalt("Failed to load Extension " .. file .. ": " .. res .. "\n")
		else
			if not res or getmetatable(res) ~= ELib.Extension then
				ErrorNoHalt("Failed to load Extension " .. file .. ": Did not return an Extension type!\n")
			else
				---@type Extension
				local res = res

				local ok, why = pcall(res.register, res, DefaultCtx)
				if not ok then
					ErrorNoHalt("Failed to load Extension " .. file .. ": " .. why .. "\n")
				else
					table.insert(extensions, res)
				end
			end
		end]]
	end

	ELib.Extensions = extensions
end

reload()

-- Just reloads all of the extensions for now.
-- TODO: Make it reload all currently placed chips
concommand.Add("expressive_reload" .. (CLIENT and "_cl" or ""), reload)