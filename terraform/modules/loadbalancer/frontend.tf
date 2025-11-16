# Global IP Address
resource "google_compute_global_address" "wordpress" {
  name = "${var.env}-wordpress-ip"
}

# URL Map
resource "google_compute_url_map" "wordpress" {
  name            = "${var.env}-wordpress-lb"
  default_service = google_compute_backend_service.wordpress.id

  # ホストルール（マルチドメイン対応）
  dynamic "host_rule" {
    for_each = var.domains
    content {
      hosts        = [host_rule.value]
      path_matcher = "wordpress"
    }
  }

  path_matcher {
    name            = "wordpress"
    default_service = google_compute_backend_service.wordpress.id
  }
}

# HTTPS Proxy
resource "google_compute_target_https_proxy" "wordpress" {
  name             = "${var.env}-wordpress-https-proxy"
  url_map          = google_compute_url_map.wordpress.id
  ssl_certificates = [google_compute_managed_ssl_certificate.wordpress.id]
}

# HTTP Proxy（HTTPSへリダイレクト）
resource "google_compute_target_http_proxy" "wordpress" {
  name    = "${var.env}-wordpress-http-proxy"
  url_map = google_compute_url_map.wordpress_redirect.id
}

# HTTPリダイレクト用URL Map
resource "google_compute_url_map" "wordpress_redirect" {
  name = "${var.env}-wordpress-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Forwarding Rule（HTTPS）
resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.env}-wordpress-https"
  target     = google_compute_target_https_proxy.wordpress.id
  port_range = "443"
  ip_address = google_compute_global_address.wordpress.address
}

# Forwarding Rule（HTTP）
resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.env}-wordpress-http"
  target     = google_compute_target_http_proxy.wordpress.id
  port_range = "80"
  ip_address = google_compute_global_address.wordpress.address
}

