# assumes that this is running on the app server

if node.role?('app') &&
   node['cfn'] &&
   node['cfn']['application_stack'] &&
   node['cfn']['application_stack']['config'] &&
   node['cfn']['application_stack']['config']['cvc_enabled'] &&
   node['cfn']['properties']['cvc_sha']

  include_recipe 'revenuemasters::apache2'

  hostname = "cvc-#{node['cfn']['properties']['env_name']}.#{node['cfn']['properties']['hosted_zone_name']}".chop
  webroot = '/var/www/cvcpath'

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

  mailer_config = node['cfn']['application_stack']['config']['mailer']
  template "#{webroot}/shared/dot-env" do
    source 'dot-env-cvc.erb'
    user 'root'
    group 'root'
    mode '0755'
    variables(
      :app_key           => citadel['cvc-app-key'].chomp,
      :database_database => "revenuemasters_cvc",
      :database_hostname => node['cfn']['properties']['database_host'],
      :database_password => citadel['rds-admin-password'].chomp,
      :database_username => 'admin',
      :email_auth        => mailer_config['auth'],
      :email_host        => mailer_config['host'],
      :email_password    => citadel['email-password'].chomp,
      :email_port        => mailer_config['port'],
      :email_username    => mailer_config['username'],
      :hostname          => hostname
    )
  end

  # Deploy
  deploy_revision webroot do
    # action :force_deploy
    repo "#{node['cfn']['properties']['repo_base']}/rm-cvc.git"
    revision node['cfn']['properties']['cvc_sha']
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
