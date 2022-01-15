local settings = ExpressiveEditor.Settings.settings

----------------------------------------
function ExpressiveEditor.Menu(keep_open, parent)
	if not keep_open then
		CloseDermaMenus()
	end

	return vgui.Create("E4SyperMenu", parent)
end

local Menu = {}

function Menu:Paint(w, h)
	surface.SetDrawColor(settings.style_data.gutter_background)
	surface.DrawRect(0, 0, w, h)

	return true
end

function Menu:AddOption(...)
	local pnl = vgui.GetControlTable("DMenu").AddOption(self, ...)

	pnl.Paint = function(s, w, h)
		if s.Hovered then
			surface.SetDrawColor(settings.style_data.gutter_foreground)
			surface.DrawRect(2, 2, w - 4, h - 4)
			surface.SetTextColor(settings.style_data.ide_foreground)
		else
			surface.SetTextColor(settings.style_data.gutter_foreground)
		end

		surface.SetFont("syper_ide")
		local str = s:GetText()
		local tw, th = surface.GetTextSize(str)
		surface.SetTextPos((h - th) / 2, (h - th) / 2)
		surface.DrawText(str)

		return true
	end

	return pnl
end

vgui.Register("E4SyperMenu", Menu, "DMenu")