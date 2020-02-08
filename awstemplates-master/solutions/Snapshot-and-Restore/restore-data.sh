#!/bin/bash

# declare variables for s3 buckets
# input provided to the script
# first variable as backup bucket like "pvai-<env>-backup-data"
# second variable as primary bucket like "pvai-<env>-primary-data"

backup_bucket=$1
primary_bucket=$2
primary_region="us-east-1"

# sync s3 data from dr bucket to primary bucket

echo "starting sync data on `date` from s3://$backup_bucket to s3://$primary_bucket" > /tmp/restore_data

nohup aws s3 sync s3://$backup_bucket s3://$primary_bucket --region $primary_region >> /tmp/restore_data &