local ltask = require "ltask"

local arg = ...

print "Bootstrap Begin"
print(os.date("%c", (ltask.now())))

local addr = ltask.spawn("myuser", "Hello")

print("Spawn user", addr)



print "Bootstrap End"
