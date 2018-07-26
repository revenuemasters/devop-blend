class AlarmMonitorLambda < CloudformationStack

  class << self

    def with_params(env, options)
      stack_name = "#{env}-alarm-monitor-lambda-stack"
      template_params = {
        SnsAlarmTopic: options['sns-alarm-topic']
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

  end

end
