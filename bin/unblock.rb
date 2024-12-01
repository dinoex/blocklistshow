#!/usr/local/bin/ruby

def find_files( list )
  list.each do |filename|
    next if filename == ''

    return filename if File.exist?( filename )
  end

  list.first
end

BDB_FILES = [
  '/var/db/blocklistd.db',
  '/var/db/blacklistd.db'
].freeze

HELPER_FILES = [
  '/usr/local/libexec/blocklistd-helper',
  '/usr/libexec/blacklistd-helper',
  '/libexec/blocklistd-helper'
].freeze

BDB_FILE = find_files( BDB_FILES ).freeze
HELPER_FILE = find_files( HELPER_FILES ).freeze

LOCAL_BDB_FILE_MODE = 0o0600
LOCAL_BDB_OPTIONS = { 'set_pagesize' => 1024, 'set_cachesize' => 32 * 1024 }.freeze

require 'ipaddr'
require 'bdb1'

# /usr/src/contrib/blacklist/bin/conf.h
#  struct conf {
#         struct sockaddr_storage c_ss;
#         int                     c_lmask;
#         int                     c_port;
#         int                     c_proto;
#         int                     c_family;
#         int                     c_uid;
#         int                     c_nfail;
#         char                    c_name[128];
#         int                     c_rmask;
#         int                     c_duration;
# };

# /usr/src/contrib/blacklist/bin/state.h
# struct dbinfo {
#         int count;
#         time_t last;
#         char id[64];
# };

# /usr/include/sys/_sockaddr_storage.h
# struct sockaddr_storage {
#         unsigned char   ss_len;         /* address length */
#         sa_family_t     ss_family;      /* address family */
#         char            __ss_pad1[_SS_PAD1SIZE];
#         __int64_t       __ss_align;     /* force desired struct alignment */
#         char            __ss_pad2[_SS_PAD2SIZE];
# };

def decode_ip( key, afamily )
  case afamily
  when 2
    off = 4
    key[ off .. ].unpack( 'C4' ).join( '.' )
  when 28
    off = 8
    IPAddr::IN6FORMAT % key[ off .. ].unpack( 'n8' )
  else
    raise IPAddr::AddressFamilyError, 'unsupported address family'
  end
end

def ip_from_key( key )
  # puts "size: #{key.size}"

  # len = key.unpack1( 'C' )
  # puts "len: #{len}"

  af = key[ 1 .. 1 ].unpack1( 'C' )
  # puts "af: #{af}"

  ip = decode_ip( key, af )
  # puts "ip: #{ip}"

  IPAddr.new( ip )
end

def search_db( dbh, list )
  found = []
  dbh.each_key do |key|
    # pp key, val
    ip2 = ip_from_key( key ).to_s
    next unless list.include?( ip2 )

    puts "ip2: #{ip2}"
    found.push( key )
  end
  found
end

PROTOCOLS = {
  6 => 'tcp',
  17 => 'udp',
  132 => 'sctp'
}.freeze

def decode_key( key )
  af = key[ 1 .. 1 ].unpack1( 'C' )
  {
    af: af,
    ip: decode_ip( key, af ),
    mask: key[ 128 .. 131 ].unpack1( 'L' ),
    port: key[ 132 .. 135 ].unpack1( 'L' ),
    proto: PROTOCOLS[ key[ 136 .. 139 ].unpack1( 'L' ) ],
    family: key[ 140 .. 143 ].unpack1( 'L' ),
    uid: key[ 144 .. 147 ].unpack1( 'L' ),
    nfail: key[ 148 .. 151 ].unpack1( 'L' ),
    name: key[ 152 .. 279 ].delete( "\0" ),
    rmask: key[ 280 .. 283 ].unpack1( 'L' ),
    duration: key[ 284 .. 287 ].unpack1( 'L' )
  }
end 

def decode_data( key )
  {
    count: key[ 0 .. 3 ].unpack1( 'L' ),
    pad1: key[ 4 .. 7 ].unpack1( 'L' ),
    time1: Time.at( key[ 8 .. 11 ].unpack1( 'L' ) ),
    time2: key[ 12 .. 15 ].unpack1( 'L' ),
    text: key[ 16 .. 79 ].delete( "\0" )
  }
end 

def remove_db( dbh, found )
  removed = 0
  found.each do |key|
    # pp key
    h = decode_key( key )
    # data = dbh[ key ]
    # pp decode_data( data )
    dbh.delete( key )
    # pp h
    line = "#{HELPER_FILE} 'rem' '#{h[ :name ]}' '#{h[ :proto ]}' '#{h[ :ip ]}' '#{h[ :mask ]}' '#{h[ :port ]}' '#{h[ :uid ]}'"
    puts line
    `#{line}`
    removed += 1
  end
  puts "removed: #{removed}"
  dbh.sync
  dbh.close
end

if ARGV.empty?
  warn "#{$0} IP-Addresss [ IP-Addresss ] [ ... ]"
  exit 64
end

dbh = BDB1::Hash.open( BDB_FILE,
                       BDB1::WRITE | BDB1::CREATE,
                       LOCAL_BDB_FILE_MODE,
                       LOCAL_BDB_OPTIONS )
found = search_db( dbh, ARGV )
remove_db( dbh, found )

# eof
