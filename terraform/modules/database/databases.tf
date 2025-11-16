# サイト数を domains リストから自動計算
locals {
  site_count = length(var.domains)
}

# WordPress用データベース（domains数分）
resource "google_sql_database" "wordpress_sites" {
  count     = local.site_count
  name      = "wordpress_site_${count.index + 1}"
  instance  = google_sql_database_instance.wordpress.name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# DBユーザー（各サイト用）
resource "google_sql_user" "wordpress_users" {
  count    = local.site_count
  name     = "wp_user_${count.index + 1}"
  instance = google_sql_database_instance.wordpress.name
  password = random_password.db_passwords[count.index].result
}

# ランダムパスワード生成
resource "random_password" "db_passwords" {
  count   = local.site_count
  length  = 32
  special = true
}

# パスワードをSecret Managerに保存
resource "google_secret_manager_secret" "db_passwords" {
  count     = local.site_count
  secret_id = "${var.env}-wordpress-db-password-${count.index + 1}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_passwords" {
  count  = local.site_count
  secret = google_secret_manager_secret.db_passwords[count.index].id
  
  secret_data = random_password.db_passwords[count.index].result
}

