CloudFormation do

  Description "Creates an instance of the worker for one client site"

  Parameter(:ChefSha) do
    String
  end

  Parameter(:CodeDeployRoleArn) do
    String
  end

  Parameter(:DatabaseHost) do
    String
  end

  Parameter(:EnvName) do
    String
  end

  Parameter(:ImageId) do
    String
  end

  Parameter(:KeyName) do
    Description 'The EC2 key pair to allow SSH access to the instances'
    String
  end

  Parameter(:PrivateSubnets) do
    Type :CommaDelimitedList
  end

  Parameter(:RootVolumeSize) do
    String
  end

  Parameter(:SiteName) do
    String
  end

  Parameter(:SecretsBucket) do
    String
  end

  Parameter(:SnsAlarmTopicArn) do
    String
  end

  Parameter(:WorkerIamProfile) do
    String
  end

  Parameter(:WorkerInstanceType) do
    String
  end

  Parameter(:WorkerMaxSize) do
    Type :Number
  end

  Parameter(:WorkerMinSize) do
    Type :Number
  end

  Parameter(:WorkerProcess) do
    String
    Default ''
  end

  Parameter(:WorkerQueueName) do
    String
  end

  Parameter(:WorkerQueueUrl) do
    String
  end

  Parameter(:WorkerScheduleEndRecurrence) do
    String
    Default ''
  end

  Parameter(:WorkerScheduleNumInstances) do
    String
    Default ''
  end

  Parameter(:WorkerScheduleStartRecurrence) do
    String
    Default ''
  end

  Parameter(:WorkerSecurityGroup) do
    String
  end

  Parameter(:WorkerVolumeSize) do
    String
  end

  Condition :DoWorkerScheduledScaling, FnNot([FnEquals(Ref(:WorkerScheduleStartRecurrence), '')])

  AutoScaling_LaunchConfiguration(:WorkerInstancesLaunchConfig) do
    KeyName Ref(:KeyName)
    ImageId Ref(:ImageId)
    IamInstanceProfile Ref(:WorkerIamProfile)
    InstanceType Ref(:WorkerInstanceType)
    SecurityGroups [ Ref(:WorkerSecurityGroup) ]
    Property(
      'BlockDeviceMappings',
      [
        {
          'DeviceName' => '/dev/sda1',
          'Ebs' => {
            'VolumeSize' => Ref(:RootVolumeSize),
            'VolumeType' => 'gp2'
          }
        },
        {
          'DeviceName' => '/dev/sdf',
          'Ebs' => {
            'Encrypted' => true,
            'VolumeSize' => Ref(:WorkerVolumeSize),
            'VolumeType' => 'gp2'
          }
        }
      ]
    )
    UserData(
      FnBase64(
        FnJoin(
          '',
          [
            "#!/bin/bash -v\n",
            "\n",
            "# change me to reprovision 2018-01-15\n",
            "\n",
            "# format encrypted drive\n",
            "mkfs -t ext4 /dev/xvdf\n",
            "mkdir -p /encrypted\n",
            "mount /dev/xvdf /encrypted\n",
            "echo '/dev/xvdf /encrypted ext4 defaults,nofail 0 2' >> /etc/fstab\n",
            "\n",
            "instance_id=`curl http://169.254.169.254/latest/meta-data/instance-id`\n",
            # tag root volume with a name
            "until apt-get install -y jq\n",
            "do\n",
            "  sleep 10\n",
            "done\n",
            "\n",
            "volume_ids=$(aws ec2 describe-volumes",
            " --filters Name=attachment.instance-id,Values=$instance_id",
            " --region ", Ref('AWS::Region'),
            " | jq -r '.Volumes[].VolumeId' | tr '\\n' ' ') &&",
            "aws ec2 create-tags",
            " --region ", Ref('AWS::Region'),
            " --resources $volume_ids",
            " --tags 'Key=\"Name\",Value=\"", Ref(:EnvName), "-worker-", Ref(:SiteName), "-root\"'",
            "\n",
            "cfn-init --stack ", Ref('AWS::StackName'), " --resource WorkerInstancesAsg --region ", Ref('AWS::Region'), "\n",
          ]
        )
      )
    )
  end

  AutoScaling_AutoScalingGroup(:WorkerInstancesAsg) do
    VPCZoneIdentifier Ref(:PrivateSubnets)
    LaunchConfigurationName Ref(:WorkerInstancesLaunchConfig)
    MaxSize Ref(:WorkerMaxSize)
    MinSize Ref(:WorkerMinSize)
    Tags [
      { Key: 'Environment', Value: Ref(:EnvName), PropagateAtLaunch: 'true' },
      { Key: 'Name', Value: FnJoin('', [ Ref(:EnvName), '-worker-', Ref(:SiteName) ]), PropagateAtLaunch: 'true' },
      { Key: 'Role', Value: 'worker', PropagateAtLaunch: 'true' }
    ]

    Metadata(
      :aws_region => Ref('AWS::Region'),
      :chef_sha => Ref(:ChefSha),
      :co_name => co_name,
      :config => config.to_json,
      :database_host => Ref(:DatabaseHost),
      :env_name => Ref(:EnvName),
      :repo_base => repo_base,
      :secrets_bucket => Ref(:SecretsBucket),
      :sns_alarm_topic => Ref(:SnsAlarmTopicArn),
      :worker_process => Ref(:WorkerProcess),
      'AWS::CloudFormation::Init' => {
        :config => {
          :files => {
            '/etc/rm-role' => {
              :content => 'worker',
              :mode => '00644',
              :owner => 'root',
              :group => 'root'
            },
            '/usr/bin/run-chef' => {
              :content => FnJoin(
                '',
                [
                  "#!/usr/bin/env bash\n",
                  "chef-solo -c /root/src/solo.rb -o 'role[worker]'\n"
                ]
              ),
              :mode => '00700',
              :owner => 'root',
              :group => 'root'
            },
            '/etc/profile.d/shell_tweaks.sh' => {
              :content => FnJoin(
                '',
                [
                  "set -o emacs\n",
                  "PS1='\\n\\u in \\w [ Revenue Masters | \\t | \\h | worker | ",
                  { "Ref": "AWS::StackName" },
                  " | ",
                  { "Ref": "AWS::Region" },
                  " ]\\n# '\n"
                ]
              ),
              :mode => "000444",
              :owner => "root",
              :group => "root"
            }
          },
          :commands => {
            '0_install_ohai_hints' => {
              :command => FnJoin(
                '',
                [
                  "mkdir -p -m 0755 /etc/chef/ohai/hints && ",
                  "touch /etc/chef/ohai/hints/ec2.json && ",
                  "chmod 0644 /etc/chef/ohai/hints/ec2.json && ",
                  "touch /etc/chef/ohai/hints/iam.json && ",
                  "chmod 0644 /etc/chef/ohai/hints/iam.json"
                ]
              )
            },
            '1_run_chef' => {
              :command => FnJoin(
                '',
                [
                  "cd /root/src/devops && ",
                  "ssh-agent bash -c 'ssh-add /root/.ssh/keys/github-#{co_name}-devops; git fetch --all' && ",
                  "ssh-agent bash -c 'ssh-add /root/.ssh/keys/github-#{co_name}-devops; git checkout --force ", Ref(:ChefSha), "' && ",
                  "run-chef"
                ]
              )
            }
          }
        }
      }
    )
  end

  AutoScaling_ScheduledAction(:ScheduledActionUp) do
    Condition :DoWorkerScheduledScaling
    AutoScalingGroupName Ref(:WorkerInstancesAsg)
    MinSize Ref(:WorkerScheduleNumInstances)
    Recurrence Ref(:WorkerScheduleStartRecurrence)
  end

  AutoScaling_ScheduledAction(:ScheduledActionDown) do
    Condition :DoWorkerScheduledScaling
    AutoScalingGroupName Ref(:WorkerInstancesAsg)
    MinSize 0
    Recurrence Ref(:WorkerScheduleEndRecurrence)
  end

  AutoScaling_ScalingPolicy(:WorkerScaleUpPolicy) do
    AdjustmentType 'ChangeInCapacity'
    AutoScalingGroupName Ref(:WorkerInstancesAsg)
    Cooldown 600
    ScalingAdjustment 2
  end

  AutoScaling_ScalingPolicy(:WorkerScaleDownPolicy) do
    AdjustmentType 'ChangeInCapacity'
    AutoScalingGroupName Ref(:WorkerInstancesAsg)
    Cooldown 60
    ScalingAdjustment -2
  end

  CloudWatch_Alarm(:WorkerQueueAlarmHigh) do
    AlarmDescription 'scale-up if queue length is not zero'
    MetricName 'ApproximateNumberOfMessagesVisible'
    Namespace 'AWS/SQS'
    Statistic 'Average'
    Period 300
    EvaluationPeriods 1
    Threshold 0
    AlarmActions [ Ref(:WorkerScaleUpPolicy) ]
    Dimensions [
      {
        Name: 'QueueName',
        Value: Ref(:WorkerQueueName)
      }
    ]
    ComparisonOperator 'GreaterThanThreshold'
  end

  CloudWatch_Alarm(:WorkerQueueAlarmLow) do
    AlarmDescription 'scale-down if queue length is zero'
    MetricName 'ApproximateNumberOfMessagesVisible'
    Namespace 'AWS/SQS'
    Statistic 'Average'
    Period 300
    EvaluationPeriods 2
    Threshold 1
    AlarmActions [ Ref(:WorkerScaleDownPolicy) ]
    Dimensions [
      {
        Name: 'QueueName',
        Value: Ref(:WorkerQueueName)
      }
    ]
    ComparisonOperator 'LessThanThreshold'
  end

  Output(:WorkerInstancesAsg, Ref(:WorkerInstancesAsg))
end
