# API GATEWAY :: DOMAIN

data "aws_acm_certificate" "mancevice_dev" {
  domain      = "mancevice.dev"
  most_recent = true
  types       = ["AMAZON_ISSUED"]
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

  lifecycle {
    ignore_changes = [deployment_id]
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.pypi.name}"
  retention_in_days = 30
  tags              = local.tags
}

# API GATEWAY :: HTTP INTEGRATIONS

resource "aws_apigatewayv2_integration" "pypi" {
  api_id             = aws_apigatewayv2_api.pypi.id
  connection_type    = "INTERNET"
  description        = "PyPI proxy handler"
  integration_method = "POST"
  integration_type   = "AWS_PROXY"
  integration_uri    = module.serverless_pypi.lambda_api.invoke_arn
}

resource "aws_lambda_permission" "invoke_api" {
  action        = "lambda:InvokeFunction"
  function_name = module.serverless_pypi.lambda_api.function_name
  principal     = "apigateway.amazonaws.com"
  statement_id  = "InvokeAPIv2"
  source_arn    = "${aws_apigatewayv2_api.pypi.execution_arn}/*/*/*"
}

# API GATEWAY :: HTTP ROUTES

resource "aws_apigatewayv2_route" "root_get" {
  api_id             = aws_apigatewayv2_api.pypi.id
  route_key          = "GET /"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.pypi.id}"
}

resource "aws_apigatewayv2_route" "root_head" {
  api_id             = aws_apigatewayv2_api.pypi.id
  route_key          = "HEAD /"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.pypi.id}"
}

resource "aws_apigatewayv2_route" "root_post" {
  api_id             = aws_apigatewayv2_api.pypi.id
  route_key          = "POST /"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.pypi.id}"
}

resource "aws_apigatewayv2_route" "proxy_get" {
  api_id             = aws_apigatewayv2_api.pypi.id
  route_key          = "GET /{proxy+}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.pypi.id}"
}

resource "aws_apigatewayv2_route" "proxy_head" {
  api_id             = aws_apigatewayv2_api.pypi.id
  route_key          = "HEAD /{proxy+}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.pypi.id}"
}

resource "aws_apigatewayv2_route" "proxy_post" {
  api_id             = aws_apigatewayv2_api.pypi.id
  route_key          = "POST /{proxy+}"
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.pypi.id}"
}
