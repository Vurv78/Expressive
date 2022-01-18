local PANEL = {}

-- FontAwesome 5 Icons
local Icons = {
	-- Exclamation Circle
	Error = utf8.char(tonumber("f06a", 16)),
	-- Exclamation Triangle
	Warning = utf8.char(tonumber("f071", 16)),
	-- Question Circle
	Notify = utf8.char(tonumber("f059", 16)),
}

function PANEL:Init()
	self.BaseClass.Init(self)
	self.settings = ExpressiveEditor.Settings.settings
	self.style = self.settings.style_data
	self.base_color = Color(255, 255, 255, 199)
	self.info_color = Color(81, 155, 204)
	self.warn_color = Color(200, 214, 69)
	self.err_color = Color(197, 72, 72)

	local bg = self.style.gutter_background
	self:SetBackgroundColor(Color(bg.r, bg.g, bg.b, bg.a))

	self.lines = {}
	self.nlines = 0
	local rich_text = self:Add("RichText")
	rich_text:Dock(FILL)

	rich_text.PerformLayout = function(this)
		this:SetFontInternal("Expressive.FontAwesome")
		this:SetFGColor(self.current_color)
	end

	self.text_entry = rich_text
end

function PANEL:Clear()
	self.text_entry:SetText("")
end

function PANEL:TryChangeColor(col)
	if self.current_color == col then return end
	self.text_entry:InsertColorChange(col.r, col.g, col.b, col.a)
	self.current_color = col
end

function PANEL:WriteLn(...)
	self.text_entry:AppendText(string.format(...) .. "\n")
end

function PANEL:InfoLn(...)
	self:TryChangeColor(self.info_color)
	self:WriteLn("%s %s", Icons.Notify, string.format(...))
end

function PANEL:WarnLn(...)
	self:TryChangeColor(self.warn_color)
	self:WriteLn("%s %s", Icons.Warning, string.format(...))
end

function PANEL:ErrorLn(...)
	self:TryChangeColor(self.err_color)
	self:WriteLn("%s %s", Icons.Error, string.format(...))
end

vgui.Register("E4Console", PANEL, "DPanel")