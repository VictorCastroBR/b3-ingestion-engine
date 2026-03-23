variable "service_name" {
  description = "The name of the service, used to create resource names."
  type        = string
}

variable "glue_job_name" {
  description = "The name of the Glue job to be triggered."
  type        = string
}
