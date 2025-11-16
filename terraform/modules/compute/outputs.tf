output "instance_group" {
  description = "Managed instance group self link"
  value       = google_compute_region_instance_group_manager.web.instance_group
}

output "instance_group_manager_id" {
  description = "Instance group manager ID"
  value       = google_compute_region_instance_group_manager.web.id
}

output "health_check_id" {
  description = "Health check ID"
  value       = google_compute_health_check.web.id
}

output "instance_template_id" {
  description = "Instance template ID"
  value       = google_compute_region_instance_template.web.id
}

