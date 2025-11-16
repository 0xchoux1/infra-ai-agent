# リージョナル・インスタンステンプレート
resource "google_compute_region_instance_template" "web" {
  name_prefix  = "${var.env}-web-template-"
  description  = "WordPress web server template"
  machine_type = var.machine_type
  region       = var.region

  tags = ["web-server", "allow-ssh", "http-server", "https-server"]

  labels = {
    environment = var.env
    managed_by  = "terraform"
    service     = "wordpress"
  }

  # ブートディスク（Debian 12 Bookworm）
  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-ssd"
  }

  # ネットワーク設定
  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    # 外部IPなし（Cloud NATを使用）
    # access_config ブロックを削除 = 外部IP割り当てなし
  }

  # メタデータ
  metadata = {
    enable-oslogin = "TRUE"
    startup-script = data.template_file.startup_script.rendered
    domains        = jsonencode(var.domains) # ドメインリストを渡す
  }

  # サービスアカウント
  service_account {
    email = var.service_account_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/secretmanager", # Secret Manager access
    ]
  }

  # テンプレート更新時に新しいリソースを先に作成
  lifecycle {
    create_before_destroy = true
  }
}

