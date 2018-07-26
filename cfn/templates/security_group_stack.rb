CloudFormation do

  Description "Creates a single security group"

  Parameter(:CidrIp) do
    String
  end

  Parameter(:Description) do
    String
    Default "none"
  end

  Parameter(:Name) do
    String
  end

  Parameter(:VpcId) do
    String
  end

  EC2_SecurityGroup(:SecurityGroup) do
    GroupDescription Ref(:Description)
    SecurityGroupIngress(
      CidrIp: Ref(:CidrIp),
      FromPort: 22,
      IpProtocol: :tcp,
      ToPort: 22
    )
    VpcId Ref(:VpcId)
  end

  Output(:SecurityGroup, Ref(:SecurityGroup))

end
