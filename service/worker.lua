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

-- data: `["ping", {"start":123}]`

function S.player_request(pid, data)
	local p = starre.query("player@"..pid)
	local t = json.decode(data) 			
	local f = assert(request[t[1]], t[1])
	local r = f(p, t[2])
	if r and assert(type(r) == "table") then
		return json.encode(r)
	end
end


function S.player_login(pid, addr)
	starre.new("player@"..pid, {
		id = pid,
		gold = 50000,
		diamond = 50000
	})
end





return S
