# installs and configures new relic

node.set['newrelic']['license'] = citadel['newrelic-license-key'].chomp

newrelic_agent_php 'install new relic' do
  license node['newrelic']['license']
  service_name 'apache2'
  app_name node['cfn']['properties']['env_name']
  config_file '/etc/php5/mods-available/newrelic.ini'
end

['apache2', 'cli'].each do |dir|
  file "/etc/php5/#{dir}/conf.d/newrelic.ini" do
    action :delete
  end

  link "/etc/php5/#{dir}/conf.d/20-newrelic.ini" do
    to '/etc/php5/mods-available/newrelic.ini'
  end
end
