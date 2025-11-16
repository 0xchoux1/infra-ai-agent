variable "env" {
  description = "Environment name"
  type        = string
}

variable "zone" {
  description = "Zone for Filestore instance"
  type        = string
}

variable "tier" {
  description = "Filestore tier"
  type        = string
  default     = "BASIC_HDD"

  validation {
    condition     = contains(["BASIC_HDD", "BASIC_SSD", "HIGH_SCALE_SSD"], var.tier)
    error_message = "Tier must be one of: BASIC_HDD, BASIC_SSD, HIGH_SCALE_SSD"
  }
}

variable "capacity_gb" {
  description = "Filestore capacity in GB"
  type        = number
  default     = 1024 # BASIC_HDD minimum

  validation {
    condition     = var.capacity_gb >= 1024
    error_message = "BASIC_HDD requires minimum 1024 GB"
  }
}

variable "network_id" {
  description = "VPC network ID (full resource name: projects/{project}/global/networks/{network})"
  type        = string
}

