#!/bin/sh

#/sbin/service jira stop
#/sbin/service confluence stop
#/sbin/service atlbitbucket stop
#/bin/service bamboo stop


/bin/rm -fr /usr/local/atlassian
/bin/rm -fr /opt/atlassian
/bin/rm -fr /data/atlassian

/usr/sbin/userdel jira >/dev/null
/usr/sbin/userdel confluence >/dev/null
/usr/sbin/userdel atlbitbucket >/dev/null
/usr/sbin/userdel bamboo >/dev/null

/bin/rm -fr /home/bamboo
/bin/rm -fr /home/atlbitbucket
/bin/rm -fr /home/jira
/bin/rm -fr /home/confluence

exit 0
