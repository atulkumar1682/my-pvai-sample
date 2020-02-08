#!/bin/bash

# declare variables for s3 buckets
# input provided to the script
primary_bucket=$1
primary_region="us-east-1"

# remove all s3 data from the bucket

echo "empty bucket on `date` from s3://$primary_bucket" > /tmp/empty_bucket

nohup aws s3 rm s3://$primary_bucket --recursive >> /tmp/empty_bucket &