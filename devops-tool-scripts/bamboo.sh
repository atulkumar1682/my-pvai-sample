#!/bin/sh
################### Restore Atlassian Application #######################
# Version: 1.1.0 September 4 2019
##################### Application Directories ###########################
# Set Directory of Install Application.
AP='/usr/local/atlassian/bamboo'
APL='BAMBOO'

# Set Directory of Application Data
APD='/data/atlassian/bamboo'

# Set Directory of Application Shared Data
APSD='/home/bamboo'

# Set S3 Folder for this Application
F='s3://pvai-devops-dr/bamboo'

# Set Application user name
USER="bamboo"

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

# CREATE BAMBOO HOME
if [ ${#APSD} -ne 0 ]; then
   echo "Restoring Home directory..........";
   E=`aws s3 sync --delete \
                --exclude='.cache/*' \
                                               $F/${RET}${APSD} ${APSD}`
   /bin/mkdir -p ${APSD}/.cache
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
   /bin/chmod 755 ${AP}/bin/*.sh
fi

# CREATE DATA
if [ ${#APD} -ne 0 ]; then
   echo "Restoring App Data directory.....";
   D=`aws s3 sync --delete \
                --exclude='xml-data/build-dir/*' \
                --exclude='backups/*' \
                --exclude='export/*' \
                --exclude='temp/*' \
                --exclude='artifacts/*' \
                --exclude='caches/*' \
                --exclude='logs/*' \
                --exclude='analytics-logs/*' \
                                              $F/${RET}${APD} ${APD}`

   /bin/mkdir -p ${APD}/xml-data/build-dir
   /bin/mkdir -p ${APD}/backups
   /bin/mkdir -p ${APD}/export
   /bin/mkdir -p ${APD}/temp
   /bin/mkdir -p ${APD}/artifacts
   /bin/mkdir -p ${APD}/caches
   /bin/mkdir -p ${APD}/logs
   /bin/mkdir -p ${APD}/analytics-logs
   /bin/chown -R ${USER}.${USER} ${APD}
fi

# RESTORE TO DATABASE
if [ ${S3DB} = "Y" ] || [ ${S3DB} = "y" ]; then
    DB=`aws s3 cp $F/${RET}/${USER}.sql.gz ${HOME}/.`

    if [ -e ${HOME}/${USER}.sql.gz ]; then
       /bin/gzip -cd ${HOME}/${USER}.sql.gz | /usr/bin/psql -w -h $DATABASE -U pvai -d ${USER}
       /bin/rm ${HOME}/${USER}.sql.gz
    fi
fi

# UPDATE DATABASE CONFIG FILE


echo "Bamboo will start after 10 seconds. If you don't want to, please type cnt+C now."


exit 0;