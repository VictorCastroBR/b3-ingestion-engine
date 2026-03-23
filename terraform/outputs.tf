output "raw_bucket_name" {
  value       = module.raw_bucket.s3_bucket_id
  description = "The name of the raw S3 bucket where files are uploaded."
}

output "trigger_glue_function_name" {
  value       = module.trigger_glue_function.lambda_function_name
  description = "The name of the Lambda function that triggers the Glue Workflow."
}

output "refined_bucket_name" {
  value       = module.refined_bucket.s3_bucket_id
  description = "The name of the refined S3 bucket where processed files are stored."
}

output "glue_job" {
  value       = aws_glue_job.b3_etl_job.name
  description = "The name of the Glue Job that processes the data."
}

output "glue_database" {
  value       = aws_glue_catalog_database.b3_database.name
  description = "The name of the Glue Catalog Database."
}
