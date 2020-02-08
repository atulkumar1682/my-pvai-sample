# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 02-Feb-2019
import boto3
import requests
from requests_aws4auth import AWS4Auth

host = os.environ['ES_HOST'] # include https:// and trailing /
region = os.environ['REGION'] # e.g. us-east-1
service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

# Lambda execution starts here.
def lambda_handler(event, context):
    # Register repository

    path = '_snapshot/' + os.environ['SNAPSHOT_NAME'] # the Elasticsearch API endpoint
    url = host + path

    bucket = os.environ['SNAPSHOT_BUCKET']
    role_arn = os.environ['ROLE_ARN']

    payload = {
      "type": "s3",
      "settings": {
        "bucket": bucket,
        "region": region,
        "role_arn": role_arn
      }
    }

    headers = {"Content-Type": "application/json"}

    r = requests.put(url, auth=awsauth, json=payload, headers=headers)

    print(r.status_code)
    print(r.text)