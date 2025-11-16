variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-northeast1-a"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "domains" {
  description = "List of WordPress domain names"
  type        = list(string)
}

variable "db_availability_type" {
  description = "Cloud SQL availability type (REGIONAL or ZONAL)"
  type        = string
  default     = "ZONAL"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-1-3840"
}

variable "filestore_tier" {
  description = "Filestore tier"
  type        = string
  default     = "BASIC_HDD"
}

variable "filestore_capacity_gb" {
  description = "Filestore capacity in GB"
  type        = number
  default     = 1024
}

variable "machine_type" {
  description = "Compute instance machine type"
  type        = string
  default     = "e2-micro"
}

variable "min_replicas" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of instances"
  type        = number
  default     = 2
}
