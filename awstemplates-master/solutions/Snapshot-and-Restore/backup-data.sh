#!/bin/bash

# declare variables for s3 buckets
# input provided to the script
# first variable as primary bucket like "pvai-<env>-primary-data"
# second variable as backup bucket like "pvai-<env>-backup-data"

primary_bucket=$1
backup_bucket=$2
primary_region="us-east-1"

# sync s3 data from dr bucket to primary bucket
echo "starting sync data on `date` from s3://$primary_bucket to s3://$backup_bucket" > /tmp/backup_data

nohup aws s3 sync s3://$primary_bucket s3://$backup_bucket --region $primary_region >> /tmp/backup_data &