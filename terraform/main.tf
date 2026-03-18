terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

locals {
  name = "${var.env}-${var.project}"
  s3_bucket_name = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}"
  ecr_repo_name  = var.ecr_repo_name
  lambda_name   = var.lambda_function_name_prefix
  lambda_role_name = "${var.lambda_function_name_prefix}-lambda-role"
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Networking: dedicated VPC created once by Terraform state
#
# Broken behavior we want:
# - Lambda in a subnet with NO default route -> external HTTPS times out
# - S3 connectivity via Gateway VPC Endpoint -> S3 calls fail with IAM (AccessDenied)
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.200.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = local.name }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = local.name }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.200.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.200.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${local.name}-private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${local.name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private route table: NO default route (no NAT) -> Lambda cannot reach internet.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-private" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Allow S3 connectivity without requiring NAT (Gateway endpoint).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags               = { Name = "${local.name}-s3-endpoint" }
}

# ---------------------------------------------------------------------------
# S3 bucket (Lambda will try to list objects; role has no S3 permissions)
# ---------------------------------------------------------------------------
data "aws_s3_bucket" "data" {
  bucket = local.s3_bucket_name
}

# ---------------------------------------------------------------------------
# Lambda: role with CloudWatch Logs only — no S3 permissions (cannot list buckets)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = local.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Only basic execution (CloudWatch Logs). No S3 policy.
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution (ENI in private subnet)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "lambda" {
  name_prefix = "${local.name}-lambda-"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-lambda" }
}

# Lambda is deployed as a container image from ECR (repository is pre-created by the workflow).
data "aws_ecr_repository" "lambda" {
  name = local.ecr_repo_name
}

resource "aws_lambda_function" "main" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${data.aws_ecr_repository.lambda.repository_url}:${var.image_tag}"
  timeout       = 30

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      BUCKET_NAME      = local.s3_bucket_name
      EXTERNAL_API_URL = "https://httpbin.org/get"
    }
  }

  tags = { Name = local.name }
}
