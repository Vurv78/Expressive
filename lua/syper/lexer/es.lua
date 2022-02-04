﻿local ELib = require("expressive/library")

local TOKEN = Syper.TOKEN
-- Const data
local CLASSES = {"int", "double", "string", "boolean", "void"} -- Base types for now
local LIBRARIES
local OPERATORS
local KEYWORDS

if ExpressiveEditor then
	-- CLASSES = table.GetKeys(ExpressiveEditor.HelperData.classes)
	LIBRARIES = table.GetKeys(ExpressiveEditor.HelperData.libraries)
	OPERATORS = table.GetKeys(ELib.Operators)
	KEYWORDS = table.GetKeys(ELib.Keywords)
else
	-- Some other addon's syper is trying to load this, just give generic info because ES isn't loaded yet.
	CLASSES = {}
	LIBRARIES = {}
	OPERATORS = {}
	KEYWORDS = {}
end

return {
	main = {
		-- whitespace
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		-- multiline comment
		{"(/%*)", TOKEN.Comment, "mcomment"},
		-- comment
		{"(//[^\n]*)", TOKEN.Comment},
		-- string
		{"(\")", TOKEN.String, "string"},
		-- number
		{"(0x%x+)", TOKEN.Number},
		{"(%d*%.%d*[%deE]%-?%d+)", TOKEN.Number},
		{"(%d+[%deE]%-?%d+)", TOKEN.Number},
		{"(%d+%.?%d*)", TOKEN.Number},
		{"(%.%d+)", TOKEN.Number},
		-- ... and self
		{"(%.%.%.)", TOKEN.Identifier_Modifier},
		{"(self)", TOKEN.Identifier_Modifier},
		-- directive, usually followed by string
		{"(@%w+)", TOKEN.Identifier_Modifier},
		-- literal keyword
		{
			"(%w+)", TOKEN.Identifier_Modifier, list = {"true", "false", "null"}
		},
		-- function
		{"(function)", TOKEN.Keyword_Modifier, "func"},
		-- class definition
		{"(class)", TOKEN.Keyword_Modifier, "class"},
		-- class
		{
			"([%a_][%w_]*)", TOKEN.Class, list = CLASSES
		},
		-- library
		{
			"([%a_][%w_]*)", TOKEN.Identifier_Modifier, list = LIBRARIES
		},
		-- keyword
		{
			"([%a_][%w_]*)", TOKEN.Keyword, list = KEYWORDS
		},
		-- function call
		{"([%a_\128-\255][%w_\128-\255]*)[%w_.]*%s*[%(%{\"']", TOKEN.Callable},
		-- identifier
		{"([%a_\128-\255][%w_\128-\255]*)", TOKEN.Identifier},
		-- operators
		{
			"([" .. string.PatternSafe("<>-+/*^&@|%?,;$#~.") .. "]+)", TOKEN.Operator, list = OPERATORS,
			list_nomatch = TOKEN.Error
		},
		-- other
		{"([%(%)%[%]{},%.:])", TOKEN.Punctuation},
		{"(.)", TOKEN.Other},
	},
	mcomment = {
		{"(.*%*/)", TOKEN.Comment, "main"},
		{"(.*\n)", TOKEN.Comment},
	},
	string = {
		{"(\\[\"\\/bfnrt])", TOKEN.String_Escape},
		{"(\\u%x%x%x%x)", TOKEN.String_Escape},
		{"(\")", TOKEN.String, "main"},
		{"(\n)", TOKEN.Error, "main"},
		{"([^\"\\\n]+)", TOKEN.String},
		{"(\\.?)", TOKEN.Error},
	},
	--[[
		function void main()
	]]
	func = {
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		{"(%a%w*)", TOKEN.Identifier, "func_arg"}, -- Function name
		{"(%()", TOKEN.Punctuation, "func_arg"}, -- This is a lambda, skip name.
		{"([^\n]+\n)", TOKEN.Error, "main"},
	},
	-- {"([%a_][%w_]*)%s*\n", TOKEN.Error, "main"}
	func_name = {
		{"([%s\n]+)", TOKEN.Whitespace},
		{"(%w+)", TOKEN.Function}, -- Name
		{"([^%()])", TOKEN.Punctuation, "main"},
		{"(%()", TOKEN.Punctuation, "func_arg"}
	},
	func_arg = {
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		{"([%a_][%w_]*)", TOKEN.Class, list = CLASSES},
		{"([%a_\128-\255][%w_\128-\255]*)", TOKEN.Argument},
		{"(%))", TOKEN.Punctuation, "main"},
		{"([:,])", TOKEN.Punctuation},
		{"([^%a_%)]+)", TOKEN.Error}
	},
	class = {
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		{"(%a%w*)", TOKEN.Class, "main"}, -- Class name
		{"([^\n]+\n)", TOKEN.Error, "main"}
	}
}