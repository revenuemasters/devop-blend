class LogGroupsStack < CloudformationStack

  class << self

    def with_params(env, options)
      stack_name = "#{env}-log-groups-stack"
      template_params = {
        EnvName: env,
        LogRetentionInDays: options['log-retention-in-days'],
      }
      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

  end

end
