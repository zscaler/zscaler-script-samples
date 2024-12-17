# Zscaler Deception/AWS GuardDuty Integration

This tool integrates AWS's GuardDuty with Zscaler Deception to provide high fidelity threat intelligence. Deception is a threat detection platform that deploys realistic decoys across an environment to lure, detect, and intercept active attackers. In AWS environments, it utilizes decoy web servers, databases, and file servers to detect lateral movement, diverting malicious actors away from critical cloud assets. Additionally, it employs Internet-facing decoys to detect pre-breach threats specifically targeting your organization, enhancing your threat intelligence capabilities.

During runtime, the integration periodically (by default, every 5 minutes) checks Zscaler Deception findings and uploads them as a text file to a common S3 bucket. GuardDuty then ingests the contents of this text file and updates its Findings, which can then be used by other AWS services (such as Security Hub) to provide automated remediation.

## Requirements
- Zscaler Deception
- A subscription to AWS GuardDuty with an active Detector
- Access to AWS CloudFormation with permission to create a CloudWatch rule and Lambda Function with the following permissions:
    - logs:CreateLogGroup
    - logs:CreateLogStream
    - logs:PutLogEvents
    - guardduty:ListDetectors
    - guardduty:CreateThreatIntelSet
    - guardduty:GetThreatIntelSet
    - guardduty:ListThreatIntelSets
    - guardduty:UpdateThreatIntelSet
    - events:PutRule
    - events:PutTargets
    - events:RemoveTargets
    - events:DeleteRule
    - iam:PutRolePolicy
    - iam:DeleteRolePolicy
    - s3:getobject
    - s3:putobject

## Getting Started
- Download the threatfeed.yaml file. The lambda_function.py file is provided as reference, but is not necessary to download as it is embedded into the CloudFormation template.

## Deception Configuration
Note that what follows simply sets up the AWS GuardDuty integration and assumes that Zscaler Deception has already been configured for the environment. For more detailed information on deploying Deception, visit https://help.zscaler.com/deception/getting-started.

From the Deception dashboard, navigate to Orchestration -- Rules. Click on Add Rule. In the pane that appears, provide a name for the rule and create the condition in which this rule will fire (for instance, "attacker.score > 1 and decoy.group is 'Threat Intelligence'"). Scroll down and select the Enabled switch under AWS. Choose AWS GuardDuty (Threat IP Lists) from the dropdown and click Save.

Navigate to Orchestration -- Containment. In the list that appears, find the AWS GuardDuty integration and click the Edit icon. Note the URL that appears in the window pane. This will be entered into the CloudFormation template wizard in the next section.

## Installation
From the AWS CloudFormation dashboard, create a new stack with new resources. Choose the option to upload a template file and select the threatfeed.yaml file previously downloaded. Click next and provide a name for the stack. Enter the Threatfeed URL obtained from Deception as well as the Threatfeed Name (which will be used to name the CloudWatch Rule and Lambda Function). Set the polling frequency (how often Lambda checks Deception for new findings) in the Frequency field, then click the next button. Proceed through the remainder of the wizard and update remaining default values as you see fit for your environment.

## Verification
You can verify script execution in several ways:
 - Directly from CloudWatch logs
 - From the Lambda Function itself (use the Test tab to verify the script can be manually executed and results in a 200 success)
 - From the GuardDuty Overview page (verify that new Findings appear within the dashboard)
 - From the S3 Bucket (verify that *.txt files are placed in this bucket by the Lambda function).

# Patch Notes
Initial Release: 16 December, 2024