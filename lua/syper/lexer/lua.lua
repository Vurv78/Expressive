local TOKEN = Syper.TOKEN

return {
	main = {
		-- shebang
		{
			"(#![^\n]*)", TOKEN.Comment, shebang = true
		},
		-- whitespace
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		-- multiline comment
		{"(%-%-%[(=*)%[)", TOKEN.Comment, "mcomment"},
		-- multiline string
		{"(%[(=*)%[)", TOKEN.String, "mstring"},
		-- comment
		{"(%-%-[^\n]*)", TOKEN.Comment},
		-- string
		{"((\"))", TOKEN.String, "string"},
		{"(('))", TOKEN.String, "string"},
		-- number
		{"(0x%x+)", TOKEN.Number},
		{"(%d*%.%d*[%deE]%-?%d+)", TOKEN.Number},
		{"(%d+[%deE]%-?%d+)", TOKEN.Number},
		{"(%d+%.?%d*)", TOKEN.Number},
		{"(%.%d+)", TOKEN.Number},
		-- ... and self
		{"(%.%.%.)", TOKEN.Identifier_Modifier},
		{"(self)", TOKEN.Identifier_Modifier},
		-- operator
		{
			"([%+%-%*/%%^#=~<>]+)", TOKEN.Operator, list = {"+", "-", "*", "/", "%", "^", "#", "==", "~=", "<=", ">=", "<", ">", "="},
			list_nomatch = TOKEN.Error
		},
		{"(%.%.)", TOKEN.Operator},
		{
			"([%a_][%w_]*)", TOKEN.Operator, list = {"and", "or", "not"}
		},
		{"(::[%a_\128-\255][%w_\128-\255]*::)", TOKEN.Operator},
		-- keyword
		{
			"([%a_][%w_]*)", TOKEN.Keyword, list = {"break", "do", "else", "elseif", "end", "for", "if", "in", "local", "repeat", "return", "then", "until", "while", "goto"}
		},
		{
			"([%a_][%w_]*)", TOKEN.Keyword_Constant, list = {"true", "false", "nil", "_G"}
		},
		-- function
		{"(function)", TOKEN.Keyword_Modifier, "func"},
		-- function call
		{"([%a_\128-\255][%w_\128-\255]*)[%w_.]*%s*[%(%{\"']", TOKEN.Callable},
		-- identifier
		{"([%a_\128-\255][%w_\128-\255]*)", TOKEN.Identifier},
		-- other
		{"([%(%)%[%]{},%.])", TOKEN.Punctuation},
		{"(.)", TOKEN.Other},
	},
	mcomment = {
		{"(.*%]<CAP>%])", TOKEN.Comment, "main"},
		{"(.*\n)", TOKEN.Comment},
	},
	mstring = {
		{"(.*%]<CAP>%])", TOKEN.String, "main"},
		{"(.*\n)", TOKEN.String},
	},
	string = {
		{"(\\%d%d?%d?)", TOKEN.String_Escape},
		{"(\\%g)", TOKEN.String_Escape},
		{"(<CAP>)", TOKEN.String, "main"},
		{"(\\\n)", TOKEN.String_Escape},
		{"(\n)", TOKEN.Error, "main"},
		{"([^<CAP>\\\n]+)", TOKEN.String},
		{"(\\.?)", TOKEN.Error},
	},
	func = {
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		{"([%a_\128-\255]?[%w_\128-\255]*)[%s\n]*[%.:%(]", TOKEN.Function, "func_punc"},
		{"([^\n]+\n)", TOKEN.Error, "main"}
	},
	-- {"([%a_][%w_]*)%s*\n", TOKEN.Error, "main"}
	func_punc = {
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		{"([%.:])", TOKEN.Punctuation, "func"},
		{"(%()", TOKEN.Punctuation, "func_arg"},
	},
	func_arg = {
		{"(\n)", TOKEN.Whitespace},
		{"([^%S\n]+)", TOKEN.Whitespace},
		{"([%a_\128-\255][%w_\128-\255]*)", TOKEN.Argument},
		{"(%.%.%.)", TOKEN.Argument},
		{"(%))", TOKEN.Punctuation, "main"},
		{"(,)", TOKEN.Punctuation},
		{"([^%a_%)]+)", TOKEN.Error},
	}
}