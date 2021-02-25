terraform {
  required_version = "~> 0.14"

  backend "s3" {
    bucket = "mancevice.dev"
    key    = "terraform/pypi.mancevice.dev.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# PROVIDERS

provider "aws" {
  region = "us-east-1"
}

# LOCALS

locals {
  publish_lambdas = false

  tags = {
    App  = "pypi.mancevice.dev"
    Name = "pypi.mancevice.dev"
    Repo = "https://github.com/amancevice/pypi.mancevice.dev"
  }
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
  lambda_api_tags               = local.tags

  lambda_reindex_function_name = "mancevice-dev-pypi-reindex"
  lambda_reindex_publish       = local.publish_lambdas
  lambda_reindex_tags          = local.tags

  log_group_api_retention_in_days     = 30
  log_group_api_tags                  = local.tags
  log_group_reindex_retention_in_days = 30
  log_group_reindex_tags              = local.tags

  s3_bucket_name = "pypi.mancevice.dev"
  s3_bucket_tags = local.tags

  sns_topic_name = "mancevice-dev-pypi-s3-events"
  sns_topic_tags = local.tags
}

# RESOURCE GROUPS

resource "aws_resourcegroups_group" "resource_group" {
  description = "pypi.mancevice.dev resources"
  name        = local.tags.App
  tags        = merge(local.tags, {})

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]

      TagFilters = [{
        Key    = "App"
        Values = [local.tags.App]
      }]
    })
  }
}

# OUTPUTS

output "pypi_url_http" {
  description = "PyPI endpoint URL"
  value       = "https://${module.domain.name}/${module.domain.base_path}/"
}
