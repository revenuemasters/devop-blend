CloudFormation do

  Description "Creates an IAM role and profile to be attached to all instances"

  IAM_Role(:RootRole) do
    AssumeRolePolicyDocument(
      Statement: [
        {
          Action: [ 'sts:AssumeRole' ],
          Effect: 'Allow',
          Principal: {
            Service: [ 'ec2.amazonaws.com' ]
          }
        }
      ]
    )
    Path('/')
    Policies(
      [
        PolicyName: 'cloudwatchPutMetricData',
        PolicyDocument: {
          Statement: [
            {
              Effect: 'Allow',
              Action: 'cloudwatch:PutMetricData',
              Resource: '*'
            }
          ]
        }
      ]
    )
  end

  IAM_InstanceProfile(:RootInstanceProfile) do
    Path('/')
    Roles([ Ref(:RootRole) ])
  end

end
