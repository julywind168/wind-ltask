local ltask = require "ltask"
local socket = require "lsocket"
local starre = require "starre"
local json = require "json"


local S = setmetatable({}, { __gc = function() print "Worker exit" end } )

local ID = ...
print("Worker init", ID)


local request = {}

function request:ping(params)
	return {start = params.now, now = os.time()}
end



--------------------------------------------------------------------
local connection = {}


function S.socket_open(fd, addr)
	print("new client", fd, addr)
	connection[fd] = {
		addr = addr,
		authed = false,
		login = false
	}
end


function S.socket_data(fd, message)
	local c = assert(connection[fd])
	if c.authed == false then
		if message == "STARRE\n" then
			c.authed = true
			socket.send(fd, "Authenticated, Please Enter your id to login.\n")
		else
			-- todo 
			-- close invalid connection
		end
	elseif c.login == false then
		local pid = message:sub(1, -2)
		c.login = true

		-- Maybe you should load player data from the database
		c.player = {
			id = pid,
			gold  = 50000,
			diamond = 50000
		}
		socket.send(fd, "Login success!\n")
	else
		if message:sub(-1) == "\n" then
			message = message:sub(1, -2)
		end
 		local p = assert(c.player)
 		local t = json.decode(message) 			-- message: `["ping", {"start":123}]`
 		local f = assert(request[t[1]], t[1])
 		local r = f(p, t[2])
 		socket.send(fd, json.encode{"response", t[1], r} .. "\n")
	end
end


function S.socket_close(fd)
end


return S
