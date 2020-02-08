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
############################################################################

#input variables
SERVICE=$1 # for ex: xce-web
AWS_ACCOUNT_NAME=$2 # for ex: product
REGION=$3 # for ex: us-east-1
ENV=$4 # for ex: dev
AMI=$5 # for ex: ami-1234567
EC2KEY=$6
PACKAGE_PATH=$7
IMAGE_TAG=$8 # for ex: 1.0.0
WEBAPP_SECRET_KEY=${9}
DESIRED_CAPACITY=${10}
CFT_S3_PATH=${11}


if [[ $SERVICE = *"web"* ]]; then
  echo "Deploying xce-web service!"
  #Declare variables
  XCE_STACK_NAME=pvai-$ENV-$SERVICE-service
  OUTPUT_FILE="output_$SERVICE.log"
  ERROR_FILE="error_$SERVICE.log"
  LOOP_COUNT=10
  SLEEP_TIME=60
  NOT_EXIST_ERROR="Stack with id $XCE_STACK_NAME does not exist"
  CREATE_FAILED="ROLLBACK"
  CREATE_ERROR="CREATE_FAILED"
  UPDATE_COMP="UPDATE_COMPLETE"
  CREATE_COMP="CREATE_COMPLETE"
  EC2TYPE="c5.xlarge"

  #Check if stack is already there
  aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION > $OUTPUT_FILE 2> $ERROR_FILE
  DESCRIBE_STACK=`grep "Stack with id $XCE_STACK_NAME does not exist" $ERROR_FILE`
  
    if [ ! -s $ERROR_FILE ]
	then

	#Stack already exist we will update the stack
			echo "Stack already exist. Updating stack"
			aws cloudformation update-stack --stack-name $XCE_STACK_NAME --template-url $CFT_S3_PATH --parameters ParameterKey=EnvType,ParameterValue=$ENV ParameterKey=AMI,ParameterValue=$AMI ParameterKey=InstanceType,ParameterValue=$EC2TYPE ParameterKey=KeyName,ParameterValue=$EC2KEY ParameterKey=Service,ParameterValue=$SERVICE ParameterKey=DesiredCapacity,ParameterValue=$DESIRED_CAPACITY ParameterKey=WebAppSecretKey,ParameterValue=$WEBAPP_SECRET_KEY ParameterKey=PackagePath,ParameterValue=$PACKAGE_PATH ParameterKey=ImageTag,ParameterValue=$IMAGE_TAG --region $REGION >> $OUTPUT_FILE 2> $ERROR_FILE
			if [ -s $ERROR_FILE ]
			then
					echo "Below error occurred while updating"
					cat $ERROR_FILE
					exit 1 #check
			else
			#no error, we will proceed with the Stack check
					echo "Cloud formation stack is Getting updated, Please wait"
					count=1;
					echo $count
					while [[ $count -le $LOOP_COUNT ]] ;
					do
							echo $count: checking for stack;
							if [ -s $ERROR_FILE ]
							then
									echo "An error occurred while updating or it is taking too much time"
									cat $ERROR_FILE
									exit 1 #check
							else
									echo "Stack is updating Please wait"
									DESCRIBE_STACK=`aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION 2> $ERROR_FILE | grep "StackStatus"`
									echo "$DESCRIBE_STACK: checking status"
									if [[ "$DESCRIBE_STACK" == *"$CREATE_FAILED"* ]]
									then
											echo "Unable to Create stack encountered ROLLBACK ERROR"
											aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION| grep "StackStatusReason"
											exit 1
									elif [[ "$DESCRIBE_STACK" == *"$UPDATE_COMP"* ]]
									then
											echo "Successfully Updated the Stack with the below details"
											aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION
											exit 0
									fi
									sleep $SLEEP_TIME
							fi
					count=$((count+1));
					done;
			fi
	elif [[ "$DESCRIBE_STACK" == *"$NOT_EXIST_ERROR"* ]]
	then
	#no Stack exist will create a New stack
			echo "No stack exists, will create a stack"
			aws cloudformation create-stack --stack-name $XCE_STACK_NAME --template-url $CFT_S3_PATH --parameters ParameterKey=EnvType,ParameterValue=$ENV ParameterKey=AMI,ParameterValue=$AMI ParameterKey=InstanceType,ParameterValue=$EC2TYPE ParameterKey=KeyName,ParameterValue=$EC2KEY ParameterKey=Service,ParameterValue=$SERVICE ParameterKey=DesiredCapacity,ParameterValue=$DESIRED_CAPACITY ParameterKey=WebAppSecretKey,ParameterValue=$WEBAPP_SECRET_KEY ParameterKey=PackagePath,ParameterValue=$PACKAGE_PATH ParameterKey=ImageTag,ParameterValue=$IMAGE_TAG --region $REGION >> $OUTPUT_FILE 2> $ERROR_FILE
			count=1;
			echo $count
			while [[ $count -le $LOOP_COUNT ]] ;
					do
					echo $count: checking for stack;
					if [ -s $ERROR_FILE ]
							then
							echo "An error occurred"
							cat $ERROR_FILE
							exit 1 #check
					else
							echo "Creating Stack..... Please wait...... "
							DESCRIBE_STACK=`aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION 2> $ERROR_FILE | grep "StackStatus"`
							echo "$DESCRIBE_STACK"
							if [[ "$DESCRIBE_STACK" == *"$CREATE_FAILED"* ]] || [[ "$DESCRIBE_STACK" == *"$CREATE_ERROR"* ]]
									then
									echo "Unable to Create stack encountered ROLLBACK ERROR"
									aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION| grep "StackStatusReason"
									exit 1
							elif [[ "$DESCRIBE_STACK" == *"$CREATE_COMP"* ]]
									then
									echo "Successfully Updated the Stack with the below details"
									aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION
									exit 0
							fi
							cat $ERROR_FILE
							sleep $SLEEP_TIME
					fi
					count=$((count+1));
			done;
	else
			echo "ERROR"
			cat $ERROR_FILE
			exit 1
	fi
else
  echo "$SERVICE not found - Only for XCE-WEB service"
fi