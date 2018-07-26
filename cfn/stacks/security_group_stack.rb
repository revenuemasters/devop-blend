
class SecurityGroupStack < CloudformationStack

  class << self

    def ssh_access_sg(env, options)
      stack_name = "#{env}-ssh-access-sg"
      template_params = {
        CidrIp: '0.0.0.0/0',
        Description: 'SSH inbound access',
        Name: 'ssh-security-group',
        VpcId: options['vpc-id']
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

  end

end
