cw_home       = '/root/software/cw_monitoring'
install_path  = "#{cw_home}/aws-scripts-mon"
zip_filepath  = "#{cw_home}/CloudWatchMonitoringScripts.zip"
remote_source = 'http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip'

directory '/root/software'
directory cw_home

%w{unzip libwww-perl libcrypt-ssleay-perl libdatetime-perl}.each do |p|
  package p do
    action :install
  end
end

remote_file zip_filepath do
  source remote_source
  owner 'root'
  group 'root'
  mode 0755
  not_if { File.directory? install_path }
end

bash 'extract_aws-scripts-mon' do
  cwd ::File.dirname(zip_filepath)
  # FYI removing the 'Filesystem' dimension as it makes it hard to automate alarms
  code <<-EOH
    rm -rf #{install_path}
    [[ -d #{File.dirname(install_path)} ]] || mkdir -vp #{File.dirname(install_path)}
    unzip #{zip_filepath}
    mv -v ./aws-scripts-mon #{install_path}
    sed -i.bak '/Filesystem/d' #{install_path}/mon-put-instance-data.pl
  EOH
  not_if { File.directory? install_path }
end

file zip_filepath do
  action :delete
end
