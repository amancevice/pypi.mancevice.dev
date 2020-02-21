terraform {
  backend s3 {
    bucket = "mancevice.dev"
    key    = "terraform/pypi.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 0.12.0"
}

provider archive {
  version = "~> 1.2"
}

provider aws {
  region  = "us-east-1"
  version = "~> 2.7"
}

locals {
  tags = {
    App     = "pypi.mancevice.dev"
    Name    = "mancevice.dev"
    Release = "2020.2.2"
    Repo    = "https://github.com/amancevice/pypi.mancevice.dev"
  }
}

module serverless_pypi {
  source                       = "amancevice/serverless-pypi/aws"
  version                      = "~> 0.2"
  api_authorization            = "CUSTOM"
  api_authorizer_id            = module.serverless_pypi_cognito.authorizer.id
  api_base_path                = module.serverless_pypi_domain.base_path.base_path
  api_name                     = "pypi.mancevice.dev"
  lambda_function_name_api     = "pypi-mancevice-dev-api"
  lambda_function_name_reindex = "pypi-mancevice-dev-reindex"
  role_name                    = "pypi-mancevice-dev"
  s3_bucket_name               = "pypi.mancevice.dev"
  tags                         = local.tags
}

module serverless_pypi_cognito {
  source               = "amancevice/serverless-pypi-cognito/aws"
  version              = "~> 0.2"
  api_id               = module.serverless_pypi.api.id
  lambda_function_name = "pypi-mancevice-dev-authorizer"
  role_name            = "pypi-mancevice-dev-authorizer"
  tags                 = local.tags
  user_pool_name       = "pypi.mancevice.dev"
}

module serverless_pypi_domain {
  source      = "./domain"
  api_id      = module.serverless_pypi.api.id
  base_path   = "simple"
  cert_domain = "mancevice.dev"
  pypi_domain = "pypi.mancevice.dev"
  stage_name  = "simple"
}

output api_id {
  description = "API Gateway REST API ID"
  value       = module.serverless_pypi.api.id
}

output api_base_path {
  description = "API Gateway Custom Domain base path"
  value       = module.serverless_pypi_domain.base_path.base_path
}

output cognito_client_id {
  description = "Cognito user pool client ID"
  value       = module.serverless_pypi_cognito.user_pool_client.id
}

output cognito_user_pool_id {
  description = "Cognito user pool ID"
  value       = module.serverless_pypi_cognito.user_pool.id
}
