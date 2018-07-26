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

%w( php7.0 php7.0-fpm php7.0-mysql php7.0-curl php7.0-cli php7.0-xml php7.0-mbstring php7.0-zip ).each do |p|
  package p
end
