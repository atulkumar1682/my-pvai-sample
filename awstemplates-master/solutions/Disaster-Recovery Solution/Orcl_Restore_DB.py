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
## date = 22-Feb-2019
import boto3  
import botocore  
import datetime  
import re  
import logging
import os

db_instance_class=os.environ['DB_INSTANCE_CLASS'] # for ex: 'db.m4.xlarge' 
db_subnet=os.environ['DB_SUBNET'] #for ex: 'pvai-prod-subnet-group'

region = os.environ['REGION']  
instances = [os.environ['DB_ID']]
db_id = os.environ['DB_ID']


print('Loading function')

def byTimestamp(snap):  
  if 'SnapshotCreateTime' in snap:
    return datetime.datetime.isoformat(snap['SnapshotCreateTime'])
  else:
    return datetime.datetime.isoformat(datetime.datetime.now())

def lambda_handler(event, context):  
    source = boto3.client('rds', region_name=region)
    multi_az = os.environ['MULTI_AZ']
	
    for instance in instances:
        try:
            source_snaps = source.describe_db_snapshots(DBInstanceIdentifier = instance)['DBSnapshots']
            print "DB_Snapshots:", source_snaps
            source_snap = sorted(source_snaps, key=byTimestamp, reverse=True)[0]['DBSnapshotIdentifier']
            snap_id = (re.sub( '-\d\d-\d\d-\d\d\d\d ?', '', source_snap))
            print('Will restore %s to %s' % (source_snap, db_id))
			#restore latest snapshot in RDS
            response = source.restore_db_instance_from_db_snapshot(DBInstanceIdentifier=db_id, 
            DBSnapshotIdentifier=source_snap,DBInstanceClass=db_instance_class,DBSubnetGroupName=db_subnet, 
            MultiAZ=str2bool(multi_az), PubliclyAccessible=False)
            print(response)

        except botocore.exceptions.ClientError as e:
            raise Exception("Could not restore: %s" % e)
            
def str2bool(v):
  return v.lower() in ("yes", "true", "t", "1")