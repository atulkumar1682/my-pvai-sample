# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 20-Feb-2019

import os
import boto3
import json

region = os.environ['REGION']
client = boto3.client('autoscaling', region_name=region)
tag_key = os.environ['FILTER_TAG_KEY']
scheduled_tag = os.environ['SCHEDULED_TAG']

def lambda_handler(event, context):


    paginator = client.get_paginator('describe_auto_scaling_groups')
    page_iterator = paginator.paginate(
        PaginationConfig={'PageSize': 100}
    )
    
    # get tags value list from Variable as comma separated string
    spiltted_tags = os.environ['FILTER_TAG_VALUES'].split(',')
    tags_list = [x.strip() for x in spiltted_tags]
    print(tags_list)
    
    try:
        # get minimum and desired capcity from environment variables
        min_size = int(os.environ['MIN_SIZE'])
        desired_capacity = int(os.environ['DESIRED_CAPACITY'])
    except ValueError:
         print("Oops!  That was no valid number.  Set Environment Variables Properly...")
         return

    try:
        # get Scheduled flag value
        scheduled_flag='yes' # get this value dynamically from ASG Tag
        
        for tag in tags_list:
            print(tag_key+ ": " + tag)
        
            filtered_asgs = page_iterator.search(
                'AutoScalingGroups[] | [?contains(Tags[?Key==`{}`].Value, `{}`)] | [?contains(Tags[?Key==`{}`].Value, `{}`)]'.format(tag_key, tag, scheduled_tag, scheduled_flag)
            )
        
            for asg in filtered_asgs:
                print asg['AutoScalingGroupName']
                response = client.update_auto_scaling_group(
                            AutoScalingGroupName=asg['AutoScalingGroupName'],    
                            MinSize=min_size,
                            DesiredCapacity=desired_capacity
                            )
                print response
    except Exception as e:
        print(e)