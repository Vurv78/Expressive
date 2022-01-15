local Stream = require("bitstream")
local ELib = require("expressive/library")

local test = Stream.new()
local t = { ["Foo"] = "bar", ["baz"] = "quux", ["bar"] = "aaaaaaaaaaaaa" }
local n = table.Count(t)
test:writeU16(n)
for k, v in pairs(t) do
	test:writeString(k)

	test:writeU32(#v)
	test:writeString(v, true)
end

local buf = test:getBuffer()
local read = Stream.new(buf)

local n = read:readU(16)
print("n: should be 2: ", n)

for i = 1, n do
	local key = read:readString()
	local len = read:readU(32)
	local val = read:read(len)
	print("kl#v", key, #key, len, val)
end