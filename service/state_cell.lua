local ltask = require "ltask"
local ltdiff = require "ltdiff"

local id, t = ...
local version = 0
local patches = {}


print(string.format('StateCell ["%s"] init', id))

local S = setmetatable({}, { __gc = function() print(string.format('StateCell ["%s"] exit', id)) end } )


function S.patch(diff)
	patches[#patches + 1] = diff
	version = version + 1
	t = ltdiff.patch(t, diff)
end


function S.query(v)
	v = v or 0

	if v == 0 then
		return version, t
	end

	if v == version then
		return version
	end

	if patches[v+1] then
		local list = {}

		for i=v+1, #patches do
			table.insert(list, patches[i])
		end
		return version, nil, list
	else
		return version, t
	end
end


function S.exit()
	ltask.quit()
end


return S
