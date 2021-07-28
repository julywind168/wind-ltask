local ltask = require "ltask"

local arg = ...

print "Bootstrap Begin"
print(os.date("%c", (ltask.now())))


local state_mgr = ltask.uniqueservice("state_mgr")

ltask.call(state_mgr, "newstate", "hello", {
	msg = "world"
})

ltask.call(state_mgr, "newstate", "game", {
	nplayer = 0,
	nroom = 0,
})


ltask.spawn("worker", 1)
ltask.spawn("worker", 2)


ltask.spawn("network")

print "Bootstrap End"