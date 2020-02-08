#!/bin/sh
################### Restore Atlassian Application #######################
# Version: 1.1.0 August 28 2019
##################### Application Directories ###########################
# Set Directory of Install Application.
AP='/usr/local/atlassian/jira'

# Set Directory of Application Data
APD='/opt/atlassian/application-data/jira'

# Set Directory of Application Shared Data
APSD='/efs/atlassian/jira_qa'

# Set S3 Folder for this Application
F='s3://pvai-devops-dr/jiraqa'

# Set Application user name
USER="jira"

########################################################################

# Command
COMMAND="Usage: $0 [ Date of source data (YYYYMMDD) ]"


# Set Restore date at 1st argument.
if [ $# -ne 1 ]; then
    echo $COMMAND;
    exit 0;
fi

if expr "$1" : "[0-9]" >&/dev/null ;then
    RET="$1"
else
    echo "Command Error $COMMAND";
    exit 0;
fi

# Check This process is still running or not.i
P=`pgrep -f 'aws s3 sync'`
   
if [ ! -z $P ] ;then
   echo "======= Restoring process is still running.======="
   exit 0
fi

# Check Application Process is running.
declare -i X
X=`/bin/ps aux | /bin/grep ${AP} | /bin/grep -v grep | /bin/awk '{print $2}'`

if [ ${X} != 0 ]; then
    echo "The application is running now. Please stop it before you start this script."
    exit 0
fi

read -p "Please enter database endpoint: " DATABASE
read -p "Are you going to restore database from S3? [Y/n]: " S3DB 

# Start Restore from S3 to the requested directory 
echo "Start to restore application source and data.....";

# CREATE ATLASSIAN USER
U=`/bin/grep -e "^${USER}" /etc/passwd`

if [ -z ${U} ]; then
   /usr/sbin/adduser ${USER}
fi

# CREATE EFS 
if [ ${#APSD} -ne 0 ]; then
   echo "Restoring EFS directory..........";
   E=`aws s3 sync --delete \
   		--exclude='caches/*' \
                --exclude='node-status/*' \
                --exclude='analytics-logs/*' \
                                               $F/${RET}${APSD} ${APSD}`
   /bin/mkdir -p ${APSD}/caches
   /bin/mkdir -p ${APSD}/node-status
   /bin/mkdir -p ${APSD}/analytics-logs
   /bin/chown -R ${USER}.${USER} ${APSD}
fi

# CREATE APP
if [ ${#AP} -ne 0 ]; then
   echo "Restoring App directory..........";
   C=`aws s3 sync --delete \
		--exclude='logs/*' \
                                               $F/${RET}${AP} ${AP}`

   /bin/mkdir -p ${AP}/logs
   /bin/chown -R ${USER}.${USER} ${AP}
   /bin/chmod 755 ${AP}/jre/bin/*
   /bin/chmod 755 ${AP}/bin/*.sh
fi

# CREATE DATA
if [ ${#APD} -ne 0 ]; then
   echo "Restoring App Data directory.....";
   D=`aws s3 sync --delete \
                --exclude='caches/*' \
                --exclude='backup/*' \
                --exclude='log/*' \
                --exclude='analytics-logs/*' \
                                              $F/${RET}${APD} ${APD}`

   /bin/mkdir -p ${APD}/caches
   /bin/mkdir -p ${APD}/backup
   /bin/mkdir -p ${APD}/log
   /bin/mkdir -p ${APD}/analytics-logs
   /bin/chown -R ${USER}.${USER} ${APD}
   
fi

# RESTORE TO DATABASE
if [ ${S3DB} = "Y" ] || [ ${S3DB} = "y" ]; then
    DB=`aws s3 cp $F/${RET}/${USER}_qa.sql.gz ${HOME}/.`

    if [ -e ${HOME}/${USER}_qa.sql.gz ]; then
       /bin/gzip -cd ${HOME}/${USER}_qa.sql.gz | /usr/bin/psql -w -h $DATABASE -U pvai -d ${USER}_qa
       /bin/rm ${HOME}/${USER}_qa.sql.gz
    fi
fi

# UPDATE DATABASE CONFIG FILE
DBCONFIG="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<jira-database-config>
  <name>defaultDS</name>
  <delegator-name>default</delegator-name>
  <database-type>postgres72</database-type>
  <schema-name>public</schema-name>
  <jdbc-datasource>
    <url>jdbc:postgresql://${DATABASE}:5432/jira_qa</url>
    <driver-class>org.postgresql.Driver</driver-class>
    <username>pvai</username>
    <password>gopvai!!</password>
    <pool-min-size>20</pool-min-size>
    <pool-max-size>20</pool-max-size>
    <pool-max-wait>30000</pool-max-wait>
    <validation-query>select 1</validation-query>
    <min-evictable-idle-time-millis>60000</min-evictable-idle-time-millis>
    <time-between-eviction-runs-millis>300000</time-between-eviction-runs-millis>
    <pool-max-idle>20</pool-max-idle>
    <pool-remove-abandoned>true</pool-remove-abandoned>
    <pool-remove-abandoned-timeout>300</pool-remove-abandoned-timeout>
    <pool-test-on-borrow>false</pool-test-on-borrow>
    <pool-test-while-idle>true</pool-test-while-idle>
  </jdbc-datasource>
</jira-database-config>"

echo $DBCONFIG >${APD}/dbconfig.xml

echo "JIRA QA will start after 10 seconds. If you don't want to, please type cnt+C now."
sleep 10

/sbin/service jira start

exit 0;
