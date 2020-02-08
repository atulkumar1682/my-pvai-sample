#!/bin/bash

#Get instanceId from metadata
instanceid=`wget -q -O - http://instance-data/latest/meta-data/instance-id`
LOGFILE="/home/ec2-user/$instanceid.$(date +"%Y%m%d_%H%M%S").log"

#Run DeployIntakeDev and redirect output to a log file
echo "Deploy for Intake UI env on $instanceid" > $LOGFILE

#Stop tomcat for Intake UI env
sudo service tomcat-ui stop

#Get ROOT.war from deployment bucket
aws s3 cp s3://pvai-verification-deployment/intake-ui/core-app/ROOT.war /usr/local/tomcat/intakeui/webapps/

#sleep for 10 seconds
sleep 10

#start tomcat-ui service
sudo service tomcat-ui start

#Copy log file to S3 logs folder
aws s3 cp $LOGFILE s3://pvai-verification-deployment/logs/