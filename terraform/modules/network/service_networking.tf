# Service Networking API有効化（先に実行）
resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# Cloud SQL用のプライベートIP範囲を予約
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.env}-sql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16 # 10.x.0.0/16を予約
  network       = google_compute_network.vpc.id

  description = "Reserved IP range for Cloud SQL private connection"
}

# Service Networking接続（VPC Peering）
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  depends_on = [
    google_compute_global_address.private_ip_address,
    google_project_service.servicenetworking
  ]
}

