include_recipe 'revenuemasters::default'
include_recipe 'revenuemasters::setup_database'
include_recipe 'revenuemasters::apache2'
include_recipe 'revenuemasters::php5'

co_name = node['cfn']['properties']['co_name'] rescue '' # falling back to this incase ruby isn't >= 2.3 for hash#dig
repo_base = node['cfn']['properties']['repo_base'] rescue ''

apache_module 'php7.2' do
    enable false
end

apache_module 'php5' do
    enable false
end

apache_module 'php5.6' do
    filename "libphp5.6.so"
    identifier "php5_module"
    enable true
end

apache_module 'rewrite'
apache_module 'cache'
apache_module 'ssl'
apache_module 'socache_shmcb'

# Install Apache SSL certs
directory '/etc/apache2/ssl' do
  user 'root'
  group 'root'
  mode '700'
  action :create
  recursive true
end

file '/etc/apache2/ssl/wildcard.revenuemasters.com.cert.crt' do
  user 'root'
  group 'root'
  mode '600'
  action :create
  content citadel["#{co_name}-app-ssl-cert"]
  sensitive true
end

file '/etc/apache2/ssl/wildcard.revenuemasters.com.key' do
  user 'root'
  group 'root'
  mode '600'
  action :create
  content citadel["#{co_name}-app-ssl-key"]
  sensitive true
end

file '/etc/apache2/ssl/wildcard.revenuemasters.com.intermediate.crt' do
  user 'root'
  group 'root'
  mode '600'
  action :create
  content citadel["#{co_name}-app-ssl-intermediate-cert"]
  sensitive true
end

remote_file '/etc/ssl/certs/rds-combined-ca-bundle.pem' do
  user 'root'
  group 'root'
  mode '644'
  source 'http://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem'
end

# Disable the default sites if they are active
%w{ default default-ssl }.each do |v|
  apache_site v do
    enable false
  end
end

# add back in this default site
cookbook_file '/etc/apache2/sites-available/000-default.conf' do
  source 'etc/apache2/sites-available/000-default.conf'
  user node['revenuemasters']['app_user']
  group node['revenuemasters']['app_group']
  mode '0644'
end
directory '/var/www/html' do
  user 'root'
  group 'root'
end
file '/var/www/html/index.html' do
  user 'root'
  group 'root'
  action :create
  content '404'
end
apache_site '000-default' do
  enable true
end

# backup script for application.ini
template '/root/src/backup-application.ini.rb' do
  source 'backup-application.ini.rb.erb'
  user 'root'
  group 'root'
  mode '0755'
  variables(
    {
      :co_name  => co_name,
      :env_name => node['cfn']['properties']['env_name'],
      :region   => node['cfn']['vpc']['region_id'],
      :role     => node['cfn']['properties']['role']
    }
  )
end

directory '/root/scripts'

if node['cfn']['application_stack']['config']['sites']

  template '/root/scripts/composer.sh' do
    mode '0755'
    source 'scripts/composer.sh.erb'
    variables(
      {
        :sites => node['cfn']['application_stack']['config']['sites'].keys
      }
    )
  end

  template '/root/scripts/git-checkout.sh' do
    mode '0755'
    source 'scripts/git-checkout.sh.erb'
    variables(
      {
        :sites => node['cfn']['application_stack']['config']['sites'].keys
      }
    )
  end

  template '/root/scripts/git-status-all-clients.sh' do
    mode '0755'
    source 'scripts/git-status-all-clients.sh.erb'
    variables(
      {
        :sites => node['cfn']['application_stack']['config']['sites'].keys
      }
    )
  end

  template '/root/scripts/git-pull-all-stable-master.sh' do
    mode '0755'
    source 'scripts/git-pull-all-stable-master.sh.erb'
    variables(
      {
        :sites => node['cfn']['application_stack']['config']['sites'].keys
      }
    )
  end

  template '/root/scripts/clear-cache-for-all-clients.sh' do
    mode '0755'
    source 'scripts/clear-cache-for-all-clients.sh.erb'
    variables(
      {
        :sites => node['cfn']['application_stack']['config']['sites'].keys
      }
    )
  end

  node['cfn']['application_stack']['config']['sites'].each do |site, params|

    next if node.role?('worker') && !params['worker-enabled']

    # TODO: figure out where to save this data
    directory "/encrypted/client_data/#{site}" do
      recursive true
      owner 'root'
      group 'root'
      mode '0755'
    end

    ['applogs', 'outgoing', 'processing'].each do |dir|
      directory "/encrypted/client_data/#{site}/#{dir}" do
        owner 'root'
        group 'root'
        mode '0777'
      end
    end

    directory "/var/www/#{site}/shared" do
      recursive true
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
    end

    directory "/var/www/#{site}/shared/tmp" do
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0770'
    end

    mailer_config = node['cfn']['application_stack']['config']['mailer']
    # config file
    template "/var/www/#{site}/shared/application.ini" do
      source 'application.ini.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0644'
      variables(
        {
          :aws_region                         => node['cfn']['properties']['aws_region'],
          :claim_import_summary               => params['claim_import_summary'] || false,
          :claim_import_summary_recipients    => (params['claim_import_summary_recipients'] ? params['claim_import_summary_recipients'] : []),
          :crosswalk_enabled                  => (params['crosswalk_enabled'] ? '1' : '0'), # default is '0'
          :custom                             => params['custom'],
          :database_database                  => "revenuemasters_#{site}", # TODO convert to co, without breaking change?
          :database_hostname                  => node['cfn']['properties']['database_host'],
          :database_username                  => 'admin',
          :database_password                  => citadel['rds-admin-password'].chomp,
          :email_auth                         => mailer_config['auth'],
          :email_host                         => mailer_config['host'],
          :email_password                     => citadel['email-password'].chomp,
          :email_port                         => mailer_config['port'],
          :email_username                     => mailer_config['username'],
          :empty_payor_name                   => (params['empty_payor_name'] ? 'yes' : 'no'), # default is 'no'
          :enable_multiple_physicians         => (params['enable_multiple_physicians'] ? 'yes' : 'no'), # default is 'no'
          :env_name                           => node['cfn']['properties']['env_name'],
          :find_account_by_ucrn               => (params['find_account_by_ucrn'] ? 'yes' : 'no'),
          :go_live_date                       => params['go_live_date'] || false,
          :ignore_quick_numbers               => (params['ignore_quick_numbers'] ? params['ignore_quick_numbers'] : []),
          :import_oop                         => (params.key?('import_oop') ? (params['import_oop'] ? 'on' : 'off') : 'on'), # default is 'on'
          :import_process                     => (params['import_process'] || "/encrypted/sftp/rmedi/from_rmedi/#{site}"),
          :insurance_payments_pulled_from_835 => (params['insurance_payments_pulled_from_835'] ? 'yes' : 'no'), # default is 'no'
          :invert_adjustment_value            => (params['invert_adjustment_value'] ? '1' : '0'), # default is '0'
          :invert_payment_report_amounts      => (params['invert_payment_report_amounts'] ? '1' : '0'),
          :invert_writeoff_value              => (params['invert_writeoff_value'] ? '1' : '0'), # default is '0'
          :logo                               => (params['logo'] || 'logo.png'),
          :qmart_queue_low_risk_insurance     => (params.key?('qmart_queue_low_risk_insurance') ? (params['qmart_queue_low_risk_insurance'] ? '1' : '0') : '1'), # default is '1'
          :map_adj_file                       => (params['map_adj_file'] || ''),
          :map_pmt_file                       => (params['map_pmt_file'] || ''),
          :mapped_client                      => (params['mapped_client'] || site),
          :master_separator                   => (params['master_separator'] || '|'),
          :overwrite_payor                    => (params.key?('overwrite_payor') ? (params['overwrite_payor'] ? 'yes' : 'no') : 'yes'), # default is 'yes'
          :payor_code_by_payor_name           => (params.key?('payor_code_by_payor_name') ? (params['payor_code_by_payor_name'] ? 'yes' : 'no') : 'yes'), # default is 'yes'
          :replace_header_pmt_file            => (params['replace_header_pmt_file'] || ''),
          :sanitize_payor_names               => (params['sanitize_payor_names'] ? 'yes' : 'no'), # default is 'no'
          :sequestration_adjustment           => (params['sequestration_adjustment'] ? '1' : '0'), # default is '0'
          :site                               => site,
          :ucrn_import_csv_headers            => (params['ucrn_import_csv_headers'] || ''),
          :ucrn_import_separator              => (params['ucrn_import_separator'] || ''),
          :ucrn_import_is_csv                 => (params['ucrn_import_is_csv'] ? 'yes' : 'no'), # default is 'no'
          :ucrn_import_ucrn_start             => (params['ucrn_import_ucrn_start'] || '0'),
          :ucrn_import_ucrn_length            => (params['ucrn_import_ucrn_length'] || '11'),
          :ucrn_import_account_start          => (params['ucrn_import_account_start'] || '42'),
          :ucrn_import_account_length         => (params['ucrn_import_account_length'] || '12'),
          :worker_queue_url                   => params['worker-queue-url']
        }
      )
    end

    # Deploy app
    deploy_revision "/var/www/#{site}" do
      # action :force_deploy
      repo "#{repo_base}/app.git"
      revision params['app_sha'] || node['cfn']['properties']['app_sha']
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      symlink_before_migrate({})
      create_dirs_before_symlink([])
      purge_before_symlink([])
      keep_releases 1
      symlinks(
        {
          "application.ini" => "application/configs/application.ini",
          "tmp" => "tmp"
        }
      )
      before_restart do
        current_release = release_path
        if params['custom'] && params['custom']['pic_directory'] && !params['custom']['pic_directory'].to_s.empty?
          execute 'copy customization files' do
            command "cp #{current_release}/public/pics/#{params['custom']['pic_directory']}/* #{current_release}/public/pics/customization"
            only_if { File.exist?("#{current_release}/public/pics/#{params['custom']['pic_directory']}") }
          end
        end
        execute 'composer install' do
          command "composer update --lock && composer install --no-ansi --no-dev --no-interaction --no-progress --no-scripts --optimize-autoloader"
          cwd current_release
          ignore_failure true # TODO: figure out what user to run this as
        end
        execute 'phinx-migrate' do
          command "vendor/bin/phinx migrate"
          cwd current_release
          ignore_failure true
        end
      end
      notifies :reload, 'service[apache2]'
    end

    execute "chmod -R 777 /var/www/#{site}/current/data" do
      ignore_failure true
    end

    params['facilities'].each do |id, facility|
      directory "/var/www/#{site}/current/data/#{id}" do
        owner node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
        mode "0777"
      end
    end if params['facilities']

    cookbook_file "/var/www/#{site}/current/public/css/customization.css" do
      source "custom/css/customization.#{site}.css"
      owner node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode "0644"

      only_if do
          File.exists? File.join(
              Chef::Config[:file_cache_path],
              'cookbooks/revenuemasters',
              'files/default/custom/css',
              "customization.#{site}.css"
          )
      end
    end

    if params['ssl_name']
      file "/etc/apache2/ssl/#{params['ssl_name']}.cert.crt" do
        user 'root'
        group 'root'
        mode '600'
        action :create
        content citadel["#{params['ssl_name']}-ssl-cert"]
        sensitive true
      end

      file "/etc/apache2/ssl/#{params['ssl_name']}.key" do
        user 'root'
        group 'root'
        mode '600'
        action :create
        content citadel["#{params['ssl_name']}-ssl-key"]
        sensitive true
      end

      file "/etc/apache2/ssl/#{params['ssl_name']}.intermediate.crt" do
        user 'root'
        group 'root'
        mode '600'
        action :create
        content citadel["#{params['ssl_name']}-ssl-intermediate-cert"]
        sensitive true
      end
    end

    template "#{node['apache']['dir']}/sites-available/#{params['host']}.conf" do
      source 'www.revenuemasters.com.conf.erb'
      owner 'root'
      group node['apache']['root_group']
      mode '0644'
      variables(
        :application_name => params['host'],
        :params           => {
          :docroot             => "/var/www/#{site}/current/public",
          :server_name         => params['host'],
          :ssl_port            => params['ssl_port'] || '443',
          :ssl_host            => params['ssl_host'] ? params['ssl_host'] : nil,
          :ssl_name            => params['ssl_name'] ? params['ssl_name'] : nil,
          :ssl_cert_file       =>"/etc/apache2/ssl/wildcard.revenuemasters.com.cert.crt",
          :ssl_cert_key_file   => "/etc/apache2/ssl/wildcard.revenuemasters.com.key",
          :ssl_cert_chain_file => "/etc/apache2/ssl/wildcard.revenuemasters.com.intermediate.crt"
        }
      )
      not_if { File.exists?("/etc/letsencrypt/live/#{params['host']}/cert.pem") }
      if ::File.exist?("#{node['apache']['dir']}/sites-enabled/#{params['host']}.conf")
        notifies :reload, 'service[apache2]', :immediately
      end
    end
    execute "a2ensite #{params['host']}" do
      command "/usr/sbin/a2ensite #{params['host']}.conf"
      notifies :reload, 'service[apache2]', :immediately
      not_if do
        ::File.symlink?("#{node['apache']['dir']}/sites-enabled/#{params['host']}.conf") ||
          ::File.symlink?("#{node['apache']['dir']}/sites-enabled/000-#{params['host']}.conf")
      end
      only_if { ::File.exist?("#{node['apache']['dir']}/sites-available/#{params['host']}.conf") }
    end

    node.default['aws_cwlogs']['log']["apache-#{site}-error"] = {
      'file' => "/var/log/apache2/#{params['host']}-error.log",
      'log_stream_name' => '{instance_id}',
      'initial_position' => 'start_of_file',
      'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-apache-#{site}-error"
    }

    node.default['aws_cwlogs']['log']["apache-#{site}-access"] = {
      'file' => "/var/log/apache2/#{params['host']}-access.log",
      'log_stream_name' => '{instance_id}',
      'initial_position' => 'start_of_file',
      'log_group_name' => "#{node['cfn']['properties']['env_name']}-#{node['cfn']['properties']['role']}-apache-#{site}-access"
    }

  end

  # get custom ssl certs
  if node.role?('app')
    include_recipe 'revenuemasters::letsencrypt'

    node['cfn']['application_stack']['config']['sites'].each do |site, params|

      template "#{node['apache']['dir']}/sites-available/#{params['host']}.conf" do
        source 'www.revenuemasters.com.conf.erb'
        owner 'root'
        group node['apache']['root_group']
        mode '0644'
        variables(
          :application_name => params['host'],
          :params           => {
            :docroot             => "/var/www/#{site}/current/public",
            :server_name         => params['host'],
            :ssl_port            => params['ssl_port'] || '443',
            :ssl_host            => params['ssl_host'] ? params['ssl_host'] : nil,
            :ssl_name            => params['ssl_name'] ? params['ssl_name'] : nil,
            :ssl_cert_file       => "/etc/letsencrypt/live/#{params['host']}/cert.pem",
            :ssl_cert_key_file   => "/etc/letsencrypt/live/#{params['host']}/privkey.pem",
            :ssl_cert_chain_file => "/etc/letsencrypt/live/#{params['host']}/chain.pem",
          }
        )
        only_if { File.exists?("/etc/letsencrypt/live/#{params['host']}/cert.pem") }
        if ::File.exist?("#{node['apache']['dir']}/sites-enabled/#{params['host']}.conf")
          notifies :reload, 'service[apache2]', :immediately
        end
      end

    end

  end

end

include_recipe 'revenuemasters::physician_pro'
include_recipe 'revenuemasters::api_importer'
include_recipe 'revenuemasters::setup_awslogs' # Run here so role-specific log files defined in recipes are captured.
