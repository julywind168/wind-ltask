local ltask = require "ltask"


local state_mgr = (function ()
	local addr
	return function ()
		if not addr then
			addr = ltask.uniqueservice("state_mgr")
		end
		return addr
	end
end)()




local starre = {}


function starre.newstate(name, t)
	assert(type(name) == "string")
	assert(type(t) == "table")
	ltask.call(state_mgr(), "newstate", name, t)
end


function starre.querystate(name)
	local addr = ltask.call(state_mgr(), "querystate", name)
	local v, t, actions = ltask.call(addr, "query")
	return t
end



return starre