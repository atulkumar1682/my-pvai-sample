# Use the CFT update from the s3 and passing the parameter file as well from s3
"""
Update or create a stack given a name and template + params
"""
from __future__ import division, print_function, unicode_literals
from datetime import datetime
import logging
import json
import sys
import os

import boto3
import botocore

cf = boto3.client('cloudformation', region_name='us-east-1') # pylint: disable=C0103
log = logging.getLogger('deploy.cf.create_or_update') # pylint: disable=C0103


def lambda_handler(event, context):
    stack_name = os.environ['STACK_NAME']
    template_bucket = os.environ['S3_BUCKET']
    template_key = os.environ['TEMPLATE_KEY']
    parameters = os.environ['TEMPLATE_PARAMETERS']
    # main(event['stack_name'], event['template_bucket'], event['template_key'], event['parameters'])
    main(stack_name, template_bucket, template_key, parameters)


def main(stack_name, template_bucket, template_key, parameters):
    s3_client = boto3.client('s3')

    template_data = s3_client.get_object(Bucket=template_bucket, Key=template_key)
    parameter_data = s3_client.get_object(Bucket=template_bucket, Key=parameters)
    template_json_data = template_data['Body'].read(template_data['ContentLength'])
    parameter_json_data = parameter_data['Body'].read(parameter_data['ContentLength'])
    pararm = json.loads(str(parameter_json_data))
    # print(template_json_data)
    # print(parameter_json_data)

    params = {
        'StackName': stack_name,
        'TemplateBody': template_json_data,
        'Parameters': pararm,
    }
    try:
        if _stack_exists(stack_name):
            print('Updating {}'.format(stack_name))
            stack_result = cf.update_stack(**params)
            waiter = cf.get_waiter('stack_update_complete')
        else:
            print('Creating {}'.format(stack_name))
            stack_result = cf.create_stack(**params)
            waiter = cf.get_waiter('stack_create_complete')
        print("...waiting for stack to be ready...")
        waiter.wait(StackName=stack_name)
    except botocore.exceptions.ClientError as ex:
        error_message = ex.response['Error']['Message']
        if error_message == 'No updates are to be performed.':
            print("No changes")
        else:
            raise
    else:
        print(json.dumps(
            cf.describe_stacks(StackName=stack_result['StackId']),
            indent=2,
            default=json_serial
        ))


def _parse_template(template):
    with open(template) as template_fileobj:
        template_data = template_fileobj.read()
    cf.validate_template(TemplateBody=template_data)
    return template_data


def _parse_parameters(Parameters):
    with open(Parameters) as parameter_fileobj:
        parameter_data = json.load(parameter_fileobj)
    return parameter_data


def _stack_exists(stack_name):
    paginator = cf.get_paginator('list_stacks')
    for page in paginator.paginate():
        for stack in page['StackSummaries']:
            if stack['StackStatus'] == 'DELETE_COMPLETE':
                continue
            if stack['StackName'] == stack_name:
                return True
    return False


def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, datetime):
        serial = obj.isoformat()
        return serial
    raise TypeError("Type not serializable")


if __name__ == '__main__':
    main(*sys.argv[1:])