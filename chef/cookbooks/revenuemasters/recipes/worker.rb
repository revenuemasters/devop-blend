# worker recipe

node['cfn']['application_stack']['config']['sites'].each do |site, params|

  if params['worker-enabled']
    template "/etc/init/worker-#{site}.conf" do
      source 'etc/init/worker.conf.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0644'
      variables(
        {
          :site => site,
          :worker_process => params['worker_process']
        }
      )
      notifies :run, "execute[restart-#{site}-workers]"
    end

    template "/etc/init/workers-#{site}.conf" do
      source 'etc/init/workers.conf.erb'
      user node['revenuemasters']['app_user']
      group node['revenuemasters']['app_group']
      mode '0644'
      variables(
        {
          :site        => site,
          :num_workers => params['worker-num-processes']
        }
      )
      notifies :run, "execute[restart-#{site}-workers]"
    end

    execute "restart-#{site}-workers" do
      command "service workers-#{site} restart"
      # for now restart on each chef run...
      # need to update to happen just on app deploys
      # action :nothing
    end
  end

end

include_recipe 'revenuemasters::newrelic'
