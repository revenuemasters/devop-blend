class VolumeSnapshotLambda < CloudformationStack

  class << self

    def with_params(options)
      stack_name = "#{options['region']}-volume-snapshot-lambda-stack"
      stack = self.new(stack_name, options)

      template_params = {
        CreateSnapshots: options['create'],
        DeleteSnapshots: options['delete'],
        DryRun: options['dry-run'],
        LogLevel: options['log-level'],
        MaxSnapshotAgeDays: options['max-age-days'],
      }

      stack.create_or_update(template_params)
    end

  end

end
