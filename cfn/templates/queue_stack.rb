CloudFormation do

  Description "Creates an instance of the Revenue Masters application for one client"

  if config && config['sites']
    config['sites'].each do |site, params|
      SQS_Queue("WorkerQueue#{site.gsub(/[^0-9a-z]/i, '')}") do
        VisibilityTimeout 900
      end

      Output("WorkerQueue#{site.gsub(/[^0-9a-z]/i, '')}", Ref("WorkerQueue#{site.gsub(/[^0-9a-z]/i, '')}"))
      Output("WorkerQueueName#{site.gsub(/[^0-9a-z]/i, '')}", FnGetAtt("WorkerQueue#{site.gsub(/[^0-9a-z]/i, '')}", 'QueueName'))
    end
  end
end
