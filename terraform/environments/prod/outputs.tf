output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = module.loadbalancer.load_balancer_ip
}

output "database_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.database.private_ip_address
}

output "nfs_mount_command" {
  description = "NFS mount command for Filestore"
  value       = module.filestore.mount_command
}

output "vpc_id" {
  description = "VPC network ID"
  value       = module.network.vpc_id
}

output "web_server_service_account" {
  description = "Web server service account email"
  value       = module.iam.web_server_service_account_email
}

output "database_names" {
  description = "List of created database names"
  value       = module.database.database_names
}

output "database_secret_ids" {
  description = "List of Secret Manager secret IDs for database passwords"
  value       = module.database.secret_ids
}

output "ssl_certificate_status" {
  description = "SSL certificate ID (check status in GCP Console)"
  value       = module.loadbalancer.ssl_certificate_id
}

