# Filestore API有効化（先に実行）
resource "google_project_service" "filestore" {
  service            = "file.googleapis.com"
  disable_on_destroy = false
}

# Filestore用のIP範囲予約
resource "google_compute_global_address" "filestore_reserved_range" {
  name          = "${var.env}-filestore-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 29 # /29（8 IPs）- Filestoreの最小要件
  network       = var.network_id

  description = "Reserved IP range for Filestore"
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
    network           = var.network_id # フルリソース名が必要
    modes             = ["MODE_IPV4"]
    connect_mode      = "DIRECT_PEERING"
    reserved_ip_range = google_compute_global_address.filestore_reserved_range.name
  }

  labels = {
    environment = var.env
    managed_by  = "terraform"
    service     = "wordpress"
  }

  description = "WordPress shared storage for ${var.env} environment"

  depends_on = [
    google_compute_global_address.filestore_reserved_range,
    google_project_service.filestore
  ]
}

