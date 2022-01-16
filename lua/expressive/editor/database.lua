﻿local ELib = require("expressive/library")

local function store_data(extensions)
	print("ES - Editor Info Loaded!")
	local out_data = ExpressiveEditor.HelperData

	for ext_name, data in pairs(extensions) do
		local enabled = data.enabled

		if enabled then
			local price = data.price
			local state = data.state
			local functions = data.functions
			local libraries = data.libraries

			for _, data in pairs(data.constants) do
				local lib, name, type, value, native, state = unpack(data)

				if not out_data.constants[lib] then
					out_data.constants[lib] = {}
				end

				out_data.constants[lib][name] = value
			end

			for sig, data in pairs(data.classes) do
				out_data.classes[data.name] = data
			end

			for sig, data in pairs(data.functions) do
				local name = data.name
				local extension = data.extension

				if not out_data.libraries[extension] then
					out_data.libraries[extension] = {}
					out_data.libraries_sig[extension] = {}
				end

				--data.full_sig = data.extension .. '.' .. data.signature
				out_data.libraries[extension][name] = data
				out_data.libraries_sig[extension][data.signature] = data
			end
		end
	end

	ExpressiveEditor.HelperData = out_data
end

local extensions = ELib.GetExtensions()

if extensions then
	store_data(extensions)
else
	hook.Add("Expression4.PostRegisterExtensions", "Expression4.EditorDB", function()
		store_data(ELib.GetExtensions())
	end)
end