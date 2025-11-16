variable "env" {
  description = "Environment name"
  type        = string
}

variable "health_check_id" {
  description = "Health check resource ID"
  type        = string
}

variable "instance_group" {
  description = "Instance group self link"
  type        = string
}

variable "domains" {
  description = "List of domains for SSL certificate"
  type        = list(string)
}

