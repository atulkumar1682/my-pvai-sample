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
from datetime import datetime
from requests_aws4auth import AWS4Auth
from elasticsearch import Elasticsearch, RequestsHttpConnection
import logging
import curator
import os

# Adding a logger isn't strictly required, but helps with understanding Curator's requests and debugging.
logger = logging.getLogger('curator')
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.INFO)

host = os.environ['ES_HOST'] # For example, search-my-domain.region.es.amazonaws.com
region = os.environ['REGION'] # For example, us-west-1
service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

now = datetime.now()
# Clunky, but this approach keeps colons out of the URL.
date_string = '.'.join((str(now.year), str(now.month), str(now.day)))

snapshot_name = os.environ['SNAPSHOT_PREFIX'] + "-" + date_string
repository_name = os.environ['ES_REPO']

# Lambda execution starts here.
def lambda_handler(event, context):

    # Build the Elasticsearch client.
    es = Elasticsearch(
        hosts = [{'host': host, 'port': 443}],
        http_auth = awsauth,
        use_ssl = True,
        verify_certs = True,
        connection_class = RequestsHttpConnection,
        timeout = 120 # Deleting snapshots can take a while, so keep the connection open for long enough to get a response.
    )

    try:
        # Get all snapshots in the repository.
        snapshot_list = curator.SnapshotList(es, repository=repository_name)
        
        print(snapshot_list)

        # Filter by age, any snapshot older than two weeks.
        # snapshot_list.filter_by_age(source='creation_date', direction='older', unit='weeks', unit_count=2)

        # Delete the old snapshots.
        #curator.DeleteSnapshots(snapshot_list, retry_interval=30, retry_count=3).do_action()
    except (curator.exceptions.SnapshotInProgress, curator.exceptions.NoSnapshots, curator.exceptions.FailedExecution) as e:
        print(e)

    # Split into two try blocks. We still want to try and take a snapshot if deletion failed.
    try:
        # Get the list of indices.
        # You can filter this list if you didn't want to snapshot all indices.
        index_list = curator.IndexList(es)

        # Take a new snapshot. This operation can take a while, so we don't want to wait for it to complete.
        curator.Snapshot(index_list, repository=repository_name, name=snapshot_name, wait_for_completion=True).do_action()
    except (curator.exceptions.SnapshotInProgress, curator.exceptions.FailedExecution) as e:
        print(e)