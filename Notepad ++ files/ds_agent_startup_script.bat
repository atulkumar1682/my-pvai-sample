@ECHO OFF
TITLE Nessus-Agent along with ds_agent link process
start C:\"Program Files"\"Tenable"\"Nessus Agent"\nessuscli agent link --key=9d4777f71733214d2a35566bd5f4bee3fda2b19462083c5f692dc86a2306d771 --host=cloud.tenable.com --port=443 --groups="PVAI"
start /c "C:\Program Files\Trend Micro\Deep Security Agent" dsa_control -r & dsa_control -a dsm://hb.genpact.com:443/ "policyid:68"
exit

=============================================================================================================================================================



cd / "c:\Program files\Tenable\Nessus Agent"


aws ec2 describe-instances --query 'Reservations[*].Instances[*].[PrivateIpAddress, LaunchTime,  InstanceId, State.Name, Tags[?Key==`Name`].Value | [0]]' --output table > Serverlist.txt

aws ec2 describe-instances --query 'Reservations[*].Instances[*].[PrivateIpAddress,LaunchTime,]|[0].Value}' --output table > ec2-list

echo "Pfizer" | mail -s "Pfizer_Server" yukti.srivastava@genpact.com < Serverlist.txt

aws ec2 describe-instances --query 'Reservations[*].Instances[*].[PrivateIpAddress, State.Name, Tags[?Key==`Name`].Value | [0]]' --output text > Serverlist.txt


https://console.aws.amazon.com//cloudformation/r/stack/865afb60-a7cb-11e9-90fb-122d883fe268?region=us-east-1