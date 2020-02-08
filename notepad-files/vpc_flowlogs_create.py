#!/usr/bin/python

import boto3
import json
import sys

aws_profile_name = sys.argv[1]

session = boto3.Session(profile_name='%s' %aws_profile_name)
boto3.setup_default_session(profile_name='%s' %aws_profile_name)

account_number = boto3.client('sts')

region_client = boto3.client('ec2' , region_name = 'us-east-1')
regions = region_client.describe_regions()
for region_name_obj in regions['Regions']:
	region_name = region_name_obj['RegionName']
	print (region_name)
	vpc = boto3.client('ec2' , region_name=region_name)
	iam = boto3.client('iam' , region_name=region_name)
	cloudwatch = boto3.client ('logs' , region_name=region_name)
	sts = boto3.client('sts' , region_name=region_name)

	account_id = sts.get_caller_identity()["Account"]

	assume_role_policy_document = {
	  "Version": "2012-10-17",
	  "Statement": [
	    {
	      "Sid": "",
	      "Effect": "Allow",
	      "Principal": {
	        "Service": "vpc-flow-logs.amazonaws.com"
	      },
	      "Action": "sts:AssumeRole"
	    }
	  ]
	} 

	policy_for_flow_logs = {
	  "Version": "2012-10-17",
	  "Statement": [
	    {
	      "Action": [
	        "logs:CreateLogGroup",
	        "logs:CreateLogStream",
	        "logs:PutLogEvents",
	        "logs:DescribeLogGroups",
	        "logs:DescribeLogStreams"
	      ],
	      "Effect": "Allow",
	      "Resource": "*"
	    }
	  ]
	}

	describe_vpcs = vpc.describe_vpcs(
		Filters = [
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
		print (vpc_id)
		describe_flowlogs = vpc.describe_flow_logs(
			Filters = [
				{
					'Name': 'resource-id',
					'Values': [
						vpc_id
					]
				}
			]
		)
		if len(describe_flowlogs['FlowLogs']) == 0:
			print ("FlowLogs are not exist for VPC: %s" %vpc_id)
			try:
				iam_policy = iam.create_policy(
					PolicyName = 'vpc-flow-logs',
					PolicyDocument = json.dumps(policy_for_flow_logs),
					Description = 'The policy is created for vpc-flow-logs role'
				)
			except:
				pass
			try:
				create_role = iam.create_role(
				    AssumeRolePolicyDocument = json.dumps(assume_role_policy_document),
				    Path='/',
				    RoleName='vpc-flow-logs-role',
				)
			except:
				pass
			try:
				attach_policy_to_role = iam.attach_role_policy(
					RoleName = 'vpc-flow-logs-role',
					PolicyArn = 'arn:aws:iam::'+account_id+':policy/vpc-flow-logs'
				)
			except:
				pass
			try:
				create_cloudwatch_loggroup = cloudwatch.create_log_group(
					logGroupName = 'vpc-flow-logs-'+vpc_id+''
				)
				print (create_cloudwatch_loggroup)
			except:
				pass

			create_flowlogs = vpc.create_flow_logs(
				DeliverLogsPermissionArn = 'arn:aws:iam::'+account_id+':role/vpc-flow-logs-role',
				LogGroupName = 'vpc-flow-logs-'+vpc_id+'',
				ResourceIds = [
					vpc_id
				],
				ResourceType = 'VPC',
				TrafficType = 'ALL'
			)
			print (create_flowlogs)

		else:
			print ("FlowLogs are exist for VPC: %s" %vpc_id)

