# Filestore API有効化（先に実行）
resource "google_project_service" "filestore" {
  service            = "file.googleapis.com"
  disable_on_destroy = false
}

# Cloud Filestore（NFS）
resource "google_filestore_instance" "wordpress" {
  name     = "${var.env}-wordpress-nfs"
  location = var.zone
  tier     = var.tier # BASIC_HDD（1TB～）, BASIC_SSD, HIGH_SCALE_SSD

  file_shares {
    name        = "wordpress"
    capacity_gb = var.capacity_gb # 最小1024GB（BASIC_HDD）
  }

  networks {
    network           = var.network_id # ネットワーク名（prod-wordpress-vpc形式）
    modes             = ["MODE_IPV4"]
    connect_mode      = "DIRECT_PEERING"
    reserved_ip_range = "10.0.3.0/29" # Filestore用に予約するIP範囲（CIDR形式）
  }

  labels = {
    environment = var.env
    managed_by  = "terraform"
    service     = "wordpress"
  }

  description = "WordPress shared storage for ${var.env} environment"

  depends_on = [
    google_project_service.filestore
  ]
}

