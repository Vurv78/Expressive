local TOKEN = Syper.TOKEN
TOKEN.Class = TOKEN.Class or 18 -- Yep

local VS_Control_Light = { f = { r = 156, g = 220, b = 254, a = 255 } } -- vars/params light blue
local VS_Control = { f = { r = 86, g = 156, b = 214, a = 255 } } -- self/... dark blue

local VS_FunctionName = { f = { r = 220, g = 220, b = 170, a = 255 } } -- yellow
local VS_Keyword = { f = {r = 197, g = 134, b = 192, a = 255} } -- purple

return {
	-- Defaults from monokai besides the background.
	background        = {r = 30,  g = 30,  b = 30,  a = 255},
	caret             = {r = 248, g = 248, b = 242, a = 255},
	highlight         = {r = 73,  g = 72,  b = 62,  a = 255},
	highlight2        = {r = 146, g = 144, b = 140, a = 255},
	gutter_background = {r = 36,  g = 36,  b = 31,  a = 255},
	gutter_foreground = {r = 146, g = 144, b = 140, a = 255},
	fold_background   = {r = 225, g = 220, b = 50,  a = 255},
	fold_foreground   = {r = 39,  g = 40,  b = 34,  a = 255},

	ide_ui            = {r = 47,  g = 52,  b = 63,  a = 255},
	ide_ui_dark       = {r = 37,  g = 42,  b = 53,  a = 255},
	ide_ui_light      = {r = 52,  g = 57,  b = 68,  a = 255},
	ide_ui_accent     = {r = 255, g = 151, b = 31,  a = 255},
	ide_background    = {r = 25,  g = 25,  b = 21,  a = 255},
	ide_foreground    = {r = 248, g = 248, b = 242, a = 255},
	ide_disabled      = {r = 146, g = 144, b = 140, a = 255},

	[TOKEN.Identifier]          = VS_Control_Light, -- vars
	[TOKEN.Other]                    = {f = {r = 248, g = 248, b = 242, a = 255}}, -- Unknown
	[TOKEN.Whitespace]               = {f = {r = 106, g = 153, b = 85,  a = 255}},
	[TOKEN.Punctuation]              = {f = {r = 248, g = 248, b = 242, a = 255}},
	[TOKEN.Error]                    = {f = {r = 244, g = 71, b = 61, a = 255}}, -- Bad syntax
	[TOKEN.Comment]                  = {f = {r = 106, g = 153, b = 85,  a = 255}},
	[TOKEN.Keyword]             = VS_Keyword, -- end, while
	[TOKEN.Keyword_Modifier]    = VS_Keyword, -- "function"
	[TOKEN.Class or -1]              = {f = {r = 78, g = 201, b = 176, a = 255}}, -- class name and reference
	[TOKEN.Keyword_Constant]    = VS_Control_Light, -- _G, true false nil
	[TOKEN.Operator]                 = {f = {r = 212, g = 212,  b = 212, a = 255}},
	[TOKEN.Number]                   = {f = {r = 181, g = 206, b = 168, a = 255}},
	[TOKEN.String]                   = {f = {r = 206, g = 145, b = 120, a = 255}},
	[TOKEN.String_Escape]            = {f = {r = 215, g = 186, b = 125, a = 255}},
	[TOKEN.Callable]            = VS_FunctionName, -- <name>()
	[TOKEN.Function]            = VS_FunctionName, -- function <name>()
	[TOKEN.Argument]            = VS_Control_Light,	-- (a, b, c)
	[TOKEN.Identifier_Modifier] = VS_Control, -- self or ...
}