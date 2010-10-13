#!/usr/bin/env ruby

require 'rubygems'
require 'memcache'

host = 'localhost:11211'

mem = MemCache.new host

for i in 1..ARGV[0].to_i do
  begin ret = mem.cas('counter',0,true) do |value|
      value.to_i + 1
    end 
  end until ret == "STORED\r\n"
end

