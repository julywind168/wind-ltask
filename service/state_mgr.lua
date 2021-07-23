local ltask = require "ltask"





local S = setmetatable({}, { __gc = function() print "StateMgr exit" end } )

print ("StateMgr init :")


local state = {}


local function check(names)
	for _,name in ipairs(names) do
		if state[name].locked then
			return false
		end
	end
	return true
end


function S.lock(names)
	if check(names) then
		for _,name in ipairs(names) do
			state[name].locked = true
		end
		return true
	else
		-- todo
		-- join waiting queue
	end
end

function S.unlock(names)
	for _,name in ipairs(names) do
		state[name].locked = false
	end
end


function S.newstate(name, t)
	assert(type(t) == "table")
	assert(not state[name], string.format("state[%s] already exists", name))

	state[name] = {
		addr = ltask.spawn("state_cell", t),
		locked = false
	}
end

function S.querystate(name)
	return state[name] and state[name].addr
end

function S.exit()
	ltask.quit()
end

return S
