local ltask = require "ltask"


local S = setmetatable({}, { __gc = function() print "StateMgr exit" end } )

print ("StateMgr init")


local state = {}
local locked = {}
local waitting = {}


local function try_lock(names)
	for _,name in ipairs(names) do
		if locked[name] then
			return false
		end
	end
	for _,name in ipairs(names) do
		locked[name] = true
	end
	return true
end


local function querystates(names)
	local list = {}
	for i,name in ipairs(names) do
		list[i] = state[name]
	end
	return list
end

---------------------------------------------------------------------------

function S.newstate(name, t)
	assert(type(t) == "table")
	assert(not state[name], string.format("state[%s] already exists", name))

	state[name] = ltask.spawn("state_cell", name, t)
	locked[name] = false
end


function S.lock(names)
	if try_lock(names) then
		return querystates(names)
	else
		waitting[#waitting + 1] = names
		return ltask.wait(names)
	end
end


function S.unlock(names)
	print("get unlock", table.unpack(names))
	for _,name in ipairs(names) do
		locked[name] = false
	end

	for _,names in ipairs(waitting) do
		if try_lock(names) then
			ltask.wakeup(names, querystates(names))
		end
	end
end


function S.exit()
	ltask.quit()
end


return S