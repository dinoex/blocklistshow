# Blocklist

Display of data from blocklistd on FreeBSD with country codes and reverse DNS.
The reverse DNS and the country codes are cached.

## Installation

Install it on the server running blocklistd by:

    $ pkg install databases/ruby-bdb net/webalizer-geodb
    $ gem install blocklistshow

## Usage

    ########################
    # Example 1 Full list
    ########################

    $ blocklist.rb

    ###############################
    # Example 2 Filtered by port
    ###############################

    $ blocklist.rb 25

    #######################################
    # Example 3 Filtered by country code
    #######################################

    $ blocklist.rb eu

### File formats

The cache files are stored as JSON.
The Geolocation datebase is a Berkeley DB file.

