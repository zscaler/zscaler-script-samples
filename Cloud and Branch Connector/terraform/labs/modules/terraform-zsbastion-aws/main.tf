# data "aws_region" "current" {}
data "aws_vpc" "selected" {
  id = var.vpc
}

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

data "aws_ami" "ubuntu" {
  # executable_users = ["self"]
  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["packer-guac-arohyans*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# # Get a reference to aws_ami.id using a data resource by finding the right AMI
# data "aws_ami" "ubuntu" {
#   # Pick the most recent version of the AMI
#   most_recent = true

#   # Find the 20.04 image
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
#   }

#   # With the right virtualization type
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   # Check that the image is published by Canonical (a trusted source)
#   owners = ["099720109477"]
# }

resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg-${var.resource_tag}"
  description = "Allow SSH access to bastion host and outbound internet access"
  vpc_id      = data.aws_vpc.selected.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-bastion-sg-${var.resource_tag}" }
  )
}

resource "aws_security_group_rule" "ssh" {
  protocol          = "TCP"
  from_port         = 22
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = var.allowed_hosts_from_bastion
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "guacamole" {
  protocol          = "TCP"
  from_port         = 8080
  to_port           = 8080
  type              = "ingress"
  cidr_blocks       = var.allowed_hosts_from_bastion
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "internet" {
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "intranet" {
  protocol  = "-1"
  from_port = 0
  to_port   = 0
  type      = "egress"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.bastion.id
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.instance_key
  subnet_id                   = var.public_subnet
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.disk_size
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-bastion-host-${var.resource_tag}" }
  )
}