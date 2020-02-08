import boto3
import json

def lambda_handler(event, context):

	client = boto3.client('ec2')
	regions = client.describe_regions()
	for region_name_obj in regions['Regions']:
		region_name = region_name_obj['RegionName']
		print (region_name)
		ec2 = boto3.client('ec2', region_name=region_name)

		describe_security_groups = ec2.describe_security_groups(
			Filters=[
				{
					'Name': 'ip-permission.protocol',
					'Values': [
						'-1'
					]
				}
			],
		)

		sglist=[]

		for sg_id in describe_security_groups['SecurityGroups']:
			sglist.append(sg_id['GroupId'])
			print (sglist)

		for sg_id in sglist:
			print ("Security GroupId: "+sg_id)
			security_group = ec2.describe_security_groups(GroupIds=[sg_id])
			ip_permissions = security_group['SecurityGroups'][0]['IpPermissions']
			for ip_permissions_obj in ip_permissions:
				ip_protocol = (ip_permissions_obj['IpProtocol'])
				print ("Protocol: "+ip_protocol)
				ip_ranges = (ip_permissions_obj['IpRanges'])
				ipv6_ranges = (ip_permissions_obj['Ipv6Ranges'])
				for cidr_ip_obj in ip_ranges:
					cidr_ip = (cidr_ip_obj['CidrIp'])
					print ("Source IP: "+cidr_ip)
					if ip_protocol == '-1' and cidr_ip == '0.0.0.0/0':
						print ("All ports are open to public ipv4, removing the inbound rule for 'All traffic' from source '0.0.0.0/0' on 'All ports'")
						revoke_sg_ingress = ec2.revoke_security_group_ingress(
							GroupId=sg_id,
							IpPermissions=[
								{
									'IpProtocol': '-1',
									'IpRanges': [
										{
											'CidrIp': '0.0.0.0/0'
										}
									],
								},
							],
							DryRun=False
						)

					else:
						print ("All ports are not open to public for ipv4")

				for cidr_ipv6 in ipv6_ranges:
					cidr_ipv6 = (cidr_ipv6['CidrIpv6'])
					print ("Source IP: "+cidr_ipv6)
					if ip_protocol == '-1' and cidr_ipv6 == '::/0':
						print ("All ports are open to public ipv6, removing the inbound rule for 'All traffic' from source '::/0' on 'All ports'")
						revoke_sg_ingress = ec2.revoke_security_group_ingress(
							GroupId=sg_id,
							IpPermissions=[
								{
									'IpProtocol': '-1',
									'Ipv6Ranges': [
										{
											'CidrIpv6': '::/0'
										}
									],
								}
							],
							DryRun=False
						)
					else:
						print ("All port are not open for ipv6")