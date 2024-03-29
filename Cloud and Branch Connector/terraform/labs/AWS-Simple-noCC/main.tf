# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Map default tags with values to be assigned to all tagged resources
locals {
  global_tags = {
  Owner       = var.owner_tag
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
  key_name   = "${var.name_prefix}-key-${var.name_suffix}"
  public_key = tls_private_key.key.public_key_openssh

  provisioner "local-exec" {
    command = <<EOF
      echo "${tls_private_key.key.private_key_pem}" > ${var.name_prefix}-key-${var.name_suffix}.pem
      chmod 0600 ${var.name_prefix}-key-${var.name_suffix}.pem
EOF
  }
}

# 1. Network Creation
# Identify availability zones available for region selected
data "aws_availability_zones" "available" {
  state = "available"
}


# Create a new VPC
resource "aws_vpc" "vpc1" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(local.global_tags,
        { Name = "${var.name_prefix}-vpc1-${var.name_suffix}" }
  )
}


# Create an Internet Gateway
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
         { Name = "${var.name_prefix}-vpc1-igw-${var.name_suffix}" }
   )
}


# Create Public/NAT and Private/Workload Subnets
resource "aws_subnet" "pubsubnet" {
  count = 1

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 101)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
         { Name = "${var.name_prefix}-vpc1-public-subnet-${count.index + 1}-${var.name_suffix}" }
   )
}


resource "aws_subnet" "privsubnet" {
  count             = 1

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.vpc1.cidr_block, 8, count.index + 1)
  vpc_id            = aws_vpc.vpc1.id

  tags = merge(local.global_tags,
         { Name = "${var.name_prefix}-vpc1-workload-subnet-${count.index + 1}-${var.name_suffix}" }
   )
}


# Create a public Route Table towards IGW
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
  count           = length(aws_subnet.pubsubnet.*.id)
  subnet_id       = aws_subnet.pubsubnet.*.id[count.index]
  route_table_id  = aws_route_table.routetablepublic1.id
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

# 3. Create Workload
# Create Workloads
module "workload" {
  workload_count  = var.workload_count
  source          = "../modules/terraform-zsworkload-linux-aws"
  name_prefix  = "${var.name_prefix}"
  resource_tag = var.name_suffix
  global_tags  = local.global_tags
  vpc          = aws_vpc.vpc1.id
  subnet       = aws_subnet.privsubnet.*.id
  instance_type = "t3.medium"
  instance_key = aws_key_pair.deployer.key_name
}

# 4. Routing thru NAT GW for private subnets (workload servers)
# Create Route Table for private subnet pointing to NAT Gateway resource
resource "aws_route_table" "routetableprivate" {
  count = length(aws_subnet.privsubnet.*.id)
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.*.id[0]
  }

  tags = merge(local.global_tags,
         { Name = "${var.name_prefix}-natgw-rt-${count.index + 1}-${var.name_suffix}" }
   )
}

# Create Workload Route Table Association
resource "aws_route_table_association" "private-rt-asssociation" {
  count          = length(aws_subnet.privsubnet.*.id)
  subnet_id      = aws_subnet.privsubnet.*.id[count.index]
  route_table_id = aws_route_table.routetableprivate.*.id[count.index]
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
    private_key = file("${path.module}/zscc-key-${var.name_suffix}.pem")
  }
  depends_on = [module.workload,module.bastion]
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
    private_key = file("${path.module}/zscc-key-${var.name_suffix}.pem")
  }
  depends_on = [null_resource.user-mapping]
}