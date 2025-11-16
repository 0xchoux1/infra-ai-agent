# Google-managed SSL証明書
resource "google_compute_managed_ssl_certificate" "wordpress" {
  name = "${var.env}-wordpress-ssl"

  managed {
    domains = var.domains # ["example.com", "www.example.com"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 将来的なLet's Encrypt用の予約
# Phase 2で実装: certbot + Cloud Functions + Cloud Scheduler

