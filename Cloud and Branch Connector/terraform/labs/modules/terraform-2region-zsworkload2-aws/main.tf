# data "aws_region" "current" {}
data "aws_vpc" "selected" {
  provider = aws.region2
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
  owners           = ["494789115339"]

  filter {
    name   = "name"
    values = ["packer-ubuntu-jammy*"]
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

#   # Find the 22.04 image
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   # With the right virtualization type
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   # Check that the image is published by Canonical (a trusted source)
#   owners = ["099720109477"]
# }

resource "aws_iam_role" "workload-region2-iam-role" {
  name = "${var.name_prefix}-workload-region2-iam-role-${var.resource_tag}"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workload-region2-iam-role.name
}

resource "aws_security_group" "node-sg-workload" {
  name        = "${var.name_prefix}-workload-region2-sg-${var.resource_tag}"
  description = "Security group for all Server nodes in the cluster"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-workload-region2-sg-${var.resource_tag}" }
  )
}

resource "aws_security_group_rule" "workload-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node-sg-workload.id
  source_security_group_id = aws_security_group.node-sg-workload.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workload-node-ingress-rdp" {
  description       = "RDP for workload"
  from_port         = 3389
  protocol          = "tcp"
  security_group_id = aws_security_group.node-sg-workload.id
  cidr_blocks       = ["${var.bastion_ip}/32"]
  to_port           = 3389
  type              = "ingress"
}

resource "aws_security_group_rule" "workload-node-ingress-ssh" {
  description       = "SSH for workload"
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.node-sg-workload.id
  cidr_blocks       = ["${var.bastion_ip}/32"]
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "workload-node-ingress-zpa" {
  description       = "ZPA for workload"
  from_port         = 1
  protocol          = "tcp"
  security_group_id = aws_security_group.node-sg-workload.id
  cidr_blocks       = ["${var.vpc_cidr}"]
  to_port           = 65535
  type              = "ingress"
}

resource "aws_iam_instance_profile" "workload_host_profile" {
  name = "${var.name_prefix}-workload_host_region2_profile-${var.resource_tag}"
  role = aws_iam_role.workload-region2-iam-role.name
}

resource "aws_instance" "workload" {
  count                       = 1
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.instance_key
  subnet_id                   = element(var.subnet,count.index)
  iam_instance_profile        = aws_iam_instance_profile.workload_host_profile.name
  vpc_security_group_ids      = [aws_security_group.node-sg-workload.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.disk_size
    delete_on_termination = true
  }
  lifecycle {
    ignore_changes = [ami]
  }
  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-workload-region2-${var.resource_tag}" }
  )
}