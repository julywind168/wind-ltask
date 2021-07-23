local ltask = require "ltask"
local starre = require "starre"

local S = setmetatable({}, { __gc = function() print "Worker exit" end } )

print("Worker init", ...)





local t = starre.querystate("hello")

for k,v in pairs(t) do
	print(k,v)
end








return S
