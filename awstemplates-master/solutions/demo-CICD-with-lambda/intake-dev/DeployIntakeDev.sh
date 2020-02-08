#!/bin/bash

#Get instanceId from metadata
instanceid=`wget -q -O - http://instance-data/latest/meta-data/instance-id`
LOGFILE="/home/ec2-user/$instanceid.$(date +"%Y%m%d_%H%M%S").log"

#Run DeployIntakeDev and redirect output to a log file
echo "Deploy for Dev env on $instanceid" > $LOGFILE

#Stop tomcat for Dev env
sudo service tomcat stop

#Get ROOT.war from deployment bucket
aws s3 cp s3://pvai-verification-deployment/dev/core-app/ROOT.war /usr/local/tomcat/PVAI/webapps/

#sleep for 10 seconds
sleep 10

#start tomcat service
sudo service tomcat start

#Copy log file to S3 logs folder
aws s3 cp $LOGFILE s3://pvai-verification-deployment/logs/