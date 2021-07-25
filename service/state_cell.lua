local ltask = require "ltask"


local S = setmetatable({}, { __gc = function() print "StateCell exit" end } )


local id, t = ...
local version = 0
local actions = {}


print(string.format('StateCell ["%s"] init', id))


function S.version()
	return v
end


function S.query(v)
	v = v or 0

	if v == 0 then
		return version, t
	end

	if v == version then
		return version
	end

	if actions[v+1] then
		local list = {}

		for i=v+1, #actions do
			table.insert(list, actions[i])
		end
		return version, nil, list
	else
		return version, t
	end
end


return S
