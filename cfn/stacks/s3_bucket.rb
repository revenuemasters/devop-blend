class S3Bucket < CloudformationStack

  class << self

    def logging_bucket_name(env, co_name)
      "#{co_name}-#{env}-logging"
    end

    def logging_bucket(env, options)
      stack_name = "#{env}-s3-logging-bucket"
      template_params = {
        AccessControl: 'LogDeliveryWrite',
        BucketName: self.logging_bucket_name(env, options['co-name']),
        EncryptionRequired: 'false',
        LifecycleFilesystemBackups: 'false',
        LoggingBucketName: '',
        LoggingPrefix: '',
        VersioningEnabled: 'false'
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

    def secrets_bucket_name(env, co_name)
      "#{co_name}-#{env}-secrets"
    end

    def secrets_bucket(env, options)
      stack_name = "#{env}-s3-secrets-bucket"
      template_params = {
        AccessControl: 'Private',
        BucketName: self.secrets_bucket_name(env, options['co-name']),
        LifecycleFilesystemBackups: 'false',
        LoggingBucketName: self.logging_bucket_name(env, options['co-name']),
        LoggingPrefix: 's3-secrets/',
        EncryptionRequired: 'true',
        VersioningEnabled: 'true'
      }

      stack = self.new(stack_name, options)
      stack.create_or_update(template_params)
    end

    def backups_bucket_name(env, co_name)
      "#{co_name}-#{env}-backups"
    end

    def backups_bucket(env, options)
      stack_name = "#{env}-s3-backups-bucket"
      template_params = {
        AccessControl: 'Private',
        BucketName: self.backups_bucket_name(env, options['co-name']),
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
