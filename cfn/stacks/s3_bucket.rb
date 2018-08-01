class S3Bucket < CloudformationStack

  class << self
    def logging_bucket_name(env, aws_acnt_name)
      "#{aws_acnt_name}-#{env}-logging"
    end

    def logging_bucket(env, options)
      aws_acnt_name = options['aws_acnt_name']
      stack_name = "#{env}-s3-logging-bucket"
      template_params = {
        AccessControl: 'LogDeliveryWrite',
        BucketName: self.logging_bucket_name(env, aws_acnt_name),
        EncryptionRequired: 'false',
        LifecycleFilesystemBackups: 'false',
        LoggingBucketName: '',
        LoggingPrefix: '',
        VersioningEnabled: 'false'
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

    def secrets_bucket_name(env, aws_acnt_name)
      "#{aws_acnt_name}-#{env}-secrets"
    end

    def secrets_bucket(env, options)
      stack_name = "#{env}-s3-secrets-bucket"
      template_params = {
        AccessControl: 'Private',
        BucketName: self.secrets_bucket_name(env, options['aws_acnt_name']),
        LifecycleFilesystemBackups: 'false',
        LoggingBucketName: self.logging_bucket_name(env, options['aws_acnt_name']),
        LoggingPrefix: 's3-secrets/',
        EncryptionRequired: 'true',
        VersioningEnabled: 'true'
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

    def backups_bucket_name(env, aws_acnt_name)
      "#{aws_acnt_name}-#{env}-backups"
    end

    def backups_bucket(env, options)
      stack_name = "#{env}-s3-backups-bucket"
      template_params = {
        AccessControl: 'Private',
        BucketName: self.backups_bucket_name(env, options['aws_acnt_name']),
        EncryptionRequired: 'true',
        LifecycleFilesystemBackups: 'false',
        LoggingBucketName: '',
        LoggingPrefix: '',
        VersioningEnabled: 'true'
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

  end

end
