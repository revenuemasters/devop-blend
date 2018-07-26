# auditd setup with full command logging

package 'auditd'

# take over pam sshd config and add pam_tty_audit module
template '/etc/pam.d/sshd' do
  source 'pam_sshd.erb'
  mode 0644
  owner 'root'
  group 'root'
end

template '/etc/audit/audit.rules' do
  source 'audit.rules.erb'
  notifies :restart, 'service[auditd]'
end

service 'auditd' do
  supports [:start, :stop, :restart, :reload, :status]
  action :enable
end
