local TOKEN = Syper.TOKEN
TOKEN.Class = TOKEN.Class or 18 -- Yep

return {
	background        = {r = 40,  g = 44,  b = 52,  a = 255}, -- rgb(40, 44, 52)
	caret             = {r = 255,  g = 255,  b = 255,  a = 201}, -- rgba(255, 255, 255, 0.788)
	highlight         = {r = 103,  g = 118,  b = 150,  a = 96}, -- rgb(103, 118, 150) -- {r = 73,  g = 72,  b = 62,  a = 255}
	highlight2        = {r = 146, g = 144, b = 140, a = 255},
	gutter_background = {r = 33,  g = 37,  b = 43,  a = 255}, -- rgb(33, 37, 43)
	gutter_foreground = {r = 146, g = 144, b = 140, a = 255},
	fold_background   = {r = 225, g = 220, b = 50,  a = 255}, -- rgb(225, 220, 50)
	fold_foreground   = {r = 39,  g = 40,  b = 34,  a = 255},

	ide_ui            = {r = 47,  g = 52,  b = 63,  a = 255},
	ide_ui_dark       = {r = 40,  g = 44,  b = 52,  a = 255}, -- rgb(40, 44, 52)
	ide_ui_light      = {r = 52,  g = 57,  b = 68,  a = 255},
	ide_ui_accent     = {r = 255, g = 151, b = 31,  a = 255},
	ide_background    = {r = 40,  g = 44,  b = 52,  a = 255}, -- rgb(33, 37, 43)
	ide_foreground    = {r = 248, g = 248, b = 242, a = 255}, -- rgb(171, 178, 191)
	ide_disabled      = {r = 146, g = 144, b = 140, a = 255},

	[TOKEN.Identifier]               = {f = {r = 224, g = 108, b = 117, a = 255}},   -- rgb(224, 108, 117)
	[TOKEN.Other]                    = {f = {r = 248, g = 248, b = 242, a = 255}},   -- Unknown
	[TOKEN.Whitespace]               = {f = {r = 59, g = 64, b = 72,  a = 255}},     -- rgb(59, 64, 72)
	[TOKEN.Punctuation]              = {f = {r = 171, g = 178, b = 191, a = 255}},   -- rgb(171, 178, 191)
	[TOKEN.Error]                    = {f = {r = 194, g = 64, b = 56, a = 255}},     -- rgb(194, 64, 56)
	[TOKEN.Comment]                  = {f = {r = 127, g = 132, b = 142,  a = 255}},  -- rgb(127, 132, 142)
	[TOKEN.Keyword]                  = {f = {r = 198, g = 120, b = 221,  a = 255}},  -- rgb(198, 120, 221)
	[TOKEN.Keyword_Modifier]         = {f = {r = 198, g = 120, b = 221,  a = 255}},  -- rgb(198, 120, 221)
	[TOKEN.Class]                    = {f = {r = 230, g = 192, b = 128, a = 255}},   -- rgb(230, 192, 123)
	[TOKEN.Keyword_Constant]         = {f = {r = 209, b = 154, g =102, a = 255}},    -- rgb(209, 154, 102)
	[TOKEN.Operator]                 = {f = {r = 212, g = 212,  b = 212, a = 255}},  -- rgb(212, 212, 212)
	[TOKEN.Number]                   = {f = {r = 209, b = 154, g =102, a = 255}},    -- rgb(209, 154, 102)
	[TOKEN.String]                   = {f = {r = 152, g = 195, b = 121, a = 255}},   -- rgb(152, 195, 121)
	[TOKEN.String_Escape]            = {f = {r = 86, g = 182, b = 194, a = 255}},    -- rgb(86, 182, 194)
	[TOKEN.Callable]                 = {f = {r = 97, g = 175, b = 239, a = 255}},    -- rgb(97, 175, 239)
	[TOKEN.Function]                 = {f = {r = 97, g = 175, b = 239, a = 255}},    -- rgb(97, 175, 239)
	[TOKEN.Argument]                 = {f = {r = 224, g = 108, b = 117, a = 255}},   -- rgb(224, 108, 117)
	[TOKEN.Identifier_Modifier]      = {f = {r = 229, g = 192, b = 123, a = 255}},   -- rgb(229, 192, 123)
}