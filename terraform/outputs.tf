output "lambda_function_name" {
  description = "Name of the Lambda function (invoke to reproduce the issue)"
  value       = aws_lambda_function.main.function_name
}

output "s3_bucket_id" {
  description = "S3 bucket the Lambda tries to list"
  value       = local.s3_bucket_name
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "private_subnet_id" {
  value = local.lambda_subnet_id
}
