local settings = ExpressiveEditor.Settings.settings
local FT = ExpressiveEditor.FILETYPE

----------------------------------------
local icons = {
	[FT.Generic] = Material("materials/syper/fa-file-alt.png", "noclamp smooth"),
	[FT.Audio] = Material("materials/syper/fa-file-audio.png", "noclamp smooth"),
	[FT.Code] = Material("materials/syper/fa-file-code.png", "noclamp smooth"),
	[FT.Image] = Material("materials/syper/fa-file-image.png", "noclamp smooth"),
	[FT.Video] = Material("materials/syper/fa-file-video.png", "noclamp smooth"),
}

local folder = Material("materials/syper/fa-folder.png", "noclamp smooth")
local folder_open = Material("materials/syper/fa-folder-open.png", "noclamp smooth")
local linefold_down = Material("materials/syper/fa-caret-down.png", "noclamp smooth")
local linefold_right = Material("materials/syper/fa-caret-right.png", "noclamp smooth")
----------------------------------------
local Node = {}

function Node:Init()
	self.nodes = {}
	self.name = ""
	self.offset_x = 0
end

function Node:Setup(tree, name, is_folder, parent)
	self.tree = tree
	self.name = name
	self.parent = parent

	if is_folder then
		self.is_folder = true
		self.expanded = false
	else
		self.is_folder = false
		self.ext = string.match(name, "%.([^%.]+)$")
	end
end

function Node:Paint(w, h)
	if self.selected then
		surface.SetDrawColor(settings.style_data.gutter_foreground)
		surface.DrawRect(0, 0, w, h)
	end

	local clr = self.selected and settings.style_data.ide_foreground or settings.style_data.ide_disabled
	surface.SetDrawColor(clr)

	if self.is_folder then
		surface.SetMaterial(self.expanded and linefold_down or linefold_right)
		surface.DrawTexturedRect(self.offset_x + 4, 4, h - 8, h - 8)
	end

	local icon = self.icon

	if not icon and self.is_folder then
		icon = self.expanded and folder_open or folder
	end

	if icon then
		surface.SetMaterial(icon)
		surface.DrawTexturedRect(self.offset_x + h - 2, 4, h - 8, h - 8)
	end

	surface.SetTextColor(clr)
	surface.SetFont(self.tree.font)
	local tw, th = surface.GetTextSize(self.name)
	surface.SetTextPos(self.offset_x + h * 2 - 6, (h - th) / 2)
	surface.DrawText(self.name)
end

function Node:OnRemove()
	if not self.tree.nodes_lookup then return end
	self.tree.nodes_lookup[self.root_path][self.path] = nil
	self.tree.selected[self] = nil

	for i, node in ipairs(self.nodes) do
		node:Remove()
	end
end

function Node:OnMousePressed(key)
	if input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) then
		self.tree:Select(self)
	elseif key == MOUSE_RIGHT and not self.selected then
		self.tree:Select(self, true)
	elseif key == MOUSE_LEFT then
		if not self.is_folder then
			self.tree:Select(self, true)

			if self.tree.OnNodePress then
				self.tree:OnNodePress(self)
			end
		else
			self.expanded = not self.expanded
			self.tree:InvalidateLayout()
		end
	end

	if key == MOUSE_RIGHT then
		local menu = ExpressiveEditor.Menu()

		if self.root_path == "DATA" then
			if self.is_folder then
				menu:AddOption("New File", function()
					local ide = self.tree:FindIDE()
					local editor = ide:Add("E4SyperEditor")
					editor:SetSyntax(ExpressiveEditor.SyntaxFromPath(self.path))
					editor:SetContent("")
					editor:SetPath(self.path, "DATA")
					ide:AddTab("untitled", editor)
				end)

				menu:AddOption("New Folder", function()
					self.tree:FindIDE():TextEntry("New Folder", "", function(text)
						file.CreateDir(self.path .. text)
						self:Refresh()
					end, function(text) return #text > 0 and not file.Exists(self.path .. text, "DATA") end)
				end)
			end

			menu:AddOption("Rename", function()
				self.tree:FindIDE():Rename(self.path)
			end)

			menu:AddOption("Delete", function()
				local paths = {}

				for node, _ in pairs(self.tree.selected) do
					if node.root_path == "DATA" then
						paths[#paths + 1] = node.path
					end
				end

				self.tree:FindIDE():Delete(paths)
			end)
		end

		if self.main_directory then
			menu:AddOption("Refresh", function()
				self:Refresh(true)
			end)

			menu:AddOption("Remove From Project", function()
				self.tree:RemoveDirectory(self.path, self.root_path)
			end)
		end

		menu:Open()
	end
end

function Node:AddNode(name, is_folder)
	if not self.is_folder then return end
	local node = self.tree.content:Add("E4SyperTreeNode")
	node:Setup(self.tree, name, is_folder, self)
	self.nodes[#self.nodes + 1] = node

	return node
end

function Node:AddDirectory()
	if not self.is_folder then return end
	local path = string.sub(self.path, -1, -1) == "/" and self.path or self.path .. "/"

	local nodes = function(files, dirs)
		if not self.AddNode then return end

		for _, dir in ipairs(dirs) do
			local n = self:AddNode(dir, true)
			n:SetPath(path .. dir, self.root_path)
			n:AddDirectory()
		end

		for _, file in ipairs(files) do
			local n = self:AddNode(file, false)
			n:SetPath(path .. file, self.root_path)
			n:GuessIcon()
		end

		self.tree:InvalidateLayout()
	end

	if self.root_path == "GITHUB" then
		ExpressiveEditor.fetchGitHubPaths(path, nodes)
	else
		ExpressiveEditor.fileFindCallback(path .. "*", self.root_path, nodes)
	end
end

function Node:Refresh(recursive)
	if not self.is_folder then return end
	local path = string.sub(self.path, -1, -1) == "/" and self.path or self.path .. "/"

	local nodes = function(files, dirs)
		local names = {}

		for _, n in ipairs(files) do
			names[n] = 1
		end

		for _, n in ipairs(dirs) do
			names[n] = 2
		end

		for i = #self.nodes, 1, -1 do
			local node = self.nodes[i]

			if names[node.name] then
				names[node.name] = nil

				if recursive and node.is_folder then
					node:Refresh(true)
				end
			else
				node:Remove()
				table.remove(self.nodes, i)
				self.tree:InvalidateLayout()
			end
		end

		local reorder = false

		for name, typ in pairs(names) do
			if typ == 1 then
				local node = self:AddNode(name, false)
				node:SetPath(self.path .. name, self.root_path)
				node:GuessIcon()
				reorder = true
				self.tree:InvalidateLayout()
			else
				local node = self:AddNode(name, true)
				node:SetPath(self.path .. name .. "/", self.root_path)
				node:AddDirectory()
				reorder = true
				self.tree:InvalidateLayout()
			end
		end

		if reorder then
			self:ReorderChildren()
		end
	end

	if self.root_path == "GITHUB" then
		ExpressiveEditor.fetchGitHubPaths(path, nodes)
	else
		ExpressiveEditor.fileFindCallback(path .. "*", self.root_path, nodes)
	end
end

function Node:ReorderChildren()
	table.sort(self.nodes, function(a, b)
		local function dostr(a, b)
			for i = 1, math.min(#a, #b) do
				local ab, bb = string.byte(string.sub(a, i, i)), string.byte(string.sub(b, i, i))
				if ab < bb then return true end
				if bb < ab then return false end
			end

			return #a < #b
		end

		if a.is_folder then
			if b.is_folder then return dostr(a.name, b.name) end

			return true
		elseif b.is_folder then
			return false
		end

		return dostr(a.name, b.name)
	end)
end

function Node:SetPath(path, root_path)
	self.path = path
	self.root_path = root_path or "DATA"
	self.tree.nodes_lookup[self.root_path] = self.tree.nodes_lookup[self.root_path] or {}
	self.tree.nodes_lookup[self.root_path][self.path] = self
	self:MarkModified()
end

function Node:MarkModified()
	self.last_modified = file.Time(self.path, self.root_path)
end

function Node:GetExternalModified()
	local time = file.Time(self.path, self.root_path)

	if time ~= self.last_modified then
		self:MarkModified()

		return true
	end

	return false
end

function Node:GuessIcon()
	if self.ext then
		self.icon = icons[ExpressiveEditor.FILEEXTTYPE[self.ext]] or icons[FT.Generic]
	else
		self.icon = icons[FT.Generic]
	end
end

function Node:SetIcon(icon)
	self.icon = icons[icon] or icon
end

function Node:Expand(state)
	if not self.is_folder then return end

	if self.expanded ~= state then
		self.expanded = state
		self.tree:InvalidateLayout()
	end
end

vgui.Register("E4SyperTreeNode", Node, "Panel")

----------------------------------------
local Tree = {
	SyperFocusable = false
}

function Tree:Init()
	self.folders = {}
	self.selected = {}
	self.nodes_lookup = {}
	self.autorefresh = true
	self.node_size = 20
	self.last_system_focus = system.HasFocus()
	self.font = "syper_ide"
	self.scrolltarget = 0
	self.scrollbar = self:Add("DVScrollBar")
	self.scrollbar:Dock(RIGHT)
	self.scrollbar:SetWide(12)
	self.scrollbar:SetHideButtons(true)

	self.scrollbar.OnMouseWheeled = function(_, delta)
		self:OnMouseWheeled(delta, false)

		return true
	end

	self.scrollbar.OnMousePressed = function()
		local y = select(2, self.scrollbar:CursorPos())
		self:DoScroll((y > self.scrollbar.btnGrip.y and 1 or -1) * self.content_dock:GetTall())
	end

	self.scrollbar.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, settings.style_data.highlight)
	end

	self.scrollbar.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, settings.style_data.gutter_foreground)
	end

	self.content_dock = self:Add("Panel")
	self.content_dock:Dock(FILL)
	self.content = self.content_dock:Add("Panel")
end

function Tree:Paint(w, h)
	surface.SetDrawColor(settings.style_data.ide_background)
	surface.DrawRect(0, 0, w, h)
end

function Tree:Think()
	local focus = system.HasFocus()

	if self.autorefresh and focus and focus ~= self.last_system_focus then
		self:Refresh(nil, nil, true)
	end

	self.last_system_focus = focus
end

function Tree:PerformLayout(w, h)
	-- nodes
	local offset_y = 0

	local function disableNode(node)
		node:SetVisible(false)

		if node.is_folder then
			for _, node in ipairs(node.nodes) do
				disableNode(node)
			end
		end
	end

	local function doNode(node, offset_x)
		node:SetVisible(true)
		node.offset_x = offset_x
		node:SetPos(0, offset_y)
		node:SetSize(w, self.node_size)
		offset_y = offset_y + self.node_size

		if node.is_folder then
			if node.expanded then
				for _, node in ipairs(node.nodes) do
					doNode(node, offset_x + self.node_size / 2)
				end
			else
				for _, node in ipairs(node.nodes) do
					disableNode(node)
				end
			end
		end
	end

	for _, node in ipairs(self.folders) do
		doNode(node, 0)
	end

	-- scrollbar
	self.scrollbar:SetUp(h, offset_y)
	self.content:SetSize(w - (self.scrollbar.Enabled and 12 or 0), offset_y)
end

function Tree:OnMouseWheeled(delta, horizontal)
	horizontal = horizontal == nil and input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

	if horizontal then
		-- self:DoScrollH(-delta * settings.font_size * settings.scroll_multiplier)
	else
		self:DoScroll(-delta * settings.font_size * settings.scroll_multiplier)
	end
end

function Tree:DoScroll(delta)
	local speed = settings.scroll_speed
	self.scrolltarget = math.Clamp(self.scrolltarget + delta, 0, self.scrollbar.CanvasSize)

	if speed == 0 then
		self.scrollbar:SetScroll(self.scrolltarget)
	else
		self.scrollbar:AnimateTo(self.scrolltarget, 0.1 / speed, 0, -1)
	end
end

function Tree:OnVScroll(scroll)
	if self.scrollbar.Dragging then
		self.scrolltarget = -scroll
	end

	self.content:SetPos(self.content.x, scroll)
end

function Tree:Select(node, clear)
	if clear then
		for node, _ in pairs(self.selected) do
			self.selected[node] = nil
			node.selected = nil
		end
	end

	if not node or node.tree ~= self then return end

	if self.selected[node] then
		self.selected[node] = nil
		node.selected = nil
	else
		self.selected[node] = true
		node.selected = true
	end
end

function Tree:AddFolder(name, path, root_path)
	local node = self.content:Add("E4SyperTreeNode")
	node:Setup(self, name, true)
	node:SetPath(path, root_path)
	self.folders[#self.folders + 1] = node
	ExpressiveEditor.IDE:SaveSession()

	return node
end

function Tree:AddDirectory(path, root_path)
	ExpressiveEditor.IDE:SaveSession()
	self:InvalidateLayout()
	local name

	if root_path == "GITHUB" then
		local author, repo = string.match(path, "github%.com/([^/]+)/([^/]+)")
		name = author .. "/" .. repo
		path = "https://github.com/" .. name .. "/tree/master/"
	else
		name = string.match(path, "([^/]+)/?$")
		path = string.sub(path, -1, -1) == "/" and path or path .. "/"
		root_path = root_path or "DATA"
	end

	local node = self:AddFolder(name, path, root_path)
	node.main_directory = true

	local nodes = function(files, dirs)
		for _, dir in ipairs(dirs) do
			local n = node:AddNode(dir, true)
			n:SetPath(path .. dir .. "/", root_path)
			n:AddDirectory()
		end

		for _, file in ipairs(files) do
			local n = node:AddNode(file, false)
			n:SetPath(path .. file, root_path)
			n:GuessIcon()
		end

		self:InvalidateLayout()
	end

	if root_path == "GITHUB" then
		ExpressiveEditor.fetchGitHubPaths(path, nodes)
	else
		ExpressiveEditor.fileFindCallback(path .. "*", root_path, nodes)
	end

	return node
end

function Tree:RemoveDirectory(path, root_path)
	path = string.sub(path, -1, -1) == "/" and path or path .. "/"
	root_path = root_path or "DATA"

	for i, node in ipairs(self.folders) do
		if node.path == path and node.root_path == root_path then
			node:Remove()
			table.remove(self.folders, i)
			break
		end
	end

	self:InvalidateLayout()
	ExpressiveEditor.IDE:SaveSession()
end

function Tree:Refresh(path, root_path, recursive)
	self:InvalidateLayout()

	if path == nil then
		for _, node in ipairs(self.folders) do
			-- dont auto refresh github folders
			if node.root_path ~= "GITHUB" then
				node:Refresh(recursive)
			end
		end
	else
		if root_path == "GITHUB" then return end -- TODO: GitHub refresh
		local segs = string.Split(path, "/")

		if not file.IsDir(path, root_path) then
			segs[#segs] = nil
		end

		local node

		for i, n in ipairs(self.folders) do
			if n.name == segs[1] then
				node = n
				break
			end
		end

		if not node then return end
		local depth = 1

		while node do
			if depth >= #segs then
				node:Refresh(recursive)
				break
			end

			depth = depth + 1

			for i, n in ipairs(node.nodes) do
				if n.name == segs[depth] then
					node = n
					break
				end
			end
		end
	end
end

function Tree:Clear()
	for i, node in ipairs(self.folders) do
		node:Remove()
	end

	self.folders = {}
end

vgui.Register("E4SyperTree", Tree, "E4SyperBase")