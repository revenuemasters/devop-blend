CloudFormation do

  Description "Creates lambda function which alerts a SNS topic every hour if there are alarms in ALARM status"

  Parameter(:SnsAlarmTopic) do
    String
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
          'PolicyName' => 'root',
          'PolicyDocument' => {
            'Statement' => [
              {
                'Effect' => 'Allow',
                'Action' => [
                  'sns:Publish'
                ],
                'Resource' => [ Ref(:SnsAlarmTopic) ]
              },
              {
                'Effect' => 'Allow',
                'Action' => [
                  'logs:*'
                ],
                'Resource' => 'arn:aws:logs:*:*:*'
              },
              {
                'Effect' => 'Allow',
                'Action' => [
                  'cloudwatch:DescribeAlarms'
                ],
                'Resource' => [ '*' ]
              }
            ]
          }
        }
        
      ]
    )
  end

  Resource(:LambdaFunction) do
    Type 'AWS::Lambda::Function'
    Property('Description', 'Looks for CloudWatch alarms that have been in the alarm state for more than an hour and sends a report to an SNS topic')
    Property('Handler', 'index.lambda_handler')
    Property('MemorySize', '128')
    Property('Role', FnGetAtt(:LambdaExecutionRole, 'Arn'))
    Property('Runtime', 'python2.7')
    Property('Timeout', '10')
    Property(
      'Code',
      {
        'ZipFile' => File.read(File.join(File.dirname(__FILE__), 'alarm_monitor_lambda.py'))
      }
    )
  end

  Resource(:LambdaWatcherRule) do
    Type 'AWS::Events::Rule'
    Property('ScheduleExpression', 'rate(1 hour)')
    Property(
      'Targets',
      [
        {
          'Arn' => FnGetAtt(:LambdaFunction, 'Arn'),
          'Id' => 'LambdaWatcherScheduler',
          'Input' => FnJoin('', ['{"sns_alarm_arn":"', Ref(:SnsAlarmTopic), '"}'])
        }
      ]
    )
  end

  Resource(:LambdaInvokePermission) do
    Type 'AWS::Lambda::Permission'
    Property('FunctionName', FnGetAtt(:LambdaFunction, 'Arn'))
    Property('Action', 'lambda:InvokeFunction')
    Property('Principal', 'events.amazonaws.com')
    Property('SourceArn', FnGetAtt(:LambdaWatcherRule, 'Arn'))
  end

end
