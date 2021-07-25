local ltask = require "ltask"
local starre = require "starre"

local S = setmetatable({}, { __gc = function() print "Worker exit" end } )

print("Worker init", ...)





local hello, game <close> = starre.querystate("hello", "game")


print('--------------------------------------------------->')

for k,v in pairs(hello) do
	print(k,v)
end


for k,v in pairs(game) do
	print(k,v)
end

print('--------------------------------------------------->')


return S
