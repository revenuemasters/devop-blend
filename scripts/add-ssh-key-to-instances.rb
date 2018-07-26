#!/usr/bin/env ruby

require 'net/ssh'
require 'optparse'
require 'parallel'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: bundle exec ./scripts/add-ssh-key-to-instances.rb -k 'keyhere' -u ubuntu -s 1.2.3.4,3.2.34.3,43.2.4.2"

  opts.on('-k', '--key KEY', 'The public ssh key to add to the instances') do |k|
    options[:key] = k
  end

  opts.on('-u', '--user USER', 'The user to connect with and add the key to') do |u|
    options[:user] = u
  end

  opts.on('-s', '--servers SERVERS', 'Comma separated list of servers') do |s|
    options[:servers] = s
  end
end

begin
  optparse.parse!
  required = [:key, :user, :servers]
  missing = required.reject { |p| options[p] }
  unless missing.empty?
    puts "Missing option#{'s' if missing.size != 1}: #{missing.join(', ')}"
    puts optparse
    exit
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

ips = options[:servers].split(',').map(&:strip)

puts options[:key]
puts ips.inspect

Parallel.map(ips, :in_threads => ips.size) do |ip|
  puts "Adding key to #{ip}..."
  ssh = Net::SSH.start(ip, options[:user])
  ssh.exec!(%Q(grep -q -F '#{options[:key]}' ~/.ssh/authorized_keys || echo '#{options[:key]}' >> ~/.ssh/authorized_keys))
  ssh.close
end
puts 'All done!'
