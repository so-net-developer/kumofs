#!/usr/bin/env ruby

require 'rubygems'
require 'memcache'

host = 'localhost:11211'

mem = MemCache.new host


for i in 1..ARGV[0].to_i do
  value = mem.get('counter',true)
  value = value.to_i + 1
  mem.set('counter',value,0, true)
end

