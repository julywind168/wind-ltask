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


function starre.querystate(...)
	local names = {...}
	local addrs = ltask.call(state_mgr(), "lock", names)
	local results = {}

	for i,addr in ipairs(addrs) do
		local v, t, actions = ltask.call(addr, "query")
		
		local mt; mt = {__index = mt, __close = function ()
			ltask.fork(function ()
				ltask.send(state_mgr(), "unlock", names)
			end)
		end}
	
		results[i] = setmetatable(t, mt)
	end

	return table.unpack(results)
end



return starre