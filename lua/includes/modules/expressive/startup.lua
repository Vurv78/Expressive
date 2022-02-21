local ELib = require("expressive/library")

if CLIENT then
	include("expressive/editor.lua")
	include("expressive/editor/database.lua")
end

---@type Namespace
local _Namespace = include("expressive/runtime/namespace.lua")

---@type Variable
local _Var = include("expressive/compiler/variable.lua")
---@type Type
local _Type = include("expressive/runtime/type.lua")

---@type Context
local Context = include("expressive/runtime/context.lua")

---@type Tokenizer
local Tokenizer = include("expressive/compiler/tokenizer.lua")
---@type Parser
local Parser = include("expressive/compiler/parser/mod.lua")
---@type Analyzer
local Analyzer = include("expressive/compiler/analysis/mod.lua")
---@type Transpiler
local _Transpiler = include("expressive/compiler/transpiler/mod.lua")

include("expressive/compiler/ast.lua")
include("expressive/instance.lua")

---@param extensions table<string, string> # File Name -> Content
local function loadExtensions(extensions)
	-- TODO: Output extension data in a neater format for editor to use
	local _extensions_out = {}

	---@type AnalyzerConfigs
	local ExtensionConfigs = {
		AllowDeclare = true,
		Optimize = 1,
		StrictTyping = false,
		UndefinedVariables = true
	}

	local DefaultCtx = Context.new()
	ELib.DefaultCtx = DefaultCtx

	local ExtensionCtx = Context.new()
	ELib.ExtensionCtx = ExtensionCtx

	---@type table<number, string>
	MsgN("<< Loading Expressive Extensions >>")
	for name, src in pairs(extensions) do
		local ok, traceback = xpcall(function()
			local tokenizer = Tokenizer.new()
			local parser = Parser.new()
			local analyzer = Analyzer.new()
			-- local transpiler = Transpiler.new() -- Don't need this quite yet. When extensions are more than just declare statements, this will be needed.

			local tokens = tokenizer:parse(src)
			local ast = parser:parse(tokens)
			local _new_ast = analyzer:process(ExtensionCtx, ast, ExtensionConfigs)
		end, debug.traceback)

		if ok then
			MsgN("Loaded extension " .. name)
		else
			local trace = string.gsub(traceback, "\n", "\n\t>>>")
			local msg = string.format("Failed to load extension %s {\n\t>>> %s\n}\n", name, trace)
			-- If nothing appears after the "extension ..." part, then there's some errors with the datastream library / \0 chars.
			ErrorNoHalt(msg)
		end
	end

	ELib.Extensions = extensions
	hook.Run("Expressive.PostRegisterExtensions", extensions)
end

--- Network Extensions to Client
local DataStream, _DataStruct = require("datastream")
if SERVER then
	local extensions = {}
	---@type table<number, string>
	local files = file.Find("expressive/runtime/extensions/*.es.txt", "LUA")

	local stream = DataStream.new()
	stream:writeU16(#files) -- Max 65536 extensions but at that point wtf

	for _, file_name in pairs(files) do
		local path = "expressive/runtime/extensions/" .. file_name
		resource.AddSingleFile(path)

		local content = file.Read(path, "LUA")
		local no_ext = string.sub(file_name, 1, -8)

		extensions[no_ext] = content
		stream:writeString(no_ext)
		stream:writeU32(#content)
		stream:writeString(content, true)
	end

	loadExtensions(extensions)

	local buf = stream:getBuffer()

	local function callback(ply)
		MsgN("Sending Expressive extensions to " .. ply:Nick())
	end

	-- Broadcast for the first time. This is for hot reloading.
	ELib.StartNet("LoadExtensions")
		net.WriteStream(buf, callback)
	net.Broadcast()

	-- When players join, they request from their client when they are ready to receive net messages.
	-- Then the server can send them the extensions
	ELib.ReceiveNet("LoadExtensions", function(_len, ply)
		ELib.StartNet("LoadExtensions")
			net.WriteStream(buf, callback)
		net.Send(ply)
	end)
else
	-- You have to ping pong from the client to tell the server you are ready for net messages.
	-- Excellent, gmod / source!
	-- (The hook does work serverside, but your player object doesn't exist)
	hook.Add("ClientSignOnStateChanged", "Expressive.LoadExtensions", function(_user_id, _old, state)
		---@diagnostic disable-next-line: undefined-global
		if state == SIGNONSTATE_FULL then
			ELib.StartNet("LoadExtensions")
			net.SendToServer()
		end
	end)

	-- CLIENT
	ELib.ReceiveNet("LoadExtensions", function(_len)
		net.ReadStream(nil, function(data)
			if not data then
				error("Failed to read stream!")
			end
			local stream = DataStream.new(data)

			local extensions = {}
			for _ = 1, stream:readU(16) do
				local name = stream:readString()
				local len = stream:readU(32)
				local content = stream:read(len)

				extensions[name] = content
			end

			loadExtensions(extensions)
		end)
	end)
end

-- Just reloads all of the extensions for now.
-- TODO: Make it reload all currently placed chips
concommand.Add("expressive_reload" .. (CLIENT and "_cl" or ""), function()
	-- Include self
	package.required["expressive/startup"] = nil
	require("expressive/startup")
end)