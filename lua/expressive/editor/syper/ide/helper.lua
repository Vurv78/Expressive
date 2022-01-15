local PANEL = {}

function PANEL:Init()
	self.BaseClass.Init(self)
	self.settings = ExpressiveEditor.Settings.settings
	self.style = self.settings.style_data
	local frame = self:Add("DFrame")
	frame:Center()
	frame:SetSizable(true)
	frame:SetScreenLock(true)
	frame:SetDeleteOnClose(false)
	frame:SetSize(2000, 1000)
	frame:SetTitle("E4Helper")
	frame:SetVisible(true)
	--frame:SetPos( ScrW() / 2, ScrH() / 2 )
	self.frame = frame
	--[[local list = frame:Add("DListView")
	list:AddColumn("Function")
	list:AddColumn("Args")

	local desc = frame:Add("DTextEntry")
	desc:SetEditable(false)
	desc:SetMultiline(true)

	self.description_box = desc]]
end

vgui.Register("E4Helper", PANEL, "DPanel")