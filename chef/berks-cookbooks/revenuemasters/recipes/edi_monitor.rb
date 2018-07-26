if node['cfn']['properties']['edi_monitor_sha'] && !node['cfn']['properties']['edi_monitor_sha'].empty?

  include_recipe 'revenuemasters::default'
  include_recipe 'revenuemasters::apache2'
  include_recipe 'revenuemasters::php7'
  include_recipe 'revenuemasters::composer'

  execute 'phpenmod mcrypt'

  remote_file '/etc/ssl/certs/rds-combined-ca-bundle.pem' do
    user 'root'
    group 'root'
    mode '644'
    source 'http://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem'
  end

  package 'php-pear'
  execute 'pear install Mail-1.3.0' do
    not_if 'pear list | grep Mail | grep 1.3.0'
  end
  execute 'pear install Net_SMTP' do
    not_if 'pear list | grep Net_SMTP'
  end

  if node['cfn']['application_stack']['config']['sites']
    node['cfn']['application_stack']['config']['sites'].each do |site, params|

      next unless params['edi_app_enabled']

      directory "/var/www/edi_monitor_#{site}/shared" do
        recursive true
        user node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
      end

      mailer_config = node['cfn']['application_stack']['config']['mailer']

      # config file
      template "/var/www/edi_monitor_#{site}/shared/dot-env" do
        source 'dot-env-edi-monitor.erb'
        user node['revenuemasters']['app_user']
        group node['revenuemasters']['app_group']
        mode '0644'
        variables(
          {
            :site                          => site,
            :edi_monitor_facility_id       => params['edi_monitor_facility_id'],
            :edi_monitor_facility_name     => params['edi_monitor_facility_name'],
            :edi_monitor_flat_file_headers => params['edi_monitor_flat_file_headers'],
            :edi_monitor_receivers         => params['edi_monitor_receivers'],
            :email_auth                    => mailer_config['auth'],
            :email_host                    => mailer_config['host'],
            :email_password                => citadel['email-password'].chomp,
            :email_port                    => mailer_config['port'],
            :email_username                => mailer_config['username']
          }
        )
      end

      # Deploy app
      deploy_revision "/var/www/edi_monitor_#{site}" do
        repo "#{node['cfn']['properties']['repo_base']}/edi-monitor.git"
        revision node['cfn']['properties']['edi_monitor_sha']
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

      # cronjobs
      if params['edi_monitor_enabled']
        cron "#{site} edi monitor command" do
          command "php /var/www/edi_monitor_#{site}/current/app monitor"
          minute 0
          hour 11
        end
        cron "#{site} edi send-summary command" do
          command "php /var/www/edi_monitor_#{site}/current/app send-summary"
          minute 10
          hour 11
        end
      end

    end
  end

end
