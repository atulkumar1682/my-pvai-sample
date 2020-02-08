#!/bin/sh

#__________ S3 Backup for Atlassian Application _______________________
# Version: 1.2.2 November 22 2019

#__________ Application Directories ___________________________________
# Set Directory of Installed Application.
AP='/usr/local/atlassian/bitbucket'
APL='BITBUCKET'

# Set Directory of Application Data
APD='/opt/atlassian/application-data/bitbucket'

# Set Directory of Application Shared Data
APSD='/efs/atlassian/bitbucket'

# Set S3 Folder for this Application
F='s3://pvai-devops-dr/bitbucket'

# USER
USER='atlbitbucket'

# Get Database endpoint
DATABASE=`/bin/cat ${HOME}/.pgpass | grep "bitbucket" | sed  "s/:.*$//"`

#__________ Command ___________________________________________________
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

#_________ Check this application is still running.__________________
X=`pgrep -f ${AP}/app`

if [ -z ${X} ] ; then
    echo "This application is not running. Also stop the backup process."
    exit 0
fi

#__________ Get today's date ________________________________________
TODAY=`/bin/date "+%Y%m%d"`

#__________ Get delete date based on the retention day(s) ___________
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

#__________ Get number of backup files in S3 ________________________
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
        /usr/bin/aws s3 rm $F/${OLDEST} --recursive --quiet &
    fi
fi

if [ ${NEWEST} -lt ${TODAY} ];then

       # Start Backup to S3 for the requested directory 
       echo "Sync Daily Application Source and Data";
       if [ ${#AP} -ne 0 ]; then
          /usr/bin/aws s3 sync --exact-timestamps --delete ${AP} $F/${TODAY}${AP} --quiet &
       fi
       if [ ${#APD} -ne 0 ]; then
          /usr/bin/aws s3 sync --exact-timestamps --delete --no-follow-symlinks ${APD} $F/${TODAY}${APD} --quiet &
       fi
       if [ ${#APSD} -ne 0 ]; then
          /usr/bin/aws s3 sync --exact-timestamps --delete ${APSD} $F/${TODAY}${APSD} --quiet &
       fi

       # Upload SQL data source
       /usr/bin/pg_dump -w -h $DATABASE -U pvai -c --if-exists -d bitbucket | gzip > $HOME/atlassian/Backup/${USER}.sql.gz

       if [ -e $HOME/atlassian/Backup/${USER}.sql.gz ]; then
          /usr/bin/aws s3 cp $HOME/atlassian/Backup/${USER}.sql.gz  $F/${TODAY}/${USER}.sql.gz --quiet
       fi

       # Upload README File if exist
       if [ -e $HOME/atlassian/Backup/README.txt ]; then
          /usr/bin/aws s3 cp $HOME/atlassian/Backup/README.txt  $F/${TODAY}/README.txt --quiet
       fi

fi

# Start Backup to S3 for the requested directory 

LP=`pgrep -f ${F}/latest/`

if [ ! -z $LP ] ; then
   echo "========== Sync(Latest Backup) Process is still running. ==========";
else 

   echo "Sync Latest Application Source and Data";
   if [ ${#AP} -ne 0 ]; then
      C=`aws s3 sync --exact-timestamps --delete ${AP} $F/latest${AP} --quiet`
   fi
   if [ ${#APD} -ne 0 ]; then
      D=`aws s3 sync --exact-timestamps --delete --no-follow-symlinks ${APD} $F/latest${APD} --quiet`
   fi
   if [ ${#APSD} -ne 0 ]; then
      E=`aws s3 sync --exact-timestamps --delete ${APSD} $F/latest${APSD} --quiet`
   fi

   # Upload SQL data source
   /usr/bin/pg_dump -w -h $DATABASE -U pvai -c --if-exists -d bitbucket | gzip > $HOME/atlassian/Backup/${USER}.sql.gz

   if [ -e $HOME/atlassian/Backup/${USER}.sql.gz ]; then
      R=`aws s3 cp $HOME/atlassian/Backup/${USER}.sql.gz  $F/latest/${USER}.sql.gz --quiet`
   fi

   # Upload README File if exist
   if [ -e $HOME/atlassian/Backup/README.txt ]; then
      R=`aws s3 cp $HOME/atlassian/Backup/README.txt  $F/latest/README.txt --quiet`
   fi

fi

exit 0
