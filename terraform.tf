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
  api_authorization               = "CUSTOM"
  api_base_path                   = "simple"
  api_name                        = "pypi.mancevice.dev"
  domain                          = "mancevice.dev"
  lambda_function_name_api        = "pypi-mancevice-dev-api"
  lambda_function_name_authorizer = "pypi-mancevice-dev-authorizer"
  lambda_function_name_reindex    = "pypi-mancevice-dev-reindex"
  release                         = "2020.1.31"
  repo                            = "https://github.com/amancevice/pypi.mancevice.dev"
  role_name                       = "pypi-mancevice-dev"
  role_name_authorizer            = "pypi-mancevice-dev-authorizer"
  s3_bucket_name                  = "pypi.mancevice.dev"
  stage_name                      = "simple"

  basic_auth_username = var.basic_auth_username
  basic_auth_password = var.basic_auth_password

  tags = {
    App     = "pypi.mancevice.dev"
    Name    = local.domain
    Release = local.release
    Repo    = local.repo
  }
}

module serverless_pypi {
  # source                          = "amancevice/serverless-pypi/aws"
  # version                         = "~> 0.2"
  source                       = "/Users/amancevice/smallweirdnumber/terraform/aws/serverless-pypi"
  api_authorization            = local.api_authorization
  api_authorizer_id            = module.serverless_pypi_basic_auth.authorizer.id
  api_base_path                = local.api_base_path
  api_name                     = local.api_name
  lambda_function_name_api     = local.lambda_function_name_api
  lambda_function_name_reindex = local.lambda_function_name_reindex
  role_name                    = local.role_name
  s3_bucket_name               = local.s3_bucket_name
  tags                         = local.tags
}

module serverless_pypi_basic_auth {
  # source                          = "amancevice/serverless-pypi-basic-auth/aws"
  # version                         = "~> 0.2"
  source               = "/Users/amancevice/smallweirdnumber/terraform/aws/serverless-pypi-basic-auth"
  api                  = module.serverless_pypi.api
  basic_auth_username  = local.basic_auth_username
  basic_auth_password  = local.basic_auth_password
  lambda_function_name = local.lambda_function_name_authorizer
  role_name            = local.role_name_authorizer
  tags                 = local.tags
}

data aws_acm_certificate cert {
  domain = local.domain
  types  = ["AMAZON_ISSUED"]
}

resource aws_api_gateway_base_path_mapping api {
  api_id      = module.serverless_pypi.api.id
  domain_name = aws_api_gateway_domain_name.api.domain_name
  stage_name  = local.stage_name
}

resource aws_api_gateway_domain_name api {
  certificate_arn = data.aws_acm_certificate.cert.arn
  domain_name     = "pypi.${local.domain}"
}

variable basic_auth_username {
  description = "PyPI BASIC authorization username."
}

variable basic_auth_password {
  description = "PyPI BASIC authorization password."
}
