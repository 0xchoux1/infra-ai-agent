# Health Check
resource "google_compute_health_check" "web" {
  name                = "${var.env}-web-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

# Managed Instance Group
resource "google_compute_region_instance_group_manager" "web" {
  name               = "${var.env}-web-mig"
  region             = var.region
  base_instance_name = "${var.env}-web"

  version {
    instance_template = google_compute_region_instance_template.web.id
  }

  target_size = var.min_replicas

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.web.id
    initial_delay_sec = 300
  }

  update_policy {
    type                         = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 3
    max_unavailable_fixed        = 0
    instance_redistribution_type = "PROACTIVE"
    replacement_method           = "SUBSTITUTE"
  }
}

