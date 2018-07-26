# assumes that this is running on the app server

include_recipe 'revenuemasters::apache2'

if (node.role?('app') || node.role?('importer') || node.role?('worker')) &&
   node['cfn'] &&
   node['cfn']['application_stack'] &&
   node['cfn']['application_stack']['config'] &&
   node['cfn']['application_stack']['config']['sites'] &&
   node['cfn']['properties']['api_importer_sha'] &&
   !node['cfn']['properties']['api_importer_sha'].empty?

  package 'beanstalkd'
  package 'supervisor'

  repo_base = node['cfn']['properties']['repo_base'] rescue ''

  node['cfn']['application_stack']['config']['sites'].each do |site, params|

    next unless params['api_importer_enabled']

    webroot = "/var/www/api-#{site}"

    directory "#{webroot}/shared" do
      recursive true
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
    end

    directory "#{webroot}/shared/tmp" do
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0770'
    end

    hostname = "api-#{site}.#{node['cfn']['properties']['hosted_zone_name']}".chop

    template "#{webroot}/shared/dot-env" do
      source 'dot-env-api-importer.erb'
      user 'root'
      group 'root'
      mode '0755'
      variables(
        :app_key           => citadel["#{site}-api-importer-app-key"].chomp,
        :app_url           => "https://#{hostname}",
        :aws_region        => node['cfn']['properties']['aws_region'],
        :database_database => "revenuemasters_#{site}api",
        :database_hostname => node['cfn']['properties']['database_host'],
        :database_password => citadel['rds-admin-password'].chomp,
        :database_username => 'admin',
        :soap_password     => citadel["#{site}-api-soap-password"].chomp,
        :soap_username     => citadel["#{site}-api-soap-username"].chomp,
        :worker_url        => params['worker-queue-url']
      )
    end

    # Deploy
    deploy_revision webroot do
      # action :force_deploy
      repo "#{repo_base}/api-importer.git"
      revision node['cfn']['properties']['api_importer_sha']
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
          command "composer update --lock && composer install --no-ansi --no-dev --no-interaction --no-progress --no-scripts --optimize-autoloader"
          cwd current_release
          ignore_failure true # TODO: figure out what user to run this as
        end
        ['storage', 'bootstrap/cache'].each do |writable_folder|
          execute "mkdir -p #{current_release}/#{writable_folder}"
          execute "chgrp -R www-data #{current_release}/#{writable_folder}"
          execute "chmod -R ug+rwx #{current_release}/#{writable_folder}"
        end

      end
      notifies :reload, 'service[apache2]'
    end
    
    template "#{node['apache']['dir']}/sites-available/#{hostname}.conf" do
      source 'php_app.conf.erb'
      owner 'root'
      group node['apache']['root_group']
      mode '0644'
      variables(
        :application_name => hostname,
        :params           => {
          :docroot             => "#{webroot}/current/public",
          :server_name         => hostname,
          :ssl_cert_file       => "/etc/apache2/ssl/wildcard.revenuemasters.com.cert.crt",
          :ssl_cert_key_file   => "/etc/apache2/ssl/wildcard.revenuemasters.com.key",
          :ssl_cert_chain_file => "/etc/apache2/ssl/wildcard.revenuemasters.com.intermediate.crt"
        }
      )
      not_if { File.exists?("/etc/letsencrypt/live/#{hostname}/cert.pem") }
      if ::File.exist?("#{node['apache']['dir']}/sites-enabled/#{hostname}.conf")
        notifies :reload, 'service[apache2]', :immediately
      end
    end
    execute "a2ensite #{hostname}" do
      command "/usr/sbin/a2ensite #{hostname}.conf"
      notifies :reload, 'service[apache2]', :immediately
      not_if do
        ::File.symlink?("#{node['apache']['dir']}/sites-enabled/#{hostname}.conf") ||
          ::File.symlink?("#{node['apache']['dir']}/sites-enabled/000-#{hostname}.conf")
      end
      only_if { ::File.exist?("#{node['apache']['dir']}/sites-available/#{hostname}.conf") }
    end

    # will provision cert if it isn't there
    include_recipe 'revenuemasters::letsencrypt'

    template "#{node['apache']['dir']}/sites-available/#{hostname}.conf" do
      source 'php_app.conf.erb'
      owner 'root'
      group node['apache']['root_group']
      mode '0644'
      variables(
        :application_name => hostname,
        :params           => {
          :docroot             => "#{webroot}/current/public",
          :server_name         => hostname,
          :ssl_cert_file       => "/etc/letsencrypt/live/#{hostname}/cert.pem",
          :ssl_cert_key_file   => "/etc/letsencrypt/live/#{hostname}/privkey.pem",
          :ssl_cert_chain_file => "/etc/letsencrypt/live/#{hostname}/chain.pem"
        }
      )
      only_if { File.exist?("/etc/letsencrypt/live/#{hostname}/cert.pem") }
      if ::File.exist?("#{node['apache']['dir']}/sites-enabled/#{hostname}.conf")
        notifies :reload, 'service[apache2]', :immediately
      end
    end

  end
end
