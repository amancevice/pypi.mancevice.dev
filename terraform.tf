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
  domain = "mancevice.dev"

  release    = "2019.9.22"
  repo       = "https://github.com/amancevice/pypi.${local.domain}"
  base_path  = "simple"
  stage_name = "prod"

  tags = {
    App     = "pypi.${local.domain}"
    Name    = local.domain
    Release = local.release
    Repo    = local.repo
  }
}

module serverless_pypi {
  source                       = "amancevice/serverless-pypi/aws"
  version                      = "~> 0.1"
  api_name                     = "pypi.${local.domain}"
  lambda_function_name_api     = "pypi-${replace(local.domain, ".", "-")}"
  lambda_function_name_reindex = "pypi-${replace(local.domain, ".", "-")}-reindex"
  role_name                    = "pypi-${replace(local.domain, ".", "-")}"
  s3_bucket_name               = "pypi.${local.domain}"
  tags                         = local.tags
}

data aws_acm_certificate cert {
  domain = local.domain
  types  = ["AMAZON_ISSUED"]
}

resource aws_api_gateway_base_path_mapping api {
  api_id      = module.serverless_pypi.api_id
  domain_name = aws_api_gateway_domain_name.api.domain_name
  stage_name  = local.stage_name
  base_path   = local.base_path
}

resource aws_api_gateway_domain_name api {
  certificate_arn = data.aws_acm_certificate.cert.arn
  domain_name     = "pypi.${local.domain}"
}

output api_id {
  value = module.serverless_pypi.api_id
}
