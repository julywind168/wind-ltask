local ltask = require "ltask"

local AUTH_TOKEN <const> = "STARRE\n"


local function split(s)
	local packs = {}
	while true do
		if #s < 2 then
			break
		end
		local sz = s:byte(1)*256 + s:byte(2)
		if #s >= sz + 2 then
			packs[#packs+1] = s:sub(3, 2+sz)
			s = s:sub(3+sz)
		else
			break
		end
	end
	return s, packs
end


return function(network, workers)

	local nworker = #workers

	local function worker(pid)
		local n = 0
		for i=1,#pid do
			n = n + pid:byte(i)
		end
		return workers[n%nworker+1]
	end


	local connection = {}

	local function shutdown(fd)
		connection[fd] = nil
		network.close(fd)
	end


	------------------------------------------------------------
	
	local self = {}

	function self.on_accept(fd, addr)
		print("new client", fd, addr)
		connection[fd] = {
			addr = addr,
			authed = false,
			login = false,
			pid = nil,
			last = ""
		}
	end	

	function self.on_data(fd, message)
		local c = assert(connection[fd])

		if c.authed == false then
			if message == AUTH_TOKEN then
				c.authed = true
				network.send(fd, "Authenticated, Please Enter your id to login.\n")
			else
				shutdown(fd)
			end
		elseif c.login == false then
			c.pid = message:sub(1, -2)
			c.login = true
			ltask.call(worker(c.pid), "player_login", c.pid, c.addr)
			network.send(fd, "Login success!\n")
		else
			local last, packs = split(c.last .. message)
			c.last = last
			for _,pack in ipairs(packs) do
				ltask.fork(function ()
					local resp = ltask.call(worker(c.pid), "player_request", c.pid, pack)
					if resp then
						network.send(fd, resp)
					end
				end)
			end
		end
	end

	function self.on_close(fd)
		-- body
	end

	return self
end