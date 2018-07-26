CloudFormation do

  Description "Creates an s3 bucket"

  Parameter(:AccessControl) do
    String
  end

  Parameter(:BucketName) do
    String
    Default ''
  end

  Parameter(:LifecycleFilesystemBackups) do
    String
    Default 'false'
    AllowedValues ['true', 'false']
  end

  Parameter(:LoggingBucketName) do
    String
    Default ''
  end

  Parameter(:LoggingPrefix) do
    String
    Default ''
  end

  Parameter(:EncryptionRequired) do
    String
    Default 'false'
    AllowedValues ['true', 'false']
  end

  Parameter(:VersioningEnabled) do
    String
    Default 'false'
    AllowedValues ['true', 'false']
  end

  Condition :UseLifecycleOnFilesystemBackups, FnEquals(Ref(:LifecycleFilesystemBackups), 'true')
  Condition :UseBucketLogging, FnNot([FnEquals(Ref(:LoggingBucketName), '')])
  Condition :UseBucketName, FnNot([FnEquals(Ref(:BucketName), '')])
  Condition :UseBucketVersioning, FnEquals(Ref(:VersioningEnabled), 'true')
  Condition :UseBucketEncryption, FnEquals(Ref(:EncryptionRequired), 'true')

  S3_BucketPolicy(:EncryptionPolicy) do
    Condition(:UseBucketEncryption)
    Property(
      :PolicyDocument,
      {
        Version: '2012-10-17',
        Id: 'PutObjPolicy',
        Statement: [
          {
            Sid: 'DenyUnencryptedObjectUploads',
            Effect:'Deny',
            Principal:'*',
            Action:'s3:PutObject',
            Resource: FnJoin('', ['arn:aws:s3:::', Ref(:BucketName), '/*']),
            Condition: {
              StringNotEquals: {
                's3:x-amz-server-side-encryption':'AES256'
              }
            }
          }
        ]
      }
    )
    Property(:Bucket, Ref(:BucketName))
  end

  S3_Bucket(:Bucket) do
    AccessControl Ref(:AccessControl)
    BucketName Ref(:BucketName)
    Property(
      :VersioningConfiguration,
      FnIf(:UseBucketVersioning,
           {
             'Status': 'Enabled'
           },
           {
             'Ref': 'AWS::NoValue'
           }
          )
    )
    Property(
      :LifecycleConfiguration,
      FnIf(:UseLifecycleOnFilesystemBackups,
           {
             Rules: [{
               Id: 'FilesystemBackupsLifecycle',
               Status: 'Enabled',
               Prefix: 'filesystems',
               ExpirationInDays: '365',
               Transitions: [{StorageClass: 'GLACIER', TransitionInDays: '60'}],
               NoncurrentVersionExpirationInDays: FnIf(:UseBucketVersioning, '365', {'Ref': 'AWS::NoValue'}),
               NoncurrentVersionTransitions: FnIf(:UseBucketVersioning,
                                                  [{StorageClass: 'GLACIER', TransitionInDays: '60'}],
                                                  {'Ref': 'AWS::NoValue'})
            }]
           },
           {
             'Ref': 'AWS::NoValue'
           }
          )
    )
    Property(
      :LoggingConfiguration,
      FnIf(:UseBucketLogging,
           {
             DestinationBucketName: Ref(:LoggingBucketName),
             LogFilePrefix: Ref(:LoggingPrefix)
           },
           {
             'Ref': 'AWS::NoValue'
           }
          )
    )
  end

  Output(:S3Bucket, Ref(:Bucket))
end
