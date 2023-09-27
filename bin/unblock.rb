#!/usr/local/bin/ruby

BDB_FILE = '/var/db/blacklistd.db'.freeze
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

def ip_from_key( key )
  off = 4
  # puts "size: #{key.size}"

  len = key.unpack( 'C' ).first
  # puts "len: #{len}"

  af = key[ 1 .. 1 ].unpack( 'C' ).first
  # puts "af: #{af}"

  ip =
    case af
    when 2
      off = 4
      key[ off .. ].unpack('C4').join('.')
    when 28
      off = 8
      IPAddr::IN6FORMAT % key[ off .. ].unpack('n8')
    else
      raise IPAddr::AddressFamilyError, "unsupported address family"
    end

  # puts "ip: #{ip}"
  IPAddr.new( ip )
end

def search_db( dbh, list )
  found = []
  dbh.each_pair do |key, val|
    # pp key, val
    ip2 = ip_from_key( key ).to_s
    next unless list.include?( ip2 )

    puts "ip2: #{ip2}"
    found.push( key )
  end
  found
end

def remove_db( dbh, found )
  removed = 0
  found.each do |key|
    dbh.delete( key )
    removed +=1
  end
  puts "removed: #{removed}"
  dbh.sync
  dbh.close
end

dbh = BDB1::Hash.open( BDB_FILE,
                       BDB1::WRITE | BDB1::CREATE,
                       LOCAL_BDB_FILE_MODE,
                       LOCAL_BDB_OPTIONS )
found = search_db( dbh, ARGV )
remove_db( dbh, found )

# eof
