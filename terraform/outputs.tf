output "lambda_function_name" {
  description = "Name of the Lambda function (invoke to reproduce the issue)"
  value       = aws_lambda_function.main.function_name
}

output "s3_bucket_id" {
  description = "S3 bucket the Lambda tries to list"
  value       = aws_s3_bucket.data.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}
