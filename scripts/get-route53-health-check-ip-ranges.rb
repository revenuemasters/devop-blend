#!/usr/bin/env ruby

# https://forums.aws.amazon.com/ann.jspa?annID=1838

require 'json'
require 'net/http'
require 'uri'

uri           = URI.parse('https://ip-ranges.amazonaws.com/ip-ranges.json')
response      = Net::HTTP.get_response(uri)
json_response = JSON.parse(response.body)

json_response['prefixes'].each do |prefix|
  puts prefix['ip_prefix'] if prefix['service'] == 'ROUTE53_HEALTHCHECKS'
end
