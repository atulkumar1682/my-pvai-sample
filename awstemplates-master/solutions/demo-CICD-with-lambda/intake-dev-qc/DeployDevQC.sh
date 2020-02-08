#!/bin/bash

#Get instanceId from metadata
instanceid=`wget -q -O - http://instance-data/latest/meta-data/instance-id`
echo $instanceid

#Run DeployIntakeDev and redirect output to a log file
echo "Deploy for Dev-QC env on $instanceid"

#Stop tomcat for Dev env
sudo service tomcat-daily stop

#Get ROOT.war from deployment bucket
aws s3 cp s3://pvai-verification-deployment/dev-qc/core-app/ROOT.war /usr/local/tomcat/PVAIDaily/webapps/

#sleep for 10 seconds
sleep 10

#start tomcat service
sudo service tomcat-daily start