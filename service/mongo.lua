local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local mongo = require "3rd.lua-mongo.mongo"
local conf = require "conf.mongo"

local quit = false
local SERVICE_ROOT <const> = 1
local MESSAGE_REQUEST <const> = 1
local MESSAGE_RESPONSE <const> = 2


local client = mongo.client{ host = conf.host, port = conf.port}
local db = client:getDB(conf.dbname)


local REQUEST = {}


function REQUEST.count(collname, query)
	local it = db[collname]:find(query)
	return it:count()
end


function REQUEST.update(collname, query, update, upsert, multi)
    return db[collname]:update(query, update, upsert, multi)
end


function REQUEST.remove(collname, query, single)
    return db[collname]:delete(query, single)
end


function REQUEST.find_all(collname, query, fields, sorter, limit, skip)
    local t = {}
    local it = db[collname]:find(query, fields)
    if not it then
        return t
    end

    if sorter then
        if #sorter > 0 then
            it = it:sort(table.unpack(sorter))
        else
            it = it:sort(sorter)
        end
    end

    if limit then
        it:limit(limit)
        if skip then
            it:skip(skip)
        end
    end

    while it:hasNext() do
        local obj = it:next()
        table.insert(t, obj)
    end

    return t
end


function REQUEST.find_one(collname, query, fields)
    return db[collname]:findOne(query, fields)
end


function REQUEST.insert(collname, obj)
    db[collname]:insert(obj)
    return obj._id
end


local function handle_request(cmd, ...)
	local f = REQUEST[cmd]
	return f(...)
end


print("Db-mongo start")
while not quit do
	local from, session, type, msg, sz = ltask.recv_message()
	if from then
		if from == SERVICE_ROOT then
			local command = ltask.unpack_remove(msg, sz)
			if command == "QUIT" then
				quit = true
			end
		else
			assert(type == MESSAGE_REQUEST)
			local r = handle_request(ltask.unpack_remove(msg, sz))
			exclusive.send(from, session, MESSAGE_RESPONSE, ltask.pack(r))
		end
	else
		coroutine.yield()
	end
end
print("Db-mongo exit")