CloudFormation do

  Description "Creates log groups. These are separate to avoid the 200 resource limit in the app stack template."

  Parameter(:EnvName) do
    String
  end

  Parameter(:LogRetentionInDays) do
    String
  end

  Condition :UseInfiniteLogRetention, FnEquals(Ref(:LogRetentionInDays), '0')

  # The awslogs daemon creates groups with no retention limit, so we need to create them with CloudFormation and
  # define a limit there. This means we need to ensure the groups are all created before the daemon starts, so
  # we make the ASGs depend on all group definitions.
  ['app', 'importer', 'sftp'].each do |role|
    Logs_LogGroup("#{role.capitalize}ArchiveToS3") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-archive-to-s3" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}ArchiveToS3")
    Logs_LogGroup("#{role.capitalize}Auth") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-auth" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}Auth")
    Logs_LogGroup("#{role.capitalize}Certbot") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-certbot" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}Certbot")
    Logs_LogGroup("#{role.capitalize}CfnInitCmd") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-cfn-init-cmd" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}CfnInitCmd")
    Logs_LogGroup("#{role.capitalize}CloudInitOutput") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-cloud-init-output" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}CloudInitOutput")
    Logs_LogGroup("#{role.capitalize}CodedeployAgent") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-codedeploy-agent" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}CodedeployAgent")
    Logs_LogGroup("#{role.capitalize}CodedeployDeployment") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-codedeploy-deployment" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}CodedeployDeployment")
    Logs_LogGroup("#{role.capitalize}Syslog") do
      LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-syslog" ] )
      RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
    end
    log_groups.push("#{role.capitalize}Syslog")
  end

  if config && config['sites']
    config['sites'].each do |site, params|
      ['app', 'importer'].each do |role|
        Logs_LogGroup("#{role.capitalize}Apache#{site.capitalize}Access") do
          LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-apache-#{site}-access" ] )
          RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
        end
        log_groups.push("#{role.capitalize}Apache#{site.capitalize}Access")

        Logs_LogGroup("#{role.capitalize}Apache#{site.capitalize}Error") do
          LogGroupName FnJoin('-', [ Ref(:EnvName), "#{role}-apache-#{site}-error" ] )
          RetentionInDays FnIf(:UseInfiniteLogRetention, Ref('AWS::NoValue'), Ref(:LogRetentionInDays))
        end
        log_groups.push("#{role.capitalize}Apache#{site.capitalize}Error")
      end
    end
  end

end
