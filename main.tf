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

resource "aws_s3_bucket" "jira_public_lb" {
  bucket = "bh-jira-public-lb"
  acl    = "private"
  region = "us-east-1"

  versioning {
    enabled = true
  }
}

resource "aws_iam_role_policy" "jira_public_lb_lambda" {
  name = "jira-public-lb-lambda"
  role = aws_iam_role.jira_public_lb_lambda.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ],
      "Effect": "Allow",
      "Sid": "LambdaLogging"
    },
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.jira_public_lb.arn}/*"
      ],
      "Effect": "Allow",
      "Sid": "S3"
    },
    {
      "Action": [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": [
        "${aws_lb_target_group.jira_public_443.arn}"
      ],
      "Effect": "Allow",
      "Sid": "ChangeTargetGroups"
    },
    {
      "Action": [
        "elasticloadbalancing:DescribeTargetHealth"
      ],
      "Resource": "*",
      "Effect": "Allow",
      "Sid": "DescribeTargetGroups"
    },
    {
      "Action": [
        "cloudwatch:putMetricData"
      ],
      "Resource": "*",
      "Effect": "Allow",
      "Sid": "CloudWatch"
    }
  ]
}
EOF
}

resource "aws_iam_role" "jira_public_lb_lambda" {
  name        = "jira-public-lb-lambda"
  description = "Managed by Terraform"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "jira_public_lb_updater_443" {
  filename      = "lambda_function.zip"
  function_name = "jira_public_lb_updater_443"
  role          = "${aws_iam_role.jira_public_lb_lambda.arn}"
  handler       = "populate_NLB_TG_with_ALB.lambda_handler"

  source_code_hash = "${filebase64sha256("lambda_function.zip")}"

  runtime     = "python2.7"
  memory_size = 128
  timeout     = 300

  environment {
    variables = {
      ALB_DNS_NAME                      = var.alb_dns_name
      ALB_LISTENER                      = "443"
      S3_BUCKET                         = aws_s3_bucket.jira_public_lb.id
      NLB_TG_ARN                        = aws_lb_target_group.jira_public_443.arn
      MAX_LOOKUP_PER_INVOCATION         = 50
      INVOCATIONS_BEFORE_DEREGISTRATION = 10
      CW_METRIC_FLAG_IP_COUNT           = true
    }
  }
}