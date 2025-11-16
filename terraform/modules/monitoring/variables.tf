variable "env" {
  description = "Environment name"
  type        = string
}

variable "log_bucket_name" {
  description = "Cloud Storage bucket name for logs"
  type        = string
  default     = ""
}

