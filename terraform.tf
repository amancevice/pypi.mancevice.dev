locals {
  base_path       = "simple"
  publish_lambdas = true

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

# API GATEWAY :: REST API

resource "aws_api_gateway_rest_api" "pypi" {
  description = "PyPI service"
  name        = "pypi.mancevice.dev"
  tags        = local.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.v1.id
  description   = "Simple PyPI"
  rest_api_id   = aws_api_gateway_rest_api.pypi.id
  stage_name    = "prod"
  tags          = local.tags
}

resource "aws_api_gateway_deployment" "v1" {
  rest_api_id = aws_api_gateway_rest_api.pypi.id

  # depends_on = [
  #   module.serverless_pypi.rest_api_integration_root_get,
  #   module.serverless_pypi.rest_api_integration_root_head,
  #   module.serverless_pypi.rest_api_integration_root_post,
  #   module.serverless_pypi.rest_api_integration_proxy_get,
  #   module.serverless_pypi.rest_api_integration_proxy_head,
  #   module.serverless_pypi.rest_api_integration_proxy_post,
  # ]

  triggers = {
    redeployment = module.serverless_pypi.rest_api_redeployment_trigger
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SERVERLESS PYPI

module "serverless_pypi" {
  source  = "amancevice/serverless-pypi/aws"
  version = "~> 2.0"

  iam_role_name  = "mancevice-dev-pypi"
  s3_bucket_name = "pypi.mancevice.dev"
  tags           = local.tags

  lambda_api_fallback_index_url = "https://pypi.org/simple/"
  lambda_api_function_name      = "mancevice-dev-pypi-api"
  lambda_api_publish            = local.publish_lambdas

  lambda_reindex_function_name = "mancevice-dev-pypi-reindex"
  lambda_reindex_publish       = local.publish_lambdas

  rest_api_authorization    = "CUSTOM"
  rest_api_authorizer_id    = module.serverless_pypi_cognito.rest_api_authorizer.id
  rest_api_base_path        = local.base_path
  rest_api_execution_arn    = aws_api_gateway_rest_api.pypi.execution_arn
  rest_api_id               = aws_api_gateway_rest_api.pypi.id
  rest_api_root_resource_id = aws_api_gateway_rest_api.pypi.root_resource_id
}

# SERVERLESS PYPI AUTHORIZER

module "serverless_pypi_cognito" {
  source  = "amancevice/serverless-pypi-cognito/aws"
  version = "~> 1.0"

  cognito_user_pool_name = "pypi.mancevice.dev"
  iam_role_name          = "mancevice-dev-pypi-authorizer"
  lambda_function_name   = "mancevice-dev-pypi-authorizer"
  lambda_publish         = local.publish_lambdas
  rest_api_id            = aws_api_gateway_rest_api.pypi.id
  tags                   = local.tags
}

# OUTPUTS

output "cognito_client_id" {
  description = "Cognito user pool client ID"
  value       = module.serverless_pypi_cognito.cognito_user_pool_client.id
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID"
  value       = module.serverless_pypi_cognito.cognito_user_pool.id
}

output "pypi_url" {
  description = "PyPI endpoint URL"
  value       = "https://${aws_apigatewayv2_domain_name.pypi_mancevice_dev.domain_name}/${aws_apigatewayv2_stage.default.name}/"
}
