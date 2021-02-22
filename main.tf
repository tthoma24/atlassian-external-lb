provider "aws" {
  region = var.aws_region
  version = "2.7.0"
}

resource "aws_eip" "jira-public_us_east_1c" {
  tags = {
    "Name" = "jira-public_us_east_1c"
  }
}

resource "aws_eip" "jira-public_us_east_1d" {
  tags = {
    "Name" = "jira-public_us_east_1d"
  }
}

resource "aws_lb" "jira_public" {
  name                       = "jira-public"
  load_balancer_type         = "network"
  internal                   = false

  subnet_mapping {
    subnet_id     = var.public_subnet_us_east_1c
    allocation_id = aws_eip.jira-public_us_east_1a.ic
  }

  subnet_mapping {
    subnet_id     = var.public_subnet_us_east_1d
    allocation_id = aws_eip.jira-public_us_east_1d.id
  }
}

resource "aws_lb_target_group" "jira_public_80" {
  name              = "jira-public-80"
  port              = 80
  protocol          = "TCP"
  target_type       = "ip"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = false
}

resource "aws_lb_target_group" "jira_public_443" {
  name              = "jira-public-443"
  port              = 443
  protocol          = "TCP"
  target_type       = "ip"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = false
}

resource "aws_lb_listener" "jira_public_80" {
  load_balancer_arn = "${aws_lb.jira_public.arn}"
  port              = "80"
  protocol          = "TCP"

  default_action {
    type	 = "redirect"

    redirect {
      port          = "443"
      protocol      = "TCP"
      status_code   = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "jira_public_443" {
  load_balancer_arn = "${aws_lb.jira_public.arn}"
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.jira_public_443.arn}"
  }
}

