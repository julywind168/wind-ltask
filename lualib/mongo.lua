local ltask = require "ltask"

local SERVICE_MONGO <const> = 4


local cache = {}

local function collection(coll)
    local c = cache[coll]
    if not c then
        c = setmetatable({}, {__index = setmetatable({}, {__index = function (_, k)
            return function (...)
                return ltask.call(SERVICE_MONGO, k, coll, ...)
            end
        end})})
        cache[coll] = c
    end
    return c
end

return setmetatable({}, {__index = function (_, name)
	return collection(name)
end})