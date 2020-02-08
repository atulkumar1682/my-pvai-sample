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
#	print (region_name)
	ec2 = boto3.client('ec2', region_name=region_name)

	describe_vpcs = ec2.describe_vpcs(
		Filters=[
			{
				'Name': 'state',
				'Values': [
					'available'
				]
			}
		]
		)
	for vpc_id_obj in describe_vpcs['Vpcs']:
		vpc_id = vpc_id_obj['VpcId']
#		print (vpc_id)
		list_route_tables = ec2.describe_route_tables(
			Filters=[
				{
					'Name': 'vpc-id',
					'Values': [
						vpc_id
					]
				}
			]
			)
		route_tables_list=[]
		for route_table_id_obj in list_route_tables['RouteTables']:
			route_table_id = route_table_id_obj['RouteTableId']
			route_tables_list.append(route_table_id)

#		print (route_tables_list)
		try:
			create_vpc_s3_endpoint = ec2.create_vpc_endpoint(
				DryRun= False,
				VpcId= vpc_id,
				VpcEndpointType= 'Gateway',
				ServiceName= 'com.amazonaws.'+region_name+'.s3',
				RouteTableIds= route_tables_list,
				)
			print (create_vpc_s3_endpoint)
		except:
			pass

		print ('Endpoint is created for VPC : %s in Region : %s ' %(vpc_id , region_name))