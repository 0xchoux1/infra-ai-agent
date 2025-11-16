variable "env" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-2-7680" # 2 vCPU, 7.5GB RAM
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "network_id" {
  description = "VPC network ID for private IP"
  type        = string
}

variable "domains" {
  description = "List of WordPress domain names"
  type        = list(string)
}

variable "availability_type" {
  description = "Availability type: REGIONAL (HA) or ZONAL (single zone)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.availability_type)
    error_message = "availability_type must be either REGIONAL or ZONAL"
  }
}

