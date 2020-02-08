#!/usr/bin/python

import boto3 
import json
import sys

aws_profile_name = sys.argv[1]

session = boto3.Session(profile_name='%s' %aws_profile_name)
boto3.setup_default_session(profile_name='%s' %aws_profile_name)

region_client = boto3.client('ec2' , region_name='us-east-1')
regions = region_client.describe_regions()

for region_name_obj in regions['Regions']:
	region_name = region_name_obj['RegionName']
	ec2 = boto3.client('ec2',  region_name=region_name)

	list_subnet = ec2.describe_subnets(
		Filters=[
			{
				'Name': 'state',
				'Values': [
					'available'
				],
			}
		]
		)

	for subnet_id_obj in list_subnet['Subnets']:
		subnet_id = subnet_id_obj['SubnetId']
		response = ec2.modify_subnet_attribute(
			MapPublicIpOnLaunch={
				'Value': False
			},
			SubnetId=subnet_id
		)
		print (response)
		print ('Disabled Auto-assign public IP for subnet %s in region %s ' %(subnet_id , region_name))