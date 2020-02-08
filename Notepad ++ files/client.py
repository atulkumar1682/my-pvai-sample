from __future__ import print_function

import grpc
from services_impl import common_model_pb2
from services_impl import sparkbeyond_service_pb2_grpc
from services_impl import sparkbeyond_service_pb2
from services_impl import learningstore_model_pb2
from services_impl import extraction_model_pb2
from services_impl import datastore_service_pb2_grpc
from services_impl import datastore_service_pb2
import pandas as pd
import sys
import os
import argparse
from sklearn.externals import joblib
import cPickle
import re
import json
import settings as config
import cx_Oracle
from hashlib import md5
from math import ceil
import base64
import settings
#datastore_conn_str=os.environ['datastore_conn_str']
#learningstore_conn_str=os.environ['learningstore_conn_str']
#sparkbeyond_conn_str = '10.10.18.127:50091'
sparkbeyond_conn_str = os.environ['SPARKBEYOND_ENDPOINT']
#sparkbeyond_conn_str = '10.10.18.127:5001'
#sparkbeyond_conn_str = 'xce-sb-dummy-nlb-cc8f620102a8db20.elb.us-east-1.amazona                                                                                        ws.com:50091'
#sparkbeyond_conn_str = '127.0.0.1:5001'
#sparkbeyond_conn_str = '127.0.0.1:5000'
#datastore_conn_str = 'nlb.dev.pvai.com:50051'
#datastore_conn_str = 'xce-datastore-nlb-3e68cd876219ddfd.elb.us-east-1.amazonaw                                                                                        s.com:50051'
datastore_conn_str = os.environ['DATA_STORE_ENDPOINT']
#datastore_conn_str = '127.0.0.1:50051'
client_id = "SBRun1"
module_id = "com.pvai.xce.SB"
hashdict = {}

def get_conn():
        ORA_DB_HOST = config.db_host
        ORA_DB_PORT = config.db_port
        ORA_DB_USER = config.db_username
        ORA_DB_PASSWORD = config.db_password
        ORA_SERVICE_NAME = config.db_servicename
        try:
            dsnStr = cx_Oracle.makedsn(ORA_DB_HOST, ORA_DB_PORT, sid=ORA_SERVICE                                                                                        _NAME)
            connection = cx_Oracle.connect(ORA_DB_USER, ORA_DB_PASSWORD, dsnStr)
            return connection
        except Exception as e:
            print (e, e.message)
            print("Unable to connect to the database!")

def putModelsLocal(configpath, version, update=False):
    try:
        delModels(version)
        print("\nExecuting putLearnings .................................")
        config_file = json.load(open(configpath))
        cntr = 1
        modelList = []
        connection = get_conn()
        cursor = connection.cursor()
        print("Insert learning:")
        statement = 'insert into learning (client_id, version, module_id, is_act                                                                                        ive, is_client_specific, source_type) values (:1, :2, :3, :4, :5, :6)'
        cursor.execute(statement, (str(client_id), str(version), str(module_id),                                                                                         '1', str(""), str("")))
        cursor.execute('select LEARNING_SEQ.currval from dual')
        seq = cursor.fetchone()
        l_id = seq[0]
        print("l_id:", l_id)
        print("l_id:", l_id)
        for sourcetype in config_file:
            for classificationtype in (config_file[sourcetype]):
                print(sourcetype, classificationtype)
                for model in config_file[sourcetype][classificationtype]:
                    projectfile = model['projectfile']
                    project_name, revision = os.path.basename(projectfile).split                                                                                        ('.')[0].rsplit('_', 1)
                    if not projectfile.endswith(('.zip', '.ZIP')):
                        print('No zip files present for sourcetype(%s), classifi                                                                                        cationtype(%s)' % (os.path.basename(sourcetype), os.path.basename(classification                                                                                        type)))
                        continue
                    var = cursor.var(cx_Oracle.CLOB)
                    var.setvalue(0, '')    # write a small value first to force                                                                                         the temporary LOB to be created
                    lob = var.getvalue()    # get the temporary LOB
                    model_file = open(projectfile, "rb")
                    buf = model_file.read()
                    buf = base64.b64encode(buf)
                    hashdict[project_name] = [md5(buf).hexdigest()]
                    bufSize = len(buf)
                    blocksize = 1024 * 1024 * 256
                    l = float(bufSize) / blocksize
                    l = int(ceil(l))
                    k = 0
                    for i in range(1, l+1):
                        #print(i, lob.size())
                        #print("k:\t%s\tk+blocksize:\t%s"% (k, k+blocksize))
                        lob.write(buf[k:k+blocksize],k + 1)  # write in portions                                                                                         < 512 MB
                        k = k + blocksize

                    id_ = sourcetype + "-" + classificationtype + "-" + project_                                                                                        name
                    k1 = learningstore_model_pb2.Kwargs(key='classificationtype'                                                                                        ,value=classificationtype)
                    k2 = learningstore_model_pb2.Kwargs(key='sourcetype',value=s                                                                                        ourcetype)
                    k3 = learningstore_model_pb2.Kwargs(key='revision',value=rev                                                                                        ision)
                    k4 = learningstore_model_pb2.Kwargs(key='probabilitycolumn',                                                                                        value=model['probabilitycolumn'])
                    str_param_list = []
                    for param in [k1, k2, k3, k4]:
                        try:
                            str_param = param.SerializeToString()
                            str_param_list.append(str_param)
                        except Exception, err:
                            print(err)

                    ser_str_param_list = cPickle.dumps(str_param_list)
                    ser_str_feature_list = ""
                    statement = 'insert into learning_model (learning_id, model_                                                                                        id, name, object, features, params) values (:1, :2, :3, :4, :5, :6)'
                    print(l_id, str(id_), str(project_name), var)
                    #print("insert model:")
                    cursor.execute(statement, (l_id, str(id_), str(project_name)                                                                                        , var, ser_str_feature_list, ser_str_param_list))
                    #connection.close()
                    print('Done')
        connection.commit()
        connection.close()

    except Exception, err:
        print(err)

def putModels(configpath, version, update=False):
    """
    Sample code to put regex/fuzzy Rules on SourceTypeClassicationService
    It read csv file and populate sourcetype_service_pb2.Rules object
    function: put_sourcetype_rules is used to put learning in learning store
    """
    try:
        print("\nExecuting putLearnings .................................")
        config_file = json.load(open(configpath))
        cntr = 1
        modelList = []
        for sourcetype in config_file:
            for classificationtype in (config_file[sourcetype]):
                print(sourcetype, classificationtype)
                for model in config_file[sourcetype][classificationtype]:
                    projectfile = model['projectfile']
                    project_name, revision = os.path.basename(projectfile).split                                                                                        ('.')[0].rsplit('_', 1)
                    if not projectfile.endswith(('.zip', '.ZIP')):
                        print('No zip files present for sourcetype(%s), classifi                                                                                        cationtype(%s)' % (os.path.basename(sourcetype), os.path.basename(classification                                                                                        type)))
                        continue
                    with open(projectfile, 'rb') as f:
                        sb_artifact = f.read()
                        print(len(sb_artifact))
                        cntr += 1
                        id_ = sourcetype + "-" + classificationtype + "-" + proj                                                                                        ect_name
                        k1 = learningstore_model_pb2.Kwargs(key='classificationt                                                                                        ype',value=classificationtype)
                        k2 = learningstore_model_pb2.Kwargs(key='sourcetype',val                                                                                        ue=sourcetype)
                        k3 = learningstore_model_pb2.Kwargs(key='revision',value                                                                                        =revision)
                        k4 = learningstore_model_pb2.Kwargs(key='probabilitycolu                                                                                        mn',value=model['probabilitycolumn'])
                        m = learningstore_model_pb2.Model(id=id_, name=project_n                                                                                        ame, object=base64.b64encode(sb_artifact), params=[k1, k2, k3, k4])
                        #m = learningstore_model_pb2.Model(id=id_, name=project_                                                                                        name, object='abc', params=[k1, k2, k3, k4])
                        modelList.append(m)
        learningObj = learningstore_model_pb2.Learning(version = version, model=                                                                                        modelList)
        #channel = grpc.insecure_channel(sparkbeyond_conn_str)
        channel = grpc.insecure_channel(sparkbeyond_conn_str, options=[('grpc.ma                                                                                        x_send_message_length', -1),
                                   ('grpc.max_receive_message_length', -1)])

        stub = sparkbeyond_service_pb2_grpc.SparkBeyondClassicationServiceStub(c                                                                                        hannel)
        if not update:
            responses = stub.putLearnings(learningObj)
        else:
            responses = stub.updateLearnings(learningObj)
        for response in responses:
            if response.status_code == "202":
                print("Received ack")
            if response.status_code == "201":
                print("Completed")
                print(str(response))
            if response.status_code == config.FAILURE_CODE:
                print("Failure")
                print(str(response))

    except Exception, err:
        print(err)

def delModels(version):
    """
    Delete models from learning store
    """
    try:
        print("\nExecuting delLearnings .................................")
        learningObj = learningstore_model_pb2.Learning(version = version)
        #channel = grpc.insecure_channel(sparkbeyond_conn_str)
        channel = grpc.insecure_channel(sparkbeyond_conn_str, options=[('grpc.ma                                                                                        x_send_message_length', -1),
                                   ('grpc.max_receive_message_length', -1)])

        stub = sparkbeyond_service_pb2_grpc.SparkBeyondClassicationServiceStub(c                                                                                        hannel)
        for response in stub.delLearnings(learningObj):
            if response.status_code == "202":
                print("Received ack")
            if response.status_code == "201":
                print("Completed")
                print(str(response))
            if response.status_code == config.FAILURE_CODE:
                print("Failure")
                print(str(response))
    except Exception, err:
        print(err)

def retrieveModels(version):
    try:
        """
        sample code to recieve models
        """
        print("\nExecuting getLearnings .................................")
        channel = grpc.insecure_channel(sparkbeyond_conn_str, options=[('grpc.ma                                                                                        x_send_message_length', -1),
                                   ('grpc.max_receive_message_length', -1)])
        stub = sparkbeyond_service_pb2_grpc.SparkBeyondClassicationServiceStub(c                                                                                        hannel)
        versionObj = sparkbeyond_service_pb2.Version(version=version)
        cntr = 0
        for response in stub.getLearnings(versionObj):
            for model in response.model:
                cntr += 1
                print('Model >>>>>>>>>>>>>>>>>>>>>>>>> ')
                object_ = base64.b64encode(model.object)
                if model.name in hashdict.keys():
                    hashdict[model.name].append(md5(object_).hexdigest())
                print ('Name: ', model.name, '\nParams:', re.sub('[^0-9a-zA-Z,:_                                                                                        " ]+', '', str(model.params)), md5(str(object_)).hexdigest(), 'Size:', len(objec                                                                                        t_))
        #print ('Total Models:', len(response.models))
        print("Total Models;", cntr)
    except Exception, err:
        print(err)

def pushLearnings(clientId, clientName, moduleId, version):
    """
    sample code for pushing different client, version learning to be used
    """
    print("\nPushing Learnings .................................")
    channel = grpc.insecure_channel(sparkbeyond_conn_str)
    stub = sparkbeyond_service_pb2_grpc.SparkBeyondClassicationServiceStub(chann                                                                                        el)
    client = learningstore_model_pb2.Client(name=clientName, id=clientId)
    learningObj = learningstore_model_pb2.Learning(client=client, module_id=modu                                                                                        leId, version=version)
    for response in stub.pushLearnings(learningObj):
        if response.status_code == "202":
            print("Received ack")
        if response.status_code == "201":
            print("Completed")
            print(str(response))
        if response.status_code == config.FAILURE_CODE:
            print("Failure")
            print(str(response))


def classify(docset_id, run_id):
    """
    sample code to classify
    """
    print("\nClassifying .................................")
    channel = grpc.insecure_channel(sparkbeyond_conn_str)
    stub = sparkbeyond_service_pb2_grpc.SparkBeyondClassicationServiceStub(chann                                                                                        el)

    doc_set = common_model_pb2.DocSet()
    doc_set.docset_id = docset_id
    doc_set.run_id = run_id
    for response in stub.classify(doc_set):
        if response.status_code == "202":
            print("Received ack")
        if response.status_code == "201":
            print("Received data from getClassifications")
            classification = response.classification
            if  classification.clsVal.CASE_NO_CASE.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t CASE_NO_CASE: ', classification.clsVal.CASE_NO_CASE.v                                                                                        alue, classification.clsVal.CASE_NO_CASE.confidence_score)
            if  classification.clsVal.INITIAL_FOLLOWUP.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t INITIAL_FOLLOWUP:', classification.clsVal.INITIAL_FOL                                                                                        LOWUP.value, classification.clsVal.INITIAL_FOLLOWUP.confidence_score)
            if  classification.clsVal.VALID_INVALID.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t VALID_INVALID:', classification.clsVal.VALID_INVALID.                                                                                        value, classification.clsVal.VALID_INVALID.confidence_score)
            if  classification.clsVal.DEATH_LIFE_THREATENING.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t DEATH_LIFE_THREATENING:', classification.clsVal.DEATH                                                                                        _LIFE_THREATENING.value, classification.clsVal.DEATH_LIFE_THREATENING.confidence                                                                                        _score)
            if  classification.clsVal.DEATH.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t DEATH:', classification.clsVal.DEATH.value, classific                                                                                        ation.clsVal.DEATH.confidence_score)
            if  classification.clsVal.LIFE_THREATENING.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t LIFE_THREATENING:', classification.clsVal.LIFE_THREAT                                                                                        ENING.value, classification.clsVal.LIFE_THREATENING.confidence_score)
            if  classification.clsVal.HOSPITALIZATION.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t HOSPITALIZATION:', classification.clsVal.HOSPITALIZAT                                                                                        ION.value, classification.clsVal.HOSPITALIZATION.confidence_score)
            if  classification.clsVal.MEDICALLY_SIGNIFICANT.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t MEDICALLY_SIGNIFICANT:', classification.clsVal.MEDICA                                                                                        LLY_SIGNIFICANT.value, classification.clsVal.MEDICALLY_SIGNIFICANT.confidence_sc                                                                                        ore)
            if  classification.clsVal.CONGENITAL_ABNORMALITY.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t CONGENITAL_ABNORMALITY:', classification.clsVal.CONGE                                                                                        NITAL_ABNORMALITY.value, classification.clsVal.CONGENITAL_ABNORMALITY.confidence                                                                                        _score)
            if  classification.clsVal.DISABILITY.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t DISABILITY:', classification.clsVal.DISABILITY.value,                                                                                         classification.clsVal.DISABILITY.confidence_score)
            if  classification.clsVal.REQUIRED_INTERVENTION.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t REQUIRED_INTERVENTION:', classification.clsVal.REQUIR                                                                                        ED_INTERVENTION.value, classification.clsVal.REQUIRED_INTERVENTION.confidence_sc                                                                                        ore)
            if  classification.clsVal.SOURCE_TYPE.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t SOURCE_TYPE:', classification.clsVal.SOURCE_TYPE.valu                                                                                        e, classification.clsVal.SOURCE_TYPE.confidence_score)
            if  classification.clsVal.IS_MULTI_PATIENT.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t IS_MULTI_PATIENT:', classification.clsVal.IS_MULTI_PA                                                                                        TIENT.value, classification.clsVal.IS_MULTI_PATIENT.confidence_score)
            if  classification.clsVal.SERIOUSNESS.confidence_score:
                print (classification.module_id, 'document_id:' + classification                                                                                        .document_id, classification.model_id, end='')
                print ('\t SERIOUSNESS:', classification.clsVal.SERIOUSNESS.valu                                                                                        e, classification.clsVal.SERIOUSNESS.confidence_score)

        if response.status_code == config.FAILURE_CODE:
            print("Failure")
            print(str(response))

    print("Validating data store for classifications")
    channel = grpc.insecure_channel(datastore_conn_str)
    stub = datastore_service_pb2_grpc.DataStoreServiceStub(channel)
    response = stub.getClassifications(datastore_service_pb2.QueryClassification                                                                                        s(docset_id = docset_id))

    for cntr, classification in enumerate(response.ClassificationStream):
        if  classification.clsVal.CASE_NO_CASE.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t CASE_NO_CASE: ', classification.clsVal.CASE_NO_CASE.value                                                                                        , classification.clsVal.CASE_NO_CASE.confidence_score)
        if  classification.clsVal.INITIAL_FOLLOWUP.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t INITIAL_FOLLOWUP:', classification.clsVal.INITIAL_FOLLOWU                                                                                        P.value, classification.clsVal.INITIAL_FOLLOWUP.confidence_score)
        if  classification.clsVal.VALID_INVALID.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t VALID_INVALID:', classification.clsVal.VALID_INVALID.valu                                                                                        e, classification.clsVal.VALID_INVALID.confidence_score)
        if  classification.clsVal.DEATH_LIFE_THREATENING.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t DEATH_LIFE_THREATENING:', classification.clsVal.DEATH_LIF                                                                                        E_THREATENING.value, classification.clsVal.DEATH_LIFE_THREATENING.confidence_sco                                                                                        re)
        if  classification.clsVal.DEATH.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t DEATH:', classification.clsVal.DEATH.value, classificatio                                                                                        n.clsVal.DEATH.confidence_score)
        if  classification.clsVal.LIFE_THREATENING.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t LIFE_THREATENING:', classification.clsVal.LIFE_THREATENIN                                                                                        G.value, classification.clsVal.LIFE_THREATENING.confidence_score)
        if  classification.clsVal.HOSPITALIZATION.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t HOSPITALIZATION:', classification.clsVal.HOSPITALIZATION.                                                                                        value, classification.clsVal.HOSPITALIZATION.confidence_score)
        if  classification.clsVal.MEDICALLY_SIGNIFICANT.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t MEDICALLY_SIGNIFICANT:', classification.clsVal.MEDICALLY_                                                                                        SIGNIFICANT.value, classification.clsVal.MEDICALLY_SIGNIFICANT.confidence_score)
        if  classification.clsVal.CONGENITAL_ABNORMALITY.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t CONGENITAL_ABNORMALITY:', classification.clsVal.CONGENITA                                                                                        L_ABNORMALITY.value, classification.clsVal.CONGENITAL_ABNORMALITY.confidence_sco                                                                                        re)
        if  classification.clsVal.DISABILITY.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t DISABILITY:', classification.clsVal.DISABILITY.value, cla                                                                                        ssification.clsVal.DISABILITY.confidence_score)
        if  classification.clsVal.REQUIRED_INTERVENTION.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t REQUIRED_INTERVENTION:', classification.clsVal.REQUIRED_I                                                                                        NTERVENTION.value, classification.clsVal.REQUIRED_INTERVENTION.confidence_score)
        if  classification.clsVal.SOURCE_TYPE.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t SOURCE_TYPE:', classification.clsVal.SOURCE_TYPE.value, c                                                                                        lassification.clsVal.SOURCE_TYPE.confidence_score)
        if  classification.clsVal.IS_MULTI_PATIENT.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t IS_MULTI_PATIENT:', classification.clsVal.IS_MULTI_PATIEN                                                                                        T.value, classification.clsVal.IS_MULTI_PATIENT.confidence_score)
        if  classification.clsVal.SERIOUSNESS.confidence_score:
            print (classification.module_id, 'document_id:' + classification.doc                                                                                        ument_id, classification.model_id, end='')
            print ('\t SERIOUSNESS:', classification.clsVal.SERIOUSNESS.value, c                                                                                        lassification.clsVal.SERIOUSNESS.confidence_score)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Client file for sparkbeyond cl                                                                                        assification')
    parser.add_argument('--docset_id', help='',
                        required=True)
    parser.add_argument('--version', help='Version of models to use from learnin                                                                                        g store',
                        required=True)
    parser.add_argument('--configpath', help='Model directort to be used',
                        required=True)
    #parser.add_argument('--version', help='Mention version ID - 1.0  [Note it i                                                                                        s required to initially pull learning from learning store]',
    #                    required=True)
    args = parser.parse_args()
    docset_id = args.docset_id
    version = args.version
    configpath = args.configpath
    run_id = "PROD"
    clientId, clientName, moduleId = 'SBRun1', 'SB', 'com.pvai.xce.SB'
    #putModels(configpath, version)
    #putModels(configpath, version, update=True)
    #while True:
    delModels(version)
    putModelsLocal(configpath, version, update=True)
    pushLearnings(clientId, clientName, moduleId, version)
    retrieveModels(version)
    #print(hashdict)
    docset_id = "driver-139927048"
    classify(docset_id, run_id)