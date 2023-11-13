AWS GWLB Route Table Failover with Zscaler Cloud Connectors Lambda
===========================================================================================================

# **Overview**
This python-based lambda function monitors the health of Cloud Connectors in an AWS GWLB Target Group using CloudWatch Metrics and will change the specified route table(s0 to point to a NAT Gateway if all the Cloud Connectors in the group/location are unhealthy (fail-open to Internet for workloads)
The script assumes two Availability Zones but can be modified to support more or less based on your requirements
This script would be deployed on a per VPC (group of Cloud Connectors)
This script utilizes an SNS Trigger for the lambda function to change the route table to GWLB VPC Endpoints with Cloud Connectors if there is at least 1 healthy Cloud Connector in the target group, and will change the route table to the configured NAT Gateways when there are 0 healthy hosts in the target group
The script also creates a lambda execution role with least privilege permissions required to read cloudwatch metrics and also modify the target route table

## **Requirements**

- Zscaler Cloud Connectors should already be deployed and registered with the Zscaler cloud
- Permissions to deploy Lambda functions with CloudWatch
- An alternative "fail open" target such as NAT Gateways

## **Instructions to Deploy**

1. Download aws-gwlb-failover-rt-cft.yaml
1. Deploy a new CloudFormation stack in AWS using the include CFT (aws-gwlb-failover-rt-cft.yaml)
1. Specify the Route Table IDs that will route to the Cloud Connectors in Subnets/AZs 1 and 2
1. Specify the NAT Gateway IDs that will be used for the fail-open scenario in Subnets/AZs 1 and 2
1. Specify the Gateway Load Balancer VPC IDs (deployed with Zscaler) for normal operations in Subnets/AZs 1 and 2
1. Specify the GWLB Target Group ARN
1. Specify the GWLB Target Group Name. This is basically just going to be the Target Group ID from the ARN with "gwy/" prefix
1. Specify the Load Balancer Name

## **Instructions to Test Fail-Over**
1. Make sure there is at least 1 healthy Cloud Connector
1. Navigate to the Lambda Function that was deployed
1. Click the Test tab and Test button to execute. The lamba function should run successfully without changing the route table
1. Navigate to the Route Tables that was configured in the lambda function and confirm the 0.0.0.0/0 route is still pointing to the GWLB VPC Endpoint targets
1. Power off all the Cloud Connectors in the group and wait ~5 minutes
1. Monitor the CloudWatch alarm metric and refresh the page to see when it goes into an InAlarm state (red)
1. Navigate to the Route Tables and confirm they were changed over to the NAT Gateways for 0.0.0.0/0
1. Power the Cloud Connectors back on and wait ~5-10 minutes (this can take a bit longer as it takes a few minutes for the ec2 instances to power on, run all Zscaler services, and then cloudwatch metrics will trigger after a few minutes)
1. The CloudWatch metric should be OK (green) and the Route Tables chnged back to the VPC Endpoints for 0.0.0.0/0
