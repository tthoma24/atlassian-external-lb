variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_us_east_1c" {
  type = string
}

variable "public_subnet_us_east_1d" {
  type = string
}

variable "jira_alb_dns_name" {
  type = string
}

variable "confluence_alb_dns_name" {
  type = string
}