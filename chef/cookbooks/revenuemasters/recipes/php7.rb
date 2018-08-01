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

%w( php7.2 php7.2-fpm php7.2-mysql php7.2-curl php7.2-cli php7.2-xml php7.2-mbstring php7.2-zip ).each do |p|
  package p
end
