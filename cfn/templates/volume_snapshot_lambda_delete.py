"""
The "Generated" tag was inherited from a previous script so that this would continue to retire previously generated
snapshots as they aged.
"""

import datetime
import logging

import boto3
import botocore


def delete_old_snapshots(event):
    """
    For all snapshots in a region:
        1. Find all snapshots with the "Generated" tag set to "true".
        2. Exclude any younger than "max_snapshot_age_days".
        3. Exclude any snapshots that are the last snapshot of their volume. During first implementation this function
           was a replacement for an older script that only acted on snapshots of volumes attached to running instances.
           This function acts on everything, so this exclusion was added as a safety against data loss during initial
           implementation. It may need to be removed after running for a while.
    """
    owner_id = boto3.client('sts').get_caller_identity().get('Account')
    now = datetime.datetime.now(datetime.timezone.utc)
    logger = logging.getLogger()
    ec2 = boto3.resource('ec2', region_name=event['region'])
    not_generated = 0
    too_young = 0
    last_available = 0
    snapshots = list(ec2.snapshots.filter(Filters=[{'Name': 'owner-id', 'Values': [owner_id]}]))
    snapshots.sort(key=lambda s: s.start_time)
    generated_snapshots = list()
    for snapshot in snapshots:
        if snapshot.tags and {'Key': 'Generated', 'Value': 'true'} in snapshot.tags:
            generated_snapshots.append(snapshot)
            logger.debug(f'Detected Generated snapshot {snapshot.id} started at {snapshot.start_time}.')
        else:
            logger.debug(f'Detected non-Generated snapshot {snapshot.id} started at {snapshot.start_time}.')
            not_generated += 1
    deleted_snapshots = list()
    for snapshot in generated_snapshots:
        if snapshot.start_time < now - datetime.timedelta(days=event['max_snapshot_age_days']):
            logger.debug(f'Checking if {snapshot.id} is the last of {snapshot.volume_id}.')
            snapshots_of_same_volume = [s for s in generated_snapshots
                                        if s not in deleted_snapshots
                                        and s.volume_id == snapshot.volume_id]  # This test triggers a boto call.
            logger.debug(f'Snapshots of {snapshot.volume_id}: {snapshots_of_same_volume}')
            if len(snapshots_of_same_volume) > 1:
                try:
                    logger.info(f'Deleting {snapshot.snapshot_id} of {snapshot.volume_id}.')
                    snapshot.delete(DryRun=event['dry_run'])
                    deleted_snapshots.append(snapshot)
                except botocore.exceptions.ClientError as error:
                    if error.response['Error']['Code'] == 'DryRunOperation':
                        logger.info(f'(Dry Run) Deleted {snapshot.snapshot_id}.')
                    elif error.response['Error']['Code'] == 'InvalidSnapshot.InUse':
                        logger.info(f'Skipped deleting {snapshot.snapshot_id}. It is in use (e.g. by an AMI).')
                    else:
                        raise
            else:
                last_available += 1
        else:
            too_young += 1
    logger.info(f'Skipped deleting {not_generated} snapshots that did not have the "Generated" tag.')
    logger.info(f'Skipped deleting {too_young} "Generated" snapshots younger than {event["max_snapshot_age_days"]} days.')
    logger.info(f'Skipped deleting {last_available} "Generated" snapshots that were the last snapshots of their volumes.')


def lambda_handler(event, context):
    logger = logging.getLogger()
    logger.setLevel(event['log_level'])
    if event['delete_old_snapshots']:
        delete_old_snapshots(event)
    logger.info('Lambda event complete.')
