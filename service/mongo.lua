local ltask = require "ltask"
local mongo = require "3rd.lua-mongo.mongo"
local conf = require "conf.mongo"

print("Mongo init")

local S = setmetatable({}, { __gc = function() print "Mongo exit" end } )
local client = mongo.client(conf)
local db = client:getDB(conf.dbname)[conf.dbname]


function S.count(collname, query)
	local it = db[collname]:find(query)
	return it:count()
end


function S.update(collname, query, update, upsert, multi)
    return db[collname]:update(query, update, upsert, multi)
end


function S.remove(collname, query, single)
    return db[collname]:delete(query, single)
end


function S.find_all(collname, query, fields, sorter, limit, skip)
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


function S.find_one(collname, query, fields)
    return db[collname]:findOne(query, fields)
end


function S.insert(collname, obj)
    db[collname]:insert(obj)
    return obj._id
end



return S