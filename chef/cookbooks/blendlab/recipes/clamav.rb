include_recipe 'clamav'

directory '/root/scripts'

template '/root/scripts/clamscan-daily-script.sh' do
  source 'clamscan-daily-script.sh.erb'
  user 'root'
  group 'root'
  mode '0755'
  variables(
    :region          => node['cfn']['vpc']['region_id'],
    :sns_alarm_topic => node['cfn']['properties']['sns_alarm_topic']
  )
end

cron 'daily virus scan' do
  # run sometime between 1 and 2 UTC
  # https://stackoverflow.com/a/29287653
  command "perl -le 'sleep rand 3600' && /root/scripts/clamscan-daily-script.sh"
  minute '0'
  hour '1' # 5PM PST / 6PM PDT
end
