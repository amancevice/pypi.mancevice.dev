variable ROLE_ARN { default = null }

locals {
  tags = {
    App  = "pypi.mancevice.dev"
    Name = "mancevice.dev"
    Repo = "https://github.com/amancevice/pypi.mancevice.dev"
  }
}

terraform {
  backend s3 {
    bucket = "mancevice.dev"
    key    = "terraform/pypi.mancevice.dev.tfstate"
    region = "us-east-1"
  }

  required_version = "~> 0.12"
}

# PROVIDERS

provider archive {
  version = "~> 1.2"
}

provider aws {
  region  = "us-east-1"
  version = "~> 2.7"

  assume_role {
    role_arn = var.ROLE_ARN
  }
}

# REST API

resource aws_api_gateway_rest_api pypi {
  description = "PyPI service"
  name        = "pypi.mancevice.dev"
  # tags        = local.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource aws_api_gateway_stage simple {
  cache_cluster_size = "0.5"
  deployment_id      = aws_api_gateway_deployment.v1.id
  description        = "Simple PyPI"
  rest_api_id        = aws_api_gateway_rest_api.pypi.id
  stage_name         = aws_api_gateway_deployment.v1.stage_name
  tags               = local.tags
}

resource aws_api_gateway_deployment v1 {
  depends_on = []

  rest_api_id = aws_api_gateway_rest_api.pypi.id
  stage_name  = "simple"

  lifecycle {
    create_before_destroy = true
  }
}

# REST API DOMAIN

data aws_acm_certificate mancevice_dev {
  domain = "mancevice.dev"
  types  = ["AMAZON_ISSUED"]
}

resource aws_api_gateway_base_path_mapping simple {
  api_id      = aws_api_gateway_rest_api.pypi.id
  base_path   = "simple"
  domain_name = aws_api_gateway_domain_name.pypi_mancevice_dev.domain_name
  stage_name  = aws_api_gateway_stage.simple.stage_name
}

resource aws_api_gateway_domain_name pypi_mancevice_dev {
  certificate_arn = data.aws_acm_certificate.mancevice_dev.arn
  domain_name     = aws_api_gateway_rest_api.pypi.name
}

# REST API AUTHORIZER

module serverless_pypi_cognito {
  source               = "amancevice/serverless-pypi-cognito/aws"
  version              = "~> 0.3"
  api_id               = aws_api_gateway_rest_api.pypi.id
  lambda_function_name = "pypi-mancevice-dev-authorizer"
  lambda_publish       = true
  role_name            = "pypi-mancevice-dev-authorizer"
  tags                 = local.tags
  user_pool_name       = "pypi.mancevice.dev"
}

# SERVERLESS PYPI

module serverless_pypi {
  source                       = "amancevice/serverless-pypi/aws"
  version                      = "~> 1.2"
  api_authorization            = "CUSTOM"
  api_authorizer_id            = module.serverless_pypi_cognito.authorizer.id
  api_base_path                = aws_api_gateway_base_path_mapping.simple.base_path
  api_name                     = "pypi.mancevice.dev"
  fallback_index_url           = "https://pypi.org/simple/"
  lambda_api_function_name     = "pypi-mancevice-dev-api"
  lambda_api_publish           = true
  lambda_reindex_function_name = "pypi-mancevice-dev-reindex"
  lambda_reindex_publish       = true
  role_name                    = "pypi-mancevice-dev"
  s3_bucket_name               = "pypi.mancevice.dev"
  tags                         = local.tags
}

# OUTPUTS

output api_id {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.pypi.id
}

output api_base_path {
  description = "API Gateway Custom Domain base path"
  value       = aws_api_gateway_base_path_mapping.simple.base_path
}

output cognito_client_id {
  description = "Cognito user pool client ID"
  value       = module.serverless_pypi_cognito.user_pool_client.id
}

output cognito_user_pool_id {
  description = "Cognito user pool ID"
  value       = module.serverless_pypi_cognito.user_pool.id
}

output lambda_api_arn {
  value = module.serverless_pypi.lambda_api_arn
}

output lambda_reindex_arn {
  value = module.serverless_pypi.lambda_reindex_arn
}

output pypi_url {
  description = "PyPI endpoint URL"
  value       = "https://${aws_api_gateway_domain_name.pypi_mancevice_dev.domain_name}/${aws_api_gateway_base_path_mapping.simple.base_path}"
}
