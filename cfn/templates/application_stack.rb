CloudFormation do

  Description "Creates an instance of the Revenue Masters application for one client"

  Parameter(:AlarmEmail) do
    String
  end

  Parameter(:ApiImporterSha) do
    Type :String
  end

  Parameter(:AppDesiredSize) do
    Type :Number
  end

  Parameter(:AppInstanceType) do
    String
  end

  Parameter(:AppMaxSize) do
    Type :Number
  end

  Parameter(:AppMinSize) do
    Type :Number
  end

  Parameter(:AppVolumeSize) do
    Type :Number
  end

  Parameter(:AvailabilityZones) do
    Type :CommaDelimitedList
  end

  Parameter(:ChefSha) do
    String
  end

  Parameter(:CvcSha) do
    String
  end

  Parameter(:DatabaseStorageSize) do
    Type :Number
  end

  Parameter(:DatabaseInstanceType) do
    String
  end

  Parameter(:DatabaseMasterUsername) do
    String
  end

  Parameter(:DatabaseMasterPasswordNoEcho) do
    String
    NoEcho true
  end

  Parameter(:DatabaseMultiAZ) do
    String
    Default 'false'
    AllowedValues ['true', 'false']
  end

  Parameter(:DedicatedTenancy) do
    String
    Default 'false'
    AllowedValues ['true', 'false']
  end

  Parameter(:DefaultAvailabilityZone) do
    String
  end

  Parameter(:EdiMonitorSha) do
    String
  end

  Parameter(:EdiSha) do
    String
  end

  Parameter(:EdiUiSha) do
    String
  end

  Parameter(:EnvName) do
    String
  end

  Parameter(:HealthCheckUrl) do
    String
  end

  Parameter(:HostedZoneName) do
    String
  end

  Parameter(:ImageId) do
    String
  end

  Parameter(:ImporterInstanceType) do
    String
  end

  Parameter(:ImporterVolumeSize) do
    String
  end

  Parameter(:KeyName) do
    Description 'The EC2 key pair to allow SSH access to the instances'
    String
  end

  Parameter(:PostImportAlertsSha) do
    String
  end

  Parameter(:RootVolumeSize) do
    String
  end

  Parameter(:SecretsBucket) do
    String
  end

  Parameter(:BackupsBucket) do
    String
  end

  Parameter(:SftpVolumeSize) do
    String
  end

  # This is the AWS account id for the account which will be downloading the files
  Parameter(:S3ReadOnlyCrossAccountId) do
    String
    Default ''
  end

  # This is the role in the providing account that the consuming account will assume
  Parameter(:S3ReadOnlyCrossAccountRoleArn) do
    String
    Default ''
  end

  # This is the bucket which contains the files
  Parameter(:S3ReadOnlyCrossAccountRoleBucket) do
    String
    Default ''
  end

  # This allows the process for the workers to be customized per client
  Parameter(:WorkerProcess) do
    String
    Default ''
  end

  Condition :UseDatabaseMultiAZ, FnEquals(Ref(:DatabaseMultiAZ), 'true')
  Condition :UseDedicatedTenancy, FnEquals(Ref(:DedicatedTenancy), 'true')
  Condition :UseS3ReadOnlyCrossAccountRoleArn, FnNot([FnEquals(Ref(:S3ReadOnlyCrossAccountRoleArn), '')])
  Condition :UseS3ReadOnlyCrossAccountRole, FnNot([FnEquals(Ref(:S3ReadOnlyCrossAccountId), '')])

  vpc_cidr_block = '10.0.0.0/16'

  Role(:S3ReadOnlyCrossAccountRole) do
    Condition :UseS3ReadOnlyCrossAccountRole
    AssumeRolePolicyDocument(
      {
        "Version" => "2012-10-17",
        "Statement" => [
          {
            "Effect" => "Allow",
            "Principal" => {
              "AWS" => FnJoin('', ["arn:aws:iam::", Ref(:S3ReadOnlyCrossAccountId), ":root"])
            },
            "Action":"sts:AssumeRole"
          }
        ]
      }
    )
    Path '/'
  end

  IAM_Policy(:S3ReadOnlyCrossAccountPolicy) do
    Condition :UseS3ReadOnlyCrossAccountRole
    DependsOn [:S3ReadOnlyCrossAccountRole]
    Property('PolicyName', 'S3ReadOnlyCrossAccountPolicy')
    Property('Roles', [Ref(:S3ReadOnlyCrossAccountRole)])
    Property('PolicyDocument', {
               "Version" => "2012-10-17",
               "Statement" => [
                 {
                   "Effect" => "Allow",
                   "Action" => "s3:ListBucket",
                   "Resource" => [
                     FnJoin('', ["arn:aws:s3:::", Ref(:BackupsBucket)])
                   ]
                 },
                 {
                   "Effect" => "Allow",
                   "Action" => "s3:GetObject",
                   "Resource" => [
                     FnJoin('', ["arn:aws:s3:::", Ref(:BackupsBucket), "/*"])
                   ]
                 }
               ]
             }
            )
  end

  EC2_VPC(:Vpc) do
    CidrBlock vpc_cidr_block
    EnableDnsSupport true
    EnableDnsHostnames true
    InstanceTenancy FnIf(:UseDedicatedTenancy, 'dedicated', 'default')
    Tags [ { Key: "Name", Value: Ref(:EnvName) } ]
  end

  # Same settings as default but we make our own so deleting stacks works
  # https://forums.aws.amazon.com/message.jspa?messageID=409995
  EC2_DHCPOptions(:DhcpOptions) do
    DomainName 'ec2.internal'
    DomainNameServers ['AmazonProvidedDNS']
  end

  EC2_VPCDHCPOptionsAssociation(:VpcDhcpAssociation) do
    DhcpOptionsId Ref(:DhcpOptions)
    VpcId Ref(:Vpc)
  end

  EC2_InternetGateway(:InternetGateway) do
    Tags [ { Key: "Network", Value: "Public" } ]
  end

  EC2_VPCGatewayAttachment(:GatewayToInternet) do
    DependsOn [:Vpc, :InternetGateway]
    VpcId Ref(:Vpc)
    InternetGatewayId Ref(:InternetGateway)
  end

  EC2_RouteTable(:PublicRouteTable) do
    VpcId Ref(:Vpc)
  end

  EC2_Route(:PublicRoute) do
    RouteTableId Ref(:PublicRouteTable)
    DestinationCidrBlock "0.0.0.0/0"
    GatewayId Ref(:InternetGateway)
  end

  EC2_EIP(:NatEip) do
    Domain 'vpc'
  end

  Resource(:NatGateway) do
    Type 'AWS::EC2::NatGateway'
    DependsOn [:GatewayToInternet]
    Property('AllocationId', FnGetAtt(:NatEip, 'AllocationId'))
    Property('SubnetId', Ref("publicaz#{default_az}"))
  end

  EC2_RouteTable(:PrivateRouteTable) do
    VpcId Ref(:Vpc)
  end

  EC2_Route(:PrivateRoute) do
    DependsOn [:PrivateRouteTable, :NatGateway]
    RouteTableId Ref(:PrivateRouteTable)
    DestinationCidrBlock "0.0.0.0/0"
    Property('NatGatewayId', Ref(:NatGateway))
  end

  availability_zones.each_with_index do |az, index|
    ['public', 'private', 'spare'].each do |type|
      EC2_Subnet("#{type}az#{az}") do
        DependsOn [:Vpc]
        AvailabilityZone FnJoin('', [ Ref('AWS::Region'), "#{az}" ])
        MapPublicIpOnLaunch type == 'public'
        CidrBlock ApplicationStack.calc_cidr(type, index)
        VpcId Ref(:Vpc)
        Tags [ { Key: "Name", Value: FnJoin('', [Ref(:EnvName), ": #{type} ", Ref('AWS::Region'), "#{az}"]) } ]
      end

      case type
      when 'public'
        EC2_SubnetRouteTableAssociation("PublicRouteAssociation#{az}") do
          RouteTableId Ref(:PublicRouteTable)
          SubnetId Ref("#{type}az#{az}")
        end
      when 'private'
        EC2_SubnetRouteTableAssociation("PrivateRouteAssociation#{az}") do
          RouteTableId Ref(:PrivateRouteTable)
          SubnetId Ref("#{type}az#{az}")
        end
      when 'spare'
        EC2_SubnetRouteTableAssociation("SpareRouteAssociation#{az}") do
          RouteTableId Ref(:PrivateRouteTable)
          SubnetId Ref("#{type}az#{az}")
        end
      end
    end
  end

  private_subnets = availability_zones.map { |az| Ref("privateaz#{az}") }
  public_subnets  = availability_zones.map { |az| Ref("publicaz#{az}") }
  spare_subnets   = availability_zones.map { |az| Ref("spareaz#{az}") }

  sftp_ingress_rules = [
    {
      IpProtocol: 'tcp',
      FromPort: '22',
      ToPort: '22',
      CidrIp: vpc_cidr_block
    },
    # The Importer connects to SFTP using its DNS name. That DNS name resolves to a public IP
    # so the traffic goes out the NAT Gateway. This means the SFTP server sees the traffic as
    # coming from the NAT's EIP, not either of the Importer's internal IPs.
    {
      IpProtocol: 'tcp',
      FromPort: '22',
      ToPort: '22',
      CidrIp: FnJoin('', [Ref(:NatEip), '/32'])
    },
    # HTTP
    {
      IpProtocol: 'tcp',
      FromPort: '80',
      ToPort: '80',
      CidrIp: '0.0.0.0/0'
    },
    # HTTPS
    {
      IpProtocol: 'tcp',
      FromPort: '443',
      ToPort: '443',
      CidrIp: '0.0.0.0/0'
    }
  ]
  whitelisted_ip_cidrs.each do |port, cidrs|
    cidrs.each do |cidr|
      sftp_ingress_rules.concat([
      {
          IpProtocol: 'tcp',
          FromPort: port,
          ToPort: port,
          CidrIp: cidr
      }])
    end
  end
  EC2_SecurityGroup(:SftpSecurityGroup) do
    GroupDescription 'sFTP security group'
    SecurityGroupIngress(sftp_ingress_rules)
    VpcId Ref(:Vpc)
  end

  app_ingress_rules = [
    # TODO: fix - shouldn't be 0.0.0.0/0 even if not publicly accessible.
    # Should just allow SSH from the SFTP server
    # allow SSH from VPC
    {
      IpProtocol: 'tcp',
      FromPort: '22',
      ToPort: '22',
      CidrIp: '0.0.0.0/0'
    },
    # TODO: fix - shouldn't be 0.0.0.0/0
    # Should just allow this from VPC or ELB
    # allow http
    {
      IpProtocol: 'tcp',
      FromPort: '80',
      ToPort: '80',
      CidrIp: '0.0.0.0/0'
    },
  ]
  config['ssl_ports'].each do |port|
    app_ingress_rules.concat([
      # TODO: fix - shouldn't be 0.0.0.0/0
      # Should just allow this from VPC or ELB
      # allow https
      {
        IpProtocol: 'tcp',
        FromPort: "#{port}",
        ToPort: "#{port}",
        CidrIp: '0.0.0.0/0'
      }
    ])
  end
  EC2_SecurityGroup(:AppSecurityGroup) do
    GroupDescription 'app server security group'
    SecurityGroupIngress(app_ingress_rules)
    VpcId Ref(:Vpc)
  end

  EC2_SecurityGroup(:WorkerSecurityGroup) do
    GroupDescription 'worker server security group'
    SecurityGroupIngress([
      # allow SSH from everywhere
      {
        IpProtocol: 'tcp',
        FromPort: '22',
        ToPort: '22',
        CidrIp: vpc_cidr_block
      }
    ])
    VpcId Ref(:Vpc)
  end

  EC2_SecurityGroup(:DatabaseSecurityGroup) do
    GroupDescription 'database server security group'
    SecurityGroupIngress([
      # allow 3306 from the application security group
      {
        IpProtocol: 'tcp',
        FromPort: '3306',
        ToPort: '3306',
        SourceSecurityGroupId: Ref(:AppSecurityGroup)
      },
      # allow 3306 from the import security group
      {
        IpProtocol: 'tcp',
        FromPort: '3306',
        ToPort: '3306',
        SourceSecurityGroupId: Ref(:ImporterSecurityGroup)
      },
      # allow 3306 from the worker security group
      {
        IpProtocol: 'tcp',
        FromPort: '3306',
        ToPort: '3306',
        SourceSecurityGroupId: Ref(:WorkerSecurityGroup)
      },
      # allow 3306 from the sftp security group
      # this is mainly to allow developers to tunnel to db
      {
        IpProtocol: 'tcp',
        FromPort: '3306',
        ToPort: '3306',
        SourceSecurityGroupId: Ref(:SftpSecurityGroup)
      }
    ])
    VpcId Ref(:Vpc)
  end

  Role(:AppIamRole) do
    AssumeRolePolicyDocument(
      {
        "Version" => "2012-10-17",
        "Statement" => [
          {
            "Effect" => "Allow",
            "Principal" => {
              "Service" => "ec2.amazonaws.com"
            },
            "Action" => "sts:AssumeRole"
          }
        ]
      }
    )
    Path '/'
    Policies [
      {
        "PolicyName" => "app-policy",
        "PolicyDocument" => {
          "Version" => "2012-10-17",
          "Statement" => [
            {
              "Effect" => "Allow",
              "Action" => "sts:AssumeRole",
              "Resource" => [ "*" ]
            },
            {
              "Effect" => "Allow",
              "Action" => "s3:GetObject",
              "Resource" => [
                FnJoin('', ["arn:aws:s3:::", Ref(:SecretsBucket), "/*"])
              ]
            },
            {
              "Effect" => "Allow",
              "Action" => ["s3:ListBucket"],
              "Resource" => [
                FnJoin('', ["arn:aws:s3:::", Ref(:SecretsBucket)])
              ],
              "Condition" => {"StringLike":{"s3:prefix":["sftp-ssh_host_*"]}}
            },
            {
              "Effect" => "Allow",
              "Action" => ["s3:PutObject"],
              "Resource" => [
                FnJoin('', ["arn:aws:s3:::", Ref(:SecretsBucket), "/sftp-ssh_host_*"])
              ]
            },
            {
              "Effect" => "Allow",
              "Action" => "s3:PutObject",
              "Resource" => [
                FnJoin('', ["arn:aws:s3:::", Ref(:BackupsBucket), "/*"])
              ]
            },
            {
              "Effect" => "Allow",
              "Action" => "s3:DeleteObject",
              "Resource" => [
                FnJoin('', ["arn:aws:s3:::", Ref(:BackupsBucket), "/letsencrypt/*"])
              ]
            },
            {
              "Effect" => "Allow",
              "Action" => "s3:ListBucket",
              "Resource" => [
                FnJoin('', ["arn:aws:s3:::", Ref(:BackupsBucket)])
              ]
            },
            {
              "Effect" => "Allow",
              "Action" => "s3:GetObject",
              "Resource" => [
                FnJoin('', ["arn:aws:s3:::", Ref(:BackupsBucket), "/*"])
              ]
            },
            {
              "Effect" => "Allow",
              "Action" => "sns:Publish",
              "Resource" => [
                Ref(:SnsAlarmTopic)
              ]
            },
            {
              "Effect" => "Allow",
              "Action" => [
                "autoscaling:DescribeAutoScalingInstances",
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision",
                "cloudformation:DescribeStackResource",
                "cloudwatch:PutMetricData",
                "ec2:AssociateAddress",
                "ec2:AttachNetworkInterface",
                "ec2:AttachVolume",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DescribeInstances",
                "ec2:DescribeTags",
                "ec2:DescribeVolumeAttribute",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:EnableVolumeIO",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVolumeAttribute",
                "sqs:DeleteMessage",
                "sqs:ReceiveMessage",
                "sqs:SendMessage"
              ],
              "Resource" => [ "*" ]
            },
            {
              "Effect" => "Allow",
              "Action" => [
                # Although the docs say you can remove the CreateLogGroup permission from instance roles, in practice doing that prevented
                # the awslogs daemon from publishing logs even when the group already existed.
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
              ],
              "Resource": [
                FnJoin("", [ "arn:aws:logs:*:*:log-group:", Ref(:EnvName), "*:log-stream:*" ] )
              ]
            }
          ]
        }
      }
    ]
  end

  IAM_InstanceProfile(:AppIamProfile) do
    Roles [ Ref(:AppIamRole) ]
  end

  EC2_EIP(:SftpEip) do
    Domain 'vpc'
  end

  Route53_RecordSet(:SftpDns) do
    Type 'A'
    Name FnJoin('', [ 'sftp-', Ref(:EnvName), '.', Ref(:HostedZoneName) ] )
    TTL 900
    HostedZoneName Ref(:HostedZoneName)
    ResourceRecords [ Ref(:SftpEip) ]
  end

  Route53_RecordSet(:CvcDns) do
    Type 'CNAME'
    Name FnJoin('', [ 'cvc-', Ref(:EnvName), '.', Ref(:HostedZoneName) ] )
    TTL 900
    HostedZoneName Ref(:HostedZoneName)
    ResourceRecords [ FnGetAtt(:ELB, 'DNSName') ]
  end

  Route53_RecordSet(:EdiDns) do
    Type 'A'
    Name FnJoin('', [ 'edi-', Ref(:EnvName), '.', Ref(:HostedZoneName) ] )
    TTL 900
    HostedZoneName Ref(:HostedZoneName)
    ResourceRecords [ Ref(:SftpEip) ]
  end

  EC2_Volume(:SftpVolume) do
    AvailabilityZone FnJoin('', [ Ref('AWS::Region'), Ref(:DefaultAvailabilityZone) ] )
    Encrypted 'true'
    Size Ref(:SftpVolumeSize)
    VolumeType 'gp2'
    DeletionPolicy 'Snapshot'

    Tags [
      { Key: 'Environment', Value: Ref(:EnvName) },
      { Key: 'Name', Value: FnJoin('', [ Ref(:EnvName), '-sftp-data' ]) }
    ]
  end



  if config && config['sites']
    config['sites'].each do |site, params|
      Route53_RecordSet("RecordSet#{site.gsub(/[^0-9a-z]/i, '')}") do
        Type 'CNAME'
        Name "#{params['host']}."
        TTL 900
        HostedZoneName Ref(:HostedZoneName)
        ResourceRecords [ FnGetAtt(:ELB, 'DNSName') ]
      end

      if params['api_importer_enabled']
        Route53_RecordSet("RecordSetApi#{site.gsub(/[^0-9a-z]/i, '')}") do
          Type 'CNAME'
          Name FnJoin('', [ "api-#{site}.", Ref(:HostedZoneName) ] )
          TTL 900
          HostedZoneName Ref(:HostedZoneName)
          ResourceRecords [ FnGetAtt(:ELB, 'DNSName') ]
        end
      end

      # set up any extra ELBs
      if params['ssl_name']
        Resource("ELB#{params['ssl_name']}") do
          Type 'AWS::ElasticLoadBalancing::LoadBalancer'
          Property('Subnets', public_subnets)
          Property(
            'Listeners',
            [
              {
                'LoadBalancerPort': '80',
               'InstancePort': '80',
               'Protocol': 'HTTP'
              },
              {
                'LoadBalancerPort': '443',
               'InstancePort': "#{params['ssl_port']}",
               'Protocol': 'TCP'
              }
            ]
          )
          Property(
            'HealthCheck',
            {
              'HealthyThreshold': '10',
             'Interval': '10',
             'Target': 'TCP:80',
             'Timeout': '5',
             'UnhealthyThreshold': '2'
            }
          )
          Property('SecurityGroups', [ Ref(:AppSecurityGroup) ])
        end
      end

    end

  end

  AutoScaling_LaunchConfiguration(:SftpServerLaunchConfig) do
    DependsOn [:SftpVolume, :SftpEip]
    KeyName Ref(:KeyName)
    ImageId Ref(:ImageId)
    IamInstanceProfile Ref(:AppIamProfile)
    InstanceType Ref(:AppInstanceType)
    SecurityGroups [ Ref(:SftpSecurityGroup) ]
    Property("BlockDeviceMappings", [
      {
        "DeviceName" => "/dev/sda1",
        "Ebs" => {
          "VolumeSize" => Ref(:RootVolumeSize),
          "VolumeType" => "gp2"
        }
      }])
    UserData(
      FnBase64(
        FnJoin(
          '',
          [
            "#!/bin/bash -v\n",
            "\n",
            "# change me to reprovision 2018-01-15\n",
            "\n",
            "until apt-get install -y jq\n",
            "do\n",
            "  sleep 10\n",
            "done\n",
            "\n",
            "instance_id=`curl http://169.254.169.254/latest/meta-data/instance-id`\n",
            # tag root volume with a name
            "volume_ids=$(aws ec2 describe-volumes",
            " --filters Name=attachment.instance-id,Values=$instance_id",
            " --region ", Ref('AWS::Region'),
            " | jq -r '.Volumes[].VolumeId' | tr '\\n' ' ')\n",
            "aws ec2 create-tags",
            " --region ", Ref('AWS::Region'),
            " --resources $volume_ids",
            " --tags 'Key=\"Name\",Value=\"", Ref(:EnvName), "-sftp-root\"'\n",
            "function error_exit\n",
            "{\n",
            "  cfn-signal --exit-code 1 --stack ", Ref('AWS::StackName'), " --resource SftpServerAsg --region ", Ref('AWS::Region'), "\n",
            "  exit 1\n",
            "}\n",
            # associate EIP
            "max_attach_tries=12\n",
            "attach_tries=0\n",
            "success=1\n",
            "while [[ $success != 0 ]]; do\n",
            "  if [ $attach_tries -gt $max_attach_tries ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  aws ec2 associate-address --region ", Ref('AWS::Region'), " --instance-id $instance_id --allocation-id ", FnGetAtt(:SftpEip, 'AllocationId'), "\n",
            "  success=$?\n",
            "  ((attach_tries++))\n",
            "done\n",
            # disable source / destination check
            "aws ec2 modify-instance-attribute --region ",
            Ref('AWS::Region'),
            " --instance-id $instance_id --source-dest-check \"{\\\"Value\\\": false}\"\n",
            # attach volume
            "max_attach_tries=12\n",
            "attach_tries=0\n",
            "success=1\n",
            "while [[ $success != 0 ]]; do\n",
            "  if [ $attach_tries -gt $max_attach_tries ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  aws ec2 attach-volume --region ", Ref('AWS::Region'), " --volume-id ", Ref(:SftpVolume), " --instance-id $instance_id --device /dev/sdf\n",
            "  success=$?\n",
            "  ((attach_tries++))\n",
            "done\n",
            "max_waits=12\n",
            "current_waits=0\n",
            "while [ ! -e /dev/xvdf ]; do\n",
            "  echo waiting for /dev/xvdf to attach\n",
            "  if [ $current_waits -gt $max_waits ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  ((current_waits++))\n",
            "done\n",
            "file -s /dev/xvdf | grep -v ext4 &> /dev/null\n",
            "if [ $? == 0 ]; then\n",
            "  mkfs -t ext4 /dev/xvdf\n",
            "fi\n",
            "mkdir -p /encrypted\n",
            "mount /dev/xvdf /encrypted\n",
            "echo '/dev/xvdf /encrypted ext4 defaults,nofail 0 2' >> /etc/fstab\n",
            "\n",
            "cfn-init --stack ", Ref('AWS::StackName'), " --resource SftpServerAsg --region ", Ref('AWS::Region'), " || error_exit\n",
            "\n",
            "wget -O /root/codedeploy-agent_all.deb https://s3.amazonaws.com/aws-codedeploy-us-east-1/latest/codedeploy-agent_all.deb\n",
            "\n",
            "max_waits=12\n",
            "current_waits=0\n",
            "until dpkg -i /root/codedeploy-agent_all.deb\n",
            "do\n",
            "  if [ $current_waits -gt $max_waits ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  ((current_waits++))\n",
            "done\n",
            "\n",
            "cfn-signal --exit-code 0 --stack ", Ref('AWS::StackName'), " --resource SftpServerAsg --region ", Ref('AWS::Region'), "\n",
          ]
        )
      )
    )
  end

  AutoScaling_AutoScalingGroup(:SftpServerAsg) do
    DependsOn [:GatewayToInternet, :ImporterNetworkInterface].concat(log_groups)
    VPCZoneIdentifier [ Ref("publicaz#{default_az}") ]
    DesiredCapacity 1
    LaunchConfigurationName Ref(:SftpServerLaunchConfig)
    MaxSize 1
    MinSize 1
    CreationPolicy(
      'ResourceSignal',
      {
        'Count'   => 1,
        'Timeout' => 'PT30M'
      }
    )
    UpdatePolicy(
      'AutoScalingRollingUpdate',
      {
        'MinInstancesInService' => '0',
        'MaxBatchSize'          => '1',
        'PauseTime'             => 'PT15M',
        'WaitOnResourceSignals' => true
      }
    )
    Tags [
      { Key: 'Environment', Value: Ref(:EnvName), PropagateAtLaunch: 'true' },
      { Key: 'Name', Value: FnJoin('', [ Ref(:EnvName), '-sftp' ]), PropagateAtLaunch: 'true' },
      { Key: 'Role', Value: 'sftp', PropagateAtLaunch: 'true' }
    ]

    Metadata(
      :aws_region => Ref('AWS::Region'),
      :chef_sha => Ref(:ChefSha),
      :co_name => co_name,
      :config => config.to_json,
      :database_host => FnGetAtt(:DB, 'Endpoint.Address'),
      :edi_monitor_sha => Ref(:EdiMonitorSha),
      :edi_sha => Ref(:EdiSha),
      :edi_ui_sha => Ref(:EdiUiSha),
      :env_name => Ref(:EnvName),
      :hosted_zone_name => Ref(:HostedZoneName),
      :importer_private_ip => FnGetAtt(:ImporterNetworkInterface, 'PrimaryPrivateIpAddress'),
      :repo_base => repo_base,
      :role => 'sftp',
      :sns_alarm_topic => Ref(:SnsAlarmTopic),
      :secrets_bucket => Ref(:SecretsBucket),
      :backups_bucket => Ref(:BackupsBucket),
      'AWS::CloudFormation::Init' => {
        :config => {
          :files => {
            '/etc/rm-role' => {
              :content => 'sftp',
              :mode => '00644',
              :owner => 'root',
              :group => 'root'
            },
            '/usr/bin/run-chef' => {
              :content => FnJoin(
                '',
                [
                  "#!/usr/bin/env bash\n",
                  "chef-solo -c /etc/chef/codedeploy/solo.rb -o 'role[sftp]'\n"
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
                  "PS1='\\n\\u in \\w [ Revenue Masters | \\t | \\h | sftp | ",
                  { "Ref": "AWS::StackName" },
                  " | ",
                  { "Ref": "AWS::Region" },
                  " ]\\n# '\n"
                ]
              ),
              :mode => "000444",
              :owner => "root",
              :group => "root"
            },
            '/usr/local/bin/connect-to-instance' => {
              :content => FnJoin(
                '',
                [
                  "#!/usr/bin/env bash\n",
                  "\n",
                  "if [[ $# -ne 1 ]] ; then\n",
                  "    echo 'Usage: connect-to-instance [role]'\n",
                  "    exit 1\n",
                  "fi\n",
                  "\n",
                  "private_ip=$(aws ec2 describe-instances --filters \"Name=tag:Role,Values=$1\" \"Name=tag:Environment,Values=",
                  Ref(:EnvName),
                  "\" \"Name=instance-state-name,Values=running\" --region ",
                  Ref('AWS::Region'),
                  " | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')\n",
                  "echo \"Connecting you to $1 instance at $private_ip...\"\n",
                  "ssh $private_ip\n"
                ]
              ),
              :mode => '00755',
              :owner => 'root',
              :group => 'root'
            },
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
            }
          }
        }
      }
    )
  end

  # alarms for sftp disks
  # root volume
  Resource(:SftpRootVolumeAlarm) do
    DependsOn [:SnsAlarmTopic, :SftpServerAsg]
    Type 'AWS::CloudWatch::Alarm'
    Property('ActionsEnabled', true)
    Property(
      'AlarmActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('AlarmDescription', FnJoin('', [Ref(:EnvName), " sftp root volume"]))
    Property('ComparisonOperator', 'GreaterThanThreshold')
    Property('EvaluationPeriods', 1)
    Property('MetricName', 'DiskSpaceUtilization')
    Property('Namespace', 'System/Linux')
    Property(
      'OKActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('Period', 300)
    Property('Statistic', 'Maximum')
    Property('Threshold', '75')
    Property('Unit', 'Percent')
    Property(
      'Dimensions',
      [
        {
          Name: 'MountPath',
          Value: '/'
        },
        {
          Name: 'AutoScalingGroupName',
          Value: Ref(:SftpServerAsg)
        }
      ]
    )
  end

  # encrypted volume
  Resource(:SftpEncryptedVolumeAlarm) do
    DependsOn [:SnsAlarmTopic, :SftpServerAsg]
    Type 'AWS::CloudWatch::Alarm'
    Property('ActionsEnabled', true)
    Property(
      'AlarmActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('AlarmDescription', FnJoin('', [Ref(:EnvName), " sftp encrypted volume"]))
    Property('ComparisonOperator', 'GreaterThanThreshold')
    Property('EvaluationPeriods', 1)
    Property('MetricName', 'DiskSpaceUtilization')
    Property('Namespace', 'System/Linux')
    Property(
      'OKActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('Period', 300)
    Property('Statistic', 'Maximum')
    Property('Threshold', '75')
    Property('Unit', 'Percent')
    Property(
      'Dimensions',
      [
        {
          Name: 'MountPath',
          Value: '/encrypted'
        },
        {
          Name: 'AutoScalingGroupName',
          Value: Ref(:SftpServerAsg)
        }
      ]
    )
  end

  EC2_SecurityGroup(:ImporterSecurityGroup) do
    GroupDescription 'Importer security group'
    SecurityGroupIngress([
      # allow SSH from within VPC
      {
        IpProtocol: 'tcp',
        FromPort: '22',
        ToPort: '22',
        CidrIp: vpc_cidr_block
      }
    ])
    VpcId Ref(:Vpc)
  end

  EC2_Volume(:ImporterVolume) do
    AvailabilityZone FnJoin('', [ Ref('AWS::Region'), Ref(:DefaultAvailabilityZone) ] )
    Encrypted 'true'
    Size Ref(:ImporterVolumeSize)
    VolumeType 'gp2'
    DeletionPolicy 'Snapshot'

    Tags [
      { Key: 'Environment', Value: Ref(:EnvName) },
      { Key: 'Name', Value: FnJoin('', [ Ref(:EnvName), '-importer-data' ]) }
    ]

  end

  EC2_NetworkInterface(:ImporterNetworkInterface) do
    GroupSet [ Ref(:ImporterSecurityGroup) ]
    SubnetId Ref("privateaz#{default_az}")
  end

  AutoScaling_LaunchConfiguration(:ImporterLaunchConfig) do
    DependsOn [:ImporterVolume]
    KeyName Ref(:KeyName)
    ImageId Ref(:ImageId)
    IamInstanceProfile Ref(:AppIamProfile)
    InstanceType Ref(:ImporterInstanceType)
    SecurityGroups [ Ref(:ImporterSecurityGroup) ]
    Property('BlockDeviceMappings', [
      {
        'DeviceName' => '/dev/sda1',
        'Ebs' => {
          'VolumeSize' => Ref(:RootVolumeSize),
          'VolumeType' => 'gp2'
        }
      }])
    UserData(
      FnBase64(
        FnJoin(
          '',
          [
            "#!/bin/bash -v\n",
            "\n",
            "# change me to reprovision 2018-01-15\n",
            "\n",
            "until apt-get install -y jq\n",
            "do\n",
            "  sleep 10\n",
            "done\n",
            "\n",
            "instance_id=`curl http://169.254.169.254/latest/meta-data/instance-id`\n",
            # tag root volume with a name
            "volume_ids=$(aws ec2 describe-volumes",
            " --filters Name=attachment.instance-id,Values=$instance_id",
            " --region ", Ref('AWS::Region'),
            " | jq -r '.Volumes[].VolumeId' | tr '\\n' ' ')\n",
            "aws ec2 create-tags",
            " --region ", Ref('AWS::Region'),
            " --resources $volume_ids",
            " --tags 'Key=\"Name\",Value=\"", Ref(:EnvName), "-importer-root\"'\n",
            "function error_exit\n",
            "{\n",
            "  cfn-signal --exit-code 1 --stack ", Ref('AWS::StackName'), " --resource ImporterAsg --region ", Ref('AWS::Region'), "\n",
            "  exit 1\n",
            "}\n",
            # attach network interface for static internal IP
            "max_attach_tries=12\n",
            "attach_tries=0\n",
            "success=1\n",
            "while [[ $success != 0 ]]; do\n",
            "  if [ $attach_tries -gt $max_attach_tries ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  aws ec2 attach-network-interface --region ", Ref(:'AWS::Region'), " --network-interface-id ", Ref(:ImporterNetworkInterface), " --instance-id $instance_id --device-index 1\n",
            "  success=$?\n",
            "  ((attach_tries++))\n",
            "done\n",
            "max_attach_tries=12\n",
            "attach_tries=0\n",
            "success=1\n",
            "while [[ $success != 0 ]]; do\n",
            "  if [ $attach_tries -gt $max_attach_tries ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  aws ec2 attach-volume --region ", Ref('AWS::Region'), " --volume-id ", Ref(:ImporterVolume), " --instance-id $instance_id --device /dev/sdf\n",
            "  success=$?\n",
            "  ((attach_tries++))\n",
            "done\n",
            "max_waits=12\n",
            "current_waits=0\n",
            "while [ ! -e /dev/xvdf ]; do\n",
            "  echo waiting for /dev/xvdf to attach\n",
            "  if [ $current_waits -gt $max_waits ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  ((current_waits++))\n",
            "done\n",
            "file -s /dev/xvdf | grep -v ext4 &> /dev/null\n",
            "if [ $? == 0 ]; then\n",
            "  mkfs -t ext4 /dev/xvdf\n",
            "fi\n",
            "mkdir -p /encrypted\n",
            "mount /dev/xvdf /encrypted\n",
            "echo '/dev/xvdf /encrypted ext4 defaults,nofail 0 2' >> /etc/fstab\n",
            "\n",
            "cfn-init --stack ", Ref('AWS::StackName'), " --resource ImporterAsg --region ", Ref('AWS::Region'), " || error_exit\n",
            "\n",
            "wget -O /root/codedeploy-agent_all.deb https://s3.amazonaws.com/aws-codedeploy-us-east-1/latest/codedeploy-agent_all.deb\n",
            "\n",
            "max_waits=12\n",
            "current_waits=0\n",
            "until dpkg -i /root/codedeploy-agent_all.deb\n",
            "do\n",
            "  if [ $current_waits -gt $max_waits ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  ((current_waits++))\n",
            "done\n",
            "\n",
            "cfn-signal --exit-code 0 --stack ", Ref('AWS::StackName'), " --resource ImporterAsg --region ", Ref('AWS::Region'), "\n",
          ]
        )
      )
    )
  end

  AutoScaling_AutoScalingGroup(:ImporterAsg) do
    DependsOn [:GatewayToInternet].concat(log_groups)
    VPCZoneIdentifier [ Ref("privateaz#{default_az}") ]
    DesiredCapacity 1
    LaunchConfigurationName Ref(:ImporterLaunchConfig)
    MaxSize 1
    MinSize 1
    CreationPolicy(
      'ResourceSignal',
      {
        'Count'   => 1,
        'Timeout' => 'PT30M'
      }
    )
    UpdatePolicy(
      'AutoScalingRollingUpdate',
      {
        'MinInstancesInService' => '0',
        'MaxBatchSize'          => '1',
        'PauseTime'             => 'PT15M',
        'WaitOnResourceSignals' => true
      }
    )
    Tags [
      { Key: 'Environment', Value: Ref(:EnvName), PropagateAtLaunch: 'true' },
      { Key: 'Name', Value: FnJoin('', [ Ref(:EnvName), '-importer' ]), PropagateAtLaunch: 'true' },
      { Key: 'Role', Value: 'importer', PropagateAtLaunch: 'true' }
    ]

    Metadata(
      :aws_region => Ref('AWS::Region'),
      :chef_sha => Ref(:ChefSha),
      :co_name => co_name,
      :config => config.to_json,
      :database_host => FnGetAtt(:DB, 'Endpoint.Address'),
      :env_name => Ref(:EnvName),
      :hosted_zone_name => Ref(:HostedZoneName),
      :post_import_alerts_sha => Ref(:PostImportAlertsSha),
      :repo_base => repo_base,
      :role => 'importer',
      :sns_alarm_topic => Ref(:SnsAlarmTopic),
      :secrets_bucket => Ref(:SecretsBucket),
      :backups_bucket => Ref(:BackupsBucket),
      :sftp_dns => Ref(:SftpDns),
      :s3_read_only_cross_account_arn => Ref(:S3ReadOnlyCrossAccountRoleArn),
      :s3_read_only_cross_account_bucket => Ref(:S3ReadOnlyCrossAccountRoleBucket),
      :worker_process => Ref(:WorkerProcess),
      'AWS::CloudFormation::Init' => {
        :config => {
          :files => {
            '/etc/rm-role' => {
              :content => 'importer',
              :mode => '00644',
              :owner => 'root',
              :group => 'root'
            },
            '/usr/bin/run-chef' => {
              :content => FnJoin(
                '',
                [
                  "#!/usr/bin/env bash\n",
                  "chef-solo -c /etc/chef/codedeploy/solo.rb -o 'role[importer]'\n"
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
                  "PS1='\\n\\u in \\w [ Revenue Masters | \\t | \\h | importer | ",
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
            }
          }
        }
      }
    )
  end

  # alarms for importer disks
  # root volume
  Resource(:ImporterRootVolumeAlarm) do
    DependsOn [:SnsAlarmTopic, :ImporterAsg]
    Type 'AWS::CloudWatch::Alarm'
    Property('ActionsEnabled', true)
    Property(
      'AlarmActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('AlarmDescription', FnJoin('', [Ref(:EnvName), " importer root volume"]))
    Property('ComparisonOperator', 'GreaterThanThreshold')
    Property('EvaluationPeriods', 1)
    Property('MetricName', 'DiskSpaceUtilization')
    Property('Namespace', 'System/Linux')
    Property(
      'OKActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('Period', 300)
    Property('Statistic', 'Maximum')
    Property('Threshold', '75')
    Property('Unit', 'Percent')
    Property(
      'Dimensions',
      [
        {
          Name: 'MountPath',
          Value: '/'
        },
        {
          Name: 'AutoScalingGroupName',
          Value: Ref(:ImporterAsg)
        }
      ]
    )
  end

  # encrypted volume
  Resource(:ImporterEncryptedVolumeAlarm) do
    DependsOn [:SnsAlarmTopic, :ImporterAsg]
    Type 'AWS::CloudWatch::Alarm'
    Property('ActionsEnabled', true)
    Property(
      'AlarmActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('AlarmDescription', FnJoin('', [Ref(:EnvName), " importer encrypted volume"]))
    Property('ComparisonOperator', 'GreaterThanThreshold')
    Property('EvaluationPeriods', 1)
    Property('MetricName', 'DiskSpaceUtilization')
    Property('Namespace', 'System/Linux')
    Property(
      'OKActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('Period', 300)
    Property('Statistic', 'Maximum')
    Property('Threshold', '75')
    Property('Unit', 'Percent')
    Property(
      'Dimensions',
      [
        {
          Name: 'MountPath',
          Value: '/encrypted'
        },
        {
          Name: 'AutoScalingGroupName',
          Value: Ref(:ImporterAsg)
        }
      ]
    )
  end

  AutoScaling_LaunchConfiguration(:AppInstancesLaunchConfig) do
    KeyName Ref(:KeyName)
    ImageId Ref(:ImageId)
    IamInstanceProfile Ref(:AppIamProfile)
    InstanceType Ref(:AppInstanceType)
    SecurityGroups [ Ref(:AppSecurityGroup) ]
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
            'VolumeSize' => Ref(:AppVolumeSize),
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
            "function error_exit\n",
            "{\n",
            "  cfn-signal --exit-code 1 --stack ", Ref('AWS::StackName'), " --resource AppInstancesAsg --region ", Ref('AWS::Region'), "\n",
            "  exit 1\n",
            "}\n",
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
            " --tags 'Key=\"Name\",Value=\"", Ref(:EnvName), "-app-root\"'",
            "\n",
            "cfn-init --stack ", Ref('AWS::StackName'), " --resource AppInstancesAsg --region ", Ref('AWS::Region'), " || error_exit\n",
            "\n",
            "wget -O /root/codedeploy-agent_all.deb https://s3.amazonaws.com/aws-codedeploy-us-east-1/latest/codedeploy-agent_all.deb\n",
            "\n",
            "max_waits=12\n",
            "current_waits=0\n",
            "until dpkg -i /root/codedeploy-agent_all.deb\n",
            "do\n",
            "  if [ $current_waits -gt $max_waits ]; then\n",
            "    error_exit\n",
            "  fi\n",
            "  sleep 10\n",
            "  ((current_waits++))\n",
            "done\n",
            "\n",
            "cfn-signal --exit-code 0 --stack ", Ref('AWS::StackName'), " --resource AppInstancesAsg --region ", Ref('AWS::Region'), "\n",
          ]
        )
      )
    )
  end

  elbs = [Ref(:ELB)]
  config['sites'].each do |site, params|
    if params['ssl_name']
      elbs << Ref("ELB#{params['ssl_name']}")
    end
  end if config && config['sites']

  AutoScaling_AutoScalingGroup(:AppInstancesAsg) do
    DependsOn [:NatGateway].concat(log_groups)
    VPCZoneIdentifier private_subnets
    DesiredCapacity Ref(:AppDesiredSize)
    LaunchConfigurationName Ref(:AppInstancesLaunchConfig)
    LoadBalancerNames elbs
    MaxSize Ref(:AppMaxSize)
    MinSize Ref(:AppMinSize)
    CreationPolicy(
      'ResourceSignal',
      {
        'Count'   => 1,
        'Timeout' => 'PT30M'
      }
    )
    UpdatePolicy(
      'AutoScalingRollingUpdate',
      {
        'MinInstancesInService' => '1',
        'MaxBatchSize'          => '1',
        'PauseTime'             => 'PT15M',
        'WaitOnResourceSignals' => true
      }
    )
    Tags [
      { Key: 'Environment', Value: Ref(:EnvName), PropagateAtLaunch: 'true' },
      { Key: 'Name', Value: FnJoin('', [ Ref(:EnvName), '-app' ]), PropagateAtLaunch: 'true' },
      { Key: 'Role', Value: 'app', PropagateAtLaunch: 'true' }
    ]

    Metadata(
      :api_importer_sha => Ref(:ApiImporterSha),
      :aws_region => Ref('AWS::Region'),
      :chef_sha => Ref(:ChefSha),
      :co_name => co_name,
      :config => config.to_json,
      :cvc_sha => Ref(:CvcSha),
      :database_host => FnGetAtt(:DB, 'Endpoint.Address'),
      :env_name => Ref(:EnvName),
      :hosted_zone_name => Ref(:HostedZoneName),
      :repo_base => repo_base,
      :role => 'app',
      :sns_alarm_topic => Ref(:SnsAlarmTopic),
      :secrets_bucket => Ref(:SecretsBucket),
      :backups_bucket => Ref(:BackupsBucket),
      'AWS::CloudFormation::Init' => {
        :config => {
          :files => {
            '/etc/rm-role' => {
              :content => 'app',
              :mode => '00644',
              :owner => 'root',
              :group => 'root'
            },
            '/usr/bin/run-chef' => {
              :content => FnJoin(
                '',
                [
                  "#!/usr/bin/env bash\n",
                  "chef-solo -c /etc/chef/codedeploy/solo.rb -o 'role[app]'\n"
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
                  "PS1='\\n\\u in \\w [ Revenue Masters | \\t | \\h | app | ",
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
            }
          }
        }
      }
    )
  end

  # alarms for app disks
  # root volume
  Resource(:AppRootVolumeAlarm) do
    DependsOn [:SnsAlarmTopic, :AppInstancesAsg]
    Type 'AWS::CloudWatch::Alarm'
    Property('ActionsEnabled', true)
    Property(
      'AlarmActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('AlarmDescription', FnJoin('', [Ref(:EnvName), " app root volume"]))
    Property('ComparisonOperator', 'GreaterThanThreshold')
    Property('EvaluationPeriods', 1)
    Property('MetricName', 'DiskSpaceUtilization')
    Property('Namespace', 'System/Linux')
    Property(
      'OKActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('Period', 300)
    Property('Statistic', 'Maximum')
    Property('Threshold', '75')
    Property('Unit', 'Percent')
    Property(
      'Dimensions',
      [
        {
          Name: 'MountPath',
          Value: '/'
        },
        {
          Name: 'AutoScalingGroupName',
          Value: Ref(:AppInstancesAsg)
        }
      ]
    )
  end

  # encrypted volume
  Resource(:AppEncryptedVolumeAlarm) do
    DependsOn [:SnsAlarmTopic, :AppInstancesAsg]
    Type 'AWS::CloudWatch::Alarm'
    Property('ActionsEnabled', true)
    Property(
      'AlarmActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('AlarmDescription', FnJoin('', [Ref(:EnvName), " app encrypted volume"]))
    Property('ComparisonOperator', 'GreaterThanThreshold')
    Property('EvaluationPeriods', 1)
    Property('MetricName', 'DiskSpaceUtilization')
    Property('Namespace', 'System/Linux')
    Property(
      'OKActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('Period', 300)
    Property('Statistic', 'Maximum')
    Property('Threshold', '75')
    Property('Unit', 'Percent')
    Property(
      'Dimensions',
      [
        {
          Name: 'MountPath',
          Value: '/encrypted'
        },
        {
          Name: 'AutoScalingGroupName',
          Value: Ref(:AppInstancesAsg)
        }
      ]
    )
  end

  RDS_DBSubnetGroup(:DBSubnetGroup) do
    DBSubnetGroupDescription FnJoin('', ["DB subnet group for ", Ref(:EnvName)])
    SubnetIds private_subnets
  end

  RDS_DBInstance(:DB) do
    AllocatedStorage Ref(:DatabaseStorageSize)
    BackupRetentionPeriod '30'
    DBInstanceClass Ref(:DatabaseInstanceType)
    DBParameterGroupName Ref(:DBParameterGroup)
    DBSubnetGroupName Ref(:DBSubnetGroup)
    Engine 'MySQL'
    EngineVersion '5.6.34'
    MasterUsername Ref(:DatabaseMasterUsername)
    MasterUserPassword Ref(:DatabaseMasterPasswordNoEcho)
    MultiAZ Ref(:DatabaseMultiAZ)
    Property(:StorageEncrypted, true)
    Property(:StorageType, 'gp2')
    VPCSecurityGroups [ Ref(:DatabaseSecurityGroup) ]
    DeletionPolicy 'Snapshot'
  end

  Resource(:DBParameterGroup) do
    Type 'AWS::RDS::DBParameterGroup'
    Property('Description', 'RevenueMasters RDS MySQL parameter group')
    Property('Family', 'MySQL5.6')
    Property('Parameters',
      {
        'innodb_lock_wait_timeout': 120,
        'max_allowed_packet': 268435456, # 256MB
        'thread_stack': 196608,
        'thread_cache_size': 8,
        'query_cache_limit': 1048576, # 1MB
        'query_cache_size': 16777216, # 16MB
      }
    )
  end

  Resource(:ELB) do
    Type 'AWS::ElasticLoadBalancing::LoadBalancer'
    Property('Subnets', public_subnets)
    Property(
      'Listeners',
      [
        {
          'LoadBalancerPort': '80',
          'InstancePort': '80',
          'Protocol': 'HTTP'
        },
        {
          'LoadBalancerPort': '443',
          'InstancePort': '443',
          'Protocol': 'TCP'
        }
      ]
    )
    Property(
      'HealthCheck',
      {
        'HealthyThreshold': '10',
        'Interval': '10',
        'Target': 'TCP:80',
        'Timeout': '5',
        'UnhealthyThreshold': '2'
      }
    )
    Property('SecurityGroups', [ Ref(:AppSecurityGroup) ])
  end

  Resource(:SnsAlarmTopic) do
    Type 'AWS::SNS::Topic'
    Property('DisplayName', FnJoin('', [Ref(:EnvName), " Alarm Topic"]))
    Property(
      'Subscription',
      [
        {
          Endpoint: Ref(:AlarmEmail),
          Protocol: 'email'
        }
      ]
    )
  end

  # add one Route53 health check for each env
  Resource(:HealthCheck) do
    Type 'AWS::Route53::HealthCheck'
    Property(
      'HealthCheckConfig',
      {
        FailureThreshold: 3,
        FullyQualifiedDomainName: Ref(:HealthCheckUrl),
        Port: 443,
        SearchString: '<link href="/pics/favicon.ico" rel="shortcut icon" type="image/x-icon" />',
        RequestInterval: 30,
        Type: 'HTTPS_STR_MATCH'
      }
    )
    Property(
      'HealthCheckTags',
      [
        {
          Key: 'Name',
          Value: FnJoin('', [Ref(:EnvName), " general health check"])
        }
      ]
    )
  end

  # add CloudWatch alarm for the Route53 health check
  Resource(:HealthCheckAlarm) do
    DependsOn [:SnsAlarmTopic, :HealthCheck]
    Type 'AWS::CloudWatch::Alarm'
    Property('ActionsEnabled', true)
    Property(
      'AlarmActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('AlarmDescription', FnJoin('', [Ref(:EnvName), " general health check"]))
    Property('ComparisonOperator', 'LessThanThreshold')
    Property('EvaluationPeriods', 1)
    Property('MetricName', 'HealthCheckStatus')
    Property('Namespace', 'AWS/Route53')
    Property(
      'OKActions',
      [
        Ref(:SnsAlarmTopic)
      ]
    )
    Property('Period', 60)
    Property('Statistic', 'Minimum')
    Property('Threshold', '1.0')
    Property(
      'Dimensions',
      [
        {
          Name: 'HealthCheckId',
          Value: Ref(:HealthCheck)
        }
      ]
    )
  end

  Resource(:DeploymentConfig) do
    Type 'AWS::CodeDeploy::DeploymentConfig'
    Property(
      'MinimumHealthyHosts',
      {
        Type: 'FLEET_PERCENT',
        Value: '50'
      }
    )
  end

  IAM_Role(:CodeDeployRole) do
    Property(
      'AssumeRolePolicyDocument',
      {
        'Version' => '2012-10-17',
        'Statement'=> [
          {
            'Effect'=> 'Allow',
            'Principal'=> {
              'Service'=> [ 'codedeploy.amazonaws.com' ]
            },
            'Action'=> [ 'sts:AssumeRole' ]
          }
        ]
      }
    )
    Property('Path', '/')
    Property('ManagedPolicyArns', ['arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole'])
  end

  Resource(:DeploymentApplication) do
    Type 'AWS::CodeDeploy::Application'
    Property('ApplicationName', Ref(:EnvName))
  end

  Resource(:DeploymentGroup) do
    Type 'AWS::CodeDeploy::DeploymentGroup'
    Property('ApplicationName', Ref(:DeploymentApplication))
    Property(
      'AutoScalingGroups',
      [
        Ref(:AppInstancesAsg),
        Ref(:SftpServerAsg),
        Ref(:ImporterAsg)
      ]
    )
    Property(
      'Deployment',
      {
        'Description' => FnJoin('', [ 'Deploying ', Ref(:ChefSha) ]),
        'Revision' => {
          'RevisionType' => 'GitHub',
          'GitHubLocation' => {
            'CommitId' => Ref(:ChefSha),
            'Repository' => "#{repo_org}/devops"
          }
        }
      }
    )
    Property('ServiceRoleArn', FnGetAtt(:CodeDeployRole, 'Arn'))
  end

  Output(:AppInstancesAsg, Ref(:AppInstancesAsg))
  Output(:DatabaseHost, FnGetAtt(:DB, 'Endpoint.Address'))
  Output(:IamInstanceProfile, Ref(:AppIamProfile))
  Output(:ImporterAsg, Ref(:ImporterAsg))
  Output(:PrivateSubnets, FnJoin(',', private_subnets))
  Output(:SftpServerAsg, Ref(:SftpServerAsg))
  Output(:SnsAlarmTopic, Ref(:SnsAlarmTopic))
  Output(:WorkerSecurityGroup, Ref(:WorkerSecurityGroup))
end
