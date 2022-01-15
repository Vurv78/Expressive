local ELib = require("expressive/library")

local Editor = {
	LastContent = "", -- Hack to get the content of last interacted editor.
	HelperData = {
		libraries = {}, -- table<string, table<string, table>>
		libraries_sig = {}, -- table<string, table<string, table>> @ Same as libraries but using full sig instead of fn name
		classes = {}, -- table<string, table>
		constants = {}
	}
}

surface.CreateFont("FontAwesome", {
	font = "Font Awesome 6 Free Regular", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
	extended = true,
	size = 15,
	weight = 500,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

if not file.Exists("expressive", "DATA") then
	file.CreateDir("expressive")
end

function Editor.Init()
	Editor.Reload()
end

function Editor.Reload()
	include("expressive/editor.lua")
end

function Editor.Create()
	local ide = vgui.Create("E4SyperIDE")
	ide:SetDeleteOnClose(false)
	ide:SetText("Expressive Editor")
	ide:SetIcon("icon16/application_side_list.png")
	ide:Center()
	ide:MakePopup()
	Editor.IDE = ide
	Editor.Settings.loadSession(ide)
	local has_es_folder = false

	for i, node in ipairs(ide.filetree.folders) do
		if node.path == "expressive/" and node.root_path == "DATA" then
			has_es_folder = true
			break
		end
	end

	if not has_es_folder then
		ide.filetree:AddDirectory("expressive")
		ide.filetree:InvalidateLayout()
	end

	hook.Run("Expression4.EditorInit")

	return ide
end

function Editor.Get()
	return Editor.IDE or Editor.Create()
end

---@param path string? Optional file to open to.
---@param lang string? Language to intialize the editor with. By default scans from the directory.
function Editor.Open(path, lang)
	local ide = Editor.Get()
	ide:Show()

	if path then
		local editor = ide:Add("E4SyperEditor")
		editor:SetSyntax(lang or Editor.SyntaxFromPath(path))
		editor:SetPath(path)
		editor:ReloadFile()
		ide:AddTab(string.match(path, "([^/]*)$"), editor)
	end
end

function Editor.GetCode()
	if Editor.IDE then
		local handler = Editor.IDE:GetActiveTabHandler()
		local activepanel = handler:GetActivePanel()
		if activepanel and activepanel.panel.GetContentStr then return activepanel.panel:GetContentStr() end

		return Editor.LastContent
	end
end

-- Todo
function Editor.GetDirective()
end

function Editor.Validate(code)
	if Editor.IDE then
		Editor.IDE:Validate(false, code)
	end
end

ELib.ReceiveNet("OpenEditor", function()
	local entity

	if net.ReadBool() then
		entity = net.ReadEntity()
	end

	Editor.Open()

	if IsValid(entity) and entity.script then
		local ide = Editor.IDE
		local editor = ide:Add("E4SyperEditor")
		editor:SetSyntax("es")
		editor:SetName("Expressive Editor")
		editor:SetPath(path)
		editor:ReloadFile()
		ide:AddTab(entity:GetScriptName() or "generic", editor)
	end
end)

_G.ExpressiveEditor = Editor

include("expressive/editor/syper/syper.lua")

return Editor