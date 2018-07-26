CloudFormation do

  Description "Creates lambda function which creates and retires EBS volume snapshots."

  Parameter(:CreateSnapshots) do
    String
    Default 'true'
    AllowedValues ['true', 'false']
  end

  Parameter(:DeleteSnapshots) do
    String
    Default 'false'
    AllowedValues ['true', 'false']
  end

  Parameter(:DryRun) do
    String
    Default 'true'
    AllowedValues ['true', 'false']
  end

  Parameter(:LogLevel) do
    String
    Default 'INFO'
    AllowedValues ['CRITICAL', 'ERROR', 'WARNING', 'INFO', 'DEBUG'] # https://docs.python.org/3/library/logging.html#levels
  end

  Parameter(:MaxSnapshotAgeDays) do
    Numeric
    Default 60
  end

  Resource(:LambdaExecutionRole) do
    Type 'AWS::IAM::Role'
    Property(
      'AssumeRolePolicyDocument',
      {
        'Version' => '2012-10-17',
        'Statement' => [
          {
            'Effect' => 'Allow',
            'Principal' => {
              'Service' => [ 'lambda.amazonaws.com' ]
            },
            'Action' => [ 'sts:AssumeRole' ]
          }
        ]
      }
    )
    Property('Path', '/')
    Property(
      'Policies',
      [
        {
          'PolicyName' => 'volume_snapshots',
          'PolicyDocument' => {
            'Statement' => [
              {
                'Effect' => 'Allow',
                'Action' => [
                  'logs:CreateLogStream',
                  'logs:PutLogEvents'
                ],
                'Resource' => ['*']
              },
              {
                'Effect' => 'Allow',
                'Action' => [
                  'ec2:CreateSnapshot',
                  'ec2:CreateTags',
                  'ec2:DeleteSnapshot',
                  'ec2:DescribeSnapshots',
                  'ec2:DescribeVolumes'
                ],
                'Resource' => [ '*' ]
              }
            ]
          }
        }
      ]
    )
  end

  Resource(:LogGroupCreate) do
    Type 'AWS::Logs::LogGroup'
    Property('LogGroupName', FnJoin( '', [ '/aws/lambda/', Ref('AWS::Region'), '-create-volume-snapshots' ] ))
    Property('RetentionInDays', 365)
  end

  Resource(:LambdaFunctionCreate) do
    Type 'AWS::Lambda::Function'
    Property('Description', 'Snapshots EBS volumes.')
    Property('FunctionName', FnJoin( '', [ Ref('AWS::Region'), '-create-volume-snapshots' ] ))
    Property('Handler', 'index.lambda_handler')
    Property('MemorySize', '128')
    Property('Role', FnGetAtt(:LambdaExecutionRole, 'Arn'))
    Property('Runtime', 'python3.6')
    Property('Timeout', '300')
    Property(
      'Code',
      {
        'ZipFile' => File.read(File.join(File.dirname(__FILE__), 'volume_snapshot_lambda_create.py'))
      }
    )
  end

  Resource(:LambdaWatcherRuleCreate) do
    Type 'AWS::Events::Rule'
    Property('ScheduleExpression', 'cron(0 8 * * ? *)')
    Property(
      'Targets',
      [
        {
          'Arn' => FnGetAtt(:LambdaFunctionCreate, 'Arn'),
          'Id' => 'LambdaWatcherScheduler',
          'Input' => FnJoin('', [
             '{',
             '"create_snapshots": ', Ref(:CreateSnapshots), ',',
             '"dry_run": ', Ref(:DryRun), ',',
             '"log_level": "', Ref(:LogLevel), '",',
             '"region": "', Ref('AWS::Region'), '"',
             '}'
          ])
        }
      ]
    )
  end

  Resource(:LambdaInvokePermissionCreate) do
    Type 'AWS::Lambda::Permission'
    Property('FunctionName', FnGetAtt(:LambdaFunctionCreate, 'Arn'))
    Property('Action', 'lambda:InvokeFunction')
    Property('Principal', 'events.amazonaws.com')
    Property('SourceArn', FnGetAtt(:LambdaWatcherRuleCreate, 'Arn'))
  end

  Resource(:LogGroupDelete) do
    Type 'AWS::Logs::LogGroup'
    Property('LogGroupName', FnJoin( '', [ '/aws/lambda/', Ref('AWS::Region'), '-delete-volume-snapshots' ] ))
    Property('RetentionInDays', 365)
  end

  Resource(:LambdaFunctionDelete) do
    Type 'AWS::Lambda::Function'
    Property('Description', 'Deletes old EBS snapshots.')
    Property('FunctionName', FnJoin( '', [ Ref('AWS::Region'), '-delete-volume-snapshots' ] ))
    Property('Handler', 'index.lambda_handler')
    Property('MemorySize', '512')
    Property('Role', FnGetAtt(:LambdaExecutionRole, 'Arn'))
    Property('Runtime', 'python3.6')
    Property('Timeout', '300')
    Property(
      'Code',
      {
        'ZipFile' => File.read(File.join(File.dirname(__FILE__), 'volume_snapshot_lambda_delete.py'))
      }
    )
  end

  Resource(:LambdaWatcherRuleDelete) do
    Type 'AWS::Events::Rule'
    Property('ScheduleExpression', 'cron(0 10 * * ? *)')
    Property(
      'Targets',
      [
        {
          'Arn' => FnGetAtt(:LambdaFunctionDelete, 'Arn'),
          'Id' => 'LambdaWatcherScheduler',
          'Input' => FnJoin('', [
             '{',
             '"delete_old_snapshots": ', Ref(:DeleteSnapshots), ',',
             '"dry_run": ', Ref(:DryRun), ',',
             '"log_level": "', Ref(:LogLevel), '",',
             '"max_snapshot_age_days": ', Ref(:MaxSnapshotAgeDays), ',',
             '"region": "', Ref('AWS::Region'), '"',
             '}'
          ])
        }
      ]
    )
  end

  Resource(:LambdaInvokePermissionDelete) do
    Type 'AWS::Lambda::Permission'
    Property('FunctionName', FnGetAtt(:LambdaFunctionDelete, 'Arn'))
    Property('Action', 'lambda:InvokeFunction')
    Property('Principal', 'events.amazonaws.com')
    Property('SourceArn', FnGetAtt(:LambdaWatcherRuleDelete, 'Arn'))
  end

end
