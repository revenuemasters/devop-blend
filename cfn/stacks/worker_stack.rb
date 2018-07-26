require 'json'

class WorkerStack < CloudformationStack

  class << self

    def with_params(env, site, config, options)
      stack_name = "#{env}-worker-#{site}-stack"
      schedule = config['worker_schedule']
      start_recurrence = end_recurrence = num_workers = nil

      if schedule
        if m = schedule.match(/^start-(\d+)-end-(\d+)-num-(\d+)$/)
          start_recurrence = "0 #{m[1]} * * *"
          end_recurrence = "0 #{m[2]} * * *"
          num_workers = m[3]
        else
          puts "ERROR: Worker Schedule for #{site} malformed: #{schedule} - skipping..."
        end
      end

      template_params = {
        ChefSha: options['chef-sha'],
        CodeDeployRoleArn: options['code-deploy-role-arn'],
        DatabaseHost: options['database-host'],
        EnvName: env,
        ImageId: options['image-id'],
        KeyName: options['key-name'],
        PrivateSubnets: options['private-subnets'],
        RootVolumeSize: options['root-volume-size'],
        SecretsBucket: S3Bucket.secrets_bucket_name(env, options['co-name']),
        SnsAlarmTopicArn: options['sns-alarm-topic'],
        SiteName: site.gsub(/[^0-9a-z]/i, ''),
        WorkerIamProfile: options['iam-instance-profile'],
        WorkerInstanceType: options['worker-instance-type'],
        WorkerMaxSize: config['worker-max-size'] || 20,
        WorkerMinSize: 0,
        WorkerProcess: options['worker-process'],
        WorkerQueueName: config['worker-queue-name'],
        WorkerQueueUrl: config['worker-queue-url'],
        WorkerScheduleEndRecurrence: end_recurrence,
        WorkerScheduleNumInstances: num_workers,
        WorkerScheduleStartRecurrence: start_recurrence,
        WorkerSecurityGroup: options['worker-security-group'],
        WorkerVolumeSize: options['worker-volume-size']
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

  end

end
