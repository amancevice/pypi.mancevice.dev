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

provider null {
  version = "~> 2.0"
}

locals {
  domain    = "mancevice.dev"
  release   = "2019.9.22"
  repo      = "https://github.com/amancevice/pypi.${local.domain}"
  base_path = "simple"

  tags = {
    App     = "pypi.${local.domain}"
    Name    = local.domain
    Release = local.release
    Repo    = local.repo
  }
}

data archive_file package {
  source_file = "${path.module}/index.py"
  output_path = "${path.module}/package.zip"
  type        = "zip"
}

data aws_acm_certificate cert {
  domain = "mancevice.dev"
  types  = ["AMAZON_ISSUED"]
}

data aws_iam_policy_document assume_role {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data aws_iam_policy_document api {
  statement {
    sid = "ReadS3"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pypi.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.pypi.bucket}/*",
    ]
  }

  statement {
    sid       = "Reindex"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.pypi.bucket}/index.html"]
  }

  statement {
    sid = "WriteLambdaLogs"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource aws_api_gateway_base_path_mapping api {
  api_id      = aws_api_gateway_rest_api.api.id
  domain_name = aws_api_gateway_domain_name.api.domain_name
  stage_name  = "prod"
  base_path   = local.base_path
}

resource aws_api_gateway_domain_name api {
  certificate_arn = data.aws_acm_certificate.cert.arn
  domain_name     = "pypi.${local.domain}"
}

resource aws_api_gateway_integration proxy_get {
  content_handling        = "CONVERT_TO_TEXT"
  http_method             = aws_api_gateway_method.proxy_get.http_method
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_resource.proxy.id
  rest_api_id             = aws_api_gateway_rest_api.api.id
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource aws_api_gateway_integration root_get {
  content_handling        = "CONVERT_TO_TEXT"
  http_method             = aws_api_gateway_method.proxy_get.http_method
  integration_http_method = "POST"
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  rest_api_id             = aws_api_gateway_rest_api.api.id
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource aws_api_gateway_method proxy_get {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.proxy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
}

resource aws_api_gateway_method root_get {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  rest_api_id   = aws_api_gateway_rest_api.api.id
}

resource aws_api_gateway_resource proxy {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource aws_api_gateway_rest_api api {
  description = "PyPI service"
  name        = "pypi.${local.domain}"
}

resource aws_cloudwatch_log_group api {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group reindex {
  name              = "/aws/lambda/${aws_lambda_function.reindex.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_iam_role role {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "PyPI Lambda permissions"
  name               = "pypi-mancevice-dev"
  tags               = local.tags
}

resource aws_iam_role_policy policy {
  name   = "pypi-mancevice-dev"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.api.json
}

resource aws_lambda_function api {
  description      = "PyPI service REST API"
  filename         = data.archive_file.package.output_path
  function_name    = "pypi-mancevice-dev"
  handler          = "index.handler"
  role             = aws_iam_role.role.arn
  runtime          = "python3.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  tags             = local.tags

  environment {
    variables = {
      S3_BUCKET            = aws_s3_bucket.pypi.bucket
      S3_PRESIGNED_URL_TTL = "900"
      BASE_PATH            = local.base_path
    }
  }
}

resource aws_lambda_function reindex {
  description      = "Reindex PyPI root"
  filename         = data.archive_file.package.output_path
  function_name    = "pypi-mancevice-dev-reindex"
  handler          = "index.reindex"
  role             = aws_iam_role.role.arn
  runtime          = "python3.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  tags             = local.tags

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.pypi.bucket
    }
  }
}

resource aws_lambda_permission invoke_api {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource aws_lambda_permission invoke_reindex {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reindex.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.pypi.arn
}

resource aws_s3_bucket pypi {
  acl    = "private"
  bucket = "pypi.${local.domain}"
  tags   = local.tags
}

resource aws_s3_bucket_notification reindex {
  bucket = aws_s3_bucket.pypi.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.reindex.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix       = ".tar.gz"
  }
}

resource aws_s3_bucket_public_access_block pypi {
  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.pypi.id
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output bucket_name {
  description = "S3 website bucket name."
  value       = aws_s3_bucket.pypi.bucket
}
