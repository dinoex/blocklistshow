# blocklist.gemspec
Gem::Specification.new do |s|
  s.required_ruby_version = '>= 2.7'
  s.name = 'blocklistshow'
  s.version = '1.1'
  s.summary = 'show blocklistd data'
  s.description = 'Display of data from blocklistd on FreeBSD with country codes and reverse DNS.'
  s.authors = ['Dirk Meyer']
  s.homepage = 'https://rubygems.org/gems/blocklistshow'
  s.licenses = ['MIT']
  s.executables = ['blocklist.rb', 'geodb-lookup.rb' ]
  s.extra_rdoc_files = ['LICENSE.txt', 'README.md']
  s.files = ['.rubocop.yml']
  s.files += Dir['[A-Z]*']
  # s.add_runtime_dependency 'bdb', ['~> 0.6', '>= 0.6.6']
  # s.add_runtime_dependency 'bdb1', ['~> 0.2.5', '>= 0.2.5']
end
