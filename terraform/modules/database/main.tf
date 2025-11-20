# Cloud SQL Instance
resource "google_sql_database_instance" "wordpress" {
  name             = "${var.env}-wordpress-db"
  database_version = "MYSQL_8_0"
  region           = var.region
  
  # Service Networking依存
  # 注意: 実際の呼び出し側で depends_on = [module.network] を設定
  # モジュール全体への依存により、Service Networking接続完了を保証
  
  settings {
    tier              = var.tier
    availability_type = var.availability_type # REGIONAL（HA） or ZONAL（単一）
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size
    disk_autoresize   = true
    
    # バックアップ設定
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00" # JST 12:00（UTC 03:00）
      binary_log_enabled             = var.availability_type == "REGIONAL" # HAの場合のみ有効
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }
    
    # メンテナンスウィンドウ
    maintenance_window {
      day          = 1 # 月曜日
      hour         = 3 # JST 12:00
      update_track = "stable"
    }
    
    # IPアドレス設定（プライベートIPのみ）
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      require_ssl     = false
    }
    
    # データベースフラグ
    database_flags {
      name  = "max_connections"
      value = "200"
    }
    
    database_flags {
      name  = "innodb_buffer_pool_size"
      value = "4429185024" # 4224MB (55% of 7680MB RAM - maximum allowed)
    }
    
    # ロギング
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }
  
  deletion_protection = true # 本番環境保護
}

