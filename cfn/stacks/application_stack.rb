class ApplicationStack < CloudformationStack

  class << self

    def with_params(env, options)
      stack_name = "#{env}-application-stack"
      template_params = {
        AlarmEmail: options['alarm-email'],
        ApiImporterSha: options['api-importer-sha'],
        AppDesiredSize: options['app-desired-size'],
        AppInstanceType: options['app-instance-type'],
        AppMaxSize: options['app-max-size'],
        AppMinSize: options['app-min-size'],
        AppVolumeSize: options['app-volume-size'],
        AvailabilityZones: options['availability-zones'],
        BackupsBucket: S3Bucket.backups_bucket_name(env, options['co-name']),
        ChefSha: options['chef-sha'],
        CvcSha: options['cvc-sha'],
        DatabaseInstanceType: options['rds-instance-type'],
        DatabaseMasterPasswordNoEcho: get_secret(env, 'rds-admin-password', options),
        DatabaseMasterUsername: 'admin',
        DatabaseMultiAZ: options['rds-multi-az'],
        DatabaseStorageSize: options['rds-storage-size'],
        DedicatedTenancy: options['dedicated-tenancy'],
        DefaultAvailabilityZone: options['default-availability-zone'],
        EdiMonitorSha: options['edi-monitor-sha'],
        EdiSha: options['edi-sha'],
        EdiUiSha: options['edi-ui-sha'],
        EnvName: env,
        HealthCheckUrl: options['health-check-url'],
        HostedZoneName: options['hosted-zone-name'],
        ImageId: options['image-id'],
        ImporterInstanceType: options['importer-instance-type'],
        ImporterVolumeSize: options['importer-volume-size'],
        KeyName: options['key-name'],
        PostImportAlertsSha: options['post-import-alerts-sha'],
        RootVolumeSize: options['root-volume-size'],
        SecretsBucket: S3Bucket.secrets_bucket_name(env, options['co-name']),
        SftpVolumeSize: options['sftp-volume-size'],
        S3ReadOnlyCrossAccountId: options['s3-cross-account-id'],
        S3ReadOnlyCrossAccountRoleArn: options['s3-cross-account-arn'],
        S3ReadOnlyCrossAccountRoleBucket: options['s3-cross-account-bucket'],
        WorkerProcess: options['worker-process']
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

    # https://medium.com/aws-activate-startup-blog/practical-vpc-design-8412e1a18dcc#.rvoigxbvc
    def calc_cidr(type, num)
      # num is 0, 1, 2
      case type
      when 'private'
        case num
        when 0
          '10.0.0.0/19'
        when 1
          '10.0.64.0/19'
        when 2
          '10.0.128.0/19'
        end
      when 'public'
        case num
        when 0
          '10.0.32.0/20'
        when 1
          '10.0.96.0/20'
        when 2
          '10.0.160.0/20'
        end
      when 'spare'
        case num
        when 0
          '10.0.48.0/20'
        when 1
          '10.0.112.0/20'
        when 2
          '10.0.176.0/20'
        end
      end
    end

  end

end
