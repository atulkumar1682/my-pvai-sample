import boto3
import os
import botocore

db_instance_class = os.environ['DB_INSTANCE_CLASS']  # for ex: 'db.m4.xlarge'
db_subnet = os.environ['DB_SUBNET']  # for ex: 'pvai-prod-subnet-group'
source_snap = os.environ['Snapshot_ID']
multi_az = os.environ['MULTI_AZ']
region = os.environ['REGION']
security_group = os.environ['SECURITY_GROUP']


def lambda_handler(event, context):
    source = boto3.client('rds', region_name=region)
    try:
        response = source.restore_db_instance_from_db_snapshot(DBInstanceIdentifier=os.environ['DB_ID'],
																				VpcSecurityGroupIds=[
																		security_group,
																	],	
                                                               DBSnapshotIdentifier=source_snap,
                                                               DBInstanceClass=db_instance_class,
                                                               DBSubnetGroupName=db_subnet,
                                                               MultiAZ=str2bool(multi_az), PubliclyAccessible=False)
        print(response)

    except botocore.exceptions.ClientError as e:
        raise Exception("Could not restore: %s" % e)


def str2bool(v):
    return v.lower() in ("yes", "true", "t", "1")