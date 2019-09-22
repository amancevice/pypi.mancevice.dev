terraform {
  backend s3 {
    bucket = "mancevice.dev"
    key    = "terraform/pypi.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 0.12.0"
}

provider aws {
  region  = "us-east-1"
  version = "~> 2.7"
}

provider null {
  version = "~> 2.0"
}

locals {
  domain  = "mancevice.dev"
  release = "2019.9.22"
  repo    = "https://github.com/amancevice/pypi.mancevice.dev"

  tags = {
    App     = "pypi.${local.domain}"
    Name    = local.domain
    Release = local.release
    Repo    = local.repo
  }
}

data aws_iam_policy_document website {
  statement {
    sid       = "AllowCloudFront"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::pypi.${local.domain}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.website.iam_arn]
    }
  }
}

data aws_acm_certificate cert {
  domain   = local.domain
  statuses = ["ISSUED"]
}

resource aws_cloudfront_distribution website {
  aliases             = ["pypi.${local.domain}"]
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    default_ttl            = 86400
    max_ttl                = 31536000
    min_ttl                = 0
    target_origin_id       = aws_s3_bucket.website.bucket
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.website.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cert.arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method       = "sni-only"
  }
}

resource aws_cloudfront_origin_access_identity website {
  comment = "access-identity-pypi.${local.domain}.s3.amazonaws.com"
}

resource aws_s3_bucket website {
  acl           = "private"
  bucket        = "pypi.${local.domain}"
  force_destroy = false
  policy        = data.aws_iam_policy_document.website.json
  tags          = local.tags

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}

resource aws_s3_bucket_public_access_block website {
  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.website.id
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output bucket_name {
  description = "S3 website bucket name."
  value       = aws_s3_bucket.website.bucket
}

output cloudfront_distribution_id {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.website.id
}
