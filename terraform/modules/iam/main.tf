# Webサーバー用サービスアカウント
resource "google_service_account" "web_server" {
  account_id   = "${var.env}-web-server"
  display_name = "WordPress Web Server Service Account"
  description  = "Service account for WordPress web servers to access GCP services"
}

# Wazuh Manager用サービスアカウント
resource "google_service_account" "wazuh_manager" {
  account_id   = "${var.env}-wazuh-manager"
  display_name = "Wazuh Manager Service Account"
  description  = "Service account for Wazuh Manager VM"
}

# Secret Manager読み取り権限
resource "google_project_iam_member" "web_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.web_server.email}"
}

# Secret Managerバージョン追加権限（既存Secretへの追加用）
resource "google_project_iam_member" "web_secret_version_adder" {
  project = var.project_id
  role    = "roles/secretmanager.secretVersionAdder"
  member  = "serviceAccount:${google_service_account.web_server.email}"
}

# Cloud SQL Client権限
resource "google_project_iam_member" "web_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.web_server.email}"
}

# Cloud Logging書き込み権限
resource "google_project_iam_member" "web_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.web_server.email}"
}

# Cloud Monitoring書き込み権限
resource "google_project_iam_member" "web_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.web_server.email}"
}

# Filestore読み書き権限
resource "google_project_iam_member" "web_filestore_editor" {
  project = var.project_id
  role    = "roles/file.editor"
  member  = "serviceAccount:${google_service_account.web_server.email}"
}

# Wazuh Manager用のLogging権限
resource "google_project_iam_member" "wazuh_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wazuh_manager.email}"
}

# Wazuh Manager用のMonitoring権限
resource "google_project_iam_member" "wazuh_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.wazuh_manager.email}"
}

