local settings = ExpressiveEditor.Settings.settings
----------------------------------------
local Button = {}

function Button:Paint(w, h)
	surface.SetDrawColor((self.Depressed or self:IsSelected() or self:GetToggle()) and settings.style_data.ide_ui_accent or settings.style_data.ide_ui_dark)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(self:GetDisabled() and settings.style_data.gutter_foreground or (self.Hovered and settings.style_data.ide_ui_dark or settings.style_data.ide_ui_light))
	surface.DrawRect(1, 1, w - 2, h - 2)
	surface.SetTextColor(settings.style_data.ide_foreground)
	surface.SetFont(self:GetFont())
	local str = self:GetText()
	local tw, th = surface.GetTextSize(str)
	surface.SetTextPos((w - tw) / 2, (h - th) / 2)
	surface.DrawText(str)

	return true
end

vgui.Register("E4SyperButton", Button, "DButton")