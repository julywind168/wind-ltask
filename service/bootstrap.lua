local ltask = require "ltask"

local SERVICE_NETWORK <const> = 3 	-- see config, 3 = 1(root) + #exclusive
local NWORKER <const> = 2

local arg = ...

print "Bootstrap Begin"
print(os.date("%c", (ltask.now())))

local state_mgr = ltask.uniqueservice("state_mgr")

local function newstate(name, t)
	ltask.call(state_mgr, "newstate", name, t)
end


-- init
newstate("hello", {msg = "world"})
newstate("game", {nplayer = 0, nroom = 0})



----------------------------------------------------------
local workers = {}

for i=1,NWORKER do
	workers[i] = ltask.spawn("worker", i)
end

local watchdog = ltask.spawn("watchdog", workers)

ltask.call(SERVICE_NETWORK, "start", watchdog)



print "Bootstrap End"