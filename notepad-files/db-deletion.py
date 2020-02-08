# -------------------------------------------------------------------------------------------------
#
#     Copyright Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
#
# -------------------------------------------------------------------------------------------------
## author = 'Atul Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 19-Nov-2019

import boto3
import sys
import os

def lambda_handler(event, context):
    db_instance = os.environ['DB_INSTANCE_IDENTIFIER']
    region = os.environ['REGION']
    print("Instance called:", db_instance)
    try:
        client = boto3.client('rds', region_name=region)
        dbs = client.describe_db_instances(DBInstanceIdentifier=db_instance)
        for db in dbs['DBInstances']:
            print "%s@%s:%s %s" % (
                db['MasterUsername'], db['Endpoint']['Address'], db['Endpoint']['Port'], db['DBInstanceStatus'])
            DB = db['DBInstanceIdentifier']
            print "deleting the database ... ", DB
            if db['DBInstanceStatus'] == "available":
                print db['DBInstanceStatus']
                try:
                    print("Deleting DB")
                    response = client.delete_db_instance(DBInstanceIdentifier=DB, SkipFinalSnapshot=True)
                    print("Delete Response:", response)
                except Exception as error:
                    print("ERR:", error)
    except Exception as error:
        print("ERR:", error)
