include_recipe 'apt'
include_recipe 'revenuemasters::auditd'
include_recipe 'revenuemasters::ec2'
co_name = node['cfn']['properties']['co_name'] rescue '' # falling back to this incase ruby isn't >= 2.3 for hash#dig

node.default['aws_cwlogs']['region'] = node['cfn']['vpc']['region_id']
node.default['aws_cwlogs']['log']['archive_to_s3'] = {
  'file' => '/var/log/archive_to_s3.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-archive-to-s3"
}
node.default['aws_cwlogs']['log']['auditd'] = {
  'file' => '/var/log/audit/audit.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-auditd"
}
node.default['aws_cwlogs']['log']['auth'] = {
  'file' => '/var/log/auth.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-auth"
}
node.default['aws_cwlogs']['log']['certbot'] = {
  'file' => '/var/log/certbot.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-certbot"
}
node.default['aws_cwlogs']['log']['cfn-init-cmd'] = {
  'file' => '/var/log/cfn-init-cmd.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-cfn-init-cmd"
}
node.default['aws_cwlogs']['log']['cloud-init-output'] = {
  'file' => '/var/log/cloud-init-output.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-cloud-init-output"
}
node.default['aws_cwlogs']['log']['codedeploy-agent'] = {
  'file' => '/var/log/aws/codedeploy-agent/codedeploy-agent.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-codedeploy-agent"
}
node.default['aws_cwlogs']['log']['codedeploy-deployment'] = {
  'file' => '/opt/codedeploy-agent/deployment-root/*/*/logs/scripts.log',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-codedeploy-deployment"
}
node.default['aws_cwlogs']['log']['syslog'] = {
  'file' => '/var/log/syslog',
  'log_stream_name' => '{instance_id}',
  'initial_position' => 'start_of_file',
  'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-syslog"
}

package 'git'
# https://github.com/alexism/cloudwatch_monitoring/issues/7
package 'libswitch-perl'

include_recipe 'ntp'
include_recipe 'sudo'

%w{ git ruby tree vim emacs jq }.each do |p|
  package p
end

chef_gem 'aws-sdk' do
  version '2.2.31'
end

include_recipe 'revenuemasters::staff'
include_recipe 'revenuemasters::ascii_greeting'
include_recipe 'revenuemasters::cross-account-access'
include_recipe 'revenuemasters::clamav'

node.set['citadel']['bucket'] = node['cfn']['properties']['secrets_bucket']

# install deploy key for devops repo
directory '/root/.ssh/keys' do
  user 'root'
  group 'root'
  action :create
end

directory '/root/src' do
  user 'root'
  group 'root'
  action :create
end

ssh_known_hosts_entry 'github.com'

file '/root/.ssh/id_rsa.pub' do
  user 'root'
  group 'root'
  mode '0644'
  action :create
  content citadel["#{co_name}-deploy-user-key.pub"]
  sensitive true
end

file '/root/.ssh/id_rsa' do
  user 'root'
  group 'root'
  mode '0600'
  action :create
  content citadel["#{co_name}-deploy-user-key"]
  sensitive true
end

file '/root/src/solo.rb' do
  owner 'root'
  group 'root'
  mode '0400'
  content "cookbook_path ['/root/src/devops/chef/berks-cookbooks']\n"
end

# unpack application stack config variable and set default config attribute
config_json = node['cfn']['properties']['config']
node.default['cfn']['application_stack']['config'] = JSON.parse(config_json) rescue {}
