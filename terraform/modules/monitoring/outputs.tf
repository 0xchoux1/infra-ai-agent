output "http_failure_alert_id" {
  description = "HTTP failure alert policy ID"
  value       = google_monitoring_alert_policy.http_failure.id
}

output "health_check_failure_alert_id" {
  description = "Health check failure alert policy ID"
  value       = google_monitoring_alert_policy.health_check_failure.id
}

# Phase 2で実装
# output "log_sink_writer_identity" {
#   description = "Log sink writer identity (for IAM binding)"
#   value       = var.log_bucket_name != "" ? google_logging_project_sink.wordpress_logs.writer_identity : ""
# }

