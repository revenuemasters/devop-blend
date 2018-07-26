
Unreleased
==========

1.14.0
======
* REVM-126 eSolutions deployment script (additional parameterizing in cookbooks)
* REVM-129 Clam AV installation / configuration
* REVM-130 auditd implementation
* HITRUST 11126.01t1Organizational.12. Added ssh idle timeout
* KRA-3084 Automated running of phinx-migrate.sh post deploy

1.13.5
======
* Increasing size of RDS dbs

1.13.4
======
* KRA-3091 add edi_app_multiple_facilities config option

1.13.3
======
* Adding Revenue Masters SD office IP (12.35.128.50) to all envs

1.13.2
======
* Adding Brian Ngyuyen

1.13.1
======
* Adding Rodrigo
* Quoting passwords
* Updating email recipient list
* Adding missing php5.6 libraries
* Symlinking apache2 php.ini to cli php.ini

1.13.0
======
* REVM-116 Updated PHP5 version to 5.6.x, enabled upgrades by just rolling instances
* REVM-122 Updated move-incoming-client-data.sh script
* REVM-121 Adding parameters for controlling the date in report file names of post-import.sh
* REVM-108 Adjusting ingress rules for whitelisting, enables separate user lists and dynamic ports based on env
* REVM-124 Adding docker support for easier deploys
* Adding documentation for options in envs.yml to README.md

1.12.1
======
* REV-114 Fixing post-import issues

1.12.0
======
* REVM-109 Integrate mail credentials and cache folder permissions for cvc template
* REVM-103 Making write down report generic
* Adding Bryan to dev-1
* Allowing custom worker process
* REVM-101 Hardening SSL ciphers
* REVM-107 Adding IPs to prod-1 whitelist
* REVM-102 Disable Directory Browsing for EDI UI

1.11.1
======
* Enabling CVC on prod-1

1.11.0
======
* REVM-76 Removing 1edisource name
* Add Sergio
* Add EDI UI php setting max_input_vars

1.10.1
======
* REVM-20 Split CloudWatch log groups into separate templates

1.10.0
======
* REVM-90 Update Let's Encrypt Certificate Configuration
* Clean up dev-2 post-REVM-49 release.
* REVM-20 save logs in CloudWatch

1.9.2
=====
* REVM-49 Move off of Dedicated Tenancy

1.9.1
=====
* REVM-81 Don't try to delete snapshots in use by AMI
* Fix issues with web_app directive

1.9.0
=====
* REVM-10 Move to Let's Encrypt
* REVM-47 updates to EBS snapshot script
* REVM-58 1edisource permission updates
* REVM-67 New flags for NPI jobs
* REVM-72 edi infrastructure updates
* REVM-75 Updates to Quadax settings
* REVM-80 New flags for EDI app
* Removing Hector from automation code
* Enable snapshot deletes.
* Increase memory limit on EBS snapshot lambda function.

1.8.1
=====
* Use '*' for assume role policy resource

1.8.0
=====
* Updating permissions for 1edisource user
* setting payor_code_by_payor_name to false for sbhny

1.7.0
=====
* Cross Account Read configuration

1.6.0
=====
* Increase EBS snapshot Lambda function timeout to 5 minutes.
* Adding disk check for app encrypted volume
* Switching to Let's Encrypt for SSL Certs
* Adding Quadax environment
* Adding Physician Pro app
* Adding API Importer app
* Forcing update of s3 bucket templates

1.5.3
=====
* Making post_import and notes_report variable

1.5.2
=====
* Adding GetObject permission for backup bucket

1.5.1
=====
* Fixing issue with backup lambdas in different accounts

1.5.0
=====
* REVM-62 innodb_lock_wait_timeout value should be 120 on MySQL servers
* REVM-47 updates to EBS snapshot script
* REVM-51 Ensure SFTP will retry attaching EIP
* REVM-57 Specify uid and gid for 1edisource user
* REVM-59 Increase retention period for files to 540 days

1.4.3
=====
* REVM-56 Turn off archival to Glacier for s3 backups

1.4.2
=====
* Adding whitelisted IP for BitNet
* Adding new whitelisted IPs for HCA
* Adding whitelisted IP for UBMC
* Adding new client SBHNY
* Adding whitelisted IP for ahweems

1.4.1
=====
* If Importer network interface doesn't attach, retry.
* Don't wait forever for codedeploy agent to install.
* REVM-36 Implement white listing for SFTP Servers
* If EBS volumes don't attach, retry.
* Don't wait forever for attached EBS volumes to appear in Linux.
* REVM-44 Set ID for Unix groups.
* REVM-44 Accept SSH host keys between SFTP and Imorter.
* REVM-44 Remove prod's exclusion of old file cleanup on /encrypted drives.
* REVM-48 Create stage-1 environment
* REVM-45 healthpointe: bash script and cron job to execute it

1.4.0
=====
* Adding ahsanantoniophysician
* Adding some additional facilities
* Backup /encrypted volumes to s3 nightly and remove files from server after two weeks
* Adding Adam Burns
* Adding specific uids to all users and groups
* Adding ability for importer to be different size
* Upgrading prod-1 importer to m4.2xlarge
* REVM-41 New flags for UBMC

1.3.3
=====
* REVM-34 Three new clients on prod-1
* Adding LAKEVIEWSPEC to RM EDI
* Updating README.md to include info about adding new clients

1.3.2
=====
* REVMINT-30 Deployment scripts updates (application.ini, .env files)

1.3.1
=====
* REVM-29 add sanitize_payor_names to config
* REVM-26 Updating values for ubmc
* Removing North Texas and Atchison
* Adding Juan Carlos
* Adding healthpointe staging
* Removing atchison institutional cronjobs
* Adding map_pmt_file to tsjh

1.3.0
=====
* Worker queues
* Larger root volume sizes
* Adding TSJH to RM EDI & Monitor
* Adding Josh to all EDI Monitor receiver lists
* Adding Francisco to all EDI Monitor receiver lists

1.2.26
======
* Updating map_adj_file for smsopssurg

1.2.25
======
* Updating TSJH config flags
* Updating move-incoming-client-data scripts
* Updating WRMC post-import script
* Adding EDI cron job
* Adding UBMC client

1.2.24
======
* Fixing config bugs for EDI application

1.2.23
======
* Move EDI Job hour to 5 for WRMC

1.2.22
======
* Bugfixes from 1.2.21

1.2.21
======
* Adding 'php artisan migrate' to edi ui deploy

1.2.20
======
* Adding sequestration_adjustment config option
* Adding import_process config option
* prod-1 config file fixes

1.2.19
======
* EDI cron name fix
* EDI monitor template fix

1.2.18
======
* Install libapache2-php7.0 for EDI UI
* HCA config file updates

1.2.17
======
* Prepping for IP whitelisting
* EDI UI application deployed to SFTP servers
* EDI Monitor application deployed to SFTP servers
* EDI application deployed to SFTP servers
* Adding Texas Spine & Joint Hospital (tsjh) to Shared Prod

1.2.16
======
* Updating search string in health checks

1.2.15
======
* only create one health check / alarm per environment
* cloudwatch alarms for autoscaling disks
* lambda alarm monitor function
* Adding crons for smso clients
* updating config for various clients based on audit

1.2.14
======
* updating keep_releases to 1
* updating staff
* fixing 1edisource user creation on new envs
* removing mhermann and mhermannstaging sites
* adding quadax site
* adding dev-2 env
* ssl updates
* adding smsomonroe and smsopssurg

1.2.13
======
* Setting update_contract_mapping = "no" KRA-885

1.2.12
======
* added rcpsbmc to prod-hca
* added rcpsnypres to prod-hca
* added aws-sdk gem
* added backup-application.ini.erb script
* updating ssl configs

1.2.11
======
* Fix bug with boolean config values that have a default of true

1.2.10
======
* Changing pssurgical to pssurg
* Changing monroe to monroesurg

1.2.9
=====
* Updating stable-master sha

1.2.8
=====
* adding trmc, mhermannstaging, pssurgical, monroe
* adding custom -> pic_directory config option

1.2.7
=====
* defaulting payor_code_by_payor_name to 'yes'
* removing 'tyrone'
* updating crons

1.2.6
=====
* Adding 'import.shared' config option

1.2.5
=====
* Staging sites for HCA Atchison and North Texas

1.2.4
=====
* fixing password file for revworkscm

1.2.3
=====
* redeploy to fix missing password for sftp

1.2.2
=====
* updating chef sha

1.2.1
=====
* adding revworkscm.revenuemasters.com

1.2.0
=====
* Adding Hector
* New *.revenuemasters.com SSL cert
* mhermann config updates

1.1.1
=====
* Fix typo in customization deploy code

1.1.0
=====
* customizations for mhermann
* adding lakeviewspec site

1.0.0
=====
* initial release
* Adding mhermann site
