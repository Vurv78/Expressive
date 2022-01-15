local settings = ExpressiveEditor.Settings.settings
----------------------------------------
local HTML = {}

for k, v in pairs(vgui.GetControlTable("E4SyperBase")) do
	HTML[k] = HTML[k] or v
end

function HTML:Init()
	self.js = [[<script>
	                window.addEventListener("mousedown", function() {console.log("down")})
	                window.addEventListener("mouseup", function() {console.log("up")})
	            </script>]]
end

function HTML:ConsoleMessage(str)
	if str == "down" then
		self:OnMousePressed()
	elseif str == "up" then
		self:OnMouseReleased()
	end
end

function HTML:Paint(w, h)
	surface.SetDrawColor(settings.style_data.background)
	surface.DrawRect(0, 0, w, h)
end

function HTML:Think()
	if not self.holding then return end
	local x, y = self:LocalCursorPos()

	if math.sqrt((self.holding[1] - x) ^ 2 + (self.holding[2] - y) ^ 2) > 20 then
		self.holding = nil
		local parent = self:GetParent()

		while true do
			local p = parent:GetParent()
			if p.ClassName == "E4SyperTabHandler" then break end
			parent = p
		end

		local handler = self:FindTabHandler()
		self:SafeUnparent()
		parent:InvalidateLayout(true)

		timer.Simple(0, function()
			handler:ForceMovePanel(self)
		end)
	end
end

function HTML:OnMousePressed(key)
	if self:GetParent().ClassName == "E4SyperTabHandler" then return end

	self.holding = {self:LocalCursorPos()}
end

function HTML:OnMouseReleased(key)
	self.holding = nil
end

function HTML:ModPath(path)
	if string.sub(path, 1, 4) == "http" or string.sub(path, 1, 5) == "asset" then return path end

	return "asset://garrysmod/" .. path
end

function HTML:OpenImg(path)
	self.mode = 1
	self.path = self:ModPath(path)
	self:SetHTML([[<img src="]] .. self.path .. [[" style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);max-width:100%;max-height:100%">]] .. self.js)
end

-- wav seems to be unsupported
function HTML:OpenAudio(path)
	self.mode = 2
	self.path = self:ModPath(path)
	self:SetHTML([[<audio controls autoplay style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);max-width:100%;max-height:100%"><source src="]] .. path .. [["></audio>]] .. self.js)
end

-- doesn't seem to work, guess gmod chromium doesn't support the video codecs
function HTML:OpenVideo(path)
	self.mode = 3
	self.path = self:ModPath(path)
	self:SetHTML([[<video controls autoplay style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);max-width:100%;max-height:100%"><source src="]] .. path .. [["></video>]] .. self.js)
end

function HTML:GetSessionState()
	return {
		mode = self.mode,
		path = self.path
	}
end

function HTML:SetSessionState(state)
	if state.mode == 1 then
		self:OpenImg(state.path)
	elseif state.mode == 2 then
		self:OpenAudio(state.path)
	elseif state.mode == 3 then
		self:OpenVideo(state.path)
	end
end

vgui.Register("E4SyperHTML", HTML, "DHTML")