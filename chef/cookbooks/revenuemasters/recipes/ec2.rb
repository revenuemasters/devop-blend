['python-setuptools', 'python-pip', 'ruby2.0'].each do |p|
  package p
end

# tell ohai we are on ec2
%w[ /etc/chef /etc/chef/ohai /etc/chef/ohai/hints ].each do |path|
  directory path do
    owner 'root'
    group 'root'
    mode  '0755'
  end
end
file '/etc/chef/ohai/hints/ec2.json' do
  action :touch
  owner 'root'
  group 'root'
  mode '0644'
end
file '/etc/chef/ohai/hints/iam.json' do
  action :touch
  owner 'root'
  group 'root'
  mode '0644'
end

# ec2net for ubuntu
# https://github.com/ademaria/ubuntu-ec2net
['53-ec2-network-interfaces.rules', '75-persistent-net-generator.rules'].each do |rule_file|
  remote_file "/etc/udev/rules.d/#{rule_file}" do
    source "https://raw.githubusercontent.com/ademaria/ubuntu-ec2net/master/#{rule_file}"
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end
end
remote_file '/etc/dhcp/dhclient-exit-hooks.d/ec2dhcp' do
  source 'https://raw.githubusercontent.com/ademaria/ubuntu-ec2net/master/ec2dhcp'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end
remote_file '/etc/network/ec2net-functions' do
  source 'https://raw.githubusercontent.com/ademaria/ubuntu-ec2net/master/ec2net-functions'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end
remote_file '/etc/network/ec2net.hotplug' do
  source 'https://raw.githubusercontent.com/ademaria/ubuntu-ec2net/master/ec2net.hotplug'
  owner 'root'
  group 'root'
  mode '0744'
  action :create
end

# cloudformation tools
installed_file_path = '/root/.aws-cfn-bootstrap-installed'
execute 'install aws-cfn-bootstrap' do
  command 'easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz'
  not_if { File.exists?(installed_file_path) }
  notifies :run, 'execute[touch-installed]', :immediately
end
execute 'touch-installed' do
  command  "touch #{installed_file_path}"
  action :nothing
end
# aws cli
aws_cli_installed = '/root/.aws-cli-installed'
execute 'install aws cli tools' do
  command 'pip install awscli'
  not_if { File.exists?(aws_cli_installed) }
  notifies :run, 'execute[touch-aws-cli-installed]', :immediately
end
execute 'touch-aws-cli-installed' do
  command "touch #{aws_cli_installed}"
  action :nothing
end
link '/usr/bin/aws' do
  to '/usr/local/bin/aws'
end

include_recipe 'chef_cfn::ohai'
