function table.merge(t1, t2)
    for k,v in pairs(t2) do
        t1[k] = v
    end
    return t1
end


function table.eq(t1, t2)
    local function _eq(a, b)
        local type1 = type(a)
        local type2 = type(b)

        if type1 ~= type2 then
            return false
        end

        if type1 ~= "table" then
            return a == b
        else
            for k,v in pairs(a) do
                if not _eq(v, b[k]) then
                    return false
                end
            end
            for k,v in pairs(b) do
                if not _eq(v, a[k]) then
                    return false
                end
            end
            return true
        end
    end

    return _eq(t1, t2)
end

function table.random_n(t, n)
    t = table.copy(t)
    local r = {}
    for i = 1, n do
        local index = math.random(1, #t)
        r[i] = table.remove(t, index)
    end
    return r
end


function table.random_remove_n(t, n)
    local r = {}
    for i = 1, n do
        local index = math.random(1, #t)
        r[i] = table.remove(t, index)
    end
    return r
end

function table.append(t, list)
    for i,v in ipairs(list) do
        table.insert(t, v)
    end
    return t
end


function table.randsort(t)
    local len = #t
    for i = 1, len do
        local index = math.random(1, len)
        t[i], t[index] = t[index], t[i]
    end
    return t
end


function table.splice(t, index1, index2)
    assert(type(t) == 'table' and #t > 0)
    index1 = index1 or 1
    index2 = index2 or #t

    assert(index2 - index1 < #t)

    local r = {}
    for i = index2, index1, -1 do
        table.insert(r, 1, table.remove(t, i))
    end
    return r
end

function table.slice(t, index1, index2)
    assert(type(t) == 'table' and #t > 0)
    index1 = index1 or 1
    index2 = index2 or #t

    assert(index2 - index1 < #t)

    local r = {}
    for i = index1, index2 do
        table.insert(r, table.clone(t[i]))
    end
    return r
end


function table.find_one(t, item)
	for i,v in ipairs(t) do
		if v == item then
			return true
		end
	end
	return false
end


function table.copy(t)
    local new = {}
    for k,v in pairs(t) do
        new[k] = v
    end
    return new
end


function table.clone( obj )
    local function _copy( obj )
        if type(obj) ~= 'table' then
            return obj
        else
            local tmp = {}
            for k,v in pairs(obj) do
                tmp[_copy(k)] = _copy(v)
            end
            return setmetatable(tmp, getmetatable(obj))
        end
    end
    return _copy(obj)
end

function table.filter(t, filter)
	local filter_type = type(filter)
	if filter_type == "table" then
	    local new = {}
	    for k,v in pairs(t) do
	        if filter[k] == false then
	        
	        else
	            new[k] = v
	        end
	    end
	    return new
	else
		assert(filter_type == "function")
		local new = {}
		for k,v in pairs(t) do
			if filter(k, v) ~= false then
				new[k] = v
			end
		end
		return new
	end
end