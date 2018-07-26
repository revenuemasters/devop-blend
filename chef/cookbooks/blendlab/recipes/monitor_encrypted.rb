include_recipe 'revenuemasters::cloudwatch_monitoring'

options = %w{ --disk-space-util --disk-path=/encrypted --from-cron --auto-scaling }

cron 'cloudwatch_monitoring_encrypted' do
  minute '*/5'
  command %Q{/root/software/cw_monitoring/aws-scripts-mon/mon-put-instance-data.pl #{(options).join(' ')} || logger -t aws-scripts-mon "status=failed exit_code=$?"}
end
