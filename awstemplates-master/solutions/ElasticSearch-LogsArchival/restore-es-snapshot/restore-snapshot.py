# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 03-Feb-2019
## Ref: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-managedomains-snapshots.html#es-managedomains-snapshot-restore

import boto3
import requests
from requests_aws4auth import AWS4Auth
import os

host = os.environ['ES_HOST'] # include https:// and trailing /
region = os.environ['REGION'] # e.g. us-east-1
service = 'es'
snapshot_repo = os.environ['SNAPSHOT_REPO']
snapshot_name = os.environ['SNAPSHOT_NAME']
my_index = os.environ['MY_INDEX']

# get credentials using boto3 library
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

# Lambda execution starts here.
def lambda_handler(event, context):
    if my_index == "":    
        # # Restore snapshots (all indices)
        #
        print("restore all indices from snapshot " + snapshot_name)
        #
        path = '_snapshot/' + snapshot_repo + '/' + snapshot_name + '/_restore'
        url = host + path
        print(url)
        #
        payload = { "indices": "filebeat*", "ignore_unavailable": True, "include_global_state": True, "rename_pattern": "filebeat(.+)", "rename_replacement": "restored_filebeat$1"}
        #
        headers = {"Content-Type": "application/json"}
        #
        r = requests.post(url, auth=awsauth, json=payload, headers=headers)
        #
        print(r.text)
    else:
    
        #
        # # Restore snapshot (specific index)
        #
        print("restore index " + my_index + " from snapshot " + snapshot_name)
        #
        path = '_snapshot/' + snapshot_repo + '/' + snapshot_name + '/_restore'
        url = host + path
        #
        payload = {"indices": my_index}
        #
        headers = {"Content-Type": "application/json"}
        #
        r = requests.post(url, auth=awsauth, json=payload, headers=headers)
        #
        print(r.text)
