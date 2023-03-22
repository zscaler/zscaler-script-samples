data "aws_region" "current" {}
data "aws_vpc" "selected" {
  id = var.vpc
}

# Configure target group and register IP addresses
resource "aws_lb_target_group" "gwlb-target-group" {
  name     = "${var.name_prefix}-cc-target-${var.resource_tag}"
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = var.vpc
  target_type = "ip"

  health_check {
    port     = var.http_probe_port
    protocol = "HTTP"
    path     = "/?cchealth"
    interval = var.interval
    healthy_threshold = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }
}

# Register all Primary Service Interface IPs as targets to gwlb
resource "aws_lb_target_group_attachment" "gwlb-target-group-attachment1" {
  count = length(var.cc_service_ips)
  target_group_arn = aws_lb_target_group.gwlb-target-group.arn
  target_id        = element(var.cc_service_ips, count.index)

  depends_on       = [var.cc_service_ips]
}


# Configure the load balancer and listener
resource "aws_lb" "gwlb" {
  load_balancer_type = "gateway"
  name               = "${var.name_prefix}-cc-gwlb-${var.resource_tag}"
  enable_cross_zone_load_balancing = false

  subnets = var.cc_subnet_ids

  tags = merge(var.global_tags,
        { Name = "${var.name_prefix}-gwlb-${var.resource_tag}" }
  )
}

resource "aws_lb_listener" "gwlb-listener" {
  load_balancer_arn = aws_lb.gwlb.id

  default_action {
    target_group_arn = aws_lb_target_group.gwlb-target-group.id
    type             = "forward"
  }
}
