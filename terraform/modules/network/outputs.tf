output "vpc_id" {
  description = "VPC network ID"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "web_subnet_id" {
  description = "Web subnet ID"
  value       = google_compute_subnetwork.web.id
}

output "web_subnet_name" {
  description = "Web subnet name"
  value       = google_compute_subnetwork.web.name
}

output "mgmt_subnet_id" {
  description = "Management subnet ID"
  value       = google_compute_subnetwork.mgmt.id
}

output "mgmt_subnet_name" {
  description = "Management subnet name"
  value       = google_compute_subnetwork.mgmt.name
}

output "service_networking_connection" {
  description = "Service Networking connection resource (for depends_on)"
  value       = google_service_networking_connection.private_vpc_connection
}

