terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.1.5"
}

provider "aws" {
  profile = "default"
  region  = var.region
  default_tags {
    tags = {
      Project = "Promotion Code"
    }
  }
}

resource "aws_vpc" "global" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL"
    description = "${upper(var.environment)} GLOBAL VPC"
    Terraform = "true"
  }
}

resource "aws_internet_gateway" "global" {
  vpc_id = aws_vpc.global.id

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL"
    description = "${upper(var.environment)} GLOBAL Internet Gateway"
    Terraform = "true"
  }
}

resource "aws_security_group" "global" {
  name        = "${upper(var.environment)}_GLOBAL"
  description = "${upper(var.environment)} GLOBAL Security Group"
  vpc_id      = aws_vpc.global.id

  ingress {
    cidr_blocks = ["220.130.164.112/28"]
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL Security Group"
    Terraform = "true"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "global_rds_1" {
  vpc_id                  = aws_vpc.global.id
  cidr_block              = "10.100.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL rds 1"
    Terraform = "true"
  }
}

resource "aws_subnet" "global_rds_2" {
  vpc_id                  = aws_vpc.global.id
  cidr_block              = "10.100.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL rds 2"
    Terraform = "true"
  }
}

resource "aws_subnet" "global_lambda_1" {
  vpc_id                  = aws_vpc.global.id
  cidr_block              = "10.100.14.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL lambda 1"
    Terraform = "true"
  }
}

resource "aws_subnet" "global_lambda_2" {
  vpc_id                  = aws_vpc.global.id
  cidr_block              = "10.100.15.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL lambda 2"
    Terraform = "true"
  }
}

resource "aws_route_table" "global_main" {
  vpc_id = aws_vpc.global.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.global.id
  }

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL route table"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "global" {
  subnet_id      = aws_subnet.global_rds_1.id
  route_table_id = aws_route_table.global_main.id
}

resource "aws_network_acl" "global" {
  vpc_id     = aws_vpc.global.id
  subnet_ids = [aws_subnet.global_rds_1.id, aws_subnet.global_rds_2.id, aws_subnet.global_lambda_1.id, aws_subnet.global_lambda_2.id]

  ingress {
    from_port  = 0
    to_port    = 0
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }

  egress {
    from_port  = 0
    to_port    = 0
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL_ACL"
    Terraform = "true"
  }
}

resource "aws_db_subnet_group" "global" {
  name       = "${var.environment}-global-db-subg"
  subnet_ids = [aws_subnet.global_rds_1.id, aws_subnet.global_rds_2.id]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL db subnet 1"
    Terraform = "true"
  }
}

resource "aws_db_parameter_group" "global" {
  name   = "${var.environment}-global-db-pg"
  family = "postgres12"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "${upper(var.environment)}_GLOBAL db parameter group"
    Terraform = "true"
  }
}

resource "random_password" "global_db" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "global" {
  snapshot_identifier     = "rd-global-db-sample-snapshot"
  instance_class          = var.rds_instance_type
  identifier              = "${var.environment}-global-db"
  username                = "mydlink"
  password                = random_password.global_db.result
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.global.id]
  db_subnet_group_name    = "${var.environment}-global-db-subg"
  parameter_group_name    = "${var.environment}-global-db-pg"
  multi_az                = true
  skip_final_snapshot     = true
  backup_retention_period = 0
  maintenance_window      = "sun:04:30-sun:05:00"
  depends_on              = [aws_db_subnet_group.global, aws_db_parameter_group.global]
  apply_immediately       = true
}

data "aws_iam_policy" "lambda_vpc_access_execution" {
 arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "promotion_code" {
  name                = "${var.environment}-${var.lambda_iam_role_name}"
  assume_role_policy  = <<EOF
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

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_execution" {
 role       = aws_iam_role.promotion_code.name
 policy_arn = data.aws_iam_policy.lambda_vpc_access_execution.arn
}

resource "aws_iam_policy" "log_group" {
  name        = "${var.environment}-${var.lambda_policy_name}"
  description = "Promotion Code Lambda Policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "arn:aws:logs:${var.region}:${var.aws_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:CreateLogGroup",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:${var.region}:${var.aws_id}:log-group:/aws/lambda/${var.lambda_name}:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "promotion_code_vpc_execution_role" {
  role       = aws_iam_role.promotion_code.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy_attachment" "iam_policy_attach" {
  name       = "iam_policy_attach"
  roles      = [aws_iam_role.promotion_code.name]
  policy_arn = aws_iam_policy.log_group.arn
}

resource "aws_lambda_function" "promotion_code_lambda" {
  filename      = "source/${var.lambda_file}"
  function_name = "${var.environment}-${var.lambda_name}"
  role          = aws_iam_role.promotion_code.arn
  handler       = "index.handler"

  source_code_hash = filebase64sha256("source/${var.lambda_file}")
  vpc_config {
    security_group_ids = [aws_security_group.global.id]
    subnet_ids         = [aws_subnet.global_lambda_1.id, aws_subnet.global_lambda_2.id]
  }
  runtime = "nodejs16.x"

  environment {
    variables = {
      GLOBAL_DB_HOST     = aws_db_instance.global.address
      GLOBAL_DB_PASSWORD = random_password.global_db.result
      GLOBAL_DB_USER     = "mydlink"
    }
  }
}

resource "aws_api_gateway_rest_api" "promotion_code" {
  name        = "${upper(var.environment)}_Promotion_Code"
  description = "Promotion Code Serverless Application"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "promotion_code" {
  rest_api_id = aws_api_gateway_rest_api.promotion_code.id
  parent_id   = aws_api_gateway_rest_api.promotion_code.root_resource_id
  path_part   = "promotion-code"
}

resource "aws_lambda_permission" "promotion_code" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.promotion_code_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.promotion_code.execution_arn}/*/*/*"
}

resource "aws_api_gateway_resource" "promotion_code_fetch" {
  rest_api_id = aws_api_gateway_rest_api.promotion_code.id
  parent_id   = aws_api_gateway_resource.promotion_code.id
  path_part   = "fetch"
}

resource "aws_api_gateway_method" "promotion_code_fetch_post" {
  rest_api_id           = aws_api_gateway_rest_api.promotion_code.id
  resource_id           = aws_api_gateway_resource.promotion_code_fetch.id
  http_method           = "POST"
  authorization         = "NONE"
  api_key_required      = true
  authorization_scopes  = [""]

  request_models        = {
    "application/json" = ""
  }

  request_parameters    = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "promotion_code_fetch_post" {
  rest_api_id             = aws_api_gateway_rest_api.promotion_code.id
  resource_id             = aws_api_gateway_resource.promotion_code_fetch.id
  http_method             = aws_api_gateway_method.promotion_code_fetch_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.promotion_code_lambda.invoke_arn
  cache_key_parameters    = [""]

  request_templates = {
    "application/json" = ""
  }

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to cache_key_parameters, request_parameters, request_templates.
      cache_key_parameters,
      request_parameters,
      request_templates
    ]
  }
}

resource "aws_api_gateway_resource" "promotion_code_import" {
  rest_api_id = aws_api_gateway_rest_api.promotion_code.id
  parent_id   = aws_api_gateway_resource.promotion_code.id
  path_part   = "import"
}

resource "aws_api_gateway_method" "promotion_code_import_post" {
  rest_api_id      = aws_api_gateway_rest_api.promotion_code.id
  resource_id      = aws_api_gateway_resource.promotion_code_import.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "promotion_code_import_post" {
  rest_api_id             = aws_api_gateway_rest_api.promotion_code.id
  resource_id             = aws_api_gateway_resource.promotion_code_import.id
  http_method             = aws_api_gateway_method.promotion_code_import_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.promotion_code_lambda.invoke_arn
  cache_key_parameters    = ["method.request.path.proxy"]

  request_templates = {
    "application/json" = ""
  }

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to cache_key_parameters, request_parameters, request_templates.
      cache_key_parameters,
      request_parameters,
      request_templates
    ]
  }
}

resource "aws_api_gateway_deployment" "promotion_code_API" {
  rest_api_id = aws_api_gateway_rest_api.promotion_code.id
  depends_on = [
    aws_api_gateway_method.promotion_code_fetch_post,
    aws_api_gateway_method.promotion_code_import_post,
    aws_api_gateway_integration.promotion_code_fetch_post,
    aws_api_gateway_integration.promotion_code_import_post,
  ]
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.promotion_code_import,
      aws_api_gateway_method.promotion_code_import_post,
      aws_api_gateway_integration.promotion_code_import_post,
      aws_api_gateway_resource.promotion_code_fetch,
      aws_api_gateway_method.promotion_code_fetch_post,
      aws_api_gateway_integration.promotion_code_fetch_post
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "promotion_code_API" {
  deployment_id = aws_api_gateway_deployment.promotion_code_API.id
  rest_api_id   = aws_api_gateway_rest_api.promotion_code.id
  stage_name    = "API"
}

resource "aws_api_gateway_usage_plan" "promotion_code" {
  name        = "${var.environment}-${var.lambda_name}-plan"
  description = "usage plan for execute http gateway"

  api_stages {
    api_id = aws_api_gateway_rest_api.promotion_code.id
    stage  = aws_api_gateway_stage.promotion_code_API.stage_name
  }

  quota_settings {
    limit  = var.quota_limit
    period = var.quota_period
  }

  throttle_settings {
    burst_limit = var.throttle_burst_limit
    rate_limit  = var.throttle_rate_limit
  }
}

resource "aws_api_gateway_api_key" "promotion_code" {
  name = "${var.environment}-${var.lambda_name}-key"
}

resource "aws_api_gateway_usage_plan_key" "promotion_code" {
  key_id        = aws_api_gateway_api_key.promotion_code.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.promotion_code.id
}
