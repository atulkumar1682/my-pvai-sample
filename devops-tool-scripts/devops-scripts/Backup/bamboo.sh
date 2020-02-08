#!/bin/sh
#_________________ S3 Backup for Atlassian Application ____________________
# Version: 1.2.2 November 22 2019

#_____________________Application Directories _____________________________
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


#______________________ Command __________________________________________
COMMAND="Usage: $0 [ Retention day(s) ]"

# Set retention Period at 1st argument.
if [ $# -ne 1 ]; then
    echo $COMMAND;
    exit 0;
fi

if expr "$1" : "[0-9]" >&/dev/null ;then
    RET="$1"
else
    echo "Command Error:  $COMMAND";
    exit 0;
fi

#_________ Check this application is still running.______________________
X=`pgrep -f ${AP}/conf`

if [ -z ${X} ] ; then
    echo "This application is not running. Also stop the backup process."
    exit 0
fi

#________________ Get today's date _____________________________________
TODAY=`/bin/date "+%Y%m%d"`

#__________ Get delete date based on the retention day(s) ______________
OLDEST=`/bin/date "+%Y%m%d"`
NEWEST=0

FILES=`aws s3 ls ${F}/`
for f in $FILES; do
    if [ $f != "PRE" ] && [ $f != "latest/" ]; then
        if [ ${OLDEST} -ge ${f%/} ]; then
           OLDEST=${f%/}
        fi
        if [ ${NEWEST} -le ${f%/} ]; then
          NEWEST=${f%/}
        fi
    fi
done


#__________ Get number of backup files in S3. _______________________
C=`aws s3 ls ${F}/`

FN=0
for c in $C; do
    if [ $c != "PRE" ] && [ $c != "latest/" ]; then
        FN=`expr $FN + 1`
    fi
done

# Delete old backup if the number of files reached the requested retention period.
if [ $FN -gt $RET ]; then
    echo "Reached Retention Period."
    Q=`pgrep -f 'aws s3 rm'`
    if [ ${#Q} -ne 0 ] ; then
        echo "========== aws s3 rm is still running ==========";
    else
        echo "aws s3 rm $F/${OLDEST} --recursive --quiet";
        /usr/bin/aws s3 rm $F/${OLDEST} --recursive --quiet&
     fi
fi

if [ ${NEWEST} -lt ${TODAY} ]; then

        # Start Backup to S3 for the requested directory 
        echo "Sync Daily Backup Application Source and Data";
        if [ ${#AP} -ne 0 ]; then
           /usr/bin/aws s3 sync --delete --exclude='.cache/*' ${AP} $F/${TODAY}${AP} --quiet &
        fi
        if [ ${#APD} -ne 0 ]; then
           /usr/bin/aws s3 sync --delete \
                        --exclude='temp/*'\
                        --exclude='caches/*' \
                        --exclude='logs/*' \
                        --exclude='analytics-logs/*' \
                                                ${APD} $F/${TODAY}${APD} --quiet &

        fi
        if [ ${#APSD} -ne 0 ]; then
           /usr/bin/aws s3 sync --delete --no-follow-symlinks \
                        --exclude='.cache/*' \
                                                ${APSD} $F/${TODAY}${APSD} --quiet &
        fi

        # Upload SQL data source
        /usr/bin/pg_dump -w -h $DATABASE -U pvai -c --if-exists -d bamboo | gzip > $HOME/atlassian/Backup/bamboo.sql.gz

        if [ -e $HOME/atlassian/Backup/bamboo.sql.gz ]; then
           /usr/bin/aws s3 cp $HOME/atlassian/Backup/bamboo.sql.gz  $F/${TODAY}/bamboo.sql.gz --quiet &
        fi

        # Upload README File if exist
        if [ -e $HOME/atlassian/Backup/README.txt ]; then
           /usr/bin/aws s3 cp $HOME/atlassian/Backup/README.txt  $F/${TODAY}/README.txt --quiet &
        fi        

fi

# Start Backup to S3 for the latest directory 

LP=`pgrep -f ${F}/latest/`

if [ ! -z $LP ] ; then
   echo "========== Sync(Latest Backup) Process is still running. ==========";
else 
      echo "Sync Latest Application Source and Data";
      if [ ${#AP} -ne 0 ]; then
         C=`aws s3 sync --delete \
                      --exclude='.cache/*'\
                                               ${AP} $F/latest${AP} --quiet`
      fi
      if [ ${#APD} -ne 0 ]; then
         D=`aws s3 sync --delete \
                      --exclude='temp/*'\
                      --exclude='caches/*' \
                      --exclude='logs/*' \
                      --exclude='analytics-logs/*' \
                                              ${APD} $F/latest${APD} --quiet`

      fi
      if [ ${#APSD} -ne 0 ]; then
         E=`aws s3 sync --delete --no-follow-symlinks \
                      --exclude='.cache/*' \
                                              ${APSD} $F/latest${APSD} --quiet`
      fi

      # Upload SQL data source
      /usr/bin/pg_dump -w -h $DATABASE -U pvai -c --if-exists -d bamboo | gzip > $HOME/atlassian/Backup/bamboo.sql.gz

      if [ -e $HOME/atlassian/Backup/bamboo.sql.gz ]; then
         R=`aws s3 cp $HOME/atlassian/Backup/bamboo.sql.gz  $F/latest/bamboo.sql.gz --quiet`
      fi

      # Upload README File if exist
      if [ -e $HOME/atlassian/Backup/README.txt ]; then
         R=`aws s3 cp $HOME/atlassian/Backup/README.txt  $F/latest/README.txt --quiet`
      fi
fi

exit 0
