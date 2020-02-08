# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 21-Feb-2019
import boto3
import os

region = os.environ['REGION']
ec2 = boto3.client('ec2', region_name=region)
tag_key = os.environ['FILTER_TAG_KEY']
scheduled_tag = os.environ['SCHEDULED_TAG']


def lambda_handler(event, context):
    
    # get tags value list from Variable as comma separated string
    spiltted_tags = os.environ['FILTER_TAG_VALUES'].split(',')
    tags_list = [x.strip() for x in spiltted_tags]
    
    # check each environment and get instances details
    try:
        
		# get Scheduled flag value
        scheduled_flag='yes' # get this value dynamically from ASG Tag
		
        for tag in tags_list:
            print(tag_key+ ": " + tag)
        
            filtered_instances = ec2.describe_instances(Filters=[{'Name':'tag:' + tag_key, 'Values':[tag]}, 
                                {'Name':'tag:' + scheduled_tag, 'Values':[scheduled_flag]}, 
                                {'Name':'instance-state-name', 'Values':['stopped']}])
                                
            if len(filtered_instances['Reservations']) == 0:
                print("no instance matching with criteria")
            else:
                # check all reservation objects
                for reservation in filtered_instances['Reservations']:
                    # get all instances
                    for instance in reservation['Instances']:
                        print("instance: " + instance['InstanceId'] + " having private ip: " + instance['PrivateIpAddress'] +  
                        " with current state as " + instance['State']['Name'])
                        
                        asg_instance = ec2.describe_instances(Filters=[{'Name':'tag-key', 'Values':['aws:autoscaling:groupName']}, 
                        {'Name':'instance-id', 'Values':[instance['InstanceId']]}])
                  
                        if asg_instance['Reservations']:
                            print ("ignore ec2 instance attached to ASG")
                        else:
                            # stop the instance
                            print("start the instance: " + instance['InstanceId'])
                            response = ec2.start_instances(InstanceIds=[instance['InstanceId']])
                            print(response)
    except Exception as e:
        print(e)