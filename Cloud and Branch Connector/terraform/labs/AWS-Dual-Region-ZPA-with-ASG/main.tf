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
  "${var.name_prefix}-cluster-${var.name_suffix}" = "shared"
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

# Locate Latest CC AMI by product code
################################################################################
data "aws_ami" "cloudconnector-region1" {
  provider = aws.region1
  most_recent = true

  filter {
    name   = "product-code"
    values = ["2l8tfysndbav4tv2nfjwak3cu"]
  }

  owners = ["aws-marketplace"]
}
data "aws_ami" "cloudconnector-region2" {
  provider = aws.region2
  most_recent = true

  filter {
    name   = "product-code"
    values = ["2l8tfysndbav4tv2nfjwak3cu"]
  }

  owners = ["aws-marketplace"]
}

# Create the specified CC VMs via Launch Template and Autoscaling Group
module "cc_asg" {
    providers = {
    aws = aws.region1
   }
  source                    = "../modules/terraform-zscc-2region-asg1-aws"
  name_prefix               = var.name_prefix
  resource_tag              = var.name_suffix
  global_tags               = local.global_tags
  cc_subnet_ids             = aws_subnet.cc-subnet.*.id
  ccvm_instance_type        = var.ccvm_instance_type
  cc_instance_size          = var.cc_instance_size
  instance_key              = aws_key_pair.deployer.key_name
  user_data                 = local.userdata
  iam_instance_profile      = module.cc_iam.iam_instance_profile_id
  mgmt_security_group_id    = module.cc_sg.mgmt_security_group_id
  service_security_group_id = module.cc_sg.service_security_group_id
  ami_id                    = contains(var.ami_id, "") ? [data.aws_ami.cloudconnector-region1.id] : var.ami_id
  ebs_volume_type           = var.ebs_volume_type
  ebs_encryption_enabled    = var.ebs_encryption_enabled
  byo_kms_key_alias         = var.byo_kms_key_alias
  max_size                  = var.max_size
  min_size                  = var.min_size
  target_group_arn          = module.gwlb.target_group_arn
  target_cpu_util_value     = var.target_cpu_util_value
  health_check_grace_period = var.health_check_grace_period
  instance_warmup           = var.instance_warmup
  protect_from_scale_in     = var.protect_from_scale_in
  launch_template_version   = var.launch_template_version
  warm_pool_enabled = var.warm_pool_enabled
  ### only utilzed if warm_pool_enabled set to true ###
  warm_pool_state                            = var.warm_pool_state
  warm_pool_min_size                         = var.warm_pool_min_size
  warm_pool_max_group_prepared_capacity      = var.warm_pool_max_group_prepared_capacity
  reuse_on_scale_in                          = var.reuse_on_scale_in
  lifecyclehook_instance_launch_wait_time    = var.lifecyclehook_instance_launch_wait_time
  lifecyclehook_instance_terminate_wait_time = var.lifecyclehook_instance_terminate_wait_time
  ### only utilzed if warm_pool_enabled set to true ###
  sns_enabled        = var.sns_enabled
  sns_email_list     = var.sns_email_list
  byo_sns_topic      = var.byo_sns_topic
  byo_sns_topic_name = var.byo_sns_topic_name

  depends_on = [
    local_file.user-data-file,
  ]
}

module "cc_asg2" {
    providers = {
    aws = aws.region2
   }
  source                    = "../modules/terraform-zscc-2region-asg2-aws"
  name_prefix               = var.name_prefix
  resource_tag              = var.name_suffix
  global_tags               = local.global_tags
  cc_subnet_ids             = aws_subnet.cc-subnet2.*.id
  ccvm_instance_type        = var.ccvm_instance_type
  cc_instance_size          = var.cc_instance_size
  instance_key              = aws_key_pair.deployer2.key_name
  user_data                 = local.userdata
  iam_instance_profile      = module.cc_iam2.iam_instance_profile_id
  mgmt_security_group_id    = module.cc_sg2.mgmt_security_group_id
  service_security_group_id = module.cc_sg2.service_security_group_id
  ami_id                    = contains(var.ami_id, "") ? [data.aws_ami.cloudconnector-region2.id] : var.ami_id
  ebs_volume_type           = var.ebs_volume_type
  ebs_encryption_enabled    = var.ebs_encryption_enabled
  byo_kms_key_alias         = var.byo_kms_key_alias
  max_size                  = var.max_size
  min_size                  = var.min_size
  target_group_arn          = module.gwlb2.target_group_arn
  target_cpu_util_value     = var.target_cpu_util_value
  health_check_grace_period = var.health_check_grace_period
  instance_warmup           = var.instance_warmup
  protect_from_scale_in     = var.protect_from_scale_in
  launch_template_version   = var.launch_template_version
  warm_pool_enabled = var.warm_pool_enabled
  ### only utilzed if warm_pool_enabled set to true ###
  warm_pool_state                            = var.warm_pool_state
  warm_pool_min_size                         = var.warm_pool_min_size
  warm_pool_max_group_prepared_capacity      = var.warm_pool_max_group_prepared_capacity
  reuse_on_scale_in                          = var.reuse_on_scale_in
  lifecyclehook_instance_launch_wait_time    = var.lifecyclehook_instance_launch_wait_time
  lifecyclehook_instance_terminate_wait_time = var.lifecyclehook_instance_terminate_wait_time
  ### only utilzed if warm_pool_enabled set to true ###
  sns_enabled        = var.sns_enabled
  sns_email_list     = var.sns_email_list
  byo_sns_topic      = var.byo_sns_topic
  byo_sns_topic_name = var.byo_sns_topic_name

  depends_on = [
    local_file.user-data-file,
  ]
}

################################################################################
# 5. Create IAM Policy, Roles, and Instance Profiles to be assigned to CC
################################################################################
module "cc_iam" {
    providers = {
    aws = aws.region1
   }
  source       = "../modules/terraform-zscc-2region-iam1-aws"
  name_prefix  = var.name_prefix
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  asg_enabled  = var.asg_enabled
  secret_name  = aws_secretsmanager_secret.secretmaster.name

  depends_on = [ aws_secretsmanager_secret_version.sversion ]
}

module "cc_iam2" {
    providers = {
    aws = aws.region2
   }
  source       = "../modules/terraform-zscc-2region-iam2-aws"
  name_prefix  = var.name_prefix
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  asg_enabled  = var.asg_enabled
  secret_name  = aws_secretsmanager_secret.secretmaster2.name

  depends_on = [ aws_secretsmanager_secret_version.sversion2 ]
}

################################################################################
# 6. Create Security Group and rules to be assigned to CC mgmt and and service 
#    interface(s)
################################################################################
module "cc_sg" {
    providers = {
    aws = aws.region1
   }
  source                   = "../modules/terraform-zscc-2region-sg1-aws"
  name_prefix              = var.name_prefix
  resource_tag             = var.name_suffix
  global_tags              = local.global_tags
  vpc_id                   =  aws_vpc.vpc1.id
  http_probe_port          = var.http_probe_port
  mgmt_ssh_enabled         = var.mgmt_ssh_enabled
  all_ports_egress_enabled = var.all_ports_egress_enabled
}

module "cc_sg2" {
  providers = {
    aws = aws.region2
  }
  source                   = "../modules/terraform-zscc-2region-sg2-aws"
  name_prefix              = var.name_prefix
  resource_tag             = var.name_suffix
  global_tags              = local.global_tags
  vpc_id                   =  aws_vpc.vpc2.id
  http_probe_port          = var.http_probe_port
  mgmt_ssh_enabled         = var.mgmt_ssh_enabled
  all_ports_egress_enabled = var.all_ports_egress_enabled
}

resource "aws_route_table" "workload-rt" {
  provider = aws.region1
  count = length(aws_subnet.privatesubnet.*.id)
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block = "0.0.0.0/0"
      vpc_endpoint_id = element(module.gwlb-endpoint.gwlbe, count.index)
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
      vpc_endpoint_id = element(module.gwlb-endpoint2.gwlbe, count.index)
  }
  route {
    cidr_block     = "${module.bastion.public_ip}/32"
    gateway_id     = aws_internet_gateway.igw2.id
  }

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-private-subnet-rt-${count.index + 1}-${var.name_suffix}" }
  )
}

# Create GWLB in all CC subnets. Create Target Group and attach primary service IP from all created Cloud
# Connectors as registered targets.
module "gwlb" {
    providers = {
    aws = aws.region1
   }
  source                = "../modules/terraform-zscc-2region-gwlb1-aws"
  gwlb_name             = "${var.name_prefix}-cc-gwlb-${var.name_suffix}"
  target_group_name     = "${var.name_prefix}-cc-target-${var.name_suffix}"
  global_tags           = local.global_tags
  vpc_id                = aws_vpc.vpc1.id
  cc_subnet_ids         = aws_subnet.cc-subnet.*.id
  http_probe_port       = var.http_probe_port
  health_check_interval = var.health_check_interval
  healthy_threshold     = var.healthy_threshold
  unhealthy_threshold   = var.unhealthy_threshold
  cross_zone_lb_enabled = var.cross_zone_lb_enabled
  asg_enabled           = var.asg_enabled
  deregistration_delay  = var.deregistration_delay
  flow_stickiness       = var.flow_stickiness
  rebalance_enabled     = var.rebalance_enabled
}
module "gwlb2" {
  providers = {
    aws = aws.region2
  }
  source                = "../modules/terraform-zscc-2region-gwlb2-aws"
  gwlb_name             = "${var.name_prefix}-cc-gwlb-${var.name_suffix}"
  target_group_name     = "${var.name_prefix}-cc-target-${var.name_suffix}"
  global_tags           = local.global_tags
  vpc_id                = aws_vpc.vpc2.id
  cc_subnet_ids         = aws_subnet.cc-subnet2.*.id
  http_probe_port       = var.http_probe_port
  health_check_interval = var.health_check_interval
  healthy_threshold     = var.healthy_threshold
  unhealthy_threshold   = var.unhealthy_threshold
  cross_zone_lb_enabled = var.cross_zone_lb_enabled
  asg_enabled           = var.asg_enabled
  deregistration_delay  = var.deregistration_delay
  flow_stickiness       = var.flow_stickiness
  rebalance_enabled     = var.rebalance_enabled
}

module "gwlb-endpoint" {
    providers = {
    aws = aws.region1
   }
  source              = "../modules/terraform-zscc-2region-gwlbendpoint1-aws"
  name_prefix         = var.name_prefix
  resource_tag        = var.name_suffix
  global_tags         = local.global_tags
  vpc_id              = aws_vpc.vpc1.id
  subnet_ids          = aws_subnet.cc-subnet.*.id
  gwlb_arn            = module.gwlb.gwlb_arn
  acceptance_required = var.acceptance_required
  allowed_principals  = var.allowed_principals
}
module "gwlb-endpoint2" {
  providers = {
    aws = aws.region2
   }
  source              = "../modules/terraform-zscc-2region-gwlbendpoint2-aws"
  name_prefix         = var.name_prefix
  resource_tag        = var.name_suffix
  global_tags         = local.global_tags
  vpc_id              = aws_vpc.vpc2.id
  subnet_ids          = aws_subnet.cc-subnet2.*.id
  gwlb_arn            = module.gwlb2.gwlb_arn
  acceptance_required = var.acceptance_required
  allowed_principals  = var.allowed_principals
}

# Create Lambda Function for Autoscaling support
module "asg_lambda" {
    providers = {
    aws = aws.region1
   }
  source                  = "../modules/terraform-zscc-2region-asg-lambda1-aws"
  name_prefix             = var.name_prefix
  resource_tag            = var.name_suffix
  global_tags             = local.global_tags
  cc_vm_prov_url          = var.cc_vm_prov_url
  secret_name             = aws_secretsmanager_secret.secretmaster.name
  autoscaling_group_names = module.cc_asg.autoscaling_group_ids
  asg_lambda_filename     = var.asg_lambda_filename

  depends_on = [ aws_secretsmanager_secret_version.sversion ]
}

module "asg_lambda2" {
  providers = {
    aws = aws.region2
  }
  source                  = "../modules/terraform-zscc-2region-asg-lambda2-aws"
  name_prefix             = var.name_prefix
  resource_tag            = var.name_suffix
  global_tags             = local.global_tags
  cc_vm_prov_url          = var.cc_vm_prov_url
  secret_name             = aws_secretsmanager_secret.secretmaster2.name
  autoscaling_group_names = module.cc_asg2.autoscaling_group_ids
  asg_lambda_filename     = var.asg_lambda_filename

  depends_on = [ aws_secretsmanager_secret_version.sversion2 ]
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
  #zpa_cloud = "BETA"
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
echo -e "${module.workload1.private_ip[0]} fileserver.region1.acme.com" > /etc/hosts
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