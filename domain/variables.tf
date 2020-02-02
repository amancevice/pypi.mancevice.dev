variable api_id {
  description = "API Gateway REST API ID."
}

variable base_path {
  description = "Custom domain base path."
  default     = null
}

variable cert_domain {
  description = "ACM Certificate domain."
}

variable pypi_domain {
  description = "PyPI custom domain name."
}

variable stage_name {
  description = "API Gateway REST API stage name."
}
