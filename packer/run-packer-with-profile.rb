#!/usr/bin/env ruby

# 'packer' wrapper supplying needed env vars from AWS profile

require 'aws-sdk'

if ARGV.size != 3
  puts "Usage: ./run-packer-with-profile.rb [profile] [env] [role]"
  puts "E.G.:  ./run-packer-with-profile.rb revenuemasters-dev dev-1 base"
  exit 1
end
profile  = ARGV[0]
env      = ARGV[1]
creds    = Aws::SharedCredentials.new(profile_name: profile)
env_vars = {
  'AWS_ACCESS_KEY' => creds.credentials.access_key_id,
  'AWS_SECRET_KEY' => creds.credentials.secret_access_key,
  'SECRETS_BUCKET' => "blendlab-#{env}-secrets",
  # 'SECRETS_BUCKET' => "revenuemasters-#{env}-secrets"
  # alias blend-dev doesn't allow bucket revenuemasters.com
}
template_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'packer', "#{ARGV[2] || 'base'}.json"))

system(env_vars, "packer build #{template_path}")
