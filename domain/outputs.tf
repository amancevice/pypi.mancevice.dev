output tmp {
  description = "API Gateway custom domain base path mapping."
  value       = aws_api_gateway_base_path_mapping.pypi
}

output domain {
  description = "API Gateway custom domain."
  value       = aws_api_gateway_domain_name.pypi
}
