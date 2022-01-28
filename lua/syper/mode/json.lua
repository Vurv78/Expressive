local TOKEN = Syper.TOKEN
local ignore = {"string"}

return {
	name = "JSON",
	ext = {"json"},

	indent = {
		{"{", ignore},
		{"%[", ignore},
	},

	outdent = {
		{"}", ignore},
		{"%]", ignore},
	},

	pair = {
		["{"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},

		["["] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},

	pair2 = {
		["}"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},

		["]"] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},

	bracket = {
		["{"] = {"}", ignore},
		["["] = {"]", ignore},
		["\""] = {"\"", ignore, {"\\"}},
	},

	comment = "// ",
}