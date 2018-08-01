
default['ntp']['servers'] = ['ntp.ubuntu.com', 'pool.ntp.org']

default['authorization']['sudo']['groups'] = ['admin', 'sudo', 'sysadmin']
default['authorization']['sudo']['passwordless'] = true

default['apache']['listen_ports'] = ['80', '443', '8443', '9443']
default['apache']['mpm'] = 'prefork'

default['php']['conf_dir'] = '/etc/php5/apache2'
default['php']['directives'] = {
  'include_path' => '.:/usr/share/php:/usr/share/pear:/usr/share/php/libzend-framework-php'
}

default['revenuemasters']['app_user']  = 'root'
default['revenuemasters']['app_group'] = 'www-data'

# ssh timeout policy
default['openssh']['server']['client_alive_interval']  = 900 # idle time in seconds, default 15 min
default['openssh']['server']['client_alive_count_max'] = 0 # ensure no keepalive on idle conns

# sftp stuff
default['openssh']['server']['permit_root_login'] = 'no'
default['openssh']['server']['subsystem']         = 'sftp internal-sftp -f AUTH -l VERBOSE'

default['s3_archives']['source_path'] = '/encrypted'
default['s3_archives']['source_retention_days'] = '540' # 18 months
