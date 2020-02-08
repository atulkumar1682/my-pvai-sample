## author = 'Deepak Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 10-10-2019
## Modified by = 'Atul Kumar'

import boto3
import os
import paramiko
import time

#Enviorment variable
tag_name="pvai-rge-testing"     #name of the rage server
os_user="ubuntu"                #Default username to login AWS Instance

#S3 Bucket Variables for defining source bucket and destination bucket
s3_source_path="pvai-verification-ec2-key-bucket"
s3_destination_path="pvai-verification-es-repository"

#bucket location to save pem key
pem_key_bucket="tools-verification"              
pem_key="rage-code/pvai-verification-prod.pem"


def start_stop_rage():
    # check each environment and get instances details
    try:
        s3_client = boto3.client('s3')
        s3_client.download_file(pem_key_bucket, pem_key, '/tmp/keyname.pem')

        def stop_service(instance_ip):
            k = paramiko.RSAKey.from_private_key_file("/tmp/keyname.pem")
            c = paramiko.SSHClient()
            c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            print ("connecting for stoping the service")
            c.connect( hostname = instance_ip, username = os_user, pkey = k )
            print ("connected")
			commands = ["""sudo runuser -l rageadmin -c 'kill -9 $(ps -ef | grep "jboss" | grep -v grep | awk "{print $2}")'"""]
            for command in commands:
                print ("Executing {}").format( command )
                stdin , stdout, stderr = c.exec_command(command)
                print (stdout.read())
                print( "Stoping Server.....")
                print (stderr.read())
                c.close()

        def start_service(instance_ip):
            k = paramiko.RSAKey.from_private_key_file("/tmp/keyname.pem")
            c = paramiko.SSHClient()
            c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            print ("connecting for starting the service")
            c.connect( hostname = instance_ip, username = os_user, pkey = k )
            print ("connected")
            commands = [
                    "sudo runuser -l rageadmin -c 'rm -rf /opt/application/wildfly-10.1.0.Final/standalone/data/'",
                    "sudo runuser -l rageadmin -c 'rm -rf /opt/application/wildfly-10.1.0.Final/standalone/tmp/'",
                    "sudo runuser -l rageadmin -c 'source ~/.profile;sh /opt/application/wildfly-10.1.0.Final/bin/standalone.sh > run.log 1>/dev/null 2>/dev/null &'"]

            for command in commands:
                print ("Executing {}").format( command )
                stdin , stdout, stderr = c.exec_command(command)
                print (stdout.read())
                print( "Errors")
                print (stderr.read())
            c.close()

        def s3_delete_copy(s3_source_path,s3_destination_path):
            #clear all data from s3 destination folder
            s3 = boto3.resource('s3')
            bucket = s3.Bucket(s3_destination_path)
            print("deleting destination bucket data ....")
            print(bucket)
            bucket.objects.all().delete()
			time.sleep(10)
            
			#Copy Process will start from here
            print("Copy process started from ")
            print(s3_source_path)
            print("to")
            print(s3_destination_path)
            
            bucket = s3.Bucket(s3_source_path)
            dest_bucket = s3.Bucket(s3_destination_path)

            #s3_folder=("/PVAI","/PVAIFileSync","/Pvai")
            #for folder in s3_folder:
                #print (folder)
                #copy_bucket(default_aws_key, default_aws_secret_key, args)
                #s3_bucket_to_bucket_copy.copy_bucket('AKIASAV54VCK64Y6ZYV2','F+3muAv5DUyFrSaFXPaSYISOSDf86OiYFNeIeYP4','s3_source_path+folder s3_destination_path')
				
            for obj in bucket.objects.all():
                dest_key = obj.key
                #print(dest_key)
                
                s3.Object(dest_bucket.name, dest_key).copy_from(CopySource = {'Bucket': obj.bucket_name, 'Key': obj.key})
				
            print('completed')
        ec2client = boto3.client('ec2','us-east-1')
        response = ec2client.describe_instances(Filters=[
            {'Name' : 'instance-state-name','Values' : ['running']},
            {'Name' : 'tag:Name','Values': [tag_name]}
            ])
        #print(response)

        for reservation in response["Reservations"]:
            for instance in reservation["Instances"]:
                instance_Ip=instance["PrivateIpAddress"]
                instance_id=instance["InstanceId"]
                print  (instance_Ip + "  ----  " + instance_id)
                stop_service(instance_Ip)
                s3_delete_copy(s3_source_path,s3_destination_path)
                start_service(instance_Ip)
    except Exception as e:
        print(e)

start_stop_rage()


