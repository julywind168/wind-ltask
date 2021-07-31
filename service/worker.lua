local ltask = require "ltask"
local starre = require "starre"

local S = setmetatable({}, { __gc = function() print "Worker exit" end } )

local ID = ...
print("Worker init", ID)


local function print_state(...)
	local states = {...}
	
	print('--------------------------------------------------->')

	for i,state in ipairs(states) do
		for k,v in pairs(state) do
			print(k,v)
		end
		if i ~= #states then
			print()
		end
	end

	print('--------------------------------------------------->')
end


ltask.fork(function ()
	local hello, game <close> = starre.querystate("hello", "game")

	if ID == 1 then
		print_state(hello, game)
		hello.msg = "hi, programmers"
	else
		assert(ID == 2)
		print_state(hello, game)
	end
end)




return S
