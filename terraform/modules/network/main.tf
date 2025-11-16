# VPC作成
resource "google_compute_network" "vpc" {
  name                    = "${var.env}-wordpress-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  description = "WordPress hosting VPC for ${var.env} environment"
}

# Webサーバー用サブネット
resource "google_compute_subnetwork" "web" {
  name          = "${var.env}-web-subnet"
  ip_cidr_range = var.web_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  purpose                  = "PRIVATE"
  private_ip_google_access = true # Cloud SQLアクセス用

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# 管理サーバー用サブネット（Wazuh等）
resource "google_compute_subnetwork" "mgmt" {
  name          = "${var.env}-mgmt-subnet"
  ip_cidr_range = var.mgmt_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  purpose                  = "PRIVATE"
  private_ip_google_access = true
}

