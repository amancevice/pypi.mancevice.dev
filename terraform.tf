variable ROLE_ARN { default = null }

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

# API GATEWAY :: REST API

resource aws_api_gateway_rest_api pypi {
  description = "PyPI service"
  name        = "pypi.mancevice.dev"
  tags        = local.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource aws_api_gateway_stage prod {
  deployment_id = aws_api_gateway_deployment.v1.id
  description   = "Simple PyPI"
  rest_api_id   = aws_api_gateway_rest_api.pypi.id
  stage_name    = "prod"
  tags          = local.tags
}

resource aws_api_gateway_deployment v1 {
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

# API GATEWAY :: DOMAIN

data aws_acm_certificate mancevice_dev {
  domain = "mancevice.dev"
  types  = ["AMAZON_ISSUED"]
}

resource aws_api_gateway_base_path_mapping simple {
  api_id      = aws_api_gateway_rest_api.pypi.id
  base_path   = local.base_path
  domain_name = aws_api_gateway_domain_name.pypi_mancevice_dev.domain_name
  stage_name  = aws_api_gateway_stage.prod.stage_name
}

resource aws_api_gateway_domain_name pypi_mancevice_dev {
  certificate_arn = data.aws_acm_certificate.mancevice_dev.arn
  domain_name     = aws_api_gateway_rest_api.pypi.name
}

# SERVERLESS PYPI

module serverless_pypi {
  source  = "amancevice/serverless-pypi/aws"
  version = "~> 2.0"

  iam_role_name  = "pypi-mancevice-dev"
  s3_bucket_name = "pypi.mancevice.dev"
  tags           = local.tags

  lambda_api_fallback_index_url = "https://pypi.org/simple/"
  lambda_api_function_name      = "pypi-mancevice-dev-api"
  lambda_api_publish            = local.publish_lambdas

  lambda_reindex_function_name = "pypi-mancevice-dev-reindex"
  lambda_reindex_publish       = local.publish_lambdas

  rest_api_authorization    = "CUSTOM"
  rest_api_authorizer_id    = module.serverless_pypi_cognito.rest_api_authorizer.id
  rest_api_base_path        = local.base_path
  rest_api_execution_arn    = aws_api_gateway_rest_api.pypi.execution_arn
  rest_api_id               = aws_api_gateway_rest_api.pypi.id
  rest_api_root_resource_id = aws_api_gateway_rest_api.pypi.root_resource_id
}

# SERVERLESS PYPI AUTHORIZER

module serverless_pypi_cognito {
  source  = "amancevice/serverless-pypi-cognito/aws"
  version = "~> 1.0"

  cognito_user_pool_name = "pypi.mancevice.dev"
  iam_role_name          = "pypi-mancevice-dev-authorizer"
  lambda_function_name   = "pypi-mancevice-dev-authorizer"
  lambda_publish         = local.publish_lambdas
  rest_api_id            = aws_api_gateway_rest_api.pypi.id
  tags                   = local.tags
}

# OUTPUTS

output pypi_url {
  description = "PyPI endpoint URL"
  value       = "https://${aws_api_gateway_domain_name.pypi_mancevice_dev.domain_name}/${aws_api_gateway_base_path_mapping.simple.base_path}/"
}
