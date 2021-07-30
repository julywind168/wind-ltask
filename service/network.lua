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
		local msg1 =  msg:sub(-1) == "\n" and msg:sub(1, -2) or msg
		print(string.format("client %s[%d]: %s", host, port, msg1))
		socket.sendto(fd, host, port, "server echo: "..msg)
	end
end)





return S
