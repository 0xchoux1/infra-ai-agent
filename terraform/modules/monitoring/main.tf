# Notification Channel（Slack - 将来実装）
# Phase 2で実装: Slack Webhook URL

# HTTP接続失敗アラート
resource "google_monitoring_alert_policy" "http_failure" {
  display_name = "${var.env}-http-failure-alert"
  combiner     = "OR"

  conditions {
    display_name = "HTTP 5xx Error Rate"

    condition_threshold {
      filter          = "resource.type = \"https_lb_rule\" AND metric.type = \"loadbalancing.googleapis.com/https/request_count\" AND metric.label.response_code_class = \"500\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  documentation {
    content = "HTTP 5xx errors are occurring at a high rate. Check backend instances and logs."
  }

  enabled = true
}

# Instance Health Check失敗アラート
resource "google_monitoring_alert_policy" "health_check_failure" {
  display_name = "${var.env}-health-check-failure"
  combiner     = "OR"

  conditions {
    display_name = "Instance Health Check Failure"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/uptime\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  documentation {
    content = "One or more instances are failing health checks. Check instance logs and status."
  }

  enabled = true
}

# ログシンク（Cloud Logging → Cloud Storage - オプション）
# Phase 2で実装: ログ用のGCS bucketを作成してから有効化
# resource "google_logging_project_sink" "wordpress_logs" {
#   name        = "${var.env}-wordpress-logs-sink"
#   destination = "storage.googleapis.com/${var.log_bucket_name}"
#
#   filter = "resource.type = \"gce_instance\" AND labels.service = \"wordpress\""
#
#   unique_writer_identity = true
# }

