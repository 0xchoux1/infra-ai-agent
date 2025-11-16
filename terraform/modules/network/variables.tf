variable "env" {
  description = "Environment name (prod, dev)"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "web_subnet_cidr" {
  description = "CIDR range for web subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "mgmt_subnet_cidr" {
  description = "CIDR range for management subnet"
  type        = string
  default     = "10.0.2.0/24"
}

