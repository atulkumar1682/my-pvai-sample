#!/bin/sh
################### Restore Atlassian Application #######################
# Version: 1.1.0 September 4 2019
##################### Application Directories ###########################
# Set Directory of Install Application.
AP='/usr/local/atlassian/confluence'
APL='home=/usr/local/atlassian/confluence'

# Set Directory of Application Data
APD='/opt/atlassian/application-data/confluence'

# Set Directory of Application Shared Data
APSD='/efs/atlassian/confluence'

# Set S3 Folder for this Application
F='s3://pvai-devops-dr/confluence'

# Set Application user name
USER="confluence"

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
fi

# CREATE EFS 
if [ ${#APSD} -ne 0 ]; then
   echo "Restoring EFS directory..........";
   E=`aws s3 sync --delete \
                --exclude='analytics-logs/*' \
                                               $F/${RET}${APSD} ${APSD}`
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
                --exclude='logs/*' \
                                              $F/${RET}${APD} ${APD}`

   /bin/mkdir -p ${APD}/logs
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
DBCONFIG="<?xml version=\"1.0\" encoding=\"UTF-8\"?>

<confluence-configuration>
  <setupStep>complete</setupStep>
  <setupType>cluster</setupType>
  <buildNumber>7901</buildNumber>
  <properties>
    <property name=\"access.mode\">READ_WRITE</property>
    <property name=\"admin.ui.allow.daily.backup.custom.location\">false</property>
    <property name=\"admin.ui.allow.manual.backup.download\">false</property>
    <property name=\"admin.ui.allow.site.support.email\">false</property>
    <property name=\"atlassian.license.message\">AAABVA0ODAoPeNp1UU1rg0AQve+vGOilPUSMbdIYEBpUgmA+qGl76WWyGZMtusq6ps2/7+oaQg+Fv ey8mffmvbn7oANkVIM3Bdebu/780Ycw2oHnjmds3ZZ7Upv8rSHVBBPXZWElNXK9xpKCRYnqi0jD8 oS6ahUyXsncMbA4U6BVS2zbKn7ChiLUFHSUo7FrHksFJ9lQ/FMLdbmC/gAOGvEKRRE0Va6/UZFT2 JGXI8naoA6vSqtnxjEkqUlZzazdN1yJWotK2oohMrBEyf9R7HkyjaojybFo6LphEgVpEmXx2rQ9T Z4nsykzn+BPYaOOKEWDveDSrgeJPAiE7Vk7kOqDw0JFfcMtCdcfeVMrPYjtLjX1yYab1Sp+DZNFy gbb7+YAHb3HIrq5M0nlRUvGF9x3MYDN4QHMqaA/2uccwqosSXGBBexIlTCIsfiMRWuXtpZ/AXvYr k0wLAIUR0IX8OuABMtVPJTPGq+1wDN2XKYCFEN6AsrIAR84wjVgWHEjQ4irBAlSX02go</property>
    <property name=\"attachments.dir\">\${confluenceHome}/attachments</property>
    <property name=\"confluence.cluster\">true</property>
    <property name=\"confluence.cluster.home\">/efs/atlassian/confluence</property>
    <property name=\"confluence.cluster.interface\">eth0</property>
    <property name=\"confluence.cluster.join.type\">tcp_ip</property>
    <property name=\"confluence.cluster.name\">node1</property>
    <property name=\"confluence.cluster.peers\">${IPADDRESS}</property>
    <property name=\"confluence.setup.server.id\">B9TE-ZFUC-80QY-0RCF</property>
    <property name=\"confluence.webapp.context.path\"></property>
    <property name=\"hibernate.c3p0.acquire_increment\">1</property>
    <property name=\"hibernate.c3p0.idle_test_period\">100</property>
    <property name=\"hibernate.c3p0.max_size\">60</property>
    <property name=\"hibernate.c3p0.max_statements\">0</property>
    <property name=\"hibernate.c3p0.min_size\">20</property>
    <property name=\"hibernate.c3p0.timeout\">30</property>
    <property name=\"hibernate.connection.driver_class\">org.postgresql.Driver</property>
    <property name=\"hibernate.connection.isolation\">2</property>
    <property name=\"hibernate.connection.password\">gopvai!!</property>
    <property name=\"hibernate.connection.url\">jdbc:postgresql://${DATABASE}:5432/confluence</property>
    <property name=\"hibernate.connection.username\">pvai</property>
    <property name=\"hibernate.database.lower_non_ascii_supported\">false</property>
    <property name=\"hibernate.dialect\">com.atlassian.confluence.impl.hibernate.dialect.PostgreSQLDialect</property>
    <property name=\"hibernate.setup\">true</property>
    <property name=\"jwt.private.key\">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</property>
    <property name=\"jwt.public.key\">MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAiqL4aWu5ny5JbdCx41qErZfySCaLxGsFd2yOPXSs+VdQ5pLHnaJbszTRhuAuFbOf1J/K2kBMI6ZHc4j0cIG9tRu2Cy/3zgExH1PCJd3JsS/tUA4eO+5nM64yzQemwckiyds0DRGqnuTkKJ9w6NX+jSwwCqkOPPcjQyAdTdp+NXQYpLWAxM6mA3Ns0Jx1kcoJjefQLTK155AO5jnLBko27OLxE3LiuXqV2GpYDkrtQeqwPyERzc405wpCT03tO/cbJYbD1FVXOh7RX4HwJmdqXQAPeAheZKuTqpDoVaCdzCrTlxuIkx62eHcjmU2tF03h05sMMrFWx+IFplTQGiAGKIwH6ZfNUm0D1pd+eRfag9FDBCCVwG/u832d3eJnpy6MzlV0y4UwiU6kcbc181dWpZtwg5Rn0gEexMsAbcGANKnFLq2GPq+t4YukJMEpXA7zO3LPKTFonPX5f3gvs97uDUB27xpIXsUfIIYw8TqwX30WZzECswKTl4W6ZnfZwdftAgMBAAE=</property>
    <property name=\"lucene.index.dir\">\${localHome}/index</property>
    <property name=\"synchrony.btf\">false</property>
    <property name=\"synchrony.encryption.disabled\">true</property>
    <property name=\"synchrony.proxy.enabled\">true</property>
    <property name=\"webwork.multipart.saveDir\">\${localHome}/temp</property>
  </properties>
</confluence-configuration>"

echo $DBCONFIG >${APD}/confluence.cfg.xml

echo "Confluene will start after 10 seconds. If you don't want to, please type cnt+C now."
sleep 10

/sbin/service confluence start

exit 0;
