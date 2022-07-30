---@type ExpressiveProcessor
local ENT = _G.ENT

require("expressive/library"); local ELib = ELib
local Import = ELib.Import

Import("includes/modules/expressive/startup", true)

include("shared.lua")

DEFINE_BASECLASS("base_gmodentity")

ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	self.name = "Generic ( No-Name )"
	self.OverlayFade = 0
	self.ActiveHuds = {}
end

function ENT:OnRemove()
	if self.instance then
		self.instance:runEvent("removed")
	end

	-- This is required because snapshots can cause OnRemove to run even if it wasn't removed.
	local instance = self.instance
	if instance then
		timer.Simple(0, function()
			if not self:IsValid() then
				instance:destroy()
			end
		end)
	end
end

function ENT:GetOverlayText()
	local state = self:GetNWInt("State", 1)
	local clientstr, serverstr
	if self.instance then
		local bufferAvg = self.instance.cpu_average
		clientstr = tostring(math.Round(bufferAvg * 1000000)) .. "us. (" .. tostring(math.floor(bufferAvg / self.instance.cpu_quota * 100)) .. "%)"
	elseif self.error then
		clientstr = "Errored / Terminated"
	else
		clientstr = "None"
	end
	if state == 1 then
		serverstr = tostring(self:GetNWInt("CPUus", 0)) .. "us. (" .. tostring(self:GetNWFloat("CPUpercent", 0)) .. "%)"
	elseif state == 2 then
		serverstr = "Errored"
	else
		serverstr = "None"
	end

	local authorstr =  self.author and self.author:Trim() ~= "" and "\nAuthor: " .. self.author or ""

	return "- Expressive Processor -\n[ " .. self.name .. " ]" .. authorstr .. "\nServer CPU: " .. serverstr .. "\nClient CPU: " .. clientstr
end

function ENT:Think()
	local lookedAt = self:BeingLookedAtByLocalPlayer()
	self.lookedAt = lookedAt

	if lookedAt and (not self:GetNoDraw() and self:GetColor().a > 0) then
		AddWorldTip( self:EntIndex(), self:GetOverlayText(), 0.5, self:GetPos(), self )
		halo.Add( { self }, color_white, 1, 1, 1, true, true )
	end
end

if WireLib then
	function ENT:DrawTranslucent()
		self:DrawModel()
		Wire_Render(self)
	end
else
	function ENT:DrawTranslucent()
		self:DrawModel()
	end
end

ELib.ReceiveNet("Processor.Download", function(_len)
	ELib.ReadProcessor(nil, function(ok, data)
		if ok then
			local chip = data.chip
			if IsValid(chip) then
				-- Make sure chip wasn't deleted before downloading
				chip:SetupFiles(data)
			end
		else
			ErrorNoHalt("Failed to read processor data\n")
		end
	end)
end)

ELib.ReceiveNet("Processor.Kill", function()
	---@type ExpressiveProcessor
	local target = net.ReadEntity()

	if target:IsValid() and target:GetClass() == "starfall_processor" then
		target:Error("Killed by admin")
	end
end)

ELib.ReceiveNet("Processor.Used", function(_len)
	local chip = net.ReadEntity()
	local used = net.ReadEntity()
	local activator = net.ReadEntity()
	if not (chip and chip:IsValid()) then return end
	if not (used and used:IsValid()) then return end
	local instance = chip.instance
	if not instance then return end

	instance:runEvent("used", instance.WrapObject( activator ), instance.WrapObject( used ))
end)
