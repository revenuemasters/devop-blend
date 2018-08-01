# ascii greeting
cookbook_file '/etc/update-motd.d/20-ascii-logo' do
  source '20-ascii-logo'
  backup false
  mode 0755
  notifies :run, 'execute[update-motd]', :immediately
end

execute 'update-motd' do
  command 'run-parts /etc/update-motd.d/'
  action :nothing
end
