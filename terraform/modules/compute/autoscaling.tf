resource "google_compute_region_autoscaler" "web" {
  name   = "${var.env}-web-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.web.id

  autoscaling_policy {
    min_replicas    = var.min_replicas # 2
    max_replicas    = var.max_replicas # 4
    cooldown_period = 60

    # CPU使用率ベース
    cpu_utilization {
      target = 0.9 # 90%でスケールアウト
    }

    # スケーリングモード
    mode = "ON"

    # スケールイン時の動作
    scale_in_control {
      max_scaled_in_replicas {
        fixed = 1
      }
      time_window_sec = 600 # 10分
    }
  }
}

