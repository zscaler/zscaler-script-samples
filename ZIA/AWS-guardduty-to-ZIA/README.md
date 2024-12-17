# ZIA/AWS GuardDuty Integration

This tool integrates AWS's GuardDuty Threat Intelligence with Zscaler's Zero Trust Exchange to provide an extra layer of security and visibility for traffic headed to potentially harmful destinations.

During runtime, the integration periodically (by default, every 5 minutes) checks AWS GuardDuty findings and extracts potentially dangerous FQDNs and IP addresses. These entries are then used to create/update IP and FQDN Destination Groups within Zscaler Internet Access. Once Destination Groups are created/updated with the latest findings, they are attached to a Firewall policy to block and log access. The script overwrites previous entries in the Destination Group every time it runs. As such, when GuardDuty ages entries out over time, they are likewise aged out of the ZIA Destination Group.

## Requirements
- Zscaler Internet Access
- A Zscaler Cloud Access API Key
- Valid API service credentials Lambda can use to execute Read/Write operations against ZIA
- A subscription to AWS GuardDuty with an active Detector
- Access to AWS CloudFormation with permission to create a CloudWatch rule and Lambda Function with the following permissions:
    - secretsmanager:GetSecretValue
    - logs:CreateLogGroup
    - logs:CreateLogStream
    - logs:PutLogEvents
    - guardduty:ListDetectors
    - guardduty:ListFindings
    - guardduty:GetFindings
    - events:PutRule
    - events:PutTargets
    - events:RemoveTargets
    - events:DeleteRule
    - iam:PassRole

## Getting Started
- Download the lambda_guardduty_threatfeed.zip and threatfeed.yaml files.
- Create an S3 bucket and upload the lambda_guardduty_threatfeed.zip
- Create an AWS Secrets Manager object with the following Key/Value pairs:
    - KEY: zscaler_api_base_url VALUE: Your API Base URL
    - KEY: zscaler_username VALUE: Your API Service Account username
    - KEY: zscaler_password VALUE: Your API Service Account password
    - KEY: zscaler_api_key VALUE: Your Zscaler Cloud Service API Key

## Zscaler Cloud Services API Key
In the Zscaler Internet Access UI, navigate to Administration -- Authentication Configuration -- Cloud Service API Security. Then, click Add API Key (or copy the existing key, if already present). Also note the API base URL listed above the API key. These values should be placed in the AWS Secrets Manager object along with the API Service Account username and password.

## Zscaler API Service Account
An API Service Account should be used to authenticate the Lambda service to the Zscaler cloud. We do not recommend using the Super Admin account to run the Lambda function.

Create a new role in Administration -- Administration Controls -- Role Management. Click Add Administrator Role. Ensure Firewall and Policy Access are enabled. Then, create a new Administrator (via IdP, or through the Zscaler UI) attached to this role. The username and password for this account should be placed in the AWS Secrets Manager object along with the Cloud Services API Key and API Base URL.

## Installation
From the AWS CloudFormation dashboard, create a new stack with new resources. Choose the option to upload a template file and select the threatfeed.yaml file previously downloaded. Click next and provide a name for the stack. Set the polling interval (how often Lambda runs) and enter your S3 bucket information. Lastly, enter the name of your Secrets Manger object. Proceed through the remainder of the wizard and update remaining default values as you see fit for your environment.

## Verification
You can verify script execution directly from CloudWatch logs, from the Lambda Function itself (Test), or from within the Zscaler Internet Access console by browsing to Administration -- IP & FQDN Groups. In the Destination IPv4 Groups tab, verify that new "GuardDuty Imported" groups appear. The description of these groups should also include a timestamp of when they were last updated.

# Patch Notes
Initial Release: 16 December, 2024