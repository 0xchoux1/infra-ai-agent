output "load_balancer_ip" {
  description = "Load balancer global IP address"
  value       = google_compute_global_address.wordpress.address
}

output "backend_service_id" {
  description = "Backend service ID"
  value       = google_compute_backend_service.wordpress.id
}

output "ssl_certificate_id" {
  description = "SSL certificate ID"
  value       = google_compute_managed_ssl_certificate.wordpress.id
}

output "waf_policy_id" {
  description = "Cloud Armor WAF policy ID"
  value       = google_compute_security_policy.wordpress_waf.id
}

output "https_forwarding_rule" {
  description = "HTTPS forwarding rule self link"
  value       = google_compute_global_forwarding_rule.https.self_link
}

output "http_forwarding_rule" {
  description = "HTTP forwarding rule self link"
  value       = google_compute_global_forwarding_rule.http.self_link
}

