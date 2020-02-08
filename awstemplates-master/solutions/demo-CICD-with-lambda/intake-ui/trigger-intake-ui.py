# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
#
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 15-Jan-2019
# -------------------------------------------------------------------------------------------------
import boto3
import os

def trigger_handler(event, context):
    #Get IP addresses of EC2 instances
    client = boto3.client('ec2')
    instDict=client.describe_instances(
            Filters=[{'Name':'tag:Name','Values':['pvai-dev-cor']}]
        )

    hostList=[]
    for r in instDict['Reservations']:
        for inst in r['Instances']:
            print inst
            hostList.append(inst['PrivateIpAddress'])

    #Invoke worker function for each IP address
    client = boto3.client('lambda')
    for host in hostList:
        print "Invoking worker_function on " + host
        invokeResponse=client.invoke(
            FunctionName='deploy_intake_ui',
            InvocationType='Event',
            LogType='Tail',
            Payload='{"IP":"'+ host +'"}'
        )
        print invokeResponse

    return{
        'message' : "Trigger function finished"
    }