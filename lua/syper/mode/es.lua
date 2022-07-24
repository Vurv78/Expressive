require("expressive/library"); local ELib = ELib

local TOKEN = Syper.TOKEN

local ignore = {"mcomment", "string"}

local env = {}

local KIND = {
	KEYWORD = 1,
	FUNCTION = 2,
	VARIABLE = 3,
	TYPE = 4,
	NAMESPACE = 5
}

local KIND_INV = ELib.GetInverted(KIND)

ELib.OnExtensionsReady(function(ctx)
	for k in pairs(ELib.Keywords) do
		env[k] = KIND.KEYWORD
	end

	for k, var in pairs(ctx.variables) do
		local params = string.match(var.type, "^function%((%w+)%)")
		if params then
			env[k .. "(" .. params .. ")"] = KIND.FUNCTION
		else
			env[k] = KIND.VARIABLE
		end
	end

	for k in pairs(ctx.types) do
		env[k] = KIND.TYPE
	end

	for k, mod in pairs(ctx.namespaces) do
		local tbl = {}
		for k2, var in pairs(mod.variables) do
			local params = string.match(var.type, "^function%((%w+)%)")
			if params then
				tbl[k2 .. "(" .. params .. ")"] = KIND.FUNCTION
			else
				tbl[k2] = KIND.VARIABLE
			end
		end
		env[k] = tbl
	end
end)

return {
	name = "Expressive",
	ext = {"es"},
	indent = {
		{"{", ignore},
		{"(", ignore},
	},
	outdent = {
		{"}", ignore},
		{")", ignore},
	},
	pair = {
		["{"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},
		["("] = {
			token = TOKEN.Punctuation,
			open = {"("}
		},
		["["] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},
	pair2 = {
		["elseif"] = {
			token = TOKEN.Keyword,
			open = {"function", "else"}
		},
		["else"] = {
			token = TOKEN.Keyword,
			open = {"function", "else"}
		},
		["end"] = {
			token = TOKEN.Keyword,
			open = {"function", "else"}
		},
		["}"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},
		[")"] = {
			token = TOKEN.Punctuation,
			open = {"("}
		},
		["]"] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},
	bracket = {
		["{"] = {"}", ignore},
		["("] = {")", ignore},
		["["] = {"]", ignore},
		["\""] = {
			"\"", ignore, {"\\"}
		},
	},
	comment = "// ",
	env = env,
	env_populator = function(_str) end,
	-- TODO: Most of this is taken from the lua mode. sevii is very cool
	autocomplete_stack = function(str)
		local e = #str
		local stack = {}

		for i = 1, 16 do
			local e2, s

			if i == 1 then
				e2, s = string.match(string.sub(str, 1, e), "()([%a_][%w_]*)$")

				if not e2 then
					e2, s = string.match(string.sub(str, 1, e), "[%.:]%s*()(_?)$")
				end
			else
				e2, s = string.match(string.sub(str, 1, e), "()([%a_][%w_]*)%s*[%.:]?%s*$")
			end

			if not e2 then
				e2, s = string.match(string.sub(str, 1, e), "()%[(%d*%.?x?%d*)%]%s*[%.:]?%s*$")

				if s then
					s = tonumber(s)
				end
			end

			if not e2 then
				e2, s = string.match(string.sub(str, 1, e), "()%[\"(.*)\"%]%s*[%.:]?%s*$")
			end

			if not e2 then
				e2, s = string.match(string.sub(str, 1, e), "()%['(.*)'%]%s*[%.:]?%s*$")
			end

			if not e2 then break end
			e = e2 - 1
			stack[#stack + 1] = s
		end

		if #stack > 0 then return table.Reverse(stack) end
	end,
	autocomplete = function(pre, key)
		local typ = type(key)
		if typ == "string" and string.match(string.sub(key, 1, 1), "[%a_]") then return key, 0 end
		local rem = #string.match(pre, "([^%.%[]*)$")
		if typ == "number" then return "[" .. tostring(key) .. "]", rem end

		return "[\"" .. tostring(key) .. "\"]", rem
	end,
	livevalue = function(value)
		return KIND_INV[value] or "namespace"
	end
}