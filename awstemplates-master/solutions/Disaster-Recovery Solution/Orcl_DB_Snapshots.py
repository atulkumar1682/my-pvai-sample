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
import botocore  
import datetime  
import re  
import logging
import boto3
import os
 
region=os.environ['PRIMARY_REGION']  
instances = [os.environ['DB_ID']]
 
print('Loading function')
 
def lambda_handler(event, context):  
     source = boto3.client('rds', region_name=region)
     for instance in instances:
         try:
             timestamp = str(datetime.datetime.now().strftime('%Y-%m-%d-%H-%-M-%S')) + "-lambda-snap"
             snapshot = "{0}-{1}-{2}".format("pvai", instance,timestamp)
             response = source.create_db_snapshot(DBSnapshotIdentifier=snapshot, DBInstanceIdentifier=instance)
             print(response)
         except botocore.exceptions.ClientError as e:
             raise Exception("Could not create snapshot: %s" % e)