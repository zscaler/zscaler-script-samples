#!/usr/bin/env python3

import json
from boto3 import Session

# Variables
aws_region_name = input("Enter the AWS Region where Secrets Manager exists (e.g. us-west-2): ")
aws_access_id = input("Enter your AWS Access Key: ")
aws_secret_key = input("Enter your AWS Secret Key: ")
aws_secret_name = input("Enter your AWS Secrets Manager Object Name (e.g. ZS/CC/credentials/yourSecretName): ")
keyValue = input("Enter the updated API Key value: ")

# Initialize session client
session = Session(
    aws_access_key_id=aws_access_id,
    aws_secret_access_key=aws_secret_key,
    region_name=aws_region_name
)

client = session.client(service_name="secretsmanager")

# Get original Secrets Object
original_secret = client.get_secret_value(SecretId=aws_secret_name)

# Convert SecretString to dictionary
updated_secret = json.loads(original_secret['SecretString'])

# Update the dictionary with new value
updated_secret.update({"api_key": keyValue})

# Update the secret key
client.update_secret(SecretId=aws_secret_name, SecretString=str(json.dumps(updated_secret)))
print("Update Complete")