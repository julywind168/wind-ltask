local bson = require "bson"
local socket = require "mongo.socket"
local driver = require "mongo.driver"
local crypt = require "lcrypt"
local md5 = require "md5"
local rawget = rawget
local assert = assert

local bson_encode = bson.encode
local bson_encode_order = bson.encode_order
local bson_decode = bson.decode
local empty_bson = bson_encode {}

local mongo = {}
mongo.null = assert(bson.null)
mongo.maxkey = assert(bson.maxkey)
mongo.minkey = assert(bson.minkey)
mongo.type = assert(bson.type)

local mongo_cursor = {}
local cursor_meta = {
	__index = mongo_cursor,
}

local mongo_client = {}

local client_meta = {
	__index = function(self, key)
		return rawget(mongo_client, key) or self:getDB(key)
	end,
	__tostring = function (self)
		local port_string
		if self.port then
			port_string = ":" .. tostring(self.port)
		else
			port_string = ""
		end

		return "[mongo client : " .. self.host .. port_string .."]"
	end,
	__gc = function(self)
		self:disconnect()
	end
}

local mongo_db = {}

local db_meta = {
	__index = function (self, key)
		return rawget(mongo_db, key) or self:getCollection(key)
	end,
	__tostring = function (self)
		return "[mongo db : " .. self.name .. "]"
	end
}

local mongo_collection = {}
local collection_meta = {
	__index = function(self, key)
		return rawget(mongo_collection, key) or self:getCollection(key)
	end ,
	__tostring = function (self)
		return "[mongo collection : " .. self.full_name .. "]"
	end
}

local function __parse_addr(addr)
	local host,	port = string.match(addr, "([^:]+):(.+)")
	return host, tonumber(port)
end

local auth_method = {}

local function mongo_auth(mongoc)
	local user = rawget(mongoc,	"username")
	local pass = rawget(mongoc,	"password")
	local authmod = rawget(mongoc, "authmod") or "scram_sha1"
	authmod = "auth_" ..  authmod
	local authdb = rawget(mongoc, "authdb")
	if authdb then
		authdb = mongo_client.getDB(mongoc, authdb)	-- mongoc has not set metatable yet
	end

	return function()
		if user	~= nil and pass	~= nil then
			-- autmod can be "mongodb_cr" or "scram_sha1"
			local auth_func = auth_method[authmod]
			assert(auth_func , "Invalid authmod")
			assert(auth_func(authdb or mongoc, user, pass))
		end
		-- local rs_data =	mongoc:runCommand("ismaster")
		-- if rs_data.ok == 1 then
		-- 	if rs_data.hosts then
		-- 		local backup = {}
		-- 		for	_, v in	ipairs(rs_data.hosts) do
		-- 			local host,	port = __parse_addr(v)
		-- 			table.insert(backup, {host = host, port	= port})
		-- 		end
		-- 		mongoc.__sock:changebackup(backup)
		-- 	end
		-- 	if rs_data.ismaster	then
		-- 		return
		-- 	elseif rs_data.primary then
		-- 		local host,	port = __parse_addr(rs_data.primary)
		-- 		mongoc.host	= host
		-- 		mongoc.port	= port
		-- 		mongoc.__sock:changehost(host, port)
		-- 	else
		-- 		-- socketchannel would try the next host in backup list
		-- 		error ("No primary return : " .. tostring(rs_data.me))
		-- 	end
		-- end
	end
end

function mongo.client( obj )
	obj.port = obj.port or 27017
	obj.__id = 0
	obj.__sock = assert(socket.open(obj.host, obj.port),"Connect failed")
	
	setmetatable(obj, client_meta)
	mongo_auth(obj)()
	return obj
end

function mongo_client:getDB(dbname)
	local db = {
		connection = self,
		name = dbname,
		full_name = dbname,
		database = false,
		__cmd = dbname .. "." .. "$cmd",
	}

	db.database = db

	return setmetatable(db, db_meta)
end

function mongo_client:disconnect()
	if self.__sock then
		socket.close(self.__sock)
		self.__sock = nil
	end
end

function mongo_client:genId()
	local id = self.__id + 1
	self.__id = id
	return id
end

function mongo_client:runCommand(...)
	if not self.admin then
		self.admin = self:getDB "admin"
	end
	return self.admin:runCommand(...)
end

function auth_method:auth_mongodb_cr(user,password)
	local password = md5.sumhexa(string.format("%s:mongo:%s",user,password))
	local result= self:runCommand "getnonce"
	if result.ok ~=1 then
		return false
	end

	local key =	md5.sumhexa(string.format("%s%s%s",result.nonce,user,password))
	local result= self:runCommand ("authenticate",1,"user",user,"nonce",result.nonce,"key",key)
	return result.ok ==	1
end

local function salt_password(password, salt, iter)
	salt = salt .. "\0\0\0\1"
	local output = crypt.hmac_sha1(password, salt)
	local inter = output
	for i=2,iter do
		inter = crypt.hmac_sha1(password, inter)
		output = crypt.xor_str(output, inter)
	end
	return output
end

function auth_method:auth_scram_sha1(username,password)
	local user = string.gsub(string.gsub(username, '=', '=3D'), ',' , '=2C')
	local nonce = crypt.base64encode(crypt.randomkey())
	local first_bare = "n="  .. user .. ",r="  .. nonce
	local sasl_start_payload = crypt.base64encode("n,," .. first_bare)
	local r

	r = self:runCommand("saslStart",1,"autoAuthorize",1,"mechanism","SCRAM-SHA-1","payload",sasl_start_payload)
	if r.ok ~= 1 then
		return false
	end

	local conversationId = r['conversationId']
	local server_first = r['payload']
	local parsed_s = crypt.base64decode(server_first)
	local parsed_t = {}
	for k, v in string.gmatch(parsed_s, "(%w+)=([^,]*)") do
		parsed_t[k] = v
	end
	local iterations = tonumber(parsed_t['i'])
	local salt = parsed_t['s']
	local rnonce = parsed_t['r']

	if not string.sub(rnonce, 1, 12) == nonce then
		print("Server returned an invalid nonce.")
		return false
	end
	local without_proof = "c=biws,r=" .. rnonce
	local pbkdf2_key = md5.sumhexa(string.format("%s:mongo:%s",username,password))
	local salted_pass = salt_password(pbkdf2_key, crypt.base64decode(salt), iterations)
	local client_key = crypt.hmac_sha1(salted_pass, "Client Key")
	local stored_key = crypt.sha1(client_key)
	local auth_msg = first_bare .. ',' .. parsed_s .. ',' .. without_proof
	local client_sig = crypt.hmac_sha1(stored_key, auth_msg)
	local client_key_xor_sig = crypt.xor_str(client_key, client_sig)
	local client_proof = "p=" .. crypt.base64encode(client_key_xor_sig)
	local client_final = crypt.base64encode(without_proof .. ',' .. client_proof)
	local server_key = crypt.hmac_sha1(salted_pass, "Server Key")
	local server_sig = crypt.base64encode(crypt.hmac_sha1(server_key, auth_msg))

	r = self:runCommand("saslContinue",1,"conversationId",conversationId,"payload",client_final)
	if r.ok ~= 1 then
		return false
	end
	parsed_s = crypt.base64decode(r['payload'])
	parsed_t = {}
	for k, v in string.gmatch(parsed_s, "(%w+)=([^,]*)") do
		parsed_t[k] = v
	end
	if parsed_t['v'] ~= server_sig then
		print("Server returned an invalid signature.")
		return false
	end
	if not r.done then
		r = self:runCommand("saslContinue",1,"conversationId",conversationId,"payload","")
		if r.ok ~= 1 then
			return false
		end
		if not r.done then
			print("SASL conversation failed to complete.")
			return false
		end
	end
	return true
end

local function get_reply(sock, result)
	local length = driver.length(socket.read(sock, 4))
	local reply = socket.read(sock, length)
	return reply, driver.reply(reply, result)
end

function mongo_db:runCommand(cmd,cmd_v,...)
	local request_id = self.connection:genId()
	local sock = self.connection.__sock
	local bson_cmd
	if not cmd_v then
		bson_cmd = bson_encode_order(cmd,1)
	else
		bson_cmd = bson_encode_order(cmd,cmd_v,...)
	end
	local pack = driver.query(request_id, 0, self.__cmd, 0, 1, bson_cmd)
	-- todo: check send
	socket.write(sock, pack)

	local _, succ, reply_id, doc = get_reply(sock)
	assert(request_id == reply_id, "Reply from mongod error")
	-- todo: check succ
	return bson_decode(doc)
end

function mongo_db:getCollection(collection)
	local col = {
		connection = self.connection,
		name = collection,
		full_name = self.full_name .. "." .. collection,
		database = self.database,
	}
	self[collection] = setmetatable(col, collection_meta)
	return col
end

mongo_collection.getCollection = mongo_db.getCollection

function mongo_collection:insert(doc)
	if doc._id == nil then
		doc._id = bson.objectid()
	end
	local sock = self.connection.__sock
	local pack = driver.insert(0, self.full_name, bson_encode(doc))
	-- todo: check send
	-- flags support 1: ContinueOnError
	socket.write(sock, pack)
end

function mongo_collection:batch_insert(docs)
	for i=1,#docs do
		if docs[i]._id == nil then
			docs[i]._id = bson.objectid()
		end
		docs[i] = bson_encode(docs[i])
	end
	local sock = self.connection.__sock
	local pack = driver.insert(0, self.full_name, docs)
	-- todo: check send
	socket.write(sock, pack)
end

function mongo_collection:update(selector,update,upsert,multi)
	local flags = (upsert and 1 or 0) + (multi and 2 or 0)
	local sock = self.connection.__sock
	local pack = driver.update(self.full_name, flags, bson_encode(selector), bson_encode(update))
	-- todo: check send
	socket.write(sock, pack)
end

function mongo_collection:delete(selector, single)
	local sock = self.connection.__sock
	local pack = driver.delete(self.full_name, single, bson_encode(selector))
	-- todo: check send
	socket.write(sock, pack)
end

function mongo_collection:findOne(query, selector)
	local request_id = self.connection:genId()
	local sock = self.connection.__sock
	local pack = driver.query(request_id, 0, self.full_name, 0, 1, query and bson_encode(query) or empty_bson, selector and bson_encode(selector))

	-- todo: check send
	socket.write(sock, pack)

	local _, succ, reply_id, doc = get_reply(sock)
	assert(request_id == reply_id, "Reply from mongod error")
	-- todo: check succ
	return bson_decode(doc)
end

function mongo_collection:find(query, selector)
	return setmetatable( {
		__collection = self,
		__query = query and bson_encode(query) or empty_bson,
		__selector = selector and bson_encode(selector),
		__ptr = nil,
		__data = nil,
		__cursor = nil,
		__document = {},
		__flags = 0,
	} , cursor_meta)
end

function mongo_cursor:hasNext()
	if self.__ptr == nil then
		if self.__document == nil then
			return false
		end
		local conn = self.__collection.connection
		local request_id = conn:genId()
		local sock = conn.__sock
		local pack
		if self.__data == nil then
			pack = driver.query(request_id, self.__flags, self.__collection.full_name,0,0,self.__query,self.__selector)
		else
			if self.__cursor then
				pack = driver.more(request_id, self.__collection.full_name,0,self.__cursor)
			else
				-- no more
				self.__document = nil
				self.__data = nil
				return false
			end
		end

		--todo: check send
		socket.write(sock, pack)

		local data, succ, reply_id, doc, cursor = get_reply(sock, self.__document)
		assert(request_id == reply_id, "Reply from mongod error")
		if succ then
			if doc then
				self.__data = data
				self.__ptr = 1
				self.__cursor = cursor
				return true
			else
				self.__document = nil
				self.__data = nil
				self.__cursor = nil
				return false
			end
		else
			self.__document = nil
			self.__data = nil
			self.__cursor = nil
			if doc then
				local err = bson_decode(doc)
				error(err["$err"])
			else
				error("Reply from mongod error")
			end
		end
	end

	return true
end

function mongo_cursor:next()
	if self.__ptr == nil then
		error "Call hasNext first"
	end
	local r = bson_decode(self.__document[self.__ptr])
	self.__ptr = self.__ptr + 1
	if self.__ptr > #self.__document then
		self.__ptr = nil
	end

	return r
end

function mongo_cursor:close()
	-- todo: warning hasNext after close
	if self.__cursor then
		local sock = self.__collection.connection.__sock
		local pack = driver.kill(self.__cursor)
		-- todo: check send
		socket.write(sock, pack)
	end
end

return mongo