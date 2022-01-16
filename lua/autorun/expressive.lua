local AddonRoot = ""
local _, addons = file.Find("addons/*", "GAME")

for _, addon in pairs(addons) do
	local head = "addons/" .. addon

	if file.Exists(head .. "/lua/autorun/expressive.lua", "GAME") then
		AddonRoot = head
		break
	end
end

if SERVER then
	AddCSLuaFile()

	local function addLuaFiles(path, recursive)
		local files, folders = file.Find(AddonRoot .. "/lua/" .. path .. "/*", "GAME")

		for _, file in pairs(files) do
			AddCSLuaFile(path .. '/' .. file)
		end

		if recursive then
			for _, folder in pairs(folders) do
				addLuaFiles(path .. '/' .. folder, recursive)
			end
		end
	end

	local function addResources(path, recursive)
		local files, folders = file.Find(AddonRoot .. '/' .. path .. "/*", "GAME")

		for _, file in pairs(files) do
			resource.AddSingleFile(path .. '/' .. file)
		end

		if recursive then
			for _, folder in pairs(folders) do
				addResources(path .. '/' .. folder, recursive)
			end
		end
	end

	addLuaFiles("expressive", true)
	addResources("materials", true)
	addResources("resource", true)
	addLuaFiles("includes", true)
end

-- Fix require() function to return values.
-- Because this 5 year old issue will never be fixed. https://github.com/Facepunch/garrysmod-requests/issues/445
require("fix_require")

local ELib = require("expressive/library")
--- TODO: Probably want to cut down on these for servers with a massive load of addons.
-- Or get a system to condense this into one single network string. Could be made into a tiny autorun library.

ELib.AddNetworkString("InitializedClient")
ELib.AddNetworkString("OpenEditor")

ELib.AddNetworkString("PrintTo")
ELib.AddNetworkString("Notify")

ELib.AddNetworkString("Processor.Used")
ELib.AddNetworkString("Processor.Kill")
ELib.AddNetworkString("Processor.ClientReady")
ELib.AddNetworkString("Processor.Errored")
ELib.AddNetworkString("Processor.Download")
ELib.AddNetworkString("Processor.Upload")

require("expressive/startup")