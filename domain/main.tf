locals {
  api_id      = var.api_id
  base_path   = var.base_path
  cert_domain = var.cert_domain
  pypi_domain = var.pypi_domain
  stage_name  = var.stage_name
}

data aws_acm_certificate cert {
  domain = local.cert_domain
  types  = ["AMAZON_ISSUED"]
}

resource aws_api_gateway_base_path_mapping pypi {
  api_id      = local.api_id
  base_path   = local.base_path
  domain_name = aws_api_gateway_domain_name.pypi.domain_name
  stage_name  = local.stage_name
}

resource aws_api_gateway_domain_name pypi {
  certificate_arn = data.aws_acm_certificate.cert.arn
  domain_name     = local.pypi_domain
}
