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
# XCE_STACK_NAME -- ecr stack name to be different for each docker service eg:
# SERVICE -- value selected for xce service eg: xce-datastore
# REGION -- AWS Region where service to be deployed
#
############################################################################

#$AWS_ACCOUNT_NAME $REGION $ENV $AMI c5.xlarge $KEY $SERVICE 50059 /app/logs/ XXXXX 100 XXXXX $TAG

#input variables
AWS_ACCOUNT_NAME=$1
REGION=$2
ENV=$3
AMI=$4
EC2TYPE=$5
EC2KEY=$6
SERVICE=$7
SERVICE_PORT=${8}
INTERNAL_LOG_PATH=${9}
DB_PWD=${10}
MAX_WORKERS=${11}
SBP_BOX_KEY=${12}
PACKAGE_PATH=${13}
IMAGE_TAG=${14}
DESIRED_CAPACITY=${15}
CFT_S3_PATH=${16}


#Declare variables
XCE_STACK_NAME=pvai-$ENV-$SERVICE-service
S3_BUCKET=pvai-$AWS_ACCOUNT_NAME-$ENV-primary-data
DB_SERVICE_NAME=db$ENV
OUTPUT_FILE="output_$SERVICE.log"
ERROR_FILE="error_$SERVICE.log"
LOOP_COUNT=10
SLEEP_TIME=60
NOT_EXIST_ERROR="Stack with id $XCE_STACK_NAME does not exist"
CREATE_FAILED="ROLLBACK"
CREATE_ERROR="CREATE_FAILED"
UPDATE_COMP="UPDATE_COMPLETE"
CREATE_COMP="CREATE_COMPLETE"

#Check if stack is already there
aws cloudformation describe-stacks --stack-name "$XCE_STACK_NAME" --region $REGION > $OUTPUT_FILE 2> $ERROR_FILE
DESCRIBE_STACK=`grep "Stack with id $XCE_STACK_NAME does not exist" $ERROR_FILE`

if [ ! -s $ERROR_FILE ]
then

#Stack already exist we will update the stack
        echo "Stack already exist. Updating stack"
        aws cloudformation update-stack --stack-name $XCE_STACK_NAME --template-url $CFT_S3_PATH --parameters ParameterKey=EnvType,ParameterValue=$ENV ParameterKey=AMI,ParameterValue=$AMI ParameterKey=InstanceType,ParameterValue=$EC2TYPE ParameterKey=KeyName,ParameterValue=$EC2KEY ParameterKey=Service,ParameterValue=$SERVICE ParameterKey=ServicePort,ParameterValue=$SERVICE_PORT ParameterKey=DesiredCapacity,ParameterValue=$DESIRED_CAPACITY ParameterKey=InternalLogPath,ParameterValue=$INTERNAL_LOG_PATH ParameterKey=DBServiceName,ParameterValue=$DB_SERVICE_NAME ParameterKey=DBPwd,ParameterValue=$DB_PWD ParameterKey=MaxWorkers,ParameterValue=$MAX_WORKERS ParameterKey=SBPredBoxKey,ParameterValue=$SBP_BOX_KEY ParameterKey=S3Bucket,ParameterValue=$S3_BUCKET ParameterKey=PackagePath,ParameterValue=$PACKAGE_PATH ParameterKey=ImageTag,ParameterValue=$IMAGE_TAG --region $REGION >> $OUTPUT_FILE 2> $ERROR_FILE
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
        aws cloudformation create-stack --stack-name $XCE_STACK_NAME --template-url $CFT_S3_PATH --parameters ParameterKey=EnvType,ParameterValue=$ENV ParameterKey=AMI,ParameterValue=$AMI ParameterKey=InstanceType,ParameterValue=$EC2TYPE ParameterKey=KeyName,ParameterValue=$EC2KEY ParameterKey=Service,ParameterValue=$SERVICE ParameterKey=ServicePort,ParameterValue=$SERVICE_PORT ParameterKey=DesiredCapacity,ParameterValue=$DESIRED_CAPACITY ParameterKey=InternalLogPath,ParameterValue=$INTERNAL_LOG_PATH ParameterKey=DBServiceName,ParameterValue=$DB_SERVICE_NAME ParameterKey=DBPwd,ParameterValue=$DB_PWD ParameterKey=MaxWorkers,ParameterValue=$MAX_WORKERS ParameterKey=SBPredBoxKey,ParameterValue=$SBP_BOX_KEY ParameterKey=S3Bucket,ParameterValue=$S3_BUCKET ParameterKey=PackagePath,ParameterValue=$PACKAGE_PATH ParameterKey=ImageTag,ParameterValue=$IMAGE_TAG --region $REGION >> $OUTPUT_FILE 2> $ERROR_FILE
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