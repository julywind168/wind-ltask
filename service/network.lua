local ltask = require "ltask"
local starre = require "starre"
local socket = require "lsocket"

local S = setmetatable({}, { __gc = function() print "Network exit" end } )

print("Network init")




ltask.fork(function ()
	ltask.sleep(100)

	local fd = socket.listen("127.0.0.1", 7777, socket.SOCK_DGRAM)
	print("Listen 7777")

	ltask.sleep(100)

	while fd do
		ltask.sleep(10)
		local host, port, msg = socket.recvfrom(fd)
		if msg:sub(-1) == "\n" then
			msg = msg:sub(1, -2)
		end
		print(string.format("client %s[%d]: %s", host, port, msg))
	end
end)





return S
