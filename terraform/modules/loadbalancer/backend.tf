# Backend Service
resource "google_compute_backend_service" "wordpress" {
  name        = "${var.env}-wordpress-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = true

  health_checks = [var.health_check_id]

  backend {
    group           = var.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = 0.8
  }

  # Cloud CDN設定
  cdn_policy {
    cache_mode = "USE_ORIGIN_HEADERS"

    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = true

      # WordPress用クエリパラメータ
      query_string_whitelist = ["p", "page_id", "preview", "s", "cat", "tag"]

      # ログイン状態で区別
      include_named_cookies = [
        "wordpress_logged_in_*",
        "wp-settings-*",
        "comment_author_*"
      ]
    }

    default_ttl = 300  # 5分
    max_ttl     = 3600 # 1時間
    client_ttl  = 300

    negative_caching = true
    negative_caching_policy {
      code = 404
      ttl  = 120
    }
  }

  # Cloud Armor（WAF）
  security_policy = google_compute_security_policy.wordpress_waf.id

  # ロギング
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

