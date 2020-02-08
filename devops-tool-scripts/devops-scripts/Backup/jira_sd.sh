#!/bin/sh
#__________ S3 Backup for Atlassian Application ___________________________________
# Version: 1.2.2 Noveber 22 2019

#__________ Application Directories ____=__________________________________________
# Set Directory of Installed Application.
AP='/usr/local/atlassian/jira'

# Set Directory of Application Data
APD='/opt/atlassian/application-data/jira'

# Set Directory of Application Shared Data
APSD='/efs/atlassian/servicedesk'

# Set S3 Forlder for this Application
F='s3://pvai-devops-dr/jirasd'

# Get Database endpoint
DATABASE=`/bin/cat ${HOME}/.pgpass | grep "jira_sd" | sed  "s/:.*$//"`

# Command
COMMAND="Usage: $0 [ Retention day(s) ]"


#__________ Set retention Period at 1st argument. ________________________________
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


#_________ Check this application is still running.______________________________
X=`pgrep -f ${AP}/conf`

if [ -z ${X} ] ; then
    echo "This application is not running. Also stop the backup process."
    exit 0
fi

#__________ Get today's date. ___________________________________________________
TODAY=`/bin/date "+%Y%m%d"`

#__________ Get delete date based on the retention day(s) _______________________
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

#__________ Get number of backup files in S3. __________________________________
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

if [ ${NEWEST} -lt ${TODAY} ]; then

        # Start Backup to S3 for the requested directory 
        echo "Sync Daily Application Source and Data";
        if [ ${#AP} -ne 0 ]; then
           /usr/bin/aws s3 sync --exact-timestamps --delete ${AP} $F/${TODAY}${AP} --quiet &
        fi
        if [ ${#APD} -ne 0 ]; then
           /usr/bin/aws s3 sync --exact-timestamps --delete ${APD} $F/${TODAY}${APD} --quiet &
        fi
        if [ ${#APSD} -ne 0 ]; then
           /usr/bin/aws s3 sync --exact-timestamps --delete ${APSD} $F/${TODAY}${APSD} --quiet &
        fi   

        # Upload SQL data source
        /usr/bin/pg_dump -w -h $DATABASE -U pvai -c --if-exists -d jira_sd | gzip > $HOME/atlassian/Backup/jira_sd.sql.gz

        if [ -e $HOME/atlassian/Backup/jira_sd.sql.gz ]; then
           /usr/bin/aws s3 cp $HOME/atlassian/Backup/jira_sd.sql.gz  $F/${TODAY}/jira_sd.sql.gz --quiet
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
      D=`aws s3 sync --exact-timestamps --delete ${APD} $F/latest${APD} --quiet`
   fi
   if [ ${#APSD} -ne 0 ]; then
      E=`aws s3 sync --exact-timestamps --delete ${APSD} $F/latest${APSD} --quiet`
   fi   

   # Upload SQL data source
   /usr/bin/pg_dump -w -h $DATABASE -U pvai -c --if-exists -d jira_sd | gzip > $HOME/atlassian/Backup/jira_sd.sql.gz

   if [ -e $HOME/atlassian/Backup/jira_sd.sql.gz ]; then
      R=`aws s3 cp $HOME/atlassian/Backup/jira_sd.sql.gz  $F/latest/jira_sd.sql.gz --quiet`
   fi

   # Upload README File if exist
   if [ -e $HOME/atlassian/Backup/README.txt ]; then
      R=`aws s3 cp $HOME/atlassian/Backup/README.txt  $F/latest/README.txt --quiet`
   fi
fi

exit 0
