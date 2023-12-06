AWS Lambda Website Tester with Zscaler and SSL Inspection
===========================================================================================================

# **Overview**
This python-based lambda function includes the Zscaler Root certificate and uses the requests module to conduct an http get on a list of websites you can define.
The lambda function includes a handful of example http and https websites, but you can modify the lambda environmental variable to change the list of these sites without modifying the python code
The lambda function includes an execution role to run the lambda itself and a policy that includes permissions to read VPC/subnet/SGs and ability to create/delete network interfaces. You can modify this policy in the CFT for reduced permissions to only allow the creation of the network interface in the target VPC
The lambda function does not include a schedule or trigger so you can run the tests on-demand or implement your own trigger

## **Requirements**

- Zscaler Cloud Connectors should already be deployed and registered with the Zscaler cloud
- An existing VPC and subnet is required to deploy the Lambda ENI into. This subnet must route through Cloud Connectors
- An existing Security Group is required to be used by the Lambda function. Outbound 0.0.0.0/0 is simplest

## **Instructions**

1. Download zs-site-test.zip
1. Upload the zs-site-test.zip into an existing AWS S3 bucket (or create a new bucket) in the same account/region
1. Deploy a new CloudFormation stack in AWS using the include CFT (zs-site-tester-lambda-cft.yaml)
1. Specify the S3 bucket name, S3 object name, the VPC, subnets, and security group to deploy the Lambda ENI
1. Navigate to the Lambda function and click the Test tab
1. Click Test
1. Review the test results by click the Details button once the function has completed execution
1. Review the ZIA web insight logs to look at the log entries to validate SSL inspection and if destinations were allowed or blocked