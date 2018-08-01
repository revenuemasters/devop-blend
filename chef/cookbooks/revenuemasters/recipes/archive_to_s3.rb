directory '/root/scripts'

cookbook_file '/root/scripts/archive-to-s3.sh' do
  source 'scripts/archive-to-s3.sh'
  owner 'root'
  group 'root'
  mode '0754'
  action :create
end

destination_bucket = "#{node['cfn']['properties']['co_name']}-#{node['cfn']['properties']['env_name']}-backups"
destination_key = "filesystems/#{node['cfn']['properties']['role']}/#{node['s3_archives']['source_path'].sub(%r{^/*}, '').sub(%r{/*$}, '').tr('/', '-')}"
source_retention_days = node['cfn']['properties']['env_name'] == 'dev-1' ? '5' : node['s3_archives']['source_retention_days']

cron "backup #{node['s3_archives']['source_path']}" do
  minute '0'
  hour '8'
  user 'root'
  command "/root/scripts/archive-to-s3.sh -s #{node['s3_archives']['source_path']} -b #{destination_bucket} -k #{destination_key} -d #{source_retention_days}\n"
end

logrotate_app 'archive-to-s3' do
  path '/var/log/archive_to_s3.log'
  rotate 5
  create '640 root root'
end
