output "web_server_service_account_email" {
  description = "Web server service account email"
  value       = google_service_account.web_server.email
}

output "web_server_service_account_id" {
  description = "Web server service account ID"
  value       = google_service_account.web_server.id
}

output "wazuh_manager_service_account_email" {
  description = "Wazuh Manager service account email"
  value       = google_service_account.wazuh_manager.email
}

output "wazuh_manager_service_account_id" {
  description = "Wazuh Manager service account ID"
  value       = google_service_account.wazuh_manager.id
}

