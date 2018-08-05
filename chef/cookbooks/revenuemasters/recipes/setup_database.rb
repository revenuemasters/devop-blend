
package 'mysql-client-core-5.6'
package 'mysql-client-5.6'

username = 'admin'
password = citadel["rds-admin-password"].chomp
# hostname = node['cfn']['properties']['database_host']
hostname = "dd10hziikfn4yxw.cylmcithw7vx.us-east-1.rds.amazonaws.com"

mysql_cmd = "mysql --host=#{hostname} --user=#{username} --password=#{password}"

cookbook_file '/root/src/mra_base.sql.gz' do
  source 'mra_base.sql.gz'
  backup false
  mode 0640
  sensitive true
end

cookbook_file '/usr/local/bin/backup-mysql.sh' do
  source 'usr/local/bin/backup-mysql.sh'
  owner 'root'
  group 'root'
  mode '0755'
end

# cvc database
execute "create cvc database" do
  command "echo 'create database revenuemasters_cvc' | #{mysql_cmd}"
  not_if "echo 'use revenuemasters_cvc' | #{mysql_cmd}"
  sensitive true
end

node['cfn']['application_stack']['config']['sites'].each do |site, params|

  execute "create #{site} database" do
    command "echo 'create database revenuemasters_#{site}' | #{mysql_cmd}"
    not_if "echo 'use revenuemasters_#{site}' | #{mysql_cmd}"
    notifies :run, "execute[seed #{site} database]", :immediately
    sensitive true
  end

  execute "seed #{site} database" do
    action :nothing
    command "gunzip -c /root/src/mra_base.sql.gz | #{mysql_cmd} revenuemasters_#{site}"
    sensitive true
  end

  directory "/encrypted/backups/#{site}" do
    recursive true
    owner 'root'
    group 'root'
    mode '0700'
  end

  cron "database_exporter_#{site}" do
    user 'root'
    hour '9'
    minute '0'
    command "/usr/local/bin/backup-mysql.sh"
    environment({
      'MYSQL_DATABASE' => "revenuemasters_#{site}",
      'MYSQL_DUMP_DIR' => "/encrypted/backups/#{site}",
      'MYSQL_HOST'     => hostname,
      'MYSQL_PASSWORD' => password,
      'MYSQL_USER'     => username
    })
    action :delete
  end

end if node['cfn']['application_stack']['config']['sites']
