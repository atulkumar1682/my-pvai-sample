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
import json
import boto3
import os
from datetime import datetime, timedelta, tzinfo

class Zone(tzinfo):
    def __init__(self,offset,isdst,name):
        self.offset = offset
        self.isdst = isdst
        self.name = name
    def utcoffset(self, dt):
        return timedelta(hours=self.offset) + self.dst(dt)
    def dst(self, dt):
        return timedelta(hours=1) if self.isdst else timedelta(0)
    def tzname(self,dt):
        return self.name

UTC = Zone(10,False,'UTC')

aws_region = os.environ['REGION']   
dbinstance = os.environ['DB_ID']

# Setting the retention period as per environment variable
retentionDate = datetime.now(UTC) - timedelta(days=int(os.environ['RETENTION_DAYS']))

def lambda_handler(event, context):

    try:
        print("Connecting to RDS")
        rds = boto3.setup_default_session(region_name=aws_region)
        client = boto3.client('rds')
        # get snapshots of the RDS instance
        snapshots = client.describe_db_snapshots(SnapshotType='manual',DBInstanceIdentifier=dbinstance)
        
        print('Deleting all DB Snapshots older than %s' % retentionDate)

        for i in snapshots['DBSnapshots']:
            if i['SnapshotCreateTime'] < retentionDate:
                print ('Deleting snapshot %s' % i['DBSnapshotIdentifier'])
                client.delete_db_snapshot(DBSnapshotIdentifier=i['DBSnapshotIdentifier'])
    except Exception as e:
        print(e)