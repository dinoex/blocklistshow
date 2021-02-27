#!/usr/local/bin/ruby

require 'ipaddr'
require 'bdb'

# pkg install databases/ruby-bdb net/webalizer-geodb
GEODB_FILE = '/usr/local/share/geolizer/GeoDB.dat'.freeze

def geodb_key( ip )
  ip2 = IPAddr.new( ip )
  return ip2.hton if ip2.ipv6?

  "\0\0\0\0\0\0\0\0\0\0\0\0#{ip2.hton}"
end

def get_cc( ip )
  db = BDB::Btree.open(
    GEODB_FILE, nil, BDB::RDONLY, 0o0644,
    'set_pagesize' => 1024, 'set_cachesize' => [ 0, 32 * 1024, 0 ]
  )
  country = db.cursor.set_range( geodb_key( ip ) )[ 1 ][ 0 .. 1 ]
  db.close
  country
end

ARGV.each do |ip|
  cc = get_cc( ip )
  puts "#{ip}\t#{cc}"
end

exit 0
# eof
