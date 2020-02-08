import os
import boto3
import json
import re

def lambda_handler(event, context):

	region_checklist = ['us-east-1', 'eu-west-1']
	ec2 = boto3.client('ec2')
	regions = ec2.describe_regions()
	for region_name_obj in regions['Regions']:
		region_name = region_name_obj['RegionName']
		print (region_name)
		
		if region_name in region_checklist:
			pass
		else:
			continue

		s3 = boto3.client('s3' , region_name = '%s' %region_name)
		iam = boto3.client('iam')

		paginator = iam.get_paginator('list_account_aliases')

		for response in paginator.paginate():
			account_alias = response['AccountAliases'][0]

		list_buckets = s3.list_buckets()

		storage_bucket_name = account_alias + '-s3-accesslogs-' + region_name

		bucket_list = []
		for bucket_name_obj in list_buckets['Buckets']:
			bucket_list.append(bucket_name_obj['Name'])

		if storage_bucket_name in bucket_list:
			print ("Bucket exist")
		else:
			print ("Storage Bucket is not exist, creating storage bucket: %s" %storage_bucket_name)
			if region_name == 'us-east-1':
				create_bucket = s3.create_bucket(
					Bucket = storage_bucket_name,
				)
			else:
				create_bucket = s3.create_bucket(
					Bucket = storage_bucket_name,
					CreateBucketConfiguration ={
						'LocationConstraint' : region_name
					}
				)
			put_bucket_versioning = s3.put_bucket_versioning(
				Bucket = storage_bucket_name,
				VersioningConfiguration = {
					'MFADelete' : 'Disabled',
					'Status' : 'Enabled'
				}
			)
			get_bucket_acl = s3.get_bucket_acl(
				Bucket = storage_bucket_name
			)

			owner_id = get_bucket_acl['Owner']['ID']
			put_bucket_acl = s3.put_bucket_acl(
				AccessControlPolicy = {
					'Owner' : {
						'ID' : owner_id
					},
					'Grants': [
						{
							'Grantee': {
								'Type': 'Group',
								'URI': 'http://acs.amazonaws.com/groups/s3/LogDelivery'
							},
							'Permission': 'WRITE'
						},
						{
							'Grantee': {
								'Type': 'Group',
								'URI': 'http://acs.amazonaws.com/groups/s3/LogDelivery'
							},
							'Permission': 'READ_ACP'
						}
					]
				},
				Bucket = storage_bucket_name
			)

			put_bucket_lifecycle_configuration = s3.put_bucket_lifecycle_configuration(
				Bucket=storage_bucket_name,
				LifecycleConfiguration={
					'Rules': [
						{
							
							'ID': '',
							'Prefix': '',
							'Status': 'Enabled',
							'Transitions': [
								{
									'Days': 30,
									'StorageClass': 'STANDARD_IA'
								},{
									'Days': 90,
									'StorageClass': 'GLACIER'
								}
							]
						}
					]
				}
			)
			print (put_bucket_lifecycle_configuration)
		
		for bucket_name_obj in list_buckets['Buckets']:
			bucket_name = bucket_name_obj['Name']
			if bucket_name.find("log") == -1:
				try:
					put_bucket_logging = s3.put_bucket_logging(
						Bucket = bucket_name,
						BucketLoggingStatus = {
							'LoggingEnabled': {
								'TargetBucket' : storage_bucket_name,
								'TargetPrefix' : bucket_name + '/'
							}
						}
					)
					print ("Access logs are enabled for bucket %s" %bucket_name)
				except:
					pass
			else:
				print("Access logs are not required for logs storage bucket: %s" %bucket_name)
				
	return 'Run Successfully'