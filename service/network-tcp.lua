local ltask = require "ltask"
local starre = require "starre"
local socket = require "lsocket"

local S = setmetatable({}, { __gc = function() print "Network exit" end } )

print("Network init")




ltask.fork(function ()
	ltask.sleep(100)

	local fd = socket.listen("127.0.0.1", 6666, socket.SOCK_STREAM)
	print("Listen on 6666")

	ltask.sleep(100)

	while fd do
		ltask.sleep(10)
		local id, addr, err = socket.accept(fd)
		if id then
			local msg, err = socket.recv(id)
			if msg then
				local msg1 = msg:sub(-1) == "\n" and msg:sub(1, -2) or msg
				print(string.format("client[%d - %s]: %s", id, addr, msg1))
				socket.send(id, "server echo: " .. msg)
			end
			socket.close(id)
		end
	end
end)




return S