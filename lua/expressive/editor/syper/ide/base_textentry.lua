local TextEntry = {}

for k, v in pairs(vgui.GetControlTable("E4SyperBase")) do
	TextEntry[k] = TextEntry[k] or v
end

vgui.Register("E4SyperBaseTextEntry", TextEntry, "TextEntry")