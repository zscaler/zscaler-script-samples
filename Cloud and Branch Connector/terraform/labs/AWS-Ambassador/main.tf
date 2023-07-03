# Configure the AWS Provider
provider "aws" {
  region = var.aws_region1
  alias = "region1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "aws" {
  region = var.aws_region2
  alias = "region2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Map default tags with values to be assigned to all tagged resources
locals {
  global_tags = {
  Owner       = var.name_suffix
  ManagedBy   = "terraform"
  Vendor      = "Zscaler"
  "zs-edge-connector-cluster/${var.name_prefix}-cluster-${var.name_suffix}" = "shared"
  }
}

############################################################################################################################
#### The following lines generates a new SSH key pair and stores the PEM file locally. The public key output is used    ####
#### as the instance_key passed variable to the ec2 modules for admin_ssh_key public_key authentication                 ####
#### This is not recommended for production deployments. Please consider modifying to pass your own custom              ####
#### public key file located in a secure location                                                                       ####
############################################################################################################################
# private key for login
resource "tls_private_key" "key" {
  algorithm   = var.tls_key_algorithm
}
resource "tls_private_key" "key1" {
  algorithm   = var.tls_key_algorithm
}

resource "aws_key_pair" "deployer" {
  provider = aws.region1
  key_name   = "${var.name_prefix}-region1-key-${var.name_suffix}"
  public_key = tls_private_key.key.public_key_openssh

  provisioner "local-exec" {
    command = <<EOF
      echo "${tls_private_key.key.private_key_pem}" > ${var.name_prefix}-region1-key-${var.name_suffix}.pem
      chmod 0600 ${var.name_prefix}-region1-key-${var.name_suffix}.pem
EOF
  }
}
resource "aws_key_pair" "deployer2" {
  provider = aws.region2
  key_name   = "${var.name_prefix}-region2-key-${var.name_suffix}"
  public_key = tls_private_key.key1.public_key_openssh

  provisioner "local-exec" {
    command = <<EOF
      echo "${tls_private_key.key1.private_key_pem}" > ${var.name_prefix}-region2-key-${var.name_suffix}.pem
      chmod 0600 ${var.name_prefix}-region2-key-${var.name_suffix}.pem
EOF
  }
}

# Create an AWS Secrets Manager object in Region1
resource "aws_secretsmanager_secret" "secretmaster" {
   provider = aws.region1
   name = "ZS/CC/credentials/zscc-${var.name_suffix}"
   recovery_window_in_days = 0
}

# Create an AWS Secrets Manager object in Region2
resource "aws_secretsmanager_secret" "secretmaster2" {
   provider = aws.region2
   name = "ZS/CC/credentials/zscc-${var.name_suffix}"
   recovery_window_in_days = 0
}
 
# Import CC credentials into Secrets Manager objects
resource "aws_secretsmanager_secret_version" "sversion" {
  provider = aws.region1
  secret_id = aws_secretsmanager_secret.secretmaster.id
  secret_string = <<EOF
   {
    "username": "${var.secret_username}",
    "password": "${var.secret_password}",
    "api_key": "${var.secret_apikey}"
   }
EOF
}

resource "aws_secretsmanager_secret_version" "sversion2" {
  provider = aws.region2
  secret_id = aws_secretsmanager_secret.secretmaster2.id
  secret_string = <<EOF
   {
    "username": "${var.secret_username}",
    "password": "${var.secret_password}",
    "api_key": "${var.secret_apikey}"
   }
EOF
}

## Create the user_data file
locals {
  userdata = <<USERDATA
[ZSCALER]
CC_URL=${var.cc_vm_prov_url}
SECRET_NAME=ZS/CC/credentials/zscc-${var.name_suffix}
HTTP_PROBE_PORT=${var.http_probe_port}
USERDATA
}

resource "local_file" "user-data-file" {
  content  = local.userdata
  filename = "cc_user_data.txt"
}


# 1. Network Creation
# Identify availability zones available for Region1
data "aws_availability_zones" "available" {
  provider = aws.region1
  state = "available"
}

data "aws_availability_zones" "available2" {
  provider = aws.region2
  state = "available"
}

# Create new VPCs
resource "aws_vpc" "vpc1" {
  provider = aws.region1
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-${var.name_suffix}" }
  )
}

resource "aws_vpc" "vpc2" {
  provider = aws.region2
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-${var.name_suffix}" }
  )
}

# Create DHCP Options (to set ZPA DNS to public) and associate to VPC(s)
resource "aws_vpc_dhcp_options" "dns_resolver1" {
  provider = aws.region1
  domain_name_servers = ["8.8.8.8", "8.8.4.4"]
}

resource "aws_vpc_dhcp_options" "dns_resolver2" {
  provider = aws.region2
  domain_name_servers = ["8.8.8.8", "8.8.4.4"]
}

resource "aws_vpc_dhcp_options_association" "workload_dns_resolver" {
  provider = aws.region1
  vpc_id          = aws_vpc.vpc1.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver1.id
}

resource "aws_vpc_dhcp_options_association" "cc_dns_resolver" {
  provider = aws.region1
  vpc_id          = aws_vpc.vpc1.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver1.id
}

resource "aws_vpc_dhcp_options_association" "workload_dns_resolver2" {
  provider = aws.region2
  vpc_id          = aws_vpc.vpc2.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver2.id
}

resource "aws_vpc_dhcp_options_association" "cc_dns_resolver2" {
  provider = aws.region2
  vpc_id          = aws_vpc.vpc2.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver2.id
}

# Create Internet Gateways
resource "aws_internet_gateway" "igw1" {
  provider = aws.region1
  vpc_id = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-igw-${var.name_suffix}" }
  )
}

resource "aws_internet_gateway" "igw2" {
  provider = aws.region2
  vpc_id = aws_vpc.vpc2.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-igw-${var.name_suffix}" }
  )
}

# Create equal number of Public/NAT Subnets Subnets to how many Cloud Connector subnets exist. 
resource "aws_subnet" "pubsubnet" {
  provider = aws.region1
  count = length(aws_subnet.cc-subnet.*.id)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 101)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-public-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_subnet" "pubsubnet2" {
  provider = aws.region2
  count = length(aws_subnet.cc-subnet2.*.id)
  availability_zone = data.aws_availability_zones.available2.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc2.cidr_block, 8, count.index + 101)
  vpc_id            = aws_vpc.vpc2.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-public-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_subnet" "privatesubnet" {
  provider = aws.region1
  count = length(aws_subnet.cc-subnet.*.id)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 1)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-private-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_subnet" "privatesubnet2" {
  provider = aws.region2
  count = length(aws_subnet.cc-subnet2.*.id)
  availability_zone = data.aws_availability_zones.available2.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc2.cidr_block, 8, count.index + 1)
  vpc_id            = aws_vpc.vpc2.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-private-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

# Create public Route Tables toward IGWs.
resource "aws_route_table" "routetablepublic1" {
  provider = aws.region1
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-igw-rt-${var.name_suffix}" }
  )
}

resource "aws_route_table" "routetablepublic2" {
  provider = aws.region2
  vpc_id = aws_vpc.vpc2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw2.id
  }

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-igw-rt-${var.name_suffix}" }
  )
}

# Create equal number of Route Table associations to how many Public subnets exist. 
resource "aws_route_table_association" "routetablepublic1" {
  provider = aws.region1
  count = length(aws_subnet.pubsubnet.*.id)
  subnet_id      = aws_subnet.pubsubnet.*.id[count.index]
  route_table_id = aws_route_table.routetablepublic1.id
}

resource "aws_route_table_association" "routetablepublic2" {
  provider = aws.region2
  count = length(aws_subnet.pubsubnet2.*.id)
  subnet_id      = aws_subnet.pubsubnet2.*.id[count.index]
  route_table_id = aws_route_table.routetablepublic2.id
}

# Create NAT Gateway and assign EIP per AZ.
resource "aws_eip" "eip" {
  provider = aws.region1
  count      = length(aws_subnet.pubsubnet.*.id)
  vpc        = true
  depends_on = [aws_internet_gateway.igw1]

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-eip-az${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_eip" "eip2" {
  provider = aws.region2
  count      = length(aws_subnet.pubsubnet2.*.id)
  vpc        = true
  depends_on = [aws_internet_gateway.igw2]

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-eip-az${count.index + 1}-${var.name_suffix}" }
  )
}

# Create 1 NAT Gateway per Public Subnet.
resource "aws_nat_gateway" "ngw" {
  provider = aws.region1
  count = length(aws_subnet.pubsubnet.*.id)
  allocation_id = aws_eip.eip.*.id[count.index]
  subnet_id     = aws_subnet.pubsubnet.*.id[count.index]
  depends_on    = [aws_internet_gateway.igw1]
  
  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-natgw-az${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_nat_gateway" "ngw2" {
  provider = aws.region2
  count = length(aws_subnet.pubsubnet2.*.id)
  allocation_id = aws_eip.eip2.*.id[count.index]
  subnet_id     = aws_subnet.pubsubnet2.*.id[count.index]
  depends_on    = [aws_internet_gateway.igw2]
  
  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-natgw-az${count.index + 1}-${var.name_suffix}" }
  )
}

# 2. Create Bastion Host
module "bastion" {
  providers = {
    aws = aws.region1
  }
  source        = "../modules/terraform-zsbastion-aws"
  name_prefix   = var.name_prefix
  resource_tag  = var.name_suffix
  global_tags   = local.global_tags
  vpc           = aws_vpc.vpc1.id
  public_subnet = aws_subnet.pubsubnet.0.id
  instance_type = "t3.medium"
  instance_key  = aws_key_pair.deployer.key_name
}

# 3a. Create Workload1
module "workload1" {
  providers = {
    aws = aws.region1
  }
  source       = "../modules/terraform-2region-zsworkload1-aws"
  name_prefix  = "${var.name_prefix}"
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  vpc          = aws_vpc.vpc1.id
  subnet       = aws_subnet.privatesubnet.*.id
  instance_type = "t3.medium"
  instance_key = aws_key_pair.deployer.key_name
  vpc_cidr   = var.vpc_cidr
}

# 3a. Create Workload2
module "workload2" {
  providers = {
    aws = aws.region2
  }
  source       = "../modules/terraform-2region-zsworkload2-aws"
  name_prefix  = "${var.name_prefix}"
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  vpc          = aws_vpc.vpc2.id
  subnet       = aws_subnet.privatesubnet2.*.id
  instance_type = "t3.medium"
  instance_key = aws_key_pair.deployer2.key_name
  bastion_ip   = module.bastion.public_ip
  aws_region1 = var.aws_region1
  aws_region2 = var.aws_region2
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
  vpc_cidr   = var.vpc_cidr
}

# 4. Create CC network, routing, and appliance
# Create subnet for CC network in X availability zones per az_count variable
resource "aws_subnet" "cc-subnet" {
  provider = aws.region1
  count = var.az_count

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 200)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-cc-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_subnet" "cc-subnet2" {
  provider = aws.region2
  count = var.az_count

  availability_zone = data.aws_availability_zones.available2.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc2.cidr_block, 8, count.index + 200)
  vpc_id            = aws_vpc.vpc2.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-cc-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

# Create Route Tables for CC subnets pointing to NAT Gateway resource in each AZ
resource "aws_route_table" "cc-rt" {
  provider = aws.region1
  count = length(aws_subnet.cc-subnet.*.id)
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.ngw.*.id, count.index)
  }
  
  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-cc-rt-ngw-${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_route_table" "cc-rt2" {
  provider = aws.region2
  count = length(aws_subnet.cc-subnet2.*.id)
  vpc_id = aws_vpc.vpc2.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.ngw2.*.id, count.index)
  }
  route {
    cidr_block     = "${module.bastion.public_ip}/32"
    gateway_id     = aws_internet_gateway.igw2.id
  }

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-cc-rt-ngw-${count.index + 1}-${var.name_suffix}" }
  )
}

# CC subnet NATGW Route Table Association
resource "aws_route_table_association" "cc-rt-association" {
  provider = aws.region1
  count          = length(aws_subnet.cc-subnet.*.id)
  subnet_id      = aws_subnet.cc-subnet.*.id[count.index]
  route_table_id = aws_route_table.cc-rt.*.id[count.index]
}

resource "aws_route_table_association" "cc-rt-association2" {
  provider = aws.region2
  count          = length(aws_subnet.cc-subnet2.*.id)
  subnet_id      = aws_subnet.cc-subnet2.*.id[count.index]
  route_table_id = aws_route_table.cc-rt2.*.id[count.index]
}

# Validation for Cloud Connector instance size and EC2 Instance Type compatibilty. A file will get generated in root path if this error gets triggered.
resource "null_resource" "cc-error-checker" {
  count = local.valid_cc_create ? 0 : 1 # 0 means no error is thrown, else throw error
  provisioner "local-exec" {
    command = <<EOF
      echo "Cloud Connector parameters were invalid. No appliances were created. Please check the documentation and cc_instance_size / ccvm_instance_type values that were chosen" >> errorlog.txt
EOF
  }
}

# Create X CC VMs per cc_count which will span equally across designated availability zones per az_count
# E.g. cc_count set to 4 and az_count set to 2 will create 2x CCs in AZ1 and 2x CCs in AZ2
module "cc-vm" {
  providers = {
    aws = aws.region1
  }
  source             = "../modules/terraform-2region-zscc1-aws"
  cc_count           = var.cc_count
  name_prefix        = var.name_prefix
  resource_tag       = var.name_suffix
  global_tags        = local.global_tags
  vpc                = aws_vpc.vpc1.id
  mgmt_subnet_id     = aws_subnet.cc-subnet.*.id
  service_subnet_id  = aws_subnet.cc-subnet.*.id
  instance_key       = aws_key_pair.deployer.key_name
  user_data          = local.userdata
  ccvm_instance_type = var.ccvm_instance_type
  cc_instance_size   = var.cc_instance_size
}

module "cc-vm2" {
  providers = {
    aws = aws.region2
   }
  source             = "../modules/terraform-2region-zscc2-aws"
  cc_count           = var.cc_count
  name_prefix        = var.name_prefix
  resource_tag       = var.name_suffix
  global_tags        = local.global_tags
  vpc                = aws_vpc.vpc2.id
  mgmt_subnet_id     = aws_subnet.cc-subnet2.*.id
  service_subnet_id  = aws_subnet.cc-subnet2.*.id
  instance_key       = aws_key_pair.deployer2.key_name
  user_data          = local.userdata
  ccvm_instance_type = var.ccvm_instance_type
  cc_instance_size   = var.cc_instance_size
  bastion_ip   = module.bastion.public_ip
  aws_region1 = var.aws_region1
  aws_region2 = var.aws_region2
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}

resource "aws_route_table" "workload-rt" {
  provider = aws.region1
  count = length(aws_subnet.privatesubnet.*.id)
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = module.cc-vm.eni[0]
  }

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-private-subnet-rt-${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_route_table" "workload-rt2" {
  provider = aws.region2
  count = length(aws_subnet.privatesubnet2.*.id)
  vpc_id = aws_vpc.vpc2.id
  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = module.cc-vm2.eni[0]
  }
  route {
    cidr_block     = "${module.bastion.public_ip}/32"
    gateway_id     = aws_internet_gateway.igw2.id
  }

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-private-subnet-rt-${count.index + 1}-${var.name_suffix}" }
  )
}

# Create equal number of Route Table associations to how many Workload subnets exist. 
resource "aws_route_table_association" "workload-rt-association" {
  provider = aws.region1
  count = length(aws_subnet.privatesubnet.*.id)
  subnet_id      = aws_subnet.privatesubnet.*.id[count.index]
  route_table_id = aws_route_table.workload-rt.*.id[count.index]
}

resource "aws_route_table_association" "workload-rt-association2" {
  provider = aws.region2
  count = length(aws_subnet.privatesubnet2.*.id)
  subnet_id      = aws_subnet.privatesubnet2.*.id[count.index]
  route_table_id = aws_route_table.workload-rt2.*.id[count.index]
}

# Copy User Mapping file to Guacamole
resource "null_resource" "user-mapping" {
  provisioner "file" {
    source      = "user-mapping.xml"
    destination = "/home/ubuntu/user-mapping.xml"
  }
  connection {
    type     = "ssh"
    host     = chomp(module.bastion.public_dns)
    user     = "ubuntu"
    private_key = file("${path.module}/zscc-region1-key-${var.name_suffix}.pem")
  }
  depends_on = [
    local_file.usermapping
  ]
}
resource "null_resource" "file-move" {
  provisioner "remote-exec" {
    inline = [
      "sudo cp user-mapping.xml /etc/guacamole/user-mapping.xml"
    ]
  }
  connection {
    type     = "ssh"
    host     = chomp(module.bastion.public_dns)
    user     = "ubuntu"
    private_key = file("${path.module}/zscc-region1-key-${var.name_suffix}.pem")
  }
  depends_on = [
    null_resource.user-mapping
  ]
}

## Create the App Connector(s)
provider "zpa" {
  zpa_client_id = var.zpa_client_id
  zpa_client_secret = var.zpa_client_secret
  zpa_customer_id = var.zpa_customer_id
}

# Create the App Connector Group
resource "zpa_app_connector_group" "aws_app_connector_group" {
  name                     = "zscc-Region1-App-Connector-Group-${var.name_suffix}"
  description              = "Region1 App Connector Group"
  enabled                  = true
  latitude                 = "37.3382082"
  longitude                = "-121.8863286"
  location                 = "San Jose, CA, USA"
  upgrade_day              = "SUNDAY"
  upgrade_time_in_secs     = "66600"
  override_version_profile = true
  version_profile_id       = 0
  dns_query_type           = "IPV4_IPV6"
}

# Create the AC Provisioning Key
resource "zpa_provisioning_key" "region1_provisioning_key" {
  name                  = "zscc-Region1-App-Connectors-${var.name_suffix}"
  association_type      = "CONNECTOR_GRP"
  max_usage             = "10"
  enrollment_cert_id    = data.zpa_enrollment_cert.connector.id
  zcomponent_id         = zpa_app_connector_group.aws_app_connector_group.id
}

data "zpa_enrollment_cert" "connector" {
    name = "Connector"
}

# Create the App Connector user_data file
locals {
  appuserdata = <<APPUSERDATA
#!/bin/bash
#Stop the App Connector service which was auto-started at boot time
systemctl stop zpa-connector
#Create a file from the App Connector provisioning key created in the ZPA Admin Portal
#Make sure that the provisioning key is between double quotes
echo "${zpa_provisioning_key.region1_provisioning_key.provisioning_key}" > /opt/zscaler/var/provision_key
#Run a yum update to apply the latest patches
yum update -y
#Add hosts
echo -e "${module.workload1.private_ip[0]} fileserver.zstest.net" > /etc/hosts
#Start the App Connector service to enroll it in the ZPA cloud
systemctl start zpa-connector
#Wait for the App Connector to download latest build
sleep 60
#Stop and then start the App Connector for the latest build
systemctl stop zpa-connector
systemctl start zpa-connector
APPUSERDATA
}
resource "local_file" "app-connector-user-data-file" {
  content  = local.appuserdata
  filename = "ac_user_data.txt"
}
# 4. Create App Connector network, routing, and appliance
# Create subnet for App Connector network in X availability zones per az_count variable
resource "aws_subnet" "ac-subnet" {
  provider = aws.region1
  count = var.az_count
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 220)
  vpc_id            = aws_vpc.vpc1.id
  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-ac-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}
# Create Route Tables for AC subnets pointing to NAT Gateway resource in each AZ
resource "aws_route_table" "ac-rt" {
  provider = aws.region1
  count = length(aws_subnet.ac-subnet.*.id)
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.ngw.*.id, count.index)
  }
  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-ac-rt-ngw-${count.index + 1}-${var.name_suffix}" }
  )
}
# AC subnet NATGW Route Table Association
resource "aws_route_table_association" "ac-rt-association" {
  provider = aws.region1
  count          = length(aws_subnet.ac-subnet.*.id)
  subnet_id      = aws_subnet.ac-subnet.*.id[count.index]
  route_table_id = aws_route_table.ac-rt.*.id[count.index]
}
# Create X AC VMs per ac_count which will span equally across designated availability zones per az_count
# E.g. ac_count set to 4 and az_count set to 2 will create 2x App Connectors in AZ1 and 2x App Connectors in AZ2
module "ac-vm" {
  providers = {
    aws = aws.region1
  }
  source             = "../modules/terraform-2region-zsac1-aws"
  ac_count           = var.ac_count
  name_prefix        = var.name_prefix
  resource_tag       = var.name_suffix
  global_tags        = local.global_tags
  vpc                = aws_vpc.vpc1.id
  subnet_id          = aws_subnet.ac-subnet.*.id
  instance_key       = aws_key_pair.deployer.key_name
  user_data          = local.appuserdata
  acvm_instance_type = var.acvm_instance_type
}
# Create Application Segment
resource "zpa_application_segment" "region1_applications" {
  name             = "Region1-Fileserver-${var.name_suffix}"
  description      = "Region1 Fileserver"
  enabled          = true
  health_reporting = "ON_ACCESS"
  bypass_type      = "NEVER"
  is_cname_enabled = true
  tcp_port_range {
    from = "80"
    to   = "80"
  }
  tcp_port_range {
    from = "443"
    to   = "443"
  }
  tcp_port_range {
    from = "8080"
    to   = "8080"
  }
  domain_names     = ["fileserver.zstest.net"]
  segment_group_id = zpa_segment_group.region1_segment_group.id
  server_groups {
    id = [zpa_server_group.region1_servers.id]
  }
}
## Create Server Group
resource "zpa_server_group" "region1_servers" {
  name              = "Region1-Servers-${var.name_suffix}"
  description       = "Region1 Servers"
  enabled           = true
  dynamic_discovery = true
  app_connector_groups {
    id = [zpa_app_connector_group.aws_app_connector_group.id]
  }
}
## Create Segment Group
resource "zpa_segment_group" "region1_segment_group" {
  name            = "Region1-Segment-${var.name_suffix}"
  description     = "Region1 Segment Group"
  enabled         = true
  #policy_migrated = true
}
## Retrieve Access Policy ID
data "zpa_policy_type" "access_policy" {
    policy_type = "ACCESS_POLICY"
}
## Create Access Policy for new Segments
resource "zpa_policy_access_rule" "region1_workloads" {
  name                          = "Region1-Workloads-${var.name_suffix}"
  description                   = "Region1 Workloads"
  action                        = "ALLOW"
  operator = "AND"
  policy_set_id = data.zpa_policy_type.access_policy.id
  app_connector_groups {
    id = [zpa_app_connector_group.aws_app_connector_group.id]
  }
  conditions {
    negated = false
    operator = "OR"
    operands {
      object_type = "APP"
      lhs = "id"
      rhs = zpa_application_segment.region1_applications.id
    }
  }
}
## Create Client Machine
module "client" {
  providers = {
  aws = aws.region2
  }
  source       = "../modules/terraform-zsworkload-win-ambass-aws"
  name_prefix  = "${var.name_prefix}"
  name_suffix  = "${var.name_suffix}"
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  vpc          = aws_vpc.vpc2.id
  subnet       = aws_subnet.pubsubnet2.*.id
  instance_type = "t3.medium"
  instance_key = aws_key_pair.deployer2.key_name
  pem_output   = tls_private_key.key.private_key_pem
  bastion_ip   = module.bastion.public_ip
  aws_region1 = var.aws_region1
  aws_region2 = var.aws_region2
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}