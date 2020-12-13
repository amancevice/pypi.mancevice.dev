locals {
  publish_lambdas = false

  tags = {
    App  = "pypi.mancevice.dev"
    Name = "mancevice.dev"
    Repo = "https://github.com/amancevice/pypi.mancevice.dev"
  }
}

terraform {
  required_version = "~> 0.14"

  backend "s3" {
    bucket = "mancevice.dev"
    key    = "terraform/pypi.mancevice.dev.tfstate"
    region = "us-east-1"
  }

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 1.3"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# PROVIDERS

provider "archive" {
}

provider "aws" {
  region = "us-east-1"
}

# SERVERLESS PYPI :: DNS

module "domain" {
  source = "./domain"
  tags   = local.tags
}

# SERVERLESS PYPI :: SERVICE

module "serverless_pypi" {
  # source  = "amancevice/serverless-pypi/aws"
  # version = "~> 2.0"
  source = "git::https://github.com/amancevice/terraform-aws-serverless-pypi?ref=apigatewayv2"

  iam_role_name = "mancevice-dev-pypi"

  http_api_id            = module.domain.http_api.id
  http_api_execution_arn = module.domain.http_api.execution_arn

  lambda_api_fallback_index_url = "https://pypi.org/simple/"
  lambda_api_function_name      = "mancevice-dev-pypi-http-api"
  lambda_api_publish            = local.publish_lambdas

  lambda_reindex_function_name = "mancevice-dev-pypi-reindex"
  lambda_reindex_publish       = local.publish_lambdas

  log_group_retention_in_days = 30

  s3_bucket_name = "pypi.mancevice.dev"

  sns_topic_name = "mancevice-dev-pypi-s3-events"

  tags = local.tags
}

output "pypi_url_http" {
  description = "PyPI endpoint URL"
  value       = "https://${module.domain.name}/${module.domain.base_path}/"
}
