# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
#
#     Copyright © Genpact 2018. All Rights Reserved.
#     Ltd trading as G in NYSE - Registered in US.
#     Registered Office - Canon's Court, 22 Victoria Street HAMILTON, HM 12, Bermuda.
# -*- coding: utf-8 -*-
# -------------------------------------------------------------------------------------------------
## author = 'Sandeep Kumar (Genpact Limited)'
## ver = '1.0.0'
## date = 02-Feb-2019
## Ref: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/curator.html
import boto3
from requests_aws4auth import AWS4Auth
from elasticsearch import Elasticsearch, RequestsHttpConnection
import curator
import os
import logging

#setup simple logging for INFO
logger = logging.getLogger()
logger.setLevel(logging.INFO)

#host = os.environ['ES_HOST'] # For example, search-my-domain.region.es.amazonaws.com
region = os.environ['REGION'] # For example, us-west-1
service = 'es'
index_days_count = os.environ['DAYS_COUNT'] # days to keep the indices
print index_days_count

credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

# Lambda execution starts here.
def lambda_handler(event, context):

    #create a client object for elasticsearch service
    client = boto3.client(service)
    # list all domains under current account
    list_domains = client.list_domain_names()
    print list_domains
    for item in list_domains['DomainNames']:
        es_domain = item['DomainName']
        print es_domain
        # get domain details and endpoint
        domain_details = client.describe_elasticsearch_domain(DomainName=es_domain)
        print domain_details
        domain_endpoint = domain_details['DomainStatus']['Endpoints']['vpc']
        print domain_endpoint
        # Build the Elasticsearch client.
        es = Elasticsearch(
            hosts = [{'host': domain_endpoint, 'port': 443}],
            http_auth = awsauth,
            use_ssl = True,
            verify_certs = True,
            connection_class = RequestsHttpConnection
        )
        try:
            index_list = curator.IndexList(es)
            print "index list" + index_list
            # Filters by age, anything with a time stamp older than 30 days in the index name.
            index_list.filter_by_age(source='name', direction='older', timestring='%Y.%m.%d', unit='days', unit_count=int(index_days_count))


            print("Found %s indices to delete" % len(index_list.indices))

            # If our filtered list contains any indices, delete them.
            if index_list.indices:
                curator.DeleteIndices(index_list).do_action()
        except curator.NoIndices:
            pass
            # Process empty index list here.