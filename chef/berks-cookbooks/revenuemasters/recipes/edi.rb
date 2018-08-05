#todo overwrite edi_sha
edi_sha = "a6222db94d6ff6e4f27432d6ee7repo"
# if node['cfn']['properties']['edi_sha'] && !node['cfn']['properties']['edi_sha'].empty?

  include_recipe 'revenuemasters::default'
  include_recipe 'revenuemasters::php7'
  include_recipe 'revenuemasters::composer'

  execute 'phpenmod mcrypt'

  remote_file '/etc/ssl/certs/rds-combined-ca-bundle.pem' do
    user 'root'
    group 'root'
    mode '644'
    source 'http://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem'
  end

  directory '/var/www/edi/shared' do
    recursive true
  end
  directory '/encrypted/rmedi/rmedilogs' do
    recursive true
  end

  enabled_clients = []
  puts "node sites: #{node['cfn']['application_stack']['config']['sites']}"
  # raise ArgumentError, "node sites: #{node['cfn']['application_stack']['config']['sites']}"
  node['cfn']['application_stack']['config']['sites'].each do |site, params|
    if params['edi_app_enabled']

      unless params['edi_app_sftp_server'].to_s.empty?
        # When this was added, SSH host keys of outside SFTP servers were being manually accepted without validation.
        # This line does the same thing, but automatically.
        ssh_known_hosts_entry params['edi_app_sftp_server']
      end

      directory "/encrypted/rmedi/rmedilogs/#{site}"
      config = {
        :site => site,
        :params => params.dup
      }
      if params['edi_app_sftp_uses_password']
        config[:params]['edi_app_sftp_password'] = citadel["edi-sftp-#{site}-password"].chomp
      end
      unless config[:params]['edi_app_importer_id']
        config[:params]['edi_app_importer_id'] = site
      end
      enabled_clients << config

      if params.key?('edi_app_job_minute') && params.key?('edi_app_job_hour')
        cron "#{site} edi command" do
          command "php /var/www/edi/current/app.php edi:process #{site} > /encrypted/rmedi/rmedilogs/#{site}/$(date \"+\\%Y\\%m\\%d\\%H\\%M\")rmedi_process.log 2>&1"
          minute params['edi_app_job_minute']
          hour params['edi_app_job_hour']
        end
      end
    end
  end if node['cfn']['application_stack']['config']['sites']

  # todo mailconfig
  # mailer_config = node['cfn']['application_stack']['config']['mailer']
  mailer_config = {auth => true, host => 'smtp.gmail.com',port: 25,username: 'someids@gmail.com'}
  template '/var/www/edi/shared/dot-env' do
    source 'dot-env-edi.erb'
    user 'root'
    group 'root'
    mode '0755'
    variables(
      :database_database      => 'rm_edi',
      :database_hostname      => node['cfn']['properties']['database_host'],
      :database_username      => 'admin',
      :database_password      => citadel['rds-admin-password'].chomp,
      :edi_app_receivers      => node['cfn']['application_stack']['config']['edi_app_receivers'],
      :email_auth             => mailer_config['auth'],
      :email_host             => mailer_config['host'],
      :email_password         => citadel['email-password'].chomp,
      :email_port             => mailer_config['port'],
      :email_username         => mailer_config['username'],
      :enabled_clients        => enabled_clients,
      :enabled_clients_list   => enabled_clients.map { |h| h[:site] }.join(','),
      :sftp_importer_password => citadel['rmedi-password-plain'].chomp
    )
  end

  deploy_revision '/var/www/edi' do
    repo "#{node['cfn']['properties']['repo_base']}/EDI.git"
    revision edi_sha
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

# end
