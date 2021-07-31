local ltask = require "ltask"
local starre = require "starre"
local socket = require "lsocket"
local epoll = require "lepoll"

local EPOLLIN_OR_EPOLLET <const> = epoll.EPOLLIN | epoll.EPOLLET


local S = setmetatable({}, { __gc = function() print "Network exit" end } )

print("Network init")



ltask.fork(function ()
	ltask.sleep(100)
	local epfd = assert(epoll.create())
	local listenfd = assert(socket.listen("127.0.0.1", 6666, socket.SOCK_STREAM))
	epoll.register(epfd, listenfd, EPOLLIN_OR_EPOLLET)
	print("Listen on 6666")


	local function accept()
		local fd, addr, err = socket.accept(listenfd)
		if fd then
			print("new connection", fd, addr)
			epoll.register(epfd, fd, EPOLLIN_OR_EPOLLET)
		else
			print("accept error", err)
		end
	end


	local function recv(fd)
		local msg, err = socket.recv(fd)
		if msg then
			local msg1 = msg:sub(-1) == "\n" and msg:sub(1, -2) or msg
			print(string.format("client[%d]: %s", fd, msg1))
			socket.send(fd, "server echo: " .. msg)

			if msg1 == "bye" then
				socket.close(fd)
				epoll.unregister(epfd, fd)
			end
		else
			print("recv error", err)
		end
	end


	while true do
		local events = epoll.wait(epfd, -1, 512)

		for fd,event in pairs(events) do
			if fd == listenfd then
				accept(fd)
			else
				recv(fd)
			end
		end
	end
end)




return S