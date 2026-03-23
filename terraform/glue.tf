# --------------------------------------------------
# Glue Permissions
# --------------------------------------------------

data "aws_iam_policy_document" "glue_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      module.raw_bucket.s3_bucket_arn,
      "${module.raw_bucket.s3_bucket_arn}/*",
      module.refined_bucket.s3_bucket_arn,
      "${module.refined_bucket.s3_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetTable",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
      "glue:BatchUpdatePartition",
      "glue:CreatePartition",
      "glue:DeletePartition",
      "glue:UpdatePartition"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

module "glue_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"

  use_name_prefix = false

  name = format("%s-role", var.glue_job_name)

  trust_policy_permissions = {
    TrustLambda = {
      actions = [
        "sts:AssumeRole",
      ]
      principals = [{
        type = "Service"
        identifiers = [
          "glue.amazonaws.com",
        ]
      }]
    }
  }

  policies = {
    custom = module.glue_policy.arn
  }

  tags = {
    Name    = local.function_name
    service = var.service_name
  }
}

module "glue_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "6.4.0"

  name        = format("%s-policy", var.glue_job_name)
  description = "IAM policy for Glue Job"
  policy      = data.aws_iam_policy_document.glue_policy.json

  tags = {
    Name    = format("%s-policy", var.glue_job_name)
    service = var.service_name
  }
}

# --------------------------------------------------
# Glue Catalog Database
# --------------------------------------------------

resource "aws_glue_catalog_database" "b3_database" {
  name        = format("%s-database", var.glue_job_name)
  description = "Database for B3 stock market data"

  location_uri = "s3://${module.refined_bucket.s3_bucket_id}/refined/"

  tags = {
    Name    = format("%s-database", var.glue_job_name)
    service = var.service_name
  }
}

# --------------------------------------------------
# Glue Job
# --------------------------------------------------

resource "aws_glue_job" "b3_etl_job" {
  name     = var.glue_job_name
  role_arn = module.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${module.raw_bucket.s3_bucket_id}/glue-scripts/b3_etl_script.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${module.raw_bucket.s3_bucket_id}/glue-logs/"
    "--TempDir"                          = "s3://${module.raw_bucket.s3_bucket_id}/glue-temp/"
    "--RAW_BUCKET"                       = module.raw_bucket.s3_bucket_id
    "--REFINED_BUCKET"                   = module.refined_bucket.s3_bucket_id
    "--DATABASE_NAME"                    = aws_glue_catalog_database.b3_database.name
    "--TABLE_NAME"                       = "b3_stock_refined"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 60

  tags = {
    Name    = var.glue_job_name
    service = var.service_name
  }
}

# --------------------------------------------------
# Glue Job Script Upload to S3
# --------------------------------------------------

resource "aws_s3_object" "glue_script" {
  bucket = module.raw_bucket.s3_bucket_id
  key    = "glue-scripts/b3_etl_script.py"
  source = "${path.module}/glue-scripts/b3_etl_script.py"
  etag   = filemd5("${path.module}/glue-scripts/b3_etl_script.py")
}
