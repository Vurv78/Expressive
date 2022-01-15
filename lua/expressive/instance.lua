local Lib = require("expressive/library")

--- Instance
--- This is different from the [Context], which is the immutable environment it runs in.
--- Basically this extends it and is runtime based while the Context is available to extensions at compile time.
---@class Instance
---@field src string
---@field main function
---@field modules table<string, function>
---@field ctx Context
---@field env table Environment that the chip is run inside.
---@field errored boolean
---@field ram number Ram used prior to calling into instance
---@field start_time number
---@field cpu_total number
---@field cpu_average number
---@field cpu_quota_ratio number
---@field cpu_quota number
---@field cpu_softquota number
---@field stack_level number
---@field owner GEntity|GPlayer
---@field chip GEntity
local Instance = {}
Instance.__index = Instance

--- Most of the cpu limiting stuff is taken from E3 / StarfallEx.
function Instance:movingCPUAverage()
	return self.cpu_average + (self.cpu_total - self.cpu_average) * self.cpu_quota_ratio
end

local TimeBuffer = CreateConVar("es_timebuffer", 0.005, FCVAR_ARCHIVE, "The max average the CPU time can reach.")
local TimeBufferSize = CreateConVar("es_timebuffersize", 100, FCVAR_ARCHIVE, "The window width of the CPU time quota moving average.")

---@param ctx Context
---@param main string Name of entrypoint module to call first
---@param modules table? Table of compiled lua code retrieved from the [Transpiler]
---@param chip GEntity The chip entity
---@param owner GEntity|GPlayer|nil The entity that owns this instance. Usually a player.
---@return Instance
function Instance.from(ctx, main, modules, chip, owner)
	local self = setmetatable({}, Instance)

	self.ram = collectgarbage("count")
	self.cpu_total = 0
	self.cpu_average = 0
	self.cpu_softquota = 1
	self.start_time = -1

	self.chip = chip
	self.owner = owner

	self.ctx =  ctx
	self.env = ctx:getEnv()

	local ELib = require("expressive/library")

	self.cpu_quota = TimeBuffer:GetFloat()
	self.cpu_quota_ratio = 1 / TimeBufferSize:GetInt()

	---@param name string
	---@param code string
	local function compile(name, code)
		local fn = CompileString(code, "ES:" .. name, true)
		if not isfunction(fn) then error(fn) end
		return setfenv(fn, self.env )
	end

	self.modules = {}
	for mod, code in pairs(modules) do
		self.modules[mod] = compile(mod, code)
	end
	self.main = self.modules[main]

	return self
end

function Instance:checkCpu()
	--[[self.cpu_total = SysTime() - self.start_time
	local used_ratio = self:movingCPUAverage() / self.cpu_quota
	if used_ratio > 1 then
		error("CPU Quota exceeded.")
	elseif used_ratio > self.cpu_softquota then
		error("CPU Quota warning.")
	end]]
end

--- Runs an event for a chip.
---@param name string # Name of the event to run
function Instance:runEvent(name)
	-- todo
end

function Instance:destroy()
	-- Run extension destructors
	for ext in pairs(self.ctx.extensions) do
		ext:construct(self)
	end
	self.errored = true
end

--- Runs the mainfile once
-- Should be called only once.
function Instance:init()
	self.cpu_total = 0
	self.cpu_average = 0
	self.cpu_softquota = 1

	-- Run extension constructors
	for ext in pairs(self.ctx.extensions) do
		ext:construct(self)
	end

	local ok, args = self:runFunction(self.main)

	if not ok then
		self:error(args)
		return false, args
	end
end

function Instance:error(err)
	if self.errored then return end
	if self.runOnError then -- We have a custom error function, use that instead
		self.runOnError(err)
	else
		-- Default behavior
		self:destroy()
	end
end

--- Returns a table of returns, with the first element being 'success' / 'ok' status
---@return boolean # Ran successfully?
---@return table|string # Return values, or error message if failed
function Instance:runFunction(fn, ...)
	if self.stack_level == 0 then
		self.start_time = SysTime() - self.cpu_total
	elseif self.stack_level == 128 then
		return false, { "Stack Overflow" }
	end

	local old_hook = debug.gethook()

	local function checkCpu()
		self.cpu_total = SysTime() - self.start_time
		local usedRatio = self:movingCPUAverage() / self.cpu_quota
		if usedRatio > 1 then
			error(self, "CPU Quota exceeded")
		elseif usedRatio > self.cpu_softquota then
			error(self, "CPU Quota warning")
		end
	end

	local function xpcall_callback(err)
		return err
	end

	debug.sethook(checkCpu, "", 2000)
		jit.on(fn, true)  -- Turn JIT compilation on just for the chip.
		local rets = { xpcall(fn, xpcall_callback, ...) }
	debug.sethook(old_hook)

	local ok = table.remove(rets, 1)

	if not ok then
		-- Just in case
		self:checkCpu()

		return false, table.remove(rets, 1)
	end

	return ok, rets
end

Lib.Instance = Instance

return Instance