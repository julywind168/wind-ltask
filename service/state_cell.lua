local ltask = require "ltask"
local ltdiff = require "ltdiff"
local db = require "mongo"
local persistence = require "conf.persistence"

local id, t = ...
local version = 0
local patches = {}


print(string.format('StateCell ["%s"] init', id))

local collname = id:match("(%w+)@(.+)")
local conf, query, fliter

if collname and persistence[collname] then
	conf = persistence[collname]
	conf.delay = conf.delay or 0

	query = {_id = assert(t._id)}
	t._id = nil

	if conf.fliter then
		fliter = function(t)
			local new = {}
			for k,v in pairs(t) do
				if conf.fliter[k] then
					new[k] = v
				end
			end
			return new
		end
	else
		fliter = function(t)
			return t
		end
	end
else
	collname = nil
end

local S = setmetatable({}, { __gc = function() print(string.format('StateCell ["%s"] exit', id)) end } )


local timing = false

local function delay_save(delay)
	if timing == false then
		timing = true
		ltask.timeout(delay*100, function ()
			db[collname].update(query, {["$set"] = fliter(t)})
			timing = false
		end)
	end
end

function S.patch(diff)
	patches[#patches + 1] = diff
	version = version + 1
	t = ltdiff.patch(t, diff)

	-- orm
	if conf then
		if conf.delay > 0 then
			delay_save(conf.delay)
		else
			db[collname].update(query, {["$set"] = fliter(t)})
		end
	end
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
