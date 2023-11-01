#data "aws_region" "current" {}
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

# Locate current CC AMI by product code
data "aws_ami" "cloudconnector" {
  most_recent = true

  filter {
    name   = "product-code"
    values = ["2l8tfysndbav4tv2nfjwak3cu"]
  }

  owners = ["aws-marketplace"]
}


# Create IAM role and instance profile w/ SSM and Secrets Manager access policies
resource "aws_iam_role" "cc-node-iam-role" {
  count = local.valid_cc_create ? var.cc_count : 0
  name = "${var.name_prefix}-cc-${count.index + 1}-region2-node-iam-role-${var.resource_tag}"

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

resource "aws_iam_role_policy_attachment" "SecretsManagerReadWrite" {
  count = local.valid_cc_create ? var.cc_count : 0
  policy_arn = "arn:aws:iam::aws:policy/${var.iam_role_policy_smrw}"
  role       = aws_iam_role.cc-node-iam-role.*.name[count.index]
}

resource "aws_iam_role_policy_attachment" "SSMManagedInstanceCore" {
  count = local.valid_cc_create ? var.cc_count : 0
  policy_arn = "arn:aws:iam::aws:policy/${var.iam_role_policy_ssmcore}"
  role       = aws_iam_role.cc-node-iam-role.*.name[count.index]
}

resource "aws_iam_instance_profile" "cc-host-profile" {
  count      = local.valid_cc_create ? var.cc_count : 0
  name       = "${var.name_prefix}-cc-${count.index + 1}-region2-host-profile-${var.resource_tag}"
  role       = aws_iam_role.cc-node-iam-role.*.name[count.index]
}

# Create Security Group for CC Management Interface
resource "aws_security_group" "cc-mgmt-sg" {
  count = local.valid_cc_create ? var.cc_count : 0
  name        = "${var.name_prefix}-cc-${count.index + 1}-mgmt-sg-${var.resource_tag}"
  description = "Security group for Cloud Connector-${count.index + 1} management interface"
  vpc_id      = var.vpc

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-cc-${count.index + 1}-mgmt-sg-${var.resource_tag}" }
  )
}

resource "aws_security_group_rule" "cc-mgmt-ingress-ssh" {
  count = local.valid_cc_create ? var.cc_count : 0
  description       = "Allow SSH to Cloud Connector VM"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.cc-mgmt-sg.*.id[count.index]
  cidr_blocks       = ["${var.bastion_ip}/32","10.0.0.0/8"]
  type              = "ingress"
}

# Create Security Group for Service Interface
resource "aws_security_group" "cc-service-sg" {
  count = local.valid_cc_create ? var.cc_count : 0
  name        = "${var.name_prefix}-cc-${count.index + 1}-svc-sg-${var.resource_tag}"
  description = "Security group for Cloud Connector-${count.index + 1} service interfaces"
  vpc_id      = var.vpc

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-cc-${count.index + 1}-svc-sg-${var.resource_tag}" }
  )
}

resource "aws_security_group_rule" "all-vpc-ingress-cc" {
  count = local.valid_cc_create ? var.cc_count : 0
  description       = "Allow all VPC traffic"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.cc-service-sg.*.id[count.index]
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "ingress"
}

# Create Cloud Connector VM
resource "aws_instance" "cc-vm" {
  count = local.valid_cc_create ? var.cc_count : 0
  ami                         = "ami-03e4e2d7e54e68877"
  instance_type               = var.ccvm_instance_type
  iam_instance_profile        = aws_iam_instance_profile.cc-host-profile.*.name[count.index]
  vpc_security_group_ids      = [aws_security_group.cc-mgmt-sg.*.id[count.index]]
  subnet_id                   = element(var.mgmt_subnet_id, count.index)
  key_name                    = var.instance_key
  associate_public_ip_address = true
  user_data                   = base64encode(var.user_data)
  
  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-cc-vm-${count.index + 1}-${var.resource_tag}" }
  )
}

# Create Cloud Connector Service Interface
resource "aws_network_interface" "cc-vm-service-nic" {
  count = local.valid_cc_create ? var.cc_count : 0
  description       = "Primary Interface for service traffic"
  subnet_id         = element(var.service_subnet_id, count.index)
  security_groups   = [aws_security_group.cc-service-sg.*.id[count.index]]
  source_dest_check = false
  private_ips_count = 1
  attachment {
    instance        = aws_instance.cc-vm[count.index].id
    device_index    = 1
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-cc-vm-${count.index + 1}-${var.resource_tag}-SrvcIF" }
  )
}

data "aws_network_interface" "cc-vm-service-eni" {
  count = local.valid_cc_create ? var.cc_count : 0
  id = element(aws_network_interface.cc-vm-service-nic.*.id, count.index)
}

resource "aws_network_interface" "cc-vm-service-nic2" {
  count             = local.valid_cc_create && var.cc_instance_size != "small" ? var.cc_count : 0
  description       = "Interface for service traffic"
  subnet_id         = element(var.service_subnet_id, count.index)
  security_groups   = [aws_security_group.cc-service-sg.*.id[count.index]]
  source_dest_check = false
  attachment {
    instance        = aws_instance.cc-vm[count.index].id
    device_index    = 2
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-cc-vm-${count.index + 1}-${var.resource_tag}-SrvcIF-2" }
  )
}

resource "aws_network_interface" "cc-vm-service-nic3" {
  count             = local.valid_cc_create && var.cc_instance_size != "small" ? var.cc_count : 0
  description       = "Interface for service traffic"
  subnet_id         = element(var.service_subnet_id, count.index)
  security_groups   = [aws_security_group.cc-service-sg.*.id[count.index]]
  source_dest_check = false
  attachment {
    instance        = aws_instance.cc-vm[count.index].id
    device_index    = 3
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-cc-vm-${count.index + 1}-${var.resource_tag}-SrvcIF-3" }
  )
}

resource "aws_network_interface" "cc-vm-service-nic4" {
  count             = local.valid_cc_create && var.cc_instance_size == "large" ? var.cc_count : 0
  description       = "Interface for service traffic"
  subnet_id         = element(var.service_subnet_id, count.index)
  security_groups   = [aws_security_group.cc-service-sg.*.id[count.index]]
  source_dest_check = false
  attachment {
    instance        = aws_instance.cc-vm[count.index].id
    device_index    = 4
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-cc-vm-${count.index + 1}-${var.resource_tag}-SrvcIF-4" }
  )
}