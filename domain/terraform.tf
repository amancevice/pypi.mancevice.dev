# VARIABLES & LOCALS

variable "tags" { type = map(string) }

locals { tags = var.tags }

# API GATEWAY :: HTTP API

resource "aws_apigatewayv2_api" "pypi" {
  description   = "PyPI for mancevice.dev"
  name          = "mancevice.dev/pypi"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.pypi.id
  auto_deploy = true
  name        = "$default"
  tags        = local.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn

    format = jsonencode({
      httpMethod     = "$context.httpMethod"
      ip             = "$context.identity.sourceIp"
      protocol       = "$context.protocol"
      requestId      = "$context.requestId"
      requestTime    = "$context.requestTime"
      responseLength = "$context.responseLength"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.pypi.name}"
  retention_in_days = 30
  tags              = local.tags
}

# API GATEWAY :: DNS

data "aws_acm_certificate" "mancevice_dev" {
  domain      = "mancevice.dev"
  most_recent = true
  types       = ["AMAZON_ISSUED"]
}

data "aws_route53_zone" "mancevice_dev" {
  name = "mancevice.dev."
}

resource "aws_apigatewayv2_domain_name" "pypi_mancevice_dev" {
  domain_name = "pypi.mancevice.dev"

  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.mancevice_dev.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "default" {
  api_id          = aws_apigatewayv2_api.pypi.id
  api_mapping_key = "simple"
  domain_name     = aws_apigatewayv2_domain_name.pypi_mancevice_dev.id
  stage           = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "a" {
  name    = aws_apigatewayv2_domain_name.pypi_mancevice_dev.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.mancevice_dev.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.pypi_mancevice_dev.domain_name_configuration.0.target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.pypi_mancevice_dev.domain_name_configuration.0.hosted_zone_id
    evaluate_target_health = false
  }
}

# OUTPUTS

output "base_path" { value = aws_apigatewayv2_api_mapping.default.api_mapping_key }
output "name" { value = aws_apigatewayv2_domain_name.pypi_mancevice_dev.domain_name }
output "http_api" { value = aws_apigatewayv2_api.pypi }
