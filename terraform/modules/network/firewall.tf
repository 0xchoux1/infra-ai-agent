# ファイアウォール: Load Balancerからのヘルスチェック
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.env}-allow-health-check"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # Google Cloud ヘルスチェック用のソースレンジ
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["web-server"]
}

# ファイアウォール: Load BalancerからWebサーバーへ
resource "google_compute_firewall" "allow_lb_to_web" {
  name    = "${var.env}-allow-lb-to-web"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # Google Cloud Load Balancer用のソースレンジ
  source_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = ["web-server"]
}

# ファイアウォール: SSH（管理用）
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.env}-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP（Identity-Aware Proxy）用のソースレンジ
  source_ranges = [
    "35.235.240.0/20"
  ]

  target_tags = ["web-server", "mgmt-server"]
}

# ファイアウォール: 内部通信（Wazuh等）
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.env}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.web_subnet_cidr,
    var.mgmt_subnet_cidr
  ]
}

