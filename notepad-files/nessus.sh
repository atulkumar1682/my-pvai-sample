#!/bin/bash
#aws s3 cp s3://pvai-tools-packages/nessus.sh . 
#chmod u+x nessus.sh
#./nessus.sh
/etc/init.d/nessusagent status
x=`echo $?`
/bin/systemctl status nessusagent.service
y=`echo $?`

if [ "$x" -eq 0 ] || [ "$y" -eq 0 ]
then
echo "Nessus Already Installed and Running"
  exit 1
else
# Ensure we are in /tmp
cd /tmp
pwd
# Delete previous download
#rm -f /tmp/NessusAgent-7.1.0-amzn.x86_64.rpm
#rm -f /tmp/NessusAgent-7.1.0-ubuntu1110_amd64.deb
#rm -f /tmp/NessusAgent-7.1.0-es7.x86_64.rpm

#check OS-Version
cat /etc/os-release | grep -i 'NAME="Amazon Linux AMI"'
if [ $? == 0 ]
then
#OS is Amazon Linux
aws s3 cp s3://pvai-tools-packages/NessusAgent-7.1.0-amzn.x86_64.rpm .
# Check if file is here
file NessusAgent-7.1.0-amzn.x86_64.rpm
ls -l .
ls -l /tmp
# Install and start Nessus
rpm -ivh NessusAgent-7.1.0-amzn.x86_64.rpm 
/opt/nessus_agent/sbin/nessuscli agent link --key=9d4777f71733214d2a35566bd5f4bee3fda2b19462083c5f692dc86a2306d771 --host=cloud.tenable.com --port=443 --groups="PVAI"
/etc/init.d/nessusagent start
/etc/init.d/nessusagent status
else
echo "Not Amazon Linux"
fi

cat /etc/os-release | grep -i 'NAME="Ubuntu"'
if [ $? == 0 ]
then
#OS is Ubuntu
aws s3 cp s3://pvai-tools-packages/NessusAgent-7.1.0-ubuntu1110_amd64.deb .
# Check if file is here
file NessusAgent-7.1.0-ubuntu1110_amd64.deb
ls -l .
ls -l /tmp
dpkg -i NessusAgent-7.1.0-ubuntu1110_amd64.deb
/opt/nessus_agent/sbin/nessuscli agent link --key=9d4777f71733214d2a35566bd5f4bee3fda2b19462083c5f692dc86a2306d771 --host=cloud.tenable.com --port=443 --groups="PVAI"
/etc/init.d/nessusagent start
/etc/init.d/nessusagent status
else
echo "Not Ubuntu"
fi
		
cat /etc/os-release | grep -i 'NAME="CentOS Linux"'
if [ $? == 0 ]
then
#OS is CentOS
mkdir NessusAgent
cd NessusAgent
aws s3 cp s3://pvai-tools-packages/NessusAgent-7.1.0-es7.x86_64.rpm .
# Check if file is here
file NessusAgent-7.1.0-es7.x86_64.rpm
ls -l .
ls -l /tmp/NessusAgent
rpm -ivh NessusAgent-7.1.0-es7.x86_64.rpm
/opt/nessus_agent/sbin/nessuscli agent link --key=9d4777f71733214d2a35566bd5f4bee3fda2b19462083c5f692dc86a2306d771 --host=cloud.tenable.com --port=443 --groups="PVAI"
/bin/systemctl start nessusagent.service
/bin/systemctl status nessusagent.service
else
echo "Not Cent-OS"
fi 

fi 