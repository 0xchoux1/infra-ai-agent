variable "env" {
  description = "Environment name"
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

variable "machine_type" {
  description = "Machine type for instances"
  type        = string
  default     = "e2-small"
}

variable "network" {
  description = "VPC network name"
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork name"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for instances"
  type        = string
}

variable "db_host" {
  description = "Database host IP"
  type        = string
}

variable "wazuh_manager_ip" {
  description = "Wazuh Manager IP address"
  type        = string
  default     = ""
}

variable "nfs_ip" {
  description = "Filestore NFS IP address"
  type        = string
}

variable "nfs_path" {
  description = "Filestore NFS path"
  type        = string
}

variable "domains" {
  description = "List of WordPress domain names"
  type        = list(string)
}

variable "min_replicas" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of instances"
  type        = number
  default     = 4
}

