#!/usr/bin/env ruby

require 'aws-sdk'
Aws.use_bundled_cert!

require File.dirname(__FILE__) + '/cfn/cloudformation_stack.rb'
Dir[File.dirname(__FILE__) + '/cfn/stacks/*.rb'].each { |file| require file }

CONFIG = YAML.load_file('envs.yml')

def converge!(env, options, profile)
  puts "Proceeding with converge. env = [ #{env} ] && profile = [ #{profile} ]"

  options[:EnvName] = env
  options['profile'] = profile

  # a bucket to store s3 logs
  logging_bucket = S3Bucket.logging_bucket(env, options)

  # a bucket to store secrets with citadel
  secrets_bucket = S3Bucket.secrets_bucket(env, options)

  # a bucket to store backups
  backups_bucket = S3Bucket.backups_bucket(env, options)

  # queues
  queue_stack = QueueStack.with_params(env, options)
  worker_queue_outputs = queue_stack.outputs

  # set worker-queue-url
  options['config']['sites'].each do |site, config|
    site_key = site.gsub(/[^0-9a-z]/i, '')

    config['worker-num-processes'] = options['worker-num-processes']
    config['worker-queue-name']    = queue_stack.outputs["WorkerQueueName#{site_key}"]
    config['worker-queue-url']     = queue_stack.outputs["WorkerQueue#{site_key}"]
  end

  # application
  logs_stack = LogGroupsStack.with_params(env, options)
  app_stack = ApplicationStack.with_params(env, options)
  options['database-host']          = app_stack.outputs['DatabaseHost']
  options['iam-instance-profile']   = app_stack.outputs['IamInstanceProfile']
  options['sns-alarm-topic']        = app_stack.outputs['SnsAlarmTopic']
  options['private-subnets']        = app_stack.outputs['PrivateSubnets']
  options['worker-security-group']  = app_stack.outputs['WorkerSecurityGroup']

  # workers
  options['config']['sites'].each do |site, config|
    o = options.dup
    # only want to enable workers for the relevant client
    o['config']['sites'][site]['worker-enabled'] = true
    stack = WorkerStack.with_params(env, site, config, o)
  end

  options['sns-alarm-topic'] = app_stack.outputs['SnsAlarmTopic']
  alarm_monitor_lambda_stack = AlarmMonitorLambda.with_params(env, options)

  # # security group allowing ssh access - used in test kitchen
  # ssh_access_sg = SecurityGroupStack.ssh_access_sg(env, options)

  # # default IAM profile - used in test kitchen and packer
  # default_iam_instance_profile = IamInstanceProfile.default_profile(env, options)
end

REGIONS_TO_SNAPSHOT = [
  {
    'create' => 'true',
    'delete' => 'true',
    'dry-run' => 'false',
    'log-level' => 'INFO',
    'max-age-days' => 60,
    'region' => 'us-east-1'
  },
  {
    'create' => 'true',
    'delete' => 'true',
    'dry-run' => 'false',
    'log-level' => 'INFO',
    'max-age-days' => 60,
    'region' => 'us-west-1'
  }
].freeze

def snapshot!(profile)
  raise 'profile required!' if profile.nil?

  puts "Proceeding with snapshot, profile = [ #{profile} ]"

  REGIONS_TO_SNAPSHOT.each do |options|
    options[:EnvName] = profile + '-' + options['region'] # There's no environment for snapshotting, it happens for a whole region.
    options['profile'] = profile # Always use the account associated with the converging env.

    VolumeSnapshotLambda.with_params(options)
  end
end

require 'optparse'
opts = {}
optparser = OptionParser.new do |o|
  o.banner = <<-USAGE
  Usage: bundle exec ./converge.rb [options] [environment]

  When using --profile, the AWS profile for all tasks will override the envs.yml entry.

  If no environment is provided, only account wide tasks will be performed, such as snapshots.
  This excludes converge which requires an explicit environment.

  Valid environment values: #{CONFIG['environments'].keys.join(', ')}

  Options:
USAGE

  opts[:profile] = nil
  o.on('-p', '--profile profile', 'AWS profile') do |p|
    opts[:profile] = p
  end
end

optparser.parse!
env = ARGV.shift

if opts[:profile].nil? && env.nil?
  puts optparser.help
  exit(1)
end

env_config = CONFIG['environments'][env]
profile = opts[:profile] || (env_config['profile'])

# Handle env specific tasks
unless env.nil? || env.empty?
  if env_config.nil?
    puts optparser.help
    exit(1)
  end

  converge!(env, env_config, profile)
end

# Run account-wide tasks
snapshot!(profile)

puts '... all done.'

