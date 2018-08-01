include_recipe 'aws-cloudwatchlogs'

node['aws_cwlogs']['log'].each do |name, config|
  aws_cwlogs name do
    log config
  end
end
