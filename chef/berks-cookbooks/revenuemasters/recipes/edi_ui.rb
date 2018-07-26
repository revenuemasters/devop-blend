if node['cfn']['properties']['edi_ui_sha'] && !node['cfn']['properties']['edi_ui_sha'].empty?

  include_recipe 'revenuemasters::default'
  include_recipe 'revenuemasters::apache2'
  include_recipe 'revenuemasters::php7'
  include_recipe 'revenuemasters::composer'

  package 'libapache2-mod-php7.0'

  co_name = node['cfn']['properties']['co_name'] rescue '' # falling back to this incase ruby isn't >= 2.3 for hash#dig
  repo_base = node['cfn']['properties']['repo_base'] rescue ''

  execute 'phpenmod mcrypt'

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

  webroot = '/var/www/edi_ui'

  directory "#{webroot}/shared" do
    recursive true
  end

  hostname = "edi-#{node['cfn']['properties']['env_name']}.#{node['cfn']['properties']['hosted_zone_name']}".chop

  mailer_config = node['cfn']['application_stack']['config']['mailer']
  template "#{webroot}/shared/dot-env" do
    source 'dot-env-edi-ui.erb'
    user 'root'
    group 'root'
    mode '0755'
    variables(
      :database_database => 'rm_edi',
      :database_hostname => node['cfn']['properties']['database_host'],
      :database_username => 'admin',
      :database_password => citadel['rds-admin-password'].chomp,
      :email_auth        => mailer_config['auth'],
      :email_host        => mailer_config['host'],
      :email_password    => citadel['email-password'].chomp,
      :email_port        => mailer_config['port'],
      :email_username    => mailer_config['username'],
      :hostname          => hostname,
    )
  end

  deploy_revision webroot do
    repo "#{repo_base}/EDI-UI.git"
    revision node['cfn']['properties']['edi_ui_sha']
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
      execute 'fix permissions' do
        cwd current_release
        command 'chmod -R 777 bootstrap/cache && chmod -R 777 storage'
      end
      link "#{webroot}/current/edi" do
        user 'root'
        group 'root'
        mode '0755'
        to '/var/www/edi/current'
        link_type :symbolic
      end
      # execute 'php artisan migrate' do
      #   cwd current_release
      # end
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
