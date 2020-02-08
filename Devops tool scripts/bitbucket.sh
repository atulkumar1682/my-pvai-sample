#!/bin/sh
################### Restore Atlassian Application #######################
# Version: 1.1.0 September 4 2019
##################### Application Directories ###########################
# Set Directory of Install Application.
AP='/usr/local/atlassian/bitbucket'
APL='BITBUCKET'

# Set Directory of Application Data
APD='/opt/atlassian/application-data/bitbucket'

# Set Directory of Application Shared Data
APSD='/efs/atlassian/bitbucket'

# Set S3 Folder for this Application
F='s3://pvai-devops-dr/bitbucket'

# Set Application user name
USER="atlbitbucket"

DBNAME="bitbucket"

# Get IP address of this server.
IPADDRESS=`/sbin/ip -f inet -o addr show "eth0" | cut -d\  -f 7 | cut -d/ -f 1`
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
X=`/bin/ps aux | /bin/grep ${APL} | /bin/grep -v grep | /bin/awk '{print $2}'`

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
   /usr/bin/passwd ${USER}
fi

# CREATE EFS
if [ ${#APSD} -ne 0 ]; then
   echo "Restoring EFS directory..........";
   E=`aws s3 sync --delete \
                                               $F/${RET}${APSD} ${APSD}`
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
                --exclude='log/*' \
                --exclude='logs/*' \
                --exclude='tmp/*' \
                --exclude='analytics-logs/*' \
                                              $F/${RET}${APD} ${APD}`

   /bin/mkdir -p ${APD}/log
   /bin/mkdir -p ${APD}/logs
   /bin/mkdir -p ${APD}/tmp
   /bin/mkdir -p ${APD}/analytics-logs
   /bin/ln -s ${APSD}/shared ${APD}/shared
   /bin/chown -R ${USER}.${USER} ${APD}
fi

# RESTORE TO DATABASE
if [ ${S3DB} = "Y" ] || [ ${S3DB} = "y" ]; then
    DB=`aws s3 cp $F/${RET}/${USER}.sql.gz ${HOME}/.`

    if [ -e ${HOME}/${USER}.sql.gz ]; then
       /bin/gzip -cd ${HOME}/${USER}.sql.gz | /usr/bin/psql -w -h $DATABASE -U pvai -d ${DBNAME}
       /bin/rm ${HOME}/${USER}.sql.gz
    fi
fi

# UPDATE DATABASE CONFIG FILE

{
echo "jdbc.driver=org.postgresql.Driver"
echo "jdbc.url=jdbc:postgresql://${DATABASE}:5432/${DBNAME}"
echo "jdbc.user=pvai"
echo "jdbc.password=gopvai!!"
echo ""
echo "server.proxy-name=bitbucket.pvai.com"
echo "server.proxy-port=443"
echo "server.secure=true"
echo "server.require-ssl=true"
echo ""
echo "plugin.search.elasticsearch.baseurl=http://${IPADDRESS}:9200/"
echo "plugin.search.elasticsearch.username=pvai"
echo "plugin.search.elasticsearch.password=gopvai!!"
echo ""
echo ""
echo "hazelcast.network.multicast=false"
echo "hazelcast.network.tcpip=true"
echo "hazelcast.network.tcpip.members=${IPADDRESS}"
}>${APSD}/shared/bitbucket.properties

echo "Bitbucket will start after 10 seconds. If you don't want to, please type cnt+C now."
sleep 10

/sbin/service atlbitbucket start

exit 0;