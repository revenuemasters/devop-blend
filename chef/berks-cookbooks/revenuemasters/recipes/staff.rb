
include_recipe 'user'

admin_groups = ['admin', 'sudo', 'sysadmin']

group 'admin' do
  gid 1997
end

group 'sudo'

group 'sysadmin' do
  gid 1999
end

users = data_bag('users')
users.each do |login|
  user = data_bag_item('users', login)
  # GID 2000 is already taken by the sftpusers group.
  # Starting at 2001 caused collisions sometimes, even on fresh hosts.
  # Starting at 3000 worked without collisions.
  primary_group_id = user['uid'] + 1000
  group login do
    gid primary_group_id
  end
  user_account login do
    comment user['name']
    ssh_keys user['ssh_keys']
    home "/home/#{login}"
    uid user['uid']
    gid primary_group_id
  end
  admin_groups.each do |g|
    group g do
      action :modify
      members login
      append true
    end
  end

  # tweaked .bashrc that doesn't overwrite the prompt when set from /etc/profile.d
  cookbook_file "/home/#{login}/.bashrc" do
    source "dotbashrc"
    user login
    group login
    mode "0644"
  end
end

cookbook_file "/root/.bashrc" do
  source "dotbashrc"
  user 'root'
  group 'root'
  mode "0644"
end

# ubuntu user
admin_groups.each do |g|
  group g do
    action :modify
    members 'ubuntu'
    append true
    only_if 'getent group ubuntu'
  end
end
