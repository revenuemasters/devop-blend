remote_file '/usr/local/bin/composer' do
  source 'http://getcomposer.org/composer.phar'
  mode '0755'
  action :create
end
