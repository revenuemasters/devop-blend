from dateutil.parser import parse
import boto3
import json

boto3.setup_default_session(region_name='us-east-1')
date_format='%m/%d/%Y %H:%M:%S %Z'

def lambda_handler(event, context):
    messages = []
    client_cloudwatch = boto3.client('cloudwatch')
    client_sns = boto3.client('sns')
    alarms = client_cloudwatch.describe_alarms()
    for item in alarms['MetricAlarms']:
       if item['StateValue'] == 'ALARM' and event['sns_alarm_arn'] in item['AlarmActions']:
           start_time = parse(json.loads(item['StateReasonData'])['startDate'])
           messages.append(item['AlarmDescription'] + ' entered ALARM state at ' + start_time.strftime(date_format) + ': ' + item['StateReason'])

    if len(messages) > 0:
        print '\n'.join(messages)
        client_sns.publish(
            TargetArn=event['sns_alarm_arn'],
            Message='\n'.join(messages)
        )
