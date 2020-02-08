#!/bin/sh
################ S3 Backup for Atlassian Application ####################
# Version: 1.1.0 August 28 2019
##################### Application Directories ###########################
# Set Directory of Installed Application.
AP='/usr/local/atlassian/bamboo'

# Set Directory of Application Data
APD='/data/atlassian/bamboo'

# Set Directory of Application Shared Data
APSD='/home/bamboo'

# Set S3 Folder for this Application
F='s3://pvai-devops-dr/bamboo'

# Get Database endpoint
DATABASE=`/bin/cat ${HOME}/.pgpass | grep "bamboo" | sed  "s/:.*$//"`
########################################################################

# Command
COMMAND="Usage: $0 [ Retention day(s) ]"

# Set retention Period at 1st argument.
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

if [ ! -z $P ] ; then
   echo "======= Sync(Backup) Process is still running.======="
   exit 0
fi


# Check Application Process is running.
declare -i X
X=`/bin/ps aux | /bin/grep ${AP} | /bin/grep -v grep | /bin/awk '{print $2}'`

if [ ${X} = 0 ]; then
    echo "This application is not running. Also stop the backup process."
    exit 0
fi

# Get today's date
TODAY=`/bin/date "+%Y%m%d"`

# Get delete date based on the retention day(s)
OLD=`/bin/date "+%Y%m%d"`

FILES=`aws s3 ls ${F}/`
for f in $FILES; do
    if [ $f != "PRE" ]; then
      if [ $OLD -ge ${f%/} ]; then
         OLD=${f%/}
      fi
    fi
done

# Get number of backup files in S3
C=`aws s3 ls ${F}/`

FN=0
for c in $C; do
    if [ $c != "PRE" ]; then
        FN=`expr $FN + 1`
    fi
done

# Delete old backup if the number of files reached the requested retention period.
if [ $FN -gt $RET ]; then
    echo "Reached Retention Period."
    Q=`pgrep -f 'aws s3 rm'`
    if [ ${#Q} -ne 0 ] ; then
        echo "aws s3 rm is still running";
    else
        echo "aws s3 rm $F/${OLD} --recursive";
        /usr/bin/aws s3 rm $F/${OLD} --recursive &
    fi
fi

# Start Backup to S3 for the requested directory
echo "Sync Latest Application Source and Data";
if [ ${#AP} -ne 0 ]; then
   C=`aws s3 sync --delete \
                --exclude='.cache/*'\
                                         ${AP} $F/${TODAY}${AP}`
fi
if [ ${#APD} -ne 0 ]; then
   D=`aws s3 sync --delete \
                --exclude='temp/*'\
                --exclude='caches/*' \
                --exclude='logs/*' \
                --exclude='analytics-logs/*' \
                                        ${APD} $F/${TODAY}${APD}`

fi
if [ ${#APSD} -ne 0 ]; then
   E=`aws s3 sync --delete --no-follow-symlinks \
                --exclude='.cache/*' \
                                        ${APSD} $F/${TODAY}${APSD}`
fi

# Upload SQL data source
/usr/bin/pg_dump -w -h $DATABASE -U pvai -c --if-exists -d bamboo | gzip > $HOME/backup/bamboo.sql.gz

if [ -e $HOME/backup/bamboo.sql.gz ]; then
   R=`aws s3 cp $HOME/backup/bamboo.sql.gz  $F/${TODAY}/bamboo.sql.gz`
fi

# Upload README File if exist
if [ -e $HOME/backup/README.txt ]; then
   R=`aws s3 cp $HOME/backup/README.txt  $F/${TODAY}/README.txt`
fi

exit 0
