#!/usr/local/bin/ruby

require 'ipaddr'
require 'json'
require 'pp'

DNS_CACHE_FILE = '/var/db/blacklistd.dns.json'.freeze
CC_CACHE_FILE = '/var/db/blacklistd.cc.json'.freeze

# pkg install databases/ruby-bdb net/webalizer-geodb
GEODB_FILE = '/usr/local/share/geolizer/GeoDB.dat'.freeze

def get_dns( ip )
  return @dns_cache[ ip ] if @dns_cache.key?( ip )

  result = nil
  `host '#{ip}'`.split( "\n" ).each do |line|
    return 'not found' if line =~ /not found/
    return line.split( /\s/ ).last if line =~ /domain name pointer/

    result = line
  end
  result
end

def get_cached_dns( ip )
  return @dns_cache[ ip ] if @dns_cache.key?( ip )

  @dns_cache[ ip ] = get_dns( ip )
end

def get_whois( ip )
  country = nil
  last = nil
  inetnum = false
  `whois '#{ip}'`.force_encoding( 'BINARY' ).split( "\n" ).each do |line|
    # pp line
    case line
    when /^$/
      inetnum = false
    when /^inetnum:/i
      inetnum = true
    when /^country:/i
      last = line.split( ':', 2 ).last.strip
      next unless inetnum

      country = last
    end
  end
  country = last if country.nil?
  country
end

def get_cached_whois( ip )
  return @cc_cache[ ip ] if @cc_cache.key?( ip ) && !@cc_cache[ ip ].nil?

  @cc_cache[ ip ] = get_whois( ip )
end

def geodb_key( ip )
  ip2 = IPAddr.new( ip )
  return ip2.hton if ip2.ipv6?

  "\0\0\0\0\0\0\0\0\0\0\0\0#{ip2.hton}"
end

def get_cc( ip )
  if @db.nil?
    @db = BDB::Btree.open(
      GEODB_FILE, nil, BDB::RDONLY, 0o0644,
      'set_pagesize' => 1024, 'set_cachesize' => [ 0, 32 * 1024, 0 ]
    )
  end
  @db.cursor.set_range( geodb_key( ip ) )[ 1 ][ 0 .. 1 ]
end

def get_cached_cc( ip )
  if @cc_cache.nil?
    get_cc( ip )
  else
    get_cached_whois( ip )
  end
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
  @cc_cache =
    if File.exist?( GEODB_FILE )
      require 'bdb'
      nil
    else
      load_json( CC_CACHE_FILE )
    end
end

def save_cache
  File.write( DNS_CACHE_FILE, "#{JSON.dump( @dns_cache )}\n" )
  return if @cc_cache.nil?

  File.write( CC_CACHE_FILE, "#{JSON.dump( @cc_cache )}\n" )
end

@db = nil

filter_cc = nil
filter_port = 0
until ARGV.empty?
  option = ARGV.shift
  case option
  when 'test'
    ip = ARGV.shift
    @dns_cache = {}
    @cc_cache = {}
    p get_dns( ip )
    if File.exist?( GEODB_FILE )
      require 'bdb'
      p get_cc( ip )
    else
      p get_whois( ip )
    end
    exit 0
  when /^[0-9]+$/
    filter_port = option.to_i
  when /^[a-z][a-z]$/
    filter_cc = option
  else
    warn "Fehler #{option}"
    exit 65
  end
end

load_cache
list = []
raw = `blacklistctl dump -b -n -w`
# pp raw
raw.split( "\n" ).each do |line|
  address_port, state, _nfail, access = line.split( "\t", 4 )
  list.push( [ access, address_port, state ] )
end
list.sort.each do |row|
  access, address_port, state = row
  # p [ address_port, access ]
  address_port.strip!
  pair = address_port.split( '/' )
  port = pair.last.split( ':' ).last.to_i
  next unless filter_port.zero? && port != filter_port

  ip = pair.first.strip
  cc = get_cached_cc( ip )
  next unless filter_cc.nil? && cc != filter_cc

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
