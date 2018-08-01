# sftp server
# http://www.thegeekstuff.com/2012/03/chroot-sftp-setup/

package 'mysql-client-5.6'

hostsfile_entry node['cfn']['properties']['importer_private_ip'] do
  hostname 'importer'
  action :create
end if node['cfn']['properties']['importer_private_ip']

ssh_known_hosts_entry node['cfn']['properties']['importer_private_ip']

chroot_base = '/encrypted/sftp'

cookbook_file '/root/src/archive-incoming.sh' do
  source 'scripts/archive-incoming.sh'
  mode '0755'
end

group 'sftpusers' do
  gid 2000
end

['/encrypted', chroot_base].each do |dir|
  directory dir do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

include_recipe 'openssh'
# see attributes.rb for other settings
node.default['openssh']['server']['match'] = {
  'Group sftpusers' => {
    'chroot_directory'     => "#{chroot_base}/%u",
    'force_command'        => 'internal-sftp',
    'x11_forwarding'       => 'no',
    'allow_tcp_forwarding' => 'no'
  }
}

# each 'site' can sFTP
node['cfn']['application_stack']['config']['sites'].each do |site, params|
  directory "#{chroot_base}/#{site}"
  user_account site do
    comment "sftp user for #{site}"
    ssh_keygen false
    manage_home false
    shell '/sbin/nologin'
    home '/incoming'
    # https://docs.chef.io/resource_user.html#password-shadow-hash
    # openssl passwd -1 "theplaintextpassword"
    password citadel["#{site}-password"].chomp
    uid params['uid']
  end
  group 'sftpusers' do
    action :modify
    members site
    append true
  end
  directory "#{chroot_base}/#{site}/incoming" do
    owner site
    group 'sftpusers'
  end
end if node['cfn']['application_stack']['config']['sites']

# maintain ssh host keys
directory '/root/scripts'

cookbook_file '/root/scripts/upload-host-keys.sh' do
  source 'scripts/upload-host-keys.sh'
  owner 'root'
  group 'root'
  mode '0754'
  action :create
end

['dsa', 'ecdsa', 'ed25519', 'rsa'].each do |key_type|
  execute "/root/scripts/upload-host-keys.sh -s /etc/ssh/ssh_host_#{key_type}_key -d s3://#{node['citadel']['bucket']}/sftp-ssh_host_#{key_type}_key >> /root/scripts/upload-ssh-keys.log 2>&1"

  file "/etc/ssh/ssh_host_#{key_type}_key" do
    user 'root'
    group 'root'
    mode '0600'
    content lazy{citadel["sftp-ssh_host_#{key_type}_key"]}
    sensitive true
  end

  execute "/root/scripts/upload-host-keys.sh -s /etc/ssh/ssh_host_#{key_type}_key.pub -d s3://#{node['citadel']['bucket']}/sftp-ssh_host_#{key_type}_key.pub >> /root/scripts/upload-ssh-keys.log 2>&1"

  file "/etc/ssh/ssh_host_#{key_type}_key.pub" do
    user 'root'
    group 'root'
    mode '0644'
    content lazy{citadel["sftp-ssh_host_#{key_type}_key.pub"]}
  end
end

# enable ssh from internet to importer via ip chains
include_recipe 'sysctl::default'
sysctl_param 'net.ipv4.ip_forward' do
  value 1
end

include_recipe 'iptables'

iptables_rule 'sftptoimporter' do
  action :enable
  variables(
    :importer_private_ip => node['cfn']['properties']['importer_private_ip']
  )
end

# Temporary. Becaues CodeDeploy runs the last successful version during scale-up, when deploying code
# that renames a user or group with a frozen ID we have to remove the old name first or that ID will be taken (because
# it was created when the pre-rename version ran). After rename is complete this can be removed.
user '1edisource' do
  action :remove
end
group '1edisource' do
  action :remove
end

# rmedi user for picking up RAW files from within VPC
rmedi_user = 'rmedi'
group rmedi_user do
  gid 4000
end
user_account rmedi_user do
  comment "sftp user for #{rmedi_user}"
  manage_home false
  ssh_keygen false
  home '/encrypted/rmedi'
  # https://docs.chef.io/resource_user.html#password-shadow-hash
  password citadel["#{rmedi_user}-password"].chomp
  uid 3000
  gid 4000
end
directory '/encrypted/rmedi' do
  owner rmedi_user
  group rmedi_user
  mode '0700'
end

env_name = node['cfn']['properties']['env_name']

directory '/root/scripts/logs' do
  recursive true
end

cookbook_file '/root/scripts/rawfilepreprocessor.pl' do
  source 'scripts/rawfilepreprocessor.pl'
  mode '0755'
end

cookbook_file '/root/scripts/move-incoming-client-data.sh' do
  source "scripts/move-incoming-client-data-#{env_name}.sh"
  mode '0755'

  only_if do
      File.exists? File.join(
          Chef::Config[:file_cache_path],
          'cookbooks/revenuemasters',
          'files/default/scripts',
          "move-incoming-client-data-#{env_name}.sh"
      )
  end
end

cookbook_file '/root/scripts/fix-repetitive-files.php' do
  source "scripts/fix-repetitive-files.php"
  mode '0755'
end

cron 'move incoming files' do
  command "/root/scripts/move-incoming-client-data.sh > /root/scripts/logs/$(date \"+\\%Y-\\%m-\\%d-\\%H-\\%M\").log 2>&1"
  minute '*/15'
end

include_recipe 'revenuemasters::setup_awslogs' # Run here so role-specific log files defined in recipes are captured.
