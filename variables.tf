variable "environment" {
  type    = string
  default = "rd"
}

variable "aws_id" {
  type    = string
  default = "955941525558"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "rds_instance_type" {
  type    = string
  default = "db.t3.micro"
}

variable "quota_limit" {
  type    = string
  default = "1000"
}

variable "quota_period" {
  type    = string
  default = "DAY"
}

variable "throttle_burst_limit" {
  type    = string
  default = "1"
}

variable "throttle_rate_limit" {
  type    = string
  default = "10"
}

variable "lambda_name" {
  type    = string
  default = "promotion-code"
}

variable "lambda_file" {
  type    = string
  default = "promotion-code-lambda.zip"
}

variable "lambda_iam_role_name" {
  type    = string
  default = "promotion-code"
}

variable "lambda_policy_name" {
  type    = string
  default = "promotion-code"
}

variable "basion_ami" {
  type    = string
  default = "ami-020da02dd38bd5e1d"
}
