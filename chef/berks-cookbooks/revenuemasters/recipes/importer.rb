# importer recipe

# todo quickfix
# ssh_known_hosts_entry node['cfn']['properties']['sftp_dns']
ssh_known_hosts_entry sftp-dev-1.blendcopy.revenuemasters.com

# pear libraries needed for import automation scripts
include_recipe 'revenuemasters::php5'

['Mail', 'Net_SMTP'].each do |pear_lib|
  php_pear pear_lib do
    action :install
  end
end

# for putting files on sftp servers
package 'sshpass'

# sftp user stuff
chroot_base     = '/encrypted/sftp'
rmedi_user      = 'rmedi'
rmedi_user_home = "#{chroot_base}/#{rmedi_user}"
sftp_drop       = "#{rmedi_user_home}/from_rmedi"
sftp_group      = 'sftpusers'

['/encrypted', '/encrypted/users', chroot_base, rmedi_user_home].each do |dir|
  directory dir do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

data_bag('users').each do |user|
  directory "/encrypted/users/#{user}" do
    owner user
    group user
    mode "0700"
  end
end

include_recipe 'openssh'
# see attributes.rb for other settings
node.default['openssh']['server']['match'] = {
  "Group #{sftp_group}" => {
    'chroot_directory'     => "#{chroot_base}/%u",
    'force_command'        => 'internal-sftp',
    'x11_forwarding'       => 'no',
    'allow_tcp_forwarding' => 'no'
  }
}

group sftp_group do
  gid 4000
end

# Temporary. Becaues CodeDeploy runs the last successful version during scale-up, when deploying code
# that renames a user with a frozen ID we have to remove the old name first or that ID will be taken (because
# it was created when the pre-rename version ran). After rename is complete this can be removed.
user '1edisource' do
  action :remove
end

user_account rmedi_user do
  comment "sftp user for #{rmedi_user}"
  ssh_keygen false
  manage_home false
  shell '/sbin/nologin'
  home '/from_rmedi'
  # https://docs.chef.io/resource_user.html#password-shadow-hash
  password citadel["#{rmedi_user}-password"].chomp
  uid 3000
  gid 4000
end
directory sftp_drop do
  owner rmedi_user
  group sftp_group
end

directory '/encrypted/client_data' do
  owner 'root'
  group 'root'
  mode '0755'
end

directory '/root/scripts'

if node['cfn']['application_stack']['config']['sites']

  template '/root/scripts/backup-all-databases.sh' do
    mode '0755'
    source 'scripts/backup-all-databases.sh.erb'
    variables(
      {
        :database_hostname => node['cfn']['properties']['database_host'],
        :database_username => 'admin',
        :database_password => citadel['rds-admin-password'].chomp,
        :sites             => node['cfn']['application_stack']['config']['sites'].keys
      }
    )
  end

  ['carc-codes', 'diagnosis-codes', 'drg-codes', 'drg-o-matic', 'drg-weights', 'procedure-codes', 'rarc-codes'].each do |code_type|
    template "/root/scripts/import-#{code_type}.sh" do
      mode '0755'
      source 'scripts/import-code-type.sh.erb'
      variables(
        {
          :code_type => code_type,
          :sites     => node['cfn']['application_stack']['config']['sites'].keys
        }
      )
    end
  end

  node['cfn']['application_stack']['config']['sites'].each do |site, params|

    # need to set up a sftp drop-off directory for each site
    directory "#{sftp_drop}/#{site}" do
      owner rmedi_user
      group sftp_group
    end
    ['claims', 'trigger', 'remits', 'ub_cpt', 'payments', 'ucrn', 'iplan'].each do |dir|
      directory "#{sftp_drop}/#{site}/#{dir}" do
        owner rmedi_user
        group sftp_group
      end
      params['facilities'].each do |id, facility|
        directory "#{sftp_drop}/#{site}/#{dir}/#{facility}" do
          owner rmedi_user
          group sftp_group
        end
      end if params['facilities'] && dir != 'trigger'
    end
    ['applogs', 'processing', 'outgoing'].each do |dir|
      directory "/encrypted/client_data/#{site}/#{dir}" do
        owner 'root'
        group 'root'
        recursive true
        mode '0777'
      end
    end
    directory "/encrypted/client_data/#{site}/processing/temp" do
      owner 'root'
      group 'root'
      mode '0777'
    end

    # import scripts
    template "/var/www/run_#{site}.sh" do
      source 'run_import.sh.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0755'
      variables(
        {
          :database_database => "revenuemasters_#{site}",
          :database_hostname => node['cfn']['properties']['database_host'],
          :database_username => 'admin',
          :database_password => citadel['rds-admin-password'].chomp,
        }
      )
    end

    filename = params['post_import_filename'] || 'RMRANotesReport.txt'
    if params['post_import_enabled'] && node['cfn']['properties']['post_import_alerts_sha']
      default_report_date_format = "+%m%d%Y"
      # create post import script
      template "/var/www/#{site}-post-import.sh" do
        source "post-import.sh.erb"
        user node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
        mode '0755'
        variables(
          {
            :filename                 => filename,
            :hostname                 => "sftp-#{node['cfn']['properties']['env_name']}.#{node['cfn']['properties']['hosted_zone_name']}".chop,
            :notes_report_date_format => params.fetch(:notes_report_date_format, default_report_date_format),
            :report_date_format       => params.fetch(:report_date_format, default_report_date_format),
            :sftp_password            => citadel["#{site}-sftp-password"].chomp,
            :site                     => site
          }
        )
      end
    end
    if params['notes_report_enabled']
      template "/var/www/#{site}-notes-report.sh" do
        source "notes-report.sh.erb"
        user node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
        mode '0755'
        variables(
          {
            :filename           => filename,
            :plaintext_password => citadel["#{site}-password-plain"].chomp,
            :site               => site
          }
        )
      end
      cron "#{site} notes report" do
        command "/var/www/#{site}-notes-report.sh"
        minute '0'
        hour '8'
      end
    end

    mailer_config = node['cfn']['application_stack']['config']['mailer']
    template "/var/www/#{site}-import-monitor.php" do
      source 'import-monitor.php.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0755'
      variables(
        {
          :email_auth          => mailer_config['auth'],
          :email_host          => mailer_config['host'],
          :email_password      => citadel['email-password'].chomp,
          :email_port          => mailer_config['port'],
          :email_username      => mailer_config['username'],
          :post_import_enabled => params['post_import_enabled'],
          :site                => site,
          :to_address          => params['post_import_alerts_receivers']
        }
      )
    end

    template "/var/www/#{site}-daily-import.sh" do
      source 'daily-import.sh.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0755'
      variables(
        {
          :database_database => "revenuemasters_#{site}",
          :database_hostname => node['cfn']['properties']['database_host'],
          :database_username => 'admin',
          :database_password => citadel['rds-admin-password'].chomp,
          :site              => site
        }
      )
    end

    if params.key?('npi_cron_minute') && params.key?('npi_cron_hour')
      cron "#{site} npi command" do
        command "php /var/www/#{site}/current/application/cmd/npi-distributor/app"
        minute params['npi_cron_minute']
        hour params['npi_cron_hour']
      end
    else
      cron "#{site} npi command" do
        action :delete
      end
    end

    if params['import_cron_minute']
      cron "#{site} import command" do
        command "/var/www/#{site}-daily-import.sh"
        minute params['import_cron_minute']
        hour params['import_cron_hour'] || '0'
      end
    else
      cron "#{site} import command" do
        action :delete
      end
    end

    # one worker process per site
    template "/etc/init/worker-#{site}.conf" do
      source 'etc/init/worker.conf.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0644'
      variables(
        {
          :site => site,
          :worker_process => params['worker_process']
        }
      )
      notifies :run, "execute[restart-#{site}-workers]"
    end

    template "/etc/init/workers-#{site}.conf" do
      source 'etc/init/workers.conf.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0644'
      variables(
        {
          :site        => site,
          :num_workers => 1
        }
      )
      notifies :run, "execute[restart-#{site}-workers]"
    end

    execute "restart-#{site}-workers" do
      command "service workers-#{site} restart"
      # for now restart on each chef run...
      # need to update to happen just on app deploys
      # action :nothing
    end

    if params['post_import_alerts_enabled'] &&
       node['cfn']['properties']['post_import_alerts_sha'] &&
       !node['cfn']['properties']['post_import_alerts_sha'].empty?

      directory "/var/www/post_import_alerts_#{site}/shared" do
        recursive true
        user node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
      end

      sftp_host = "sftp-#{node['cfn']['properties']['env_name']}.#{node['cfn']['properties']['hosted_zone_name']}".chop

      mailer_config = node['cfn']['application_stack']['config']['mailer']
      # config file
      template "/var/www/post_import_alerts_#{site}/shared/dot-env" do
        source 'dot-env-post-import-alerts.erb'
        user node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
        mode '0644'
        variables(
          {
            :sftp_host                    => sftp_host,
            :sftp_password                => citadel["#{site}-sftp-password"],
            :site                         => site,
            :post_import_alerts_receivers => params['post_import_alerts_receivers'],
            :email_auth                   => mailer_config['auth'],
            :email_host                   => mailer_config['host'],
            :email_password               => citadel['email-password'].chomp,
            :email_port                   => mailer_config['port'],
            :email_username               => mailer_config['username']
          }
        )
      end

      # Deploy app
      deploy_revision "/var/www/post_import_alerts_#{site}" do
        repo "#{node['cfn']['properties']['repo_base']}/post-import-alerts.git"
        revision node['cfn']['properties']['post_import_alerts_sha'] || 'master'
        user node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
        symlink_before_migrate({})
        create_dirs_before_symlink([])
        purge_before_symlink([])
        keep_releases 1
        symlinks(
          {
            'dot-env' => '.env'
          }
        )
        before_restart do
          current_release = release_path
          execute 'composer install' do
            cwd current_release
          end
        end
      end
    end
  end
end

# include_recipe 'revenuemasters::newrelic'
