local ltask = require "ltask"
local starre = require "starre"
local socket = require "lsocket"
local epoll = require "lepoll"

local AUTH_TOKEN <const> = "STARRE\n"
local EPOLLIN_OR_EPOLLET <const> = epoll.EPOLLIN | epoll.EPOLLET


local S = setmetatable({}, { __gc = function() print "Network exit" end } )

print("Network init")


local connection = {}


function S.start(watchdog)
	local epfd = assert(epoll.create())
	local listenfd = assert(socket.listen("127.0.0.1", 6666, socket.SOCK_STREAM))
	epoll.register(epfd, listenfd, EPOLLIN_OR_EPOLLET)
	print("Listen on 6666")


	local function close(fd)
		socket.close(fd)
		epoll.unregister(epfd, fd)
	end

	local function accept()
		local fd, addr, err = socket.accept(listenfd)
		if fd then
			connection[fd] = {addr = addr, authed = false}
			epoll.register(epfd, fd, EPOLLIN_OR_EPOLLET)
			ltask.send(watchdog, "socket_open", fd, addr)
		else
			print("accept error", err)
		end
	end


	local function recv(fd)
		local msg, err = socket.recv(fd)
		if msg then
			local c = connection[fd]
			if c.authed == false then
				if msg == AUTH_TOKEN then
					c.authed = true
					socket.send(fd, "Authenticated, Please Enter your id to login.\n")
				else
					close(fd)
				end
			else
				ltask.send(watchdog, "socket_data", fd, msg)
			end
		else
			print("recv error", err)
		end
	end


	while true do
		local events = epoll.wait(epfd, 1, 512)

		for fd,event in pairs(events) do
			if fd == listenfd then
				accept(fd)
			else
				recv(fd)
			end
		end
		ltask.sleep(0)
	end
end


function S.socket_send(fd, msg)
	socket.send(fd, msg)
end


return S