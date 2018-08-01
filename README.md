# devops

Infrastructure files for managing AWS servers

## Chef Development

We are using the Chef DK. Install from [here](https://downloads.chef.io/chef-dk/). Use 12.5 or newer.
The following tools are required:
- packer: sudo apt install packer
- ruby gems: sudo gem install activesupport-inflector rails aws-sdk-core aws-sdk

Make sure the Github repo for this devop script has checkbox 'Restrict editing to users in teams with push access only' unchecked

## Configuration Documentation

The configuration is stored in the `envs.yml` file in the root of the repo.

### Top Level Configuration Options

* `alarm-email` - email address that receives alerts from the system
* `app-desired-size` - desired size for app tier ASG
* `app-importer-sha` - git sha for app importer
* `app-instance-type` - instance type for app tier ASG
* `app-maz-size` - max size for app tier ASG
* `app-min-size` - min size for app tier ASG
* `app-volume-size` - size in GB of app volumes
* `app_sha` - git sha for app
* `availability-zones` - list of AZs to use (comma separated list of letters)
* `chef-sha` - git sha for chef / devops
* `config/cvc_enabled` - controls if the CVC app should be enabled in the environment
* `config/sites` - list of enabled clients (see Client Specific Configuration Options)
* `config/ssl_ports` - list of SSL ports needed (when serving from more than one hostname)
* `cvc-sha` - git sha for CVC app
* `dedicated-tenancy` - controls if dedicated tenancy should be used
* `default-availability-zone` - default AZ (for persistent EBS volumes)
* `edi-monitor-sha` - git sha for EDI Monitor app
* `edi-sha` - git sha for EDI app
* `edi-ui-sha` - git sha for EDI UI app
* `health-check-url` - URL which is monitored for cluster uptime
* `hosted-zone-name` - domain to be used for this environment
* `image-id` - Amazon Image ID to be used
* `importer-instance-type` - instance type for importer tier ASG
* `importer-volume-size` - size in GB of importer volume
* `key-name` - AWS EC2 key name
* `log-retention-in-days` - number of days to keep system logs (0 is forever)
* `post-import-alerts-sha` - git sha for post import alerts app
* `profile` - AWS profile to use
* `rds-instance-type` - instance type for RDS
* `rds-multi-az` - controls whether RDS should be multi-AZ
* `rds-storage-size` - size in GB of RDS instance
* `region` - AWS region
* `root-volume-size` - size in GB of root volume for all instance types
* `s3-cross-account-arn` - AWS role for transferring database backups
* `s3-cross-account-bucket` - AWS bucket transferring database backups
* `s3-cross-account-id` - AWS account number for transferring database backups
* `sftp-volume-size` - size in GB of SFTP volume
* `whitelisted-ip-cidrs` - list of ports and the IP ranges allowed to connect for SFTP / SSH
* `worker-instance-type` - instance type for worker tier
* `worker-num-processes` - number of processes to run on one worker instance
* `worker-volume-size` - size in GB of worker volume

### Client Specific Configuration Options

* `api_importer_enabled` - controls whether the API importer app is enabled
* `claim_import_summary_recipients` - list of emails for claim import summary
* `claim_import_summary` - controls whether the claim import summary is enabled
* `crosswalk_enabled` - controls whether crosswalk is enabled
* `custom/app/css_overwrite` - controls whether css_overwrite is enabled
* `custom/app/default_logo` - custom logo
* `custom/app/name_as_image` - custom logo with text
* `custom/app/name` - custom name
* `custom/app/powered_by` - custom powered by
* `edi_app_enabled` - controls whether the EDI app is enabled
* `edi_app_facility_code` - facility code for EDI app
* `edi_app_importer_id` - importer id for EDI app
* `edi_app_job_hour` - hour for EDI app cron
* `edi_app_job_minute` - minute for EDI app cron
* `edi_app_move_untouched` - EDI app config
* `edi_app_sftp_port` - EDI app SFTP port (client's)
* `edi_app_sftp_server` - EDI app SFTP server (client's)
* `edi_app_sftp_subfolder_claims` - EDI app SFTP claims subfolder
* `edi_app_sftp_subfolder_remits_archive` - EDI app SFTP remits archive subfolder
* `edi_app_sftp_subfolder_remits` - EDI app SFTP remits subfolder
* `edi_app_sftp_user` - EDI app SFTP user (client's)
* `edi_app_sftp_uses_password` - EDI app SFTP uses password?
* `edi_app_skip_edi_processing` - EDI app skip processing
* `edi_app_subfolder_professional` - EDI app professional subfolder
* `edi_monitor_facility_id` - EDI monitor facility ID
* `edi_monitor_facility_name` - EDI monitor facility name
* `edi_monitor_receivers` - list of emails to receive EDI monitor
* `enable_multiple_physicians` - app config option for enabling multiple physicians
* `facilities` - numbered list of facilities for the client
* `find_account_by_ucrn` - use UCRN to find account
* `host` - the hostname for this client
* `import_cron_hour` - hour for import cron
* `import_cron_minute` - minute for import cron
* `import_oop` - controls whether to import oop
* `import_process` - process for importing
* `insurance_payments_pulled_from_835` - pull insurance payments from 835
* `invert_adjustment_value` - invert adjustment value
* `invert_writeoff_value` - invert writeoff value
* `logo` - the logo to use for this client
* `map_pmt_file` - map payment file
* `master_separator` - master separator
* `notes_report_enabled` - enable notes report
* `npi_cron_hour` - NPI cron hour
* `npi_cron_minute` - NPI cron minute
* `overwrite_payor` - overwrite payor
* `payor_code_by_payor_name` - find payor code by payor name
* `post_import_alerts_enabled` - enable post import alerts
* `post_import_alerts_receivers` - list of emails to receive post import alerts
* `replace_header_pmt_file` - headers for pmt file
* `sanitize_payor_names` - enabled sanitization of payor names
* `sequestration_adjustment` - enable sequestration adjustment
* `ssl_host` - custom ssl host
* `ssl_name` - custom ssl name
* `ssl_port` - custom ssl port
* `ucrn_import_account_length` - UCRN import account length
* `ucrn_import_account_start` - UCRN import account start
* `ucrn_import_csv_headers` - UCRN import CSV headers
* `ucrn_import_is_csv` - UCRN import csv flag
* `ucrn_import_separator` - UCRN import separator
* `ucrn_import_ucrm_length` - UCRN import length
* `ucrn_import_ucrn_start` - UCRN import start
* `uid` - the linux UID to assign this client (must be unique)
* `worker_process` - custom process for worker to use
* `worker_schedule` - custom schedule for workers to be provisioned

## Runbook

### Adding an environment

1. Create an `<env>defaults` section in `envs.yml`.
1. Create a Route53 Hosted Zone named the same as what you set in the `hosted-zone-name` property of the `<env>defaults` section in `envs.yml`.
1. Edit the Hosted Zone for `revenuemasters.com` (in the prod AWS account) and add an NS record for `<env>.revenuemasters` with all four of the NS server addresses from the new zone.
1. Create an SSH key in EC2 named the same as what you set in the `key-name` property of the `<env>defaults` section in `envs.yml`.
1. Create the env under `environments` in `envs.yml` and inherit from your `<env>defaults`.
1. Edit `cfn/templates/application_stack.rb` and comment out the entire `Deployment` property in the `AWS::CodeDeploy::DeploymentGroup` resource. Don't commit this change.
1. Run Converge to create the secrets bucket. It will fail because the secrets it needs later don't exist.
1. Copy these secrets from any other environment into the new secrets bucket:
   * `revenuemasters-deploy-user-key`
   * `revenuemasters-deploy-user-key.pub`
   * `email-password`
   * `newrelic-license-key`
   * `revenuemasters-app-ssl-intermediate-cert` (Non-prod environments use self-signed keys that don't have intermediate certificates, instead their intermediate certs are filled with the ones from prod. Prods share one certificate.)
1. Generate a password into a file called `rds-admin-password` and upload that file to the new secrets bucket.
1. Generate a self-signed SSL certificate and key and upload both files to the new secrets bucket.
   1. `openssl req -x509 -nodes -days 825 -newkey rsa:2048 -keyout revenuemasters-app-ssl-key -out revenuemasters-app-ssl-cert` (Formerly, these certs were given longer expirations but [new rules](https://www.thesslstore.com/blog/cab-forum-ballot-193/) limit expiration lengths and conforming makes testing in browsers more accurate.)
   1. Enter `*.<domain>` for *Common Name*, where `<domain>` matches the Route53 Hosted Zone name.
   1. Copy the other information from one of the other non-prod certs.
1. Follow the instructions below to add clients to your new environment.
1. Follow the instructions below to add secrets for a `rmedi` client. This isn't actually a client, but it needs the same secrets.
1. Change directory into ./packer. Use the `run-packer-with-profile.rb` script to create a new AMI for the environment. If needed, make sure secrets bucket are available for download
1. Add the new AMI ID to `envs.yml` in the `image-id` field.
1. Run Converge again. It should get past the secrets errors and create a new application in CodeDeploy.
1. Follow [these instructions](http://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-partners-github.html#behaviors-authentication) to authorize the new CodeDeploy application in GitHub.
1. Revert your temporary changes to `cfn/templates/application_stack.rb`.
1. Run Converge again. It should run the deployment.

### Adding a client to an environment

* Check the `cfn/templates/log_groups_stack.rb` file and count how many log groups will be added. Add this to the total resources in the current log group stack and ensure it's below the CloudFormation per-stack resource limit of 200.
* Add the appropriate info to the ```envs.yml``` file in the correct cluster
* [Create a hashed password](https://docs.chef.io/resource_user.html#password-shadow-hash) for the client's SFTP user: `openssl passwd -1 "theplaintextpassword"`.
* Add the client's hashed SFTP password to the secrets bucket as: `[clientcode]-password`.
* Update the appropriate Google Doc with the SFTP connection information for the client
* If `edi_app_enabled` is `true` in `envs.yml`, upload the needed password (*not* the plaintext password from above) to the secrets bucket as `edi-sftp-[clientcode]-password`.
* If `post_import_enabled` or `post_import_alerts_enabled` is `true` in `envs.yml`, upload the plaintext SSH password to the secrets bucket as `[clientcode]-sftp-password`.
* For `rmedi`, upload the plaintext SSH password to the secrets bucket as `rmedi-password-plain`.
* For `healthpointe`:
  * Upload the plaintext SSH password to the secrets bucket as `healthpointe-password-plain`.
  * If `ssl_name` is `pyramidmaximizer` in `envs.yml`, copy the three `pyramidmaximizer-ssl-` SSL files from another environment to the secrets bucket.

### Deploying

#### Bundling Chef

1. `cd chef`
1. `bundle exec berks vendor` (if there are any Chef changes)
1. Commit changes.

#### Deploying Code via local Ruby

1. Copy the git hash of the devops repo commit and put it in the `chef-sha` field of the environment you're updating in `envs.yml`.
1. Commit changes.
1. Push.
1. `bundle exec ./converge.rb <env>`

#### Deploying Code via Docker wrapper

1. Copy the git hash of the devops repo commit and put it in the `chef-sha` field of the environment you're updating in `envs.yml`.
1. Commit changes.
1. Push.
1. `./docker_build.sh` # only needed when devops dependencies change
1. `./deploy.sh <env>` # takes same args as converge.rb

WARNING: Don't log in to servers during deploy. Chef sets user IDs, which will fail if the user is logged in. In some case logging in may be safe (e.g. if the deploy doesn't create new instances and you are not a new user).

### Add Public SSH key to ~/.ssh/authorized_keys file of one or more servers

    $ bundle install
    $ bundle exec ./scripts/add-ssh-key-to-instances.rb -k 'publickeycontents' -u ubuntu -s 1.2.3.5

### Allow SSH connections from your IP

The SFTP servers limit which IP addresses can connect via SSH. Hosts with static external IPs are whitelisted in `envs.yml`. If you are connecting from a dynamic IP (e.g. your home), you can manually add your IP to the Security Group.

1. Log in to the AWS web console.
1. Select the region of the env you are editing.
1. Open the EC2 service.
1. Select Security Groups.
1. Find the `<env>-application-stack-SftpSecurityGroup` entry.
1. Add a new Inbound Rule with this information:
   * Type: SSH
   * Protocol: TCP
   * Port Range: 22
   * Source: 'My IP' (the console automatically detects your external IP)

### Connecting to instances

For dev:

    $ ssh -A sftp-dev-1.nextgen.revenuemasters.com

then...

    $ connect-to-instance [app|worker|importer]

Other envs:

* sftp-stage-1.stage-1.revenuemasters.com
* sftp-prod-1.revenuemasters.com
* sftp-prod-hca.revenuemasters.com

### Running Chef Test Kitchen

*(Examples given using the Ruby environment included with the ChefDK or Chef Omnibus installs, but you can use any Ruby environment where Test Kitchen and its dependencies are installed)*

For dev:

1. Ensure you have an [AWS CLI profile](http://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html) named `revenuemasters-dev` that sets the AWS region and API keys. See the `shared_credentials_profile` option in `chef/.kitchen.yml`.

1. Ensure the `kitchen-sync` gem is installed:

    ```text
    $ chef exec gem install kitchen-sync
    ```

1. Run kitchen:

    ```text
    $ chef exec kitchen list
    ```
