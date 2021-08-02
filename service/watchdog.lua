local ltask = require "ltask"

local AUTH_TOKEN <const> = "STARRE\n"
local SERVICE_NETWORK <const> = 3

local workers = ...

local S = setmetatable({}, { __gc = function() print "Watchgog exit" end } )

print ("Watchgog init")


local function socket_send(fd, msg)
	ltask.send(SERVICE_NETWORK, "socket_send", fd, msg)
end

local function socket_close(fd)
	ltask.send(SERVICE_NETWORK, "socket_close", fd)
end


local function worker(pid)
	local n = 0
	for i=1,#pid do
		n = n + pid:byte(i)
	end
	return workers[n%#workers+1]
end


local function try_dispatch_message(c, fd)
	local pid = c.pid

	while true do
		if #c.last < 2 then
			break
		end
		local sz = c.last:byte(1)*256 + c.last:byte(2)

		if #c.last >= sz + 2 then
			local pack = c.last:sub(3, 2+sz)
			c.last = c.last:sub(3+sz)
			local resp = ltask.call(worker(pid), "player_request", pid, pack)
			if resp then
				socket_send(fd, resp)
			end
		else
			break
		end
	end
end




local connection = {}


function S.socket_open(fd, addr)
	print("new client", fd, addr)
	connection[fd] = {
		addr = addr,
		authed = false,
		login = false,
		pid = nil,
		last = ""
	}
end


local function shutdown(fd)
	connection[fd] = nil
	socket_close(fd)
end

function S.socket_data(fd, message)
	local c = assert(connection[fd])

	if c.authed == false then
		if message == AUTH_TOKEN then
			c.authed = true
			socket_send(fd, "Authenticated, Please Enter your id to login.\n")
		else
			shutdown(fd)
		end
	elseif c.login == false then
		c.pid = message:sub(1, -2)
		c.login = true
		ltask.send(worker(c.pid), "player_login", c.pid, c.addr)
		socket_send(fd, "Login success!\n")
	else
		c.last = c.last .. message
		try_dispatch_message(c, fd)
	end
end



function S.socket_close(fd)

end


function S.exit()
	ltask.quit()
end


return S