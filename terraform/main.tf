data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  raw_bucket_name     = format("%s-raw-bucket", var.service_name)
  function_name       = format("%s-trigger-glue", var.service_name)
  refined_bucket_name = format("%s-refined-bucket", var.service_name)
}

# --------------------------------------------------
# Raw S3 Bucket
# --------------------------------------------------

module "raw_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.11.0"

  bucket = local.raw_bucket_name

  tags = {
    Name    = local.raw_bucket_name
    service = var.service_name
  }
}

# --------------------------------------------------
# Lambda Permissions to trigger Glue Job
# --------------------------------------------------

data "aws_iam_policy_document" "trigger_glue_policy" {
  statement {
    actions = [
      "glue:StartJobRun",
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
}

module "lambda_trigger_glue_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "6.4.0"

  name        = format("%s-policy", local.function_name)
  description = "IAM policy for Lambda function to trigger Glue Job"
  policy      = data.aws_iam_policy_document.trigger_glue_policy.json

  tags = {
    Name    = format("%s-policy", local.function_name)
    service = var.service_name
  }
}

module "trigger_glue_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  use_name_prefix = false

  name = format("%s-role", local.function_name)

  trust_policy_permissions = {
    TrustLambda = {
      actions = [
        "sts:AssumeRole",
      ]
      principals = [{
        type = "Service"
        identifiers = [
          "lambda.amazonaws.com",
        ]
      }]
    }
  }

  policies = {
    custom = module.lambda_trigger_glue_policy.arn
  }

  tags = {
    Name    = local.function_name
    service = var.service_name
  }
}

# --------------------------------------------------
# Lambda Function to trigger Glue Job
# --------------------------------------------------

module "trigger_glue_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.7.0"

  function_name = local.function_name
  description   = "Lambda function to trigger Glue Job when a file is uploaded to S3 bucket"
  handler       = "app.lambda_handler"
  runtime       = "python3.14"
  timeout       = 600
  memory_size   = 512

  source_path = "./src"

  environment_variables = {
    GLUE_JOB_NAME = aws_glue_job.b3_etl_job.name
  }

  create_current_version_allowed_triggers = false

  allowed_triggers = {
    AllowS3Invoke = {
      principal  = "s3.amazonaws.com"
      source_arn = module.raw_bucket.s3_bucket_arn
    }
  }

  create_role = false
  lambda_role = module.trigger_glue_role.arn

  tags = {
    Name    = local.function_name
    service = var.service_name
  }
}

# --------------------------------------------------
# S3 Bucket Notification to trigger Lambda
# --------------------------------------------------

module "raw_bucket_notification" {
  source  = "terraform-aws-modules/s3-bucket/aws//modules/notification"
  version = "5.11.0"

  bucket = module.raw_bucket.s3_bucket_id

  lambda_notifications = {
    trigger_glue = {
      function_arn  = module.trigger_glue_function.lambda_function_arn
      function_name = module.trigger_glue_function.lambda_function_name
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "raw/"
    }
  }
}

# --------------------------------------------------
# Refined S3 Bucket
# --------------------------------------------------

module "refined_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.11.0"

  bucket = local.refined_bucket_name

  tags = {
    Name    = local.refined_bucket_name
    service = var.service_name
  }
}
