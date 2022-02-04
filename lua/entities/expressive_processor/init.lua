--- Credit to https://github.com/thegrb93/StarfallEx for a good chunk of this code.
--- Didn't want to deal with the networking :/

---@type ExpressiveProcessor
local ENT = _G.ENT

local ELib = require("expressive/library")
require("expressive/startup")

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )

	self:SetNWInt("State", self.States.None)
	self:SetColor(Color(255, 0, 0, self:GetColor().a))
	self.ErroredPlayers = {}
	self.ActiveHuds = {}
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:OnRemove()
	self:Destroy()
end

function ENT:Think()
	if self.instance then
		local bufferAvg = self.instance.cpu_average
		self:SetNWInt("CPUus", math.Round(bufferAvg * 1000000))
		self:SetNWFloat("CPUpercent", math.floor(bufferAvg / self.instance.cpu_quota * 100))
		self:NextThink(CurTime() + 0.25)
		return true
	end
end

---@param recipient GPlayer
function ENT:SendCode(recipient)
	if not self.send_data then return end
	ELib.SendProcessor("Processor.Download", self.send_data, recipient)
end

local copying
function ENT:PreEntityCopy()
	duplicator.ClearEntityModifier(self, "ExpressiveDupe")

	if self.chip_data then
		local info = WireLib and WireLib.BuildDupeInfo(self) or {}
		info.starfall = {
			main = self.chip_data.main,
			files = ELib.CompressFiles(self.chip_data.modules)
		}
		duplicator.StoreEntityModifier(self, "ExpressiveDupe", info)
	end

	-- Stupid hack to prevent garry dupe from copying everything
	copying = {self.chip_data, self.instance}
	self.chip_data = nil
	self.instance = nil
end

function ENT:PostEntityCopy()
	self.chip_data = copying[1]
	self.instance = copying[2]
	copying = nil
end

local function EntityLookup(CreatedEntities)
	return function(id, default)
		if id == nil then return default end
		if id == 0 then return game.GetWorld() end
		local ent = CreatedEntities[id]
		if (ent and ent:IsValid()) then return ent else return default end
	end
end

function ENT:PostEntityPaste(ply, ent, CreatedEntities)
	if ent.EntityMods and ent.EntityMods.ExpressiveDupe then
		---@type { expressive: ProcessorData }
		local info = ent.EntityMods.ExpressiveDupe

		if not ply then ply = game.GetWorld() end

		if WireLib then
			WireLib.ApplyDupeInfo(ply, ent, info, EntityLookup(CreatedEntities))
		end

		if info.expressive then
			self.chip_data = {
				owner = ply,
				files = ELib.DecompressFiles(info.expressive.modules),
				main = info.expressive.main
			}
		end
	end
end

local function dupefinished(TimedPasteData, TimedPasteDataCurrent)
	local entList = TimedPasteData[TimedPasteDataCurrent].CreatedEntities
	local starfalls = {}
	for k, v in pairs(entList) do
		if IsValid(v) and v:GetClass() == "expressive_processor" and v.chip_data then
			starfalls[#starfalls+1] = v
		end
	end
	for k, v in pairs(starfalls) do
		v:SetupFiles(v.chip_data)
		local instance = v.instance
		if instance then
			instance:runEvent("dupefinished", instance.Sanitize(entList))
		end
	end
end

hook.Add("AdvDupe_FinishPasting", "EX_DupeFinished", dupefinished)

-- Request code from the chip. If the chip doesn't have code yet add player to list to send when there is code.
ELib.ReceiveNet("Processor.Download", function(len, ply)
	---@type ExpressiveProcessor
	local proc = net.ReadEntity()

	if ply:IsValid() and proc:IsValid() then
		proc:SendCode(ply)
	end
end)

ELib.ReceiveNet("Processor.Kill", function(len, ply)
	---@type ExpressiveProcessor
	local target = net.ReadEntity()

	if ply:IsAdmin() and target:IsValid() and target:GetClass() == "expressive_processor" then
		target:Error("Killed by admin")

		ELib.StartNet("Processor.Kill")
			net.WriteEntity(target)
		net.Broadcast()
	end
end)

ELib.ReceiveNet("Processor.ClientReady", function(len, ply)
	local proc = net.ReadEntity()
	if ply:IsValid() and proc:IsValid() then
		local instance = proc.instance
		if instance then
			instance:runEvent("clientinitialized", instance.Types.Player.Wrap(ply))
		end
	end
end)

ELib.ReceiveNet("Processor.Errored", function(len, ply)
	---@type ExpressiveProcessor
	local chip = net.ReadEntity()
	if chip:IsValid() and chip.owner:IsValid() and chip.ErroredPlayers and not chip.ErroredPlayers[ply] and chip.owner ~= ply then
		chip.ErroredPlayers[ply] = true
	end
end)

hook.Add("PlayerInitialSpawn", "Expressive_PlayerInitialSpawn", function(ply)
	for k, v in ipairs(ents.FindByClass("expressive_processor")) do
		v:SendCode(ply)
	end
end)
