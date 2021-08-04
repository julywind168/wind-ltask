package.path = "lualib/?.lua;"..package.path
package.cpath = "luaclib/?.so;"..package.cpath


local socket = require "lsocket"
local json = require "json"




local function connect_server(host, port, pid)
	local fd, err = socket.connect(host, port)
	if err then
		return print("connect error", err)
	end

	socket.send(fd, "STARRE\n")
	print(socket.recv(fd))
	socket.send(fd, pid.."\n")
	print(socket.recv(fd))

	local c = {}

	function c.req(name, args)
		local s = json.encode{name, args or {}}
		socket.send(fd, string.pack(">s2", s))
		print(socket.recv(fd))
	end

	local function count(f)
		return function (...)
			local t1 = socket.time()
			f(...)
			print("use:", (socket.time()-t1).."ms")
		end
	end

	c.req = count(c.req)

	return c
end




local function main()
	local c = connect_server("127.0.0.1", 6666, "123456")
	c.req("ping", {now = socket.time()})
	c.req("ping", {now = socket.time()})
end


main()