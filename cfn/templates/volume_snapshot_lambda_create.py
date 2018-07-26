"""
The "Generated" tag was inherited from a previous script so that this would continue to retire previously generated
snapshots as they aged.
"""

import logging

import boto3
import botocore


def create_snapshots(event):
    logger = logging.getLogger()
    ec2 = boto3.resource('ec2', region_name=event['region'])
    for volume in ec2.volumes.all():
        try:
            volume_name = ''
            if volume.tags:
                volume_name = [t['Value'] for t in volume.tags if t['Key'] == 'Name'][0]
            volume_description = f'Automated snapshot of {volume.id} (volume name: "{volume_name}").'
            snapshot = volume.create_snapshot(
                Description=volume_description,
                DryRun=event['dry_run']
            )
            snapshot.create_tags(
                DryRun=event['dry_run'],
                Tags=[
                    {'Key': 'Name', 'Value': volume_description},
                    {'Key': 'Generated', 'Value': 'true'}
                ]
            )
            logger.info(f'Snapshotted {volume.id}.')
        except botocore.exceptions.ClientError as error:
            if error.response['Error']['Code'] == 'DryRunOperation':
                logger.info(f'(Dry Run) Snapshotted {volume.id}.')
            else:
                raise


def lambda_handler(event, context):
    logger = logging.getLogger()
    logger.setLevel(event['log_level'])
    if event['create_snapshots']:
        create_snapshots(event)
    logger.info('Lambda event complete.')
