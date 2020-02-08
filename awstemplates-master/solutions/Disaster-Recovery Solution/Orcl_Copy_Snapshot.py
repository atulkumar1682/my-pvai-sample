# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 22-Feb-2019
import boto3  
import botocore  
import datetime  
import re
import json
import os
    
source_region = os.environ['PRIMARY_REGION']  
target_region = os.environ['DR_REGION']
# create boto client for iam service
iam = boto3.client('iam')  
instances = [os.environ['DB_ID']]

print('Loading function')

def byTimestamp(snap):  
  if 'SnapshotCreateTime' in snap:
    return datetime.datetime.isoformat(snap['SnapshotCreateTime'])
  else:
    return datetime.datetime.isoformat(datetime.datetime.now())

def lambda_handler(event, context):  
    print("Received event: " + json.dumps(event, indent=2))
    account_ids = []
    try:
        iam.get_user()
    except Exception as e:
        account_ids.append(re.search(r'(arn:aws:sts::)([0-9]+)', str(e)).groups()[1])
        account = account_ids[0]

    source = boto3.client('rds', region_name=source_region)

    for instance in instances:
        source_instances = source.describe_db_instances(DBInstanceIdentifier= instance)
        # get all snapshots for the defined instance
        source_snaps = source.describe_db_snapshots(DBInstanceIdentifier=instance)['DBSnapshots']
        # get the latest snapshot from the list
        source_snap = sorted(source_snaps, key=byTimestamp, reverse=True)[0]['DBSnapshotIdentifier']
        # create source snapshot id ARN
        source_snap_arn = 'arn:aws:rds:%s:%s:snapshot:%s' % (source_region, account, source_snap)
        # target snap id is same as source snap id
        target_snap_id = (re.sub('rds:', '', source_snap))
        print('Will Copy %s to %s' % (source_snap_arn, target_snap_id))
        target = boto3.client('rds', region_name=target_region)

        try:
            response = target.copy_db_snapshot(
            SourceDBSnapshotIdentifier=source_snap_arn,
            TargetDBSnapshotIdentifier=target_snap_id,            
            #get Kms Key Id from environment variable 
            KmsKeyId= os.environ['KMS_KEY_ID'],
            SourceRegion=source_region)
            print(response)
        except botocore.exceptions.ClientError as e:
            raise Exception("Could not issue copy command: %s" % e)
        copied_snaps = target.describe_db_snapshots(SnapshotType='manual', DBInstanceIdentifier=instance)['DBSnapshots']