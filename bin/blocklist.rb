#!/usr/local/bin/ruby -w

require 'ipaddr'
require 'json'
require 'pp'

DNS_CACHE_FILE = '/var/db/blacklistd.dns.json'.freeze
CC_CACHE_FILE = '/var/db/blacklistd.cc.json'.freeze

def get_dns( ip )
  return @dns_cache[ ip ] if @dns_cache.key?( ip )

  `host '#{ip}'`.split( "\n" ).each do |line|
    return 'not found' if line =~ /not found/
    return line.split( /[\s]/ ).last if line =~ /domain name pointer/

    return line
  end
  nil
end

def get_cached_dns( ip )
  return @dns_cache[ ip ] if @dns_cache.key?( ip )

  @dns_cache[ ip ] = get_dns( ip )
end

def get_cc( ip )
  `whois '#{ip}'`.split( "\n" ).each do |line|
    # pp line
    case line
    when /^country:/i
      return line.split( ':', 2 ).last.strip
    end
  end
  exit 1
end

def get_cached_cc( ip )
  return @cc_cache[ ip ] if @cc_cache.key?( ip )

  @cc_cache[ ip ] = get_cc( ip )
end

def load_json( filename )
  result = {}
  if File.exist?( filename )
    raw = File.read( filename )
    result = JSON.parse( raw )
  end
  result
end

def load_cache
  @dns_cache = load_json( DNS_CACHE_FILE )
  @cc_cache = load_json( CC_CACHE_FILE )
end

def save_cache
  File.write( DNS_CACHE_FILE, JSON.dump( @dns_cache ) + "\n" )
  File.write( CC_CACHE_FILE, JSON.dump( @cc_cache ) + "\n" )
end

load_cache
list = []
raw = `blacklistctl dump -b -n`
# pp raw
raw.split( "\n" ).each do |line|
  address_port, state, _nfail, access = line.split( "\t", 4 )
  list.push( [ access, address_port, state ] )
end
list.sort.each do |row|
  access, address_port, state = row
  # p [ address_port, access ]
  ip = address_port.split( '/' ).first.strip
  cc = get_cached_cc( ip )
  dns = get_cached_dns( ip )
  white =
    case state
    when 'OK'
      ''
    else
      'OK/'
    end
  puts "#{address_port}\t#{access}\t#{white}#{cc}\t#{dns}"
end
save_cache

exit 0
# eof
