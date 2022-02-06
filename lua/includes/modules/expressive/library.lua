-- Fengari polyfill
local MsgN = print

-- Sequel to the E2Lib.
---@class ELib
---@field Version string
---@field Version_NUM number
---@field Tokenizer Tokenizer
---@field Analyzer Analyzer
---@field Parser Parser
---@field Extensions table<number, Extension> # Table of Extensions. Do not interact with this.
---@field Type Type
---@field Instance Instance
---@field Context Context
---@field Namespace Namespace
---@field Transpiler Transpiler
---@field Var Variable
---@field ExtensionCtx Context
---@field DefaultCtx Context
local Library = {
	Version = "0.1.0",
	Version_NUM = 100 -- 1.0.0 -> 100, 1.0.1 -> 101, 0.2.0 -> 020, etc.
}

Library.Operators = {
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["/"] = true,
	["%"] = true,
	["^"] = true,
	["="] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
	["++"] = true,
	["--"] = true,
	["=="] = true,
	["!="] = true,
	["<"] = true,
	["<="] = true,
	[">"] = true,
	[">="] = true,
	["&"] = true,
	["|"] = true,
	["^^"] = true,
	[">>"] = true,
	["<<"] = true,
	["!"] = true,
	["&&"] = true,
	["||"] = true,
	["?"] = true,
	[":"] = true,
	[";"] = true,
	[","] = true,
	["$"] = true,
	["#"] = true,
	["~"] = true,
	["->"] = true,
	["."] = true,
	["("] = true,
	[")"] = true,
	["{"] = true,
	["}"] = true,
	["["] = true,
	["]"] = true,
	['@'] = true,
	["..."] = true,
}

Library.Keywords = {
	-- ES6 Keywords (Active)
	["if"] = true,
	["else"] = true,
	["while"] = true,
	["for"] = true,
	["function"] = true,
	["true"] = true,
	["false"] = true,
	["break"] = true,
	["continue"] = true,
	["return"] = true,
	["try"] = true,
	["catch"] = true,
	["var"] = true,
	["let"] = true,
	["const"] = true,
	["declare"] = true, -- LOCKED to header files

	-- Custom Expressive Syntax (Active)
	["server"] = true,
	["client"] = true,
	["delegate"] = true,
	["elseif"] = true, -- TODO: Remove and support else if instead.

	-- Keywords in use, but don't have functionality.
	["new"] = true,
	["class"] = true,
	["public"] = true,
	["static"] = true,
	["constructor"] = true,
	["export"] = true,
	["namespace"] = true, -- Only works with declarations for now

	-- ES6 Keywords (Reserved)
	-- These have not been implemented into Expressive so that is why they are (Reserved)
	-- https://github.com/Microsoft/TypeScript/issues/2536
	-- * `✔️` - Will be implemented
	-- * `👍` - Likely to be implemented
	-- * `🤷‍♂️` - Not sure if will implement
	-- * `❌` - Will probably not be implemented
	["enum"] = true, -- 👍
	["this"] = true, -- ✔️
	["undefined"] = true, -- ❌ (Lua has no concept of undefined anyway, and this would add overhead.)
	["throw"] = true, -- 👍
	["typeof"] = true, -- 👍
	["delete"] = true, -- ❌
	["case"] = true, -- 🤷‍♂️
	["switch"] = true, -- 🤷‍♂️
	["type"] = true, -- 👍
	["private"] = true, -- ❌
	["protected"] = true, -- ❌
	["yield"] = true, -- 🤷‍♂️
	["await"] = true, -- 🤷‍♂️
	["async"] = true, -- 🤷‍♂️
	["abstract"] = true, -- 🤷‍♂️
	["import"] = true, -- 👍
	["extends"] = true,
	["interface"] = true, -- 👍
	["implements"] = true, -- 👍
	["instanceof"] = true, -- 👍
	["super"] = true, -- 👍
	["null"] = true, -- 🤷‍♂️
	["in"] = true, -- 🤷‍♂️
	["as"] = true, -- 🤷‍♂️
	["finally"] = true, -- 🤷‍♂️
	["symbol"] = true, -- ❌
	["unique"] = true, -- ❌
	["get"] = true, -- 🤷‍♂️
	["set"] = true, -- 🤷‍♂️
}

local function sort_values(a, b)
	if type(a) == "number" and type(b) == "number" then
		return a < b
	else
		return tostring(a) < tostring(b)
	end
end

function Library.Inspect(object, depth, dumped)
	depth = depth or 0

	if dumped then
		local ref_depth = dumped[object]
		if ref_depth then
			return "<self " .. ref_depth .. ">"
		end
	else
		dumped = {}
	end

	local obj_type = type(object)

	if obj_type == "table" then
		local keys = {}

		do
			local idx = 1
			for key, v in pairs(object) do
				keys[idx] = key
				idx = idx + 1
			end
		end

		table.sort(keys, sort_values)

		depth = depth + 1

		local output = {'{'}
		local indent = string.rep(' ', depth * 4)

		dumped[object] = depth
		for k, key in pairs(keys) do
			local ty, value = type(key), object[key]
			if ty == "number" then
				key = '[' .. key .. ']'
			elseif ty ~= "string" then
				key = '[' .. tostring(key) .. ']'
			end
			output[k + 1] = indent .. key .. " = " .. Library.Inspect(value, depth, dumped) .. ','
		end
		dumped[object] = nil

		depth = depth - 1

		-- string.sub is faster than doing string.rep again. Remove the last 4 chars (indent)
		output[#output + 1] = string.sub(indent, 1, -4) .. '}'

		return table.concat(output, '\n')
	elseif obj_type == "string" then
		return string.format("%q", object)
	else
		return tostring(object)
	end
end

--- Creates an enum from a sequential table of tables
---@param t table<number, table<number, {name: number, udata: table}>>
---@return table<string, number>
---@return table<number, table> # Table of Enum value => Userdata table
function Library.MakeEnum(t)
	local ret, ret2 = {}, {}
	for k, entry in ipairs(t) do
		ret[entry.name] = k
		ret2[k] = entry.udata
	end
	return ret, ret2
end

function Library.GetInverted(t)
	local out = {}
	for k, v in pairs(t) do
		out[v] = k
	end
	return out
end

function Library.GetIDE()
	return ExpressiveEditor.Get()
end

---@class Validator
local Validator = {}
Validator.__index = Validator

function Validator.new(script, files, callback)
	return setmetatable({}, Validator)
end

--- TODO
function Validator:start() end
function Validator:stop() end

Library.Validator = Validator

---@param name string
function Library.AddNetworkString(name)
	if SERVER then
		util.AddNetworkString("Expressive." .. name)
	end
end

---@param name string
---@param unreliable boolean
function Library.StartNet(name, unreliable)
	if net then
		local str = "Expressive." .. name
		if util.NetworkStringToID(str) == 0 then
			ErrorNoHalt("ES: Trying to start net message with unpooled name '" .. name .. "'\n")
			return
		end
		net.Start(str, unreliable)
	end
end

---@param name string
---@param callback fun(len: number, ply: GEntity|GPlayer)
function Library.ReceiveNet(name, callback)
	if net then
		net.Receive("Expressive." .. name, callback)
	end
end

function Library.GetExtensions()
	return Library.Extensions
end

---@class ProcessorData
---@field main string # Name of the entrypoint file in modules
---@field modules table<string, string>
---@field chip ExpressiveProcessor # Chip entity
---@field chip_id integer # Chip entity ID
---@field owner GEntity # Owner entity
---@field owner_id integer # Owner entity ID

local DataStream = require("datastream")

---@param from GPlayer?
---@param callback fun(ok: boolean, data: ProcessorData)
---@return ProcessorData
function Library.ReadProcessor(from, callback)
	---@type ProcessorData
	local out = { modules = {} }

	if CLIENT then
		out.chip_id = net.ReadUInt(16)
		out.owner_id = net.ReadUInt(16)

		out.chip = Entity(out.chip_id)
		out.owner = Entity(out.owner_id)
	end

	-- Name of the main file
	out.main = net.ReadString()

	net.ReadStream(from, function(data)
		if data then
			data = util.Decompress(data)
			local stream = DataStream.new(data)
			local n_files = stream:readU(16)

			for i = 1, n_files do
				-- Module name
				local name = stream:readString()

				-- Module source code
				out.modules[name] = stream:read( stream:readU(32) )
			end

			callback(true, out)
		else
			callback(false, out)
		end
	end)
end

---@param data ProcessorData
---@param callback fun(ok: boolean, data: ProcessorData)
function Library.WriteProcessor(data, callback)
	if SERVER then
		net.WriteUInt(data.chip_id, 16)
		net.WriteUInt(data.owner_id, 16)
	end

	net.WriteString(data.main)

	data = Library.CompressFiles(data.modules)
	net.WriteStream(data, callback)
end

---@param netmsg string
---@param data ProcessorData
---@param ply GPlayer? # Target to send to
---@param callback fun(ok: boolean, data: ProcessorData)
function Library.SendProcessor(netmsg, data, ply, callback)
	Library.StartNet(netmsg)
	Library.WriteProcessor(data, callback)

	if ply then
		net.Send(ply)
	elseif SERVER then
		net.Broadcast()
	else
		net.SendToServer()
	end
end

---@param files table<string, string> # Table of file name and file contents
---@return string
function Library.CompressFiles(files)
	local stream = DataStream.new()

	stream:writeU16( table.Count(files) )
	for name, src in pairs(files) do
		stream:writeString(name)
		stream:writeU32( #src )
		stream:writeString(src, true)
	end
	return util.Compress(stream:getBuffer())
end

---@param files_str string
---@return table<string, string>
function Library.DecompressFiles(files_str)
	files_str = util.Decompress(files_str)

	local stream = DataStream.new(files_str)
	local files = {}

	for i = 1, stream:readU(16) do
		local name, len = stream:readString(), stream:readU(32)
		files[name] = stream:read( len )
	end

	return files
end

if SERVER then
	local PlayerTables = {}

	hook.Add("PlayerDisconnected", "Expressive.PlayerTable", function(ply)
		for t in pairs(PlayerTables) do
			t[ply] = nil
		end
	end)

	--- Returns a table with players for keys that will be cleaned when the player leaves.
	---@return table
	function Library.PlayerTable()
		local t = {}
		PlayerTables[t] = true
		return t
	end

	local upload_data = Library.PlayerTable()

	---@param ply GPlayer
	---@param callback function
	---@param main string
	function Library.RequestCode(ply, callback, main)
		if upload_data[ply] and upload_data[ply].timeout > CurTime() then return false end

		Library.StartNet("Processor.Upload")
			net.WriteString(main or "")
		net.Send(ply)

		upload_data[ply] = {
			callback = callback,
			timeout = CurTime() + 5,
		}
		return true
	end


	Library.ReceiveNet("Processor.Upload", function(len, ply)
		local updata = upload_data[ply]
		if not updata or updata.reading then
			ErrorNoHalt("ES: Player " .. ply:GetName() .. " tried to upload code without being requested.\n")
			return
		end

		updata.reading = true

		Library.ReadProcessor(ply, function(ok, data)
			if ok then
				if #data.main > 0 then
					data.owner = ply
					updata.callback(data)
				end
			else
				if upload_data[ply] == updata then
					-- NOTIFY_ERROR
					Library.Notify(ply, 1, "There was a problem uploading your code. Try again in a second.")
				end
			end
			upload_data[ply] = nil
		end)
	end)
else
	-- CLIENT
	Library.ReceiveNet("Processor.Upload", function()
		-- Server wants us to send a file
		local mainfile = net.ReadString()
		if #mainfile == 0 then mainfile = nil end

		local handler = Library.GetIDE():GetActiveTabHandler()
		if handler then
			local active_tab = handler.tabs[handler.active_tab]
			if not active_tab then
				notification.AddLegacy("You must have an active tab to upload code.", NOTIFY_ERROR, 5)
				return
			end
			local entrypoint = active_tab.name

			local code = ExpressiveEditor.GetCode()

			Library.SendProcessor("Processor.Upload", {
				modules = { [entrypoint] = code },
				main = entrypoint
			})
		else
			notification.AddLegacy("You must have an active tab to upload code.", NOTIFY_ERROR, 5)
		end
	end)
end

---@param ply GPlayer
function Library.PrintTo(ply, msg)
	Library.StartNet("PrintTo")
		net.WriteString(msg)
	net.Send(ply)
end

---@param ply GPlayer
---@param type "NOTIFY_GENERIC|NOTIFY_ERROR|NOTIFY_UNDO|NOTIFY_HINT|NOTIFY_CLEANUP" # Notify enum. From 0 - 4.
---@param msg string
function Library.Notify(ply, type, msg)
	if SERVER then
		Library.StartNet("Notify")
			net.WriteUInt(type, 3)
			net.WriteString(msg)
		net.Send(ply)
	elseif ply == LocalPlayer() then
		notification.AddLegacy(msg, type, 5)
	end
end

if CLIENT then
	Library.ReceiveNet("PrintTo", function(len, ply)
		MsgN( net.ReadString() )
	end)

	Library.ReceiveNet("Notify", function(len, ply)
		local ty, msg = net.ReadUInt(3), net.ReadString()
		Library.Notify(ty, msg)
	end)
end

-- Just in case..
_G.ExpressiveLoaded = true

Library.Extension = require("expressive/extension")

MsgN("ExpressiveLib Loaded!")

return Library