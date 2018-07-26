package 'software-properties-common'
apt_repository 'certbot' do
  uri 'http://ppa.launchpad.net/certbot/certbot/ubuntu'
  distribution node['lsb']['codename']
  components ['main']
  keyserver 'keyserver.ubuntu.com'
  key '75BCA694'
end
package 'certbot'

directory '/root/scripts'

cookbook_file '/root/scripts/backup-letsencrypt.sh' do
  source 'scripts/backup-letsencrypt.sh'
  owner 'root'
  group 'root'
  mode '0754'
  action :create
end

cookbook_file '/root/scripts/restore-letsencrypt.sh' do
  source 'scripts/restore-letsencrypt.sh'
  owner 'root'
  group 'root'
  mode '0754'
  action :create
end

execute 'restore letsencrypt backups' do
  # Restore backups so we don't request new certs unless needed. https://letsencrypt.org/docs/rate-limits/
  command "/root/scripts/restore-letsencrypt.sh -s #{node['cfn']['properties']['backups_bucket']} -r #{node['cfn']['properties']['role']} >> /var/log/letsencrypt_backups.log 2>&1"
  ignore_failure true
end

if node.role?('app')
  node['cfn']['application_stack']['config']['sites'].each do |site, params|
    args = [
      '--non-interactive',
      '--agree-tos',
      '--email revenuemasters-notifications@revenuemasters.com',
      '--webroot',
      "-w /var/www/#{site}/current/public",
      "-d #{params['host']}"
    ]
    # This acts as a renewal when certs already exist (but won't reload apache)
    execute "certbot certonly #{args.join(' ')} >> /var/log/certbot.log 2>&1" do
      ignore_failure true
      # this will get picked up in the cron
      not_if { File.exists?("/etc/letsencrypt/live/#{params['host']}/cert.pem") }
    end
    if params['api_importer_enabled']
      api_host = "api-#{site}.#{node['cfn']['properties']['hosted_zone_name']}".chop
      args = [
        '--non-interactive',
        '--agree-tos',
        '--email revenuemasters-notifications@revenuemasters.com',
        '--webroot',
        "-w /var/www/api-#{site}/current/public",
        "-d #{api_host}"
      ]
      # This acts as a renewal when certs already exist (but won't reload apache)
      execute "certbot certonly #{args.join(' ')} >> /var/log/certbot.log 2>&1" do
        ignore_failure true
        not_if { File.exists?("/etc/letsencrypt/live/#{api_host}/cert.pem") }
      end
    end
  end
  if node['cfn']['application_stack']['config']['cvc_enabled']
    cvc_host = "cvc-#{node['cfn']['properties']['env_name']}.#{node['cfn']['properties']['hosted_zone_name']}".chop
    args = [
      '--non-interactive',
      '--agree-tos',
      '--email revenuemasters-notifications@revenuemasters.com',
      '--webroot',
      "-w /var/www/cvcpath/current/public",
      "-d #{cvc_host}"
    ]
    # This acts as a renewal when certs already exist (but won't reload apache)
    execute "certbot certonly #{args.join(' ')} >> /var/log/certbot.log 2>&1" do
      ignore_failure true
      not_if { File.exists?("/etc/letsencrypt/live/#{cvc_host}/cert.pem") }
    end
  end
end
if node.role?('sftp') # edi_ui
  edi_ui_host = "edi-#{node['cfn']['properties']['env_name']}.#{node['cfn']['properties']['hosted_zone_name']}".chop
  args = [
    '--non-interactive',
    '--agree-tos',
    '--email revenuemasters-notifications@revenuemasters.com',
    '--webroot',
    "-w /var/www/edi_ui/current/public",
    "-d #{edi_ui_host}"
  ]
  # This acts as a renewal when certs already exist (but won't reload apache)
  execute "certbot certonly #{args.join(' ')} >> /var/log/certbot.log 2>&1" do
    ignore_failure true
    not_if { File.exists?("/etc/letsencrypt/live/#{edi_ui_host}/cert.pem") }
  end
end
backup_command = "/root/scripts/backup-letsencrypt.sh -d #{node['cfn']['properties']['backups_bucket']} -r #{node['cfn']['properties']['role']} >> /var/log/letsencrypt_backups.log 2>&1"
execute backup_command do
  ignore_failure true
end
cron 'backup lets encrypt certs' do
  user 'root'
  hour '*/12'
  minute '10'
  command backup_command
end

file '/etc/cron.d/certbot' do
  action :delete # The auto-installed cron job doesn't have the post-hook we need.
end

cron 'renew lets encrypt certs' do
  user 'root'
  hour '*/12'
  minute '0'
  command 'certbot renew --post-hook "service apache2 reload" >> /var/log/certbot.log 2>&1'
end

logrotate_app 'certbot' do
  path '/var/log/certbot.log'
  rotate 5
  create '640 root root'
end
