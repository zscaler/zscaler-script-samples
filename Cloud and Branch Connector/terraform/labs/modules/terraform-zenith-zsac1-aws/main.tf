#data "aws_region" "current" {}
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

data "aws_ssm_parameter" "amazon_linux_latest" {
  name  = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_iam_role" "ac-iam-role" {
  count = var.ac_count
  name = "${var.name_prefix}-ac-${count.index + 1}-region1-node-iam-role-${var.resource_tag}"
  
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

resource "aws_iam_role_policy_attachment" "SSMManagedInstanceCore" {
  count = var.ac_count
  policy_arn = "arn:aws:iam::aws:policy/${var.iam_role_policy_ssmcore}"
  role       = aws_iam_role.ac-iam-role.*.name[count.index]
}

resource "aws_iam_instance_profile" "ac-host-profile" {
  count      = var.ac_count
  name       = "${var.name_prefix}-ac-${count.index + 1}-region1-host-profile-${var.resource_tag}"
  role       = aws_iam_role.ac-iam-role.*.name[count.index]
}

resource "aws_security_group" "ac-sg" {
  count       = var.ac_count
  name        = "${var.name_prefix}-ac-${count.index + 1}-sg-${var.resource_tag}"
  description = "Security group for App Connector-${count.index + 1} interfaces"
  vpc_id      = var.vpc

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-ac-${count.index + 1}-sg-${var.resource_tag}" }
  )
}

resource "aws_security_group_rule" "ac-node-ingress-ssh" {
  count             = var.ac_count
  description       = "Allow SSH to App Connector VM"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.ac-sg.*.id[count.index]
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "ingress"
}

# Create App Connector VM
resource "aws_instance" "ac-vm" {
  count                       = var.ac_count
  ami                         = data.aws_ssm_parameter.amazon_linux_latest.value
  instance_type               = var.acvm_instance_type
  iam_instance_profile        = aws_iam_instance_profile.ac-host-profile.*.name[count.index]
  vpc_security_group_ids      = [aws_security_group.ac-sg.*.id[count.index]]
  subnet_id                   = element(var.subnet_id, count.index)
  key_name                    = var.instance_key
  associate_public_ip_address = false
  user_data                   = base64encode(var.user_data)
  
  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-ac-vm-${count.index + 1}-${var.resource_tag}" }
  )
}
