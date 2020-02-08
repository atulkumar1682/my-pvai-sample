import boto3 
import json

def lambda_handler(event, context):

	region_client = boto3.client('ec2')
	regions = region_client.describe_regions()

	for region_name_obj in regions['Regions']:
		region_name = region_name_obj['RegionName']
		print (region_name)
		ec2 = boto3.client('ec2', region_name=region_name)

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
			print (subnet_id)
			response = ec2.modify_subnet_attribute(
				MapPublicIpOnLaunch={
					'Value': False
				},
				SubnetId=subnet_id
			)
			print (response)