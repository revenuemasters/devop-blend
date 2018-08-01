
gem_package 'awssume' do
  version '0.3.0'
end

# script for downloading files from another account
if node['cfn']['properties']['s3_read_only_cross_account_arn'] &&
   node['cfn']['properties']['s3_read_only_cross_account_bucket']
  template '/usr/local/bin/copy-from-prod' do
    source 'copy-from-prod.erb'
    user 'root'
    group 'root'
    mode '0755'
    variables(
      {
        :region => node['cfn']['vpc']['region_id'],
        :role_arn => node['cfn']['properties']['s3_read_only_cross_account_arn'],
        :s3_bucket => node['cfn']['properties']['s3_read_only_cross_account_bucket']
      }
    )
  end
end
