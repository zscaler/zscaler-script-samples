data "aws_region" "current" {}
data "aws_vpc" "selected" {
  id = var.vpc
}

data "aws_ami" "ubuntu" {
  # executable_users = ["self"]
  most_recent      = true
  owners           = ["self"]

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

resource "aws_iam_role" "workload-lin-iam-role" {
  name = "${var.name_prefix}-workload-lin-iam-role-${var.resource_tag}"
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

resource "aws_iam_role_policy_attachment" "lin-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workload-lin-iam-role.name
}

resource "aws_security_group" "lin-node-sg-workload" {
  name        = "${var.name_prefix}-workload-lin-sg-${var.resource_tag}"
  description = "Security group for all Server nodes in the cluster"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-workload-lin-sg-${var.resource_tag}" }
  )
}

resource "aws_security_group_rule" "workload-lin-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.lin-node-sg-workload.id
  source_security_group_id = aws_security_group.lin-node-sg-workload.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workload-lin-ingress-ssh" {
  description       = "SSH for workload"
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.lin-node-sg-workload.id
  cidr_blocks       = ["0.0.0.0/0"]
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "workload-lin-ingress-rdp" {
  description       = "RDP for workload"
  from_port         = 3389
  protocol          = "tcp"
  security_group_id = aws_security_group.lin-node-sg-workload.id
  cidr_blocks       = ["0.0.0.0/0"]
  to_port           = 3389
  type              = "ingress"
}

resource "aws_iam_instance_profile" "workload_lin_host_profile" {
  name = "${var.name_prefix}-workload_host_lin_profile-${var.resource_tag}"
  role = aws_iam_role.workload-lin-iam-role.name
}

resource "aws_instance" "workload" {
  count                       = 1
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.instance_key
  subnet_id                   = element(var.subnet,count.index)
  iam_instance_profile        = aws_iam_instance_profile.workload_lin_host_profile.name
  vpc_security_group_ids      = [aws_security_group.lin-node-sg-workload.id]

  root_block_device {
    volume_size           = var.disk_size
    delete_on_termination = true
  }
  lifecycle {
    ignore_changes = [ami]
  }
  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-workload-lin-${var.resource_tag}" }
  )
}