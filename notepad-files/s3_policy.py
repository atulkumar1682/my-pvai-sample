import boto3
import json

def lambda_handler(event, context):
    # TODO implement

    #session = session.Session()
    #credentials = session.get_credentials()

    #aws_key = credentials.access_key
    #aws_secret_key= credentials.secret_key
    #aws_region = session.region_name or 'us-east-1'
    #aws_token = credentials.token
    s3_client = boto3.client('s3')

    s3_resource = boto3.resource('s3')
    bucket_list=[]
    list_of_buckets = s3_client.list_buckets()

    for bucket_name_obj in list_of_buckets['Buckets']:
        bucket_list.append(bucket_name_obj['Name'])

    for bucket_name in bucket_list:
        print (bucket_name)
        try:
            existing_policy = s3_client.get_bucket_policy(
                Bucket=bucket_name
            )

        except:
            pass
            existing_policy = ''

        if existing_policy == '':
            print ("Policy does not exist")
            put_bucket_policy = s3_client.put_bucket_policy(
                Bucket = bucket_name,
                ConfirmRemoveSelfBucketAccess = False,
                Policy = '''{
				    "Version": "2012-10-17",
				    "Statement": [
				        {
				            "Sid": "PrivateAclPolicy",
				            "Effect": "Deny",
				            "Principal": {
				                "AWS": "*"
				            },
				            "Action": [
				                "s3:PutObject",
				                "s3:PutObjectAcl"
				            ],
				            "Resource": "arn:aws:s3:::'''+bucket_name+'''/*",
				            "Condition": {
				                "StringNotEquals": {
				                    "s3:x-amz-acl": "private"
				                }
				            }
				        }
				    ]
				}'''
				)
            print (put_bucket_policy)
        else:
            print ("Policy exists")
