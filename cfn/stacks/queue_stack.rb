class QueueStack < CloudformationStack

  class << self

    def with_params(env, options)
      stack_name = "#{env}-queue-stack"
      template_params = {
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

  end

end
