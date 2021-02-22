provider "aws" {
  region = var.aws_region
  version = "2.7.0"
}

resource "aws_eip" "app_us_east_1c" {
  tags = {
    "Name" = "app_us_east_1c"
  }
}

resource "aws_eip" "app_us_east_1d" {
  tags = {
    "Name" = "app_us_east_1d"
  }
}