function ExpressiveEditor.jsonToTable(json)
	local ct = ExpressiveEditor.Lexer.createContentTable(ExpressiveEditor.Lexer.lexers["json"], ExpressiveEditor.Mode.modes["json"], {
		tab_size = 0,
		utf8 = true,
		show_control_characters = false
	})

	local y, p = 1, 1

	while true do
		local s = string.find(json, "\n", p)
		ct:ModifyLine(y, string.sub(json, p, s))
		if not s then break end
		p = s + 1
		y = y + 1
	end

	ct:RebuildLines(1, y)
	ct:RebuildTokenPairs()
	-- TODO: just make it fully custom
	local json = ""

	for y = 1, ct:GetLineCount() do
		local tokens = ct:GetLineTokens(y)

		for i, token in pairs(tokens) do
			if token.token == ExpressiveEditor.TOKEN.Error then
				return false
			elseif token.token ~= ExpressiveEditor.TOKEN.Comment then
				json = json .. token.str
			end
		end
	end

	return util.JSONToTable(json)
end

function ExpressiveEditor.fetchGitHubPaths(url, callback)
	http.Fetch(url, function(content)
		local files, dirs = {}, {}

		for pos, typ in string.gmatch(content, [[<svg aria%-label="()([^"]+)" aria%-hidden="true"]]) do
			local pos, name = string.match(content, [[<a class="js%-navigation%-open Link%-%-primary" title="()([^"]+)" data%-pjax="#repo%-content%-pjax%-container"]], pos)

			if name == "This path skips through empty directories" then
				name = string.match(content, [[<span class="color%-text%-tertiary">([^<]+)</span>([^<]+)]], pos)
				-- name = name .. v
			end

			local tbl = typ == "Directory" and dirs or files
			tbl[#tbl + 1] = string.match(name, "[^/]+")
		end

		callback(files, dirs)
	end)
end

function ExpressiveEditor.getGitHubRaw(url)
	local author_repo, path = string.match(url, "github%.com/([^/]+/[^/]+)/tree/master/(.+)")

	return "https://raw.githubusercontent.com/" .. author_repo .. "/master/" .. path
end

function ExpressiveEditor.fetchGitHubFile(url, callback)
	http.Fetch(ExpressiveEditor.getGitHubRaw(url), function(content)
		callback(content)
	end)
end

function ExpressiveEditor.fileFindCallback(path, root_path, callback)
	callback(file.Find(path, root_path))
end

local names = {"CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"}

local exts = {"txt", "jpg", "png", "vtf", "dat", "json", "vmt"}

-- TODO: dont do this, just have it pre in the table, to lazy atm
for _, v in ipairs(names) do
	names[v] = true
end

for _, v in ipairs(exts) do
	exts[v] = true
end

function ExpressiveEditor.getExtension(path)
	return string.match(path, "%.([^%.]*)$") or ""
end

function ExpressiveEditor.validFileName(name)
	if #name == 0 then return false end
	if string.find(name, "[<>:\"/\\|%?%*]") then return false end
	-- if string.find(name, "[\x00-\x1F]") then return false end
	if system.IsWindows() and names[string.upper(string.match(name, "^([^%.]*)"))] then return false end
	if not exts[ExpressiveEditor.getExtension(name)] then return false end

	return true
end

function ExpressiveEditor.validPath(path)
	if string.find(path, "[<>:\"\\|%?%*]") then return false end
	-- if string.find(path, "[\x00-\x1F]") then return false end
	if system.IsWindows() and names[string.upper(string.match(string.match(path, "([^/]*)$"), "^([^%.]*)"))] then return false end
	if not exts[ExpressiveEditor.getExtension(path)] then return false end

	return true
end

local ext_overrides = {}

function ExpressiveEditor.SyntaxFromPath(path)
	local s = string.Split(path, "/")
	local ext = string.match(s[#s], "([^%.]+)$")

	for p, v in pairs(ext_overrides) do
		if string.sub(path, 1, #p) == p and (not ext or ext == v[1]) then return v[2] end
	end

	for mode, exts in pairs(ExpressiveEditor.Mode.modes) do
		for e, _ in pairs(exts.ext) do
			if ext == e then return mode end
		end
	end

	return "text"
end

function ExpressiveEditor.SyntaxExtensionPathOverride(path, ext, syntax)
	ext_overrides[path] = {ext, syntax}
end

function ExpressiveEditor.HandleStringEscapes(str)
	local tbl = {
		["%f[\\]\\a"] = "\a",
		["%f[\\]\\b"] = "\b",
		["%f[\\]\\f"] = "\f",
		["%f[\\]\\n"] = "\n",
		["%f[\\]\\r"] = "\r",
		["%f[\\]\\t"] = "\t",
		["%f[\\]\\v"] = "\v"
	}

	for p, c in pairs(tbl) do
		str = string.gsub(str, p, c)
	end

	return str
end

ExpressiveEditor.SyntaxExtensionPathOverride("starfall/", "txt", "lua")
ExpressiveEditor.SyntaxExtensionPathOverride("expressive/", "txt", "es")