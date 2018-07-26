include_recipe 'apt'
include_recipe 'alternatives'

apt_repository 'ondrej-php' do
  uri 'http://ppa.launchpad.net/ondrej/php/ubuntu'
  distribution node['lsb']['codename']
  components ['main']
  keyserver 'keyserver.ubuntu.com'
  key 'E5267A6C'
end

package 'php5-common' do
  action :purge
end

node.default['php']['conf_dir'] = '/etc/php/5.6/cli'
node.default['php']['ext_conf_dir'] = '/etc/php/5.6/cli/conf.d'
node.default['php']['packages'] = %w{ php5.6 libapache2-mod-php5.6 php5.6-bcmath php5.6-cli php5.6-curl php5.6-gd php5.6-mcrypt php5.6-apcu php5.6-json php5.6-mysql php5.6-dev php5.6-xml php5.6-soap php5.6-mbstring }
include_recipe 'php'

apache_ini_path = '/etc/php/5.6/apache2/php.ini'
cli_ini_path = '/etc/php/5.6/cli/php.ini'

file apache_ini_path do
  action :delete
  only_if { ::File.exist?(apache_ini_path) && !::File.symlink?(apache_ini_path) }
end

link apache_ini_path do
  to cli_ini_path
  only_if { ::File.exist?(cli_ini_path) }
end

alternatives 'set php5.6' do
  link_name 'php'
  path '/usr/bin/php5.6'
  action :set
end

package 'php-pear'

remote_file '/usr/local/bin/composer' do
  source 'https://getcomposer.org/download/1.6.5/composer.phar'
  mode '0755'
  checksum '67bebe9df9866a795078bb2cf21798d8b0214f2e0b2fd81f2e907a8ef0be3434'
  action :create
end

package 'zend-framework'
link '/usr/share/php/Zend' do
  to '/usr/share/php/libzend-framework-php/Zend'
end

execute 'phpenmod mcrypt'
