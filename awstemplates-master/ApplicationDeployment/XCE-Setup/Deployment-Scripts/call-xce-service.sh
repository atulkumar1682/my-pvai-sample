# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
#
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar' (Genpact Limited)'
## ver = '1.0.0'
## date = 21-Jul-2018

#!/bin/sh

############################################################################
# Parameters:
#
# SERVICE -- value selected for xce service eg: xce-datastore
# AWS_ACCOUNT_NAME -- AWS Account alias
# REGION -- AWS Region where service to be deployed
# ENV -- environment for deployment
# AMI -- AMI to be used to create servers
# TAG -- docker image tag
# DBPwd -- DB Password for XCE Schema
# SBPBoxKey -- SparkBeyond Prediction Box Key
############################################################################

#input variables
SERVICE=$1 # for ex: xce-datastore
AWS_ACCOUNT_NAME=$2 # for ex: pfizer
REGION=$3 # for ex: us-east-1
ENV=$4 # for ex: dev
AMI=$5 # for ex: ami-1234567
KEY=$6
PACKAGE_PATH=$7
TAG=$8 # for ex: 1.0.0
DBPwd=$9 
SBPBoxKey=${10}
DESIRED_CAPACITY=${11}
TEMPLATE_URL=${12}


if [[ $SERVICE = *"datastore"* ]]; then
  echo "Deploying datastore service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50051 /var/log/xce/ XXXXX 100 XXXXX  $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
elif [[ $SERVICE = *"learningstore"* ]]; then
  echo "Deploying learningstore service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50053 /var/log/xce/ $DBPwd 100 XXXXX $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
elif [[ $SERVICE = *"ocrextraction"* ]]; then
  echo "Deploying ocrextraction service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.large $KEY $SERVICE 50081 /var/log/gRPC XXXXX 100 XXXXX $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
elif [[ $SERVICE = *"sourcetype"* ]]; then
  echo "Deploying sourcetype service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50092 /var/log/ XXXXX 100 XXXXX $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
elif [[ $SERVICE = *"sparkbeyond"* ]]; then
  echo "Deploying sparkbeyond service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.large $KEY $SERVICE 50091 /var/log/xce/ $DBPwd 100 $SBPBoxKey $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
elif [[ $SERVICE = *"ensemble"* ]]; then
  echo "Deploying ensemble service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50078 /var/log/xce/ $DBPwd 100 XXXXX $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
elif [[ $SERVICE = *"datatransmit"* ]]; then
  echo "Deploying datatransmit service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50055 /var/log/xce/ $DBPwd 100 XXXXX $PACKAGE_PATH $TAG $DESIRED_CAPACITY  $TEMPLATE_URL
elif [[ $SERVICE = *"orchestration"* ]]; then
  echo "Deploying orchestration service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50061 /xce/logs/ XXXXX 100 XXXXX $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
elif [[ $SERVICE = *"loadbalancer"* ]]; then
  echo "Deploying loadbalancer service!"
  sh ./xce-deployment.sh $AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50059 /app/logs/ XXXXX 100 XXXXX $PACKAGE_PATH $TAG $DESIRED_CAPACITY $TEMPLATE_URL
else
  echo "$SERVICE not found"
fi