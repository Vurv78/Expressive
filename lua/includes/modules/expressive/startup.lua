local ELib = require("expressive/library")

include("expressive/base/tokenizer.lua")
include("expressive/base/parser/mod.lua")
include("expressive/base/analysis/mod.lua")
include("expressive/base/transpiler/mod.lua")
include("expressive/base/ast.lua")
include("expressive/instance.lua")
include("expressive/core/type.lua")

---@type Context
local Context = include("expressive/core/context.lua")

local DefaultCtx = Context.new()
ELib.DefaultCtx = DefaultCtx

if CLIENT then
	include("expressive/editor.lua")
	include("expressive/editor/database.lua")
end

local extensions = {}
local files = file.Find("expressive/core/extensions/*.lua", "LUA")
for k, file in ipairs(files) do
	print("Loading Expressive extension: " .. file)
	local ok, res = pcall(include, "expressive/core/extensions/" .. file)
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
	end
end

print("DefaultCtx", DefaultCtx)

ELib.Extensions = extensions