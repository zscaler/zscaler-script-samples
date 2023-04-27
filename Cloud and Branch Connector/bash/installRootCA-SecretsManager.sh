#!/bin/bash
# Check if AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "AWS CLI is not installed. Please install it before running this script."
    exit 1
fi

# Get the SecretString from the AWS Secret Manager
secret_string=$(aws secretsmanager get-secret-value --no-verify-ssl --secret-id ZscalerRootCert --region us-east-1 --query SecretString --output text)

# Check if the secret_string is not empty
if [[ -z "${secret_string}" ]]; then
    echo "Failed to retrieve the SecretString. Please check your AWS credentials and secret-id."
    exit 1
fi

# Determine the operating system and install the Zscaler cert based on the OS type
if [ -f /etc/os-release ]; then
    . /etc/os-release
    #Amazon Linux, CenOS, Fedora, Redhat
    if [[ "$ID" == "amzn" ]] || [[ "$ID" == "centos" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "fedora" ]]; then
        echo "Amazon Linux, CentOS, RHEL, or Federa"
        # Create zscaler.pem file in /etc/pki/ca-trust/source/anchors/
        sudo bash -c "echo '${secret_string}' > /etc/pki/ca-trust/source/anchors/zscaler.pem"
        # Update the CA trust store
        sudo update-ca-trust
        echo "Zscaler certificate has been successfully created and installed."
    elif [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
        echo "Ubuntu or Debian"
        # Create zscaler.pem file in /usr/local/share/ca-certificates/
        sudo bash -c "echo '${secret_string}' > /usr/local/share/ca-certificates/zscaler.pem"
        # Update the CA trust store
        sudo update-ca-certificates
        echo "Zscaler certificate has been successfully created and installed."
    elif [[ "$ID" == "opensuse" ]]; then
        echo "OpenSUSE"
        # Create zscaler.pem file in /etc/pki/trust/anchors/
        sudo bash -c "echo '${secret_string}' > /etc/pki/trust/anchors/zscaler.pem"
        # Update the CA trust store
        sudo update-ca-certificates
        echo "Zscaler certificate has been successfully created and installed."
    else
        echo "Unknown or unsupported operating system. Certificate not installed"
        exit 1
    fi
else
    echo "Unable to determine the operating system. Certificate not installed"
fi