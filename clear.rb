require 'rubygems'
require 'redis'

r = Redis.new
keys = r.keys("fuzzycomplete:*")
if keys.size > 0
  puts "Clearing #{keys.size} keys"
  r.del(*keys)
end
