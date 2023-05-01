data "aws_region" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc
}
data "aws_security_group" selected {
  vpc_id = var.vpc
  name   = "default"
}

# Create Route 53 outbound endpoint
resource "aws_route53_resolver_endpoint" "zpa-r53-ep" {
  name      = "${var.name_prefix}-r53-resolver-ep-${var.resource_tag}"
  direction = "OUTBOUND"

  security_group_ids = [
    data.aws_security_group.selected.id
  ]

  dynamic "ip_address" {
    for_each = var.r53_subnet_ids
    iterator = subnet_id

    content {
      subnet_id = subnet_id.value
    }
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-r53-resolver-ep-${var.resource_tag}" }
  )
}

# Create Route 53 resolver rule to steer ZPA desired domain requests to Cloud Connector
resource "aws_route53_resolver_rule" "fwd" {
  for_each             = var.domain_names
  domain_name          = each.value.domain_name
  name                 = "${var.name_prefix}-r53-rule-${each.key}-${var.resource_tag}"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.zpa-r53-ep.id

  target_ip {
    ip = var.target_address
  }

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-r53-rules-${each.key}-${var.resource_tag}" }
  )
}

# Associate Route 53 Resolver rule to VPC
resource "aws_route53_resolver_rule_association" "r53-rule-association_1" {
  for_each         = var.domain_names
  resolver_rule_id = aws_route53_resolver_rule.fwd[each.key].id
  vpc_id           = var.vpc
}
