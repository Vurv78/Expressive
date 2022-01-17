return [=[{
	// IDE stuff
	"ctrl+s": {"act": "save"},
	"ctrl+shift+s": {"act": "save", "args": [true]},

	"ctrl+g": {"act": "command_overlay", "args": [":"]},
	"ctrl+f": {"act": "find"},
	"ctrl+h": {"act": "replace"},
	// Same effect as clicking validate bar
	"ctrl+space": {"act": "validate"},

	"ctrl+pageup": {"act": "focus", "args": ["prev"]},
	"ctrl+pagedown": {"act": "focus", "args": ["next"]},
	"alt+1": {"act": "focus", "args": ["tab", 1]},
	"alt+2": {"act": "focus", "args": ["tab", 2]},
	"alt+3": {"act": "focus", "args": ["tab", 3]},
	"alt+4": {"act": "focus", "args": ["tab", 4]},
	"alt+5": {"act": "focus", "args": ["tab", 5]},
	"alt+6": {"act": "focus", "args": ["tab", 6]},
	"alt+7": {"act": "focus", "args": ["tab", 7]},
	"alt+8": {"act": "focus", "args": ["tab", 8]},
	"alt+9": {"act": "focus", "args": ["tab", 9]},
	"alt+0": {"act": "focus", "args": ["tab", 10]},

	// Editor
	"ctrl+z": {"act": "undo"},
	"ctrl+y": {"act": "redo"},
	"ctrl+shift+z": {"act": "redo"},

	"ctrl+c": {"act": "copy"},
	"ctrl+x": {"act": "cut"},
	"ctrl+v": {"act": "paste"}, // This is just a dummy, cant be changed
	"ctrl+shift+v": {"act": "pasteindent"}, // Partly a dummy, only does the indenting

	"enter": {"act": "newline"},
	"tab": {"act": "indent"},
	"shift+tab": {"act": "outdent"},
	"ctrl+shift+tab": {"act": "reindent_file"},
	"ctrl+/": {"act": "comment"},
	"ctrl+a": {"act": "selectall"},

	"insert": {"act": "toggle_insert"},
	"mouse_1": {"act": "setcaret"},
	"ctrl+mouse_1": {"act": "setcaret", "args": [true]},

	"mouse_2": {"act": "contextmenu"},
	"contextmenu": {"act": "contextmenu", "args": [true]},

	"backspace": {"act": "delete", "args": ["char", -1]},
	"delete": {"act": "delete", "args": ["char", 1]},
	"ctrl+backspace": {"act": "delete", "args": ["word", -1]},
	"ctrl+delete": {"act": "delete", "args": ["word", 1]},

	"left": {"act": "move", "args": ["char", -1]},
	"right": {"act": "move", "args": ["char", 1]},
	"shift+left": {"act": "move", "args": ["char", -1, true]},
	"shift+right": {"act": "move", "args": ["char", 1, true]},
	"ctrl+left": {"act": "move", "args": ["word", -1]},
	"ctrl+right": {"act": "move", "args": ["word", 1]},
	"ctrl+shift+left": {"act": "move", "args": ["word", -1, true]},
	"ctrl+shift+right": {"act": "move", "args": ["word", 1, true]},

	"up": {"act": "move", "args": ["line", -1]},
	"down": {"act": "move", "args": ["line", 1]},
	"shift+up": {"act": "move", "args": ["line", -1, true]},
	"shift+down": {"act": "move", "args": ["line", 1, true]},
	"ctrl+up": {"act": "move", "args": ["line", -1]},
	"ctrl+down": {"act": "move", "args": ["line", 1]},
	"ctrl+shift+up": {"act": "move", "args": ["line", -1, true]},
	"ctrl+shift+down": {"act": "move", "args": ["line", 1, true]},

	"pageup": {"act": "move", "args": ["page", -1]},
	"pagedown": {"act": "move", "args": ["page", 1]},
	"shift+pageup": {"act": "move", "args": ["page", -1, true]},
	"shift+pagedown": {"act": "move", "args": ["page", 1, true]},

	"home": {"act": "move", "args": ["bol"]},
	"end": {"act": "move", "args": ["eol"]},
	"shift+home": {"act": "move", "args": ["bol", false, true]},
	"shift+end": {"act": "move", "args": ["eol", false, true]},
	"ctrl+home": {"act": "move", "args": ["bof"]},
	"ctrl+end": {"act": "move", "args": ["eof"]},
	"ctrl+shift+home": {"act": "move", "args": ["bof", false, true]},
	"ctrl+shift+end": {"act": "move", "args": ["eof", false, true]},

	"ctrl+shift+1": {"act": "fold_level", "args": [1]},
	"ctrl+shift+2": {"act": "fold_level", "args": [2]},
	"ctrl+shift+3": {"act": "fold_level", "args": [3]},
	"ctrl+shift+4": {"act": "fold_level", "args": [4]},
	"ctrl+shift+5": {"act": "fold_level", "args": [5]},
	"ctrl+shift+6": {"act": "fold_level", "args": [6]},
	"ctrl+shift+7": {"act": "fold_level", "args": [7]},
	"ctrl+shift+8": {"act": "fold_level", "args": [8]},
	"ctrl+shift+9": {"act": "fold_level", "args": [9]},
	"ctrl+shift+0": {"act": "unfold_all"}
}]=]