# Configure the AWS Provider
provider "aws" {
  region = var.aws_region1
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

resource "aws_key_pair" "deployer" {
  key_name   = "${var.name_prefix}-aws-key-${var.name_suffix}"
  public_key = tls_private_key.key.public_key_openssh

  provisioner "local-exec" {
    command = <<EOF
      echo "${tls_private_key.key.private_key_pem}" > ${var.name_prefix}-aws-key-${var.name_suffix}.pem
      chmod 0600 ${var.name_prefix}-aws-key-${var.name_suffix}.pem
EOF
  }
}

# Create an AWS Secrets Manager object in Region1
resource "aws_secretsmanager_secret" "secretmaster" {
   name = "ZS/CC/credentials/zscc-${var.name_suffix}"
   recovery_window_in_days = 0
}
 
# Import CC credentials into Secrets Manager objects
resource "aws_secretsmanager_secret_version" "sversion" {
  secret_id = aws_secretsmanager_secret.secretmaster.id
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
  state = "available"
}

# Create new VPCs
resource "aws_vpc" "vpc1" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-${var.name_suffix}" }
  )
}

# # Create DHCP Options (to set ZPA DNS to public) and associate to VPC(s)
# resource "aws_vpc_dhcp_options" "dns_resolver" {
#   domain_name_servers = ["8.8.8.8", "8.8.4.4"]
# }

# resource "aws_vpc_dhcp_options_association" "workload_dns_resolver" {
#   vpc_id          = aws_vpc.vpc1.id
#   dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
# }

# resource "aws_vpc_dhcp_options_association" "cc_dns_resolver" {
#   vpc_id          = aws_vpc.vpc1.id
#   dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
# }

# Create Internet Gateways
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-igw-${var.name_suffix}" }
  )
}

# Create equal number of Public/NAT Subnets Subnets to how many Cloud Connector subnets exist. 
resource "aws_subnet" "pubsubnet" {
  count = length(aws_subnet.cc-subnet.*.id)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 101)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-public-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

resource "aws_subnet" "privatesubnet" {
  count = length(aws_subnet.cc-subnet.*.id)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 1)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-private-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

# Create public Route Tables toward IGWs.
resource "aws_route_table" "routetablepublic1" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-igw-rt-${var.name_suffix}" }
  )
}

# Create equal number of Route Table associations to how many Public subnets exist. 
resource "aws_route_table_association" "routetablepublic1" {
  count = length(aws_subnet.pubsubnet.*.id)
  subnet_id      = aws_subnet.pubsubnet.*.id[count.index]
  route_table_id = aws_route_table.routetablepublic1.id
}

# Create NAT Gateway and assign EIP per AZ.
resource "aws_eip" "eip" {
  count      = length(aws_subnet.pubsubnet.*.id)
  vpc        = true
  depends_on = [aws_internet_gateway.igw1]

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-eip-az${count.index + 1}-${var.name_suffix}" }
  )
}

# Create 1 NAT Gateway per Public Subnet.
resource "aws_nat_gateway" "ngw" {
  count = length(aws_subnet.pubsubnet.*.id)
  allocation_id = aws_eip.eip.*.id[count.index]
  subnet_id     = aws_subnet.pubsubnet.*.id[count.index]
  depends_on    = [aws_internet_gateway.igw1]
  
  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-natgw-az${count.index + 1}-${var.name_suffix}" }
  )
}

# 2. Create Bastion Host
module "bastion" {
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
  count        = var.win_vm_count
  source       = "../modules/terraform-zsworkload-win-aws"
  name_prefix  = "${var.name_prefix}"
  name_suffix  = "${var.name_suffix}"
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  vpc          = aws_vpc.vpc1.id
  subnet       = aws_subnet.privatesubnet.*.id
  instance_type = "t3.medium"
  instance_key = aws_key_pair.deployer.key_name
  pem_output   = tls_private_key.key.private_key_pem
}

# 3b. Create Workload2
module "workload2" {
  count        = var.lin_vm_count
  source       = "../modules/terraform-zsworkload-linux-aws"
  name_prefix  = "${var.name_prefix}"
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  vpc          = aws_vpc.vpc1.id
  subnet       = aws_subnet.privatesubnet.*.id
  instance_type = "t3.medium"
  instance_key = aws_key_pair.deployer.key_name
}

# 4. Create CC network, routing, and appliance
# Create subnet for CC network in X availability zones per az_count variable
resource "aws_subnet" "cc-subnet" {
  count = var.az_count

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 200)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-cc-subnet-${count.index + 1}-${var.name_suffix}" }
  )
}

# Create Route Tables for CC subnets pointing to NAT Gateway resource in each AZ
resource "aws_route_table" "cc-rt" {
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

# CC subnet NATGW Route Table Association
resource "aws_route_table_association" "cc-rt-association" {
  count          = length(aws_subnet.cc-subnet.*.id)
  subnet_id      = aws_subnet.cc-subnet.*.id[count.index]
  route_table_id = aws_route_table.cc-rt.*.id[count.index]
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
  source             = "../modules/terraform-zscc-aws-tagging"
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

resource "aws_route_table" "workload-rt" {
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
# Create GWLB in all CC subnets. Create Target Group and attach primary service IP from all created Cloud
# Connectors as registered targets.
module "gwlb" {
  source                  = "../modules/terraform-zsgwlb-aws-tagging"
  name_prefix             = var.name_prefix
  resource_tag            = var.name_suffix
  global_tags             = local.global_tags
  vpc                     = aws_vpc.vpc1.id
  cc_subnet_ids           = aws_subnet.cc-subnet.*.id
  cc_service_ips          = module.cc-vm.service_private_ip
  http_probe_port         = var.http_probe_port
  cross_zone_lb_enabled   = var.cross_zone_lb_enabled
  interval                = 10
  healthy_threshold       = 3
  unhealthy_threshold     = 3
}
# Create Endpoint Service associated with GWLB and 1x GWLB Endpoint per CC subnet
module "gwlb-endpoint" {
  source                  = "../modules/terraform-zsgwlbendpoint-aws-tagging"
  name_prefix             = var.name_prefix
  resource_tag            = var.name_suffix
  global_tags             = local.global_tags
  vpc                     = aws_vpc.vpc1.id
  cc_subnet_ids           = aws_subnet.cc-subnet.*.id
  gwlb_arn                = module.gwlb.gwlb_arn
}

# Create equal number of Route Table associations to how many Workload subnets exist. 
resource "aws_route_table_association" "workload-rt-association" {
  count = length(aws_subnet.privatesubnet.*.id)
  subnet_id      = aws_subnet.privatesubnet.*.id[count.index]
  route_table_id = aws_route_table.workload-rt.*.id[count.index]
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
    private_key = file("${path.module}/zscc-aws-key-${var.name_suffix}.pem")
  }
  depends_on = [module.workload1,module.workload2,module.bastion,module.cc-vm]
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
    private_key = file("${path.module}/zscc-aws-key-${var.name_suffix}.pem")
  }
  depends_on = [null_resource.user-mapping]
}