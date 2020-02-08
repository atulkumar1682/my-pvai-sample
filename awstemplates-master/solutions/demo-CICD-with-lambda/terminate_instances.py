# -------------------------------------------------------------------------------------------------
#
#     Copyright Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
#
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 28-Nov-2018
## Ref: https://gist.github.com/mlapida/1917b5db84b76b1d1d55
# -------------------------------------------------------------------------------------------------
import boto3
import logging
import os
#setup simple logging for INFO
logger = logging.getLogger()
logger.setLevel(logging.INFO)

region = 'us-east-1'

#define the connection
ec2 = boto3.resource('ec2', region)

def lambda_handler(event, context):

    instance_name = os.environ['INSTANCE_NAME']
    # Use the filter() method of the instances collection to retrieve
    # all running EC2 instances for Specific.
    filters = [{
            'Name': 'tag:Name',
            'Values': [instance_name]
        },
        {
            'Name': 'instance-state-name', 
            'Values': ['running']
        }
    ]
    
    #filter the instances
    instances = ec2.instances.filter(Filters=filters)

    #locate all running instances
    RunningInstances = [instance.id for instance in instances]
    
    #print the instances for logging purposes
    #print RunningInstances 
    
    #make sure there are actually instances to shut down. 
    if len(RunningInstances) > 0:
        #perform the shutdown
        shuttingDown = ec2.instances.filter(InstanceIds=RunningInstances).terminate()
        print shuttingDown
    else:
        print "Nothing to shutdown"