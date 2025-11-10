# Terraform 設計書 - WordPress マルチテナント ホスティング

**プロジェクト**: GCP WordPress Hosting Platform  
**作成日**: 2025-11-04  
**バージョン**: 1.0  
**対応要件**: requirements.md v1.0

---

## 目次

1. [設計方針](#1-設計方針)
2. [モジュール構成](#2-モジュール構成)
3. [ディレクトリ構造](#3-ディレクトリ構造)
4. [ネットワーク設計](#4-ネットワーク設計)
5. [コンピュートリソース設計](#5-コンピュートリソース設計)
6. [ロードバランサー設計](#6-ロードバランサー設計)
7. [データベース設計](#7-データベース設計)
8. [セキュリティ設計](#8-セキュリティ設計)
9. [監視・ログ設計](#9-監視ログ設計)
10. [バックアップ設計](#10-バックアップ設計)
11. [変数設計](#11-変数設計)
12. [実装順序](#12-実装順序)

---

## 1. 設計方針

### 1.1 基本原則

| 原則 | 説明 |
|------|------|
| **モジュール化** | 再利用可能な小さなモジュールに分割 |
| **環境分離** | dev/prod環境を変数で切り替え可能 |
| **状態管理** | Cloud Storageバックエンドで状態を共有 |
| **命名規則** | `{env}-{service}-{resource}` 形式 |
| **タグ付け** | すべてのリソースにラベルを付与 |
| **冪等性** | 何度実行しても同じ結果 |

### 1.2 Terraformバージョン

```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}
```

### 1.3 状態管理（Terraform Backend）

```hcl
terraform {
  backend "gcs" {
    bucket = "infra-ai-agent-tfstate"
    prefix = "wordpress/prod"
  }
}
```

**初期セットアップ:**
```bash
# バックエンド用バケット作成
gsutil mb -p infra-ai-agent \
  -c STANDARD \
  -l asia-northeast1 \
  gs://infra-ai-agent-tfstate

# バージョニング有効化
gsutil versioning set on gs://infra-ai-agent-tfstate
```

---

## 2. モジュール構成

### 2.1 モジュール分割戦略

```
terraform/
├── modules/                  # 再利用可能モジュール
│   ├── network/             # VPC、Subnet、Firewall、Service Networking
│   ├── filestore/           # Cloud Filestore（WordPress共有ストレージ）
│   ├── compute/             # MIG、Instance Template
│   ├── loadbalancer/        # LB、SSL、Cloud Armor
│   ├── database/            # Cloud SQL
│   ├── security/            # Wazuh Manager
│   ├── storage/             # Cloud Storage（バックアップ）
│   └── monitoring/          # Logging、Monitoring、Alerting
│
├── environments/            # 環境別設定
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── outputs.tf
│
└── shared/                  # 共通リソース
    ├── dns/                 # Cloud DNS
    └── iam/                 # サービスアカウント
```

### 2.2 モジュール依存関係

```
[network] ← 基盤（VPC + Service Networking）
    ↓
[iam, storage] ← 共通リソース
    ↓
[database, filestore, security] ← バックエンド
    ↓
[compute] ← アプリケーション（Filestoreマウント）
    ↓
[loadbalancer] ← フロントエンド
    ↓
[monitoring] ← 監視
```

---

## 3. ディレクトリ構造

### 3.1 完全なディレクトリツリー

```
terraform/
├── modules/
│   ├── network/
│   │   ├── main.tf              # VPC、Subnet定義
│   │   ├── firewall.tf          # ファイアウォールルール
│   │   ├── nat.tf               # Cloud NAT
│   │   ├── service_networking.tf # Cloud SQL Private接続用
│   │   ├── variables.tf         # 入力変数
│   │   └── outputs.tf           # 出力値
│   │
│   ├── iam/
│   │   ├── main.tf              # サービスアカウント、IAM権限
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── filestore/
│   │   ├── main.tf              # Cloud Filestore（NFS）
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── compute/
│   │   ├── main.tf              # MIG定義
│   │   ├── instance_template.tf # インスタンステンプレート
│   │   ├── autoscaling.tf       # オートスケーリング
│   │   ├── startup_script.sh    # 起動スクリプト
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── loadbalancer/
│   │   ├── main.tf              # LB本体
│   │   ├── backend.tf           # バックエンドサービス
│   │   ├── frontend.tf          # フロントエンド（IP、SSL）
│   │   ├── cdn.tf               # Cloud CDN設定
│   │   ├── armor.tf             # Cloud Armor（WAF）
│   │   ├── ssl.tf               # SSL証明書
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── database/
│   │   ├── main.tf              # Cloud SQL定義
│   │   ├── ha.tf                # HA設定
│   │   ├── backup.tf            # バックアップ設定
│   │   ├── users.tf             # DBユーザー
│   │   ├── databases.tf         # データベース作成
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── security/
│   │   ├── main.tf              # Wazuh Manager VM
│   │   ├── startup_script.sh    # Wazuh初期化
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── storage/
│   │   ├── main.tf              # バックアップバケット
│   │   ├── lifecycle.tf         # ライフサイクルポリシー
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── monitoring/
│       ├── main.tf              # Cloud Monitoring
│       ├── alerting.tf          # アラートポリシー
│       ├── logging.tf           # ログシンク
│       ├── notification.tf      # Slack通知
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars     # 機密情報あり（Git除外）
│       ├── terraform.tfvars.example
│       └── outputs.tf
│
└── shared/
    ├── backend.tf               # Terraform Backend設定
    ├── provider.tf              # プロバイダー設定
    └── versions.tf              # バージョン制約
```

---

## 4. ネットワーク設計

### 4.1 VPC設計

**modules/network/main.tf:**
```hcl
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
  
  purpose               = "PRIVATE"
  private_ip_google_access = true  # Cloud SQLアクセス用
  
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
  
  purpose               = "PRIVATE"
  private_ip_google_access = true
}
```

### 4.2 Service Networking（Cloud SQL Private接続）

**modules/network/service_networking.tf:**
```hcl
# Cloud SQL用のプライベートIP範囲を予約
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.env}-sql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16  # 10.x.0.0/16を予約
  network       = google_compute_network.vpc.id
  
  description = "Reserved IP range for Cloud SQL private connection"
}

# Service Networking API有効化（先に実行）
resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
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
```

**modules/network/outputs.tf:**
```hcl
output "vpc_id" {
  description = "VPC network ID"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "web_subnet_id" {
  description = "Web subnet ID"
  value       = google_compute_subnetwork.web.id
}

output "mgmt_subnet_id" {
  description = "Management subnet ID"
  value       = google_compute_subnetwork.mgmt.id
}

output "service_networking_connection" {
  description = "Service Networking connection resource (for depends_on)"
  value       = google_service_networking_connection.private_vpc_connection
}
```

### 4.3 Cloud NAT設計

**modules/network/nat.tf:**
```hcl
# Cloud Router（NAT用）
resource "google_compute_router" "nat_router" {
  name    = "${var.env}-nat-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Cloud NAT（プライベートVMからインターネットへ）
resource "google_compute_router_nat" "nat" {
  name   = "${var.env}-nat"
  router = google_compute_router.nat_router.name
  region = var.region
  
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

### 4.4 ファイアウォールルール

**modules/network/firewall.tf:**
```hcl
# Load BalancerからWebサーバーへのHTTP/HTTPS
resource "google_compute_firewall" "allow_lb_to_web" {
  name    = "${var.env}-allow-lb-to-web"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  
  # Load Balancer Health Check範囲
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  
  target_tags = ["web-server"]
  priority    = 1000
}

# WebサーバーからCloud SQLへ
resource "google_compute_firewall" "allow_web_to_sql" {
  name    = "${var.env}-allow-web-to-sql"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
  
  source_tags = ["web-server"]
  target_tags = ["cloud-sql"]
  priority    = 1000
}

# Wazuh Agent → Wazuh Manager
resource "google_compute_firewall" "allow_wazuh_agent" {
  name    = "${var.env}-allow-wazuh-agent"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["1514", "1515", "55000"]
  }
  
  allow {
    protocol = "udp"
    ports    = ["1514"]
  }
  
  source_tags = ["web-server"]
  target_tags = ["wazuh-manager"]
  priority    = 1000
}

# Identity-Aware Proxy経由のSSH
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.env}-allow-iap-ssh"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  # IAP範囲
  source_ranges = ["35.235.240.0/20"]
  
  target_tags = ["allow-ssh"]
  priority    = 1000
}

# デフォルト拒否（最低優先度）
resource "google_compute_firewall" "deny_all" {
  name    = "${var.env}-deny-all"
  network = google_compute_network.vpc.name
  
  deny {
    protocol = "all"
  }
  
  source_ranges = ["0.0.0.0/0"]
  priority      = 65534
}
```

---

## 5. IAM設計（サービスアカウントと権限）

### 5.1 サービスアカウント作成

**modules/iam/main.tf:**
```hcl
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
```

### 5.2 IAM権限バインディング

**modules/iam/main.tf（続き）:**
```hcl
# Secret Manager読み取り権限
resource "google_project_iam_member" "web_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.web_server.email}"
}

# Secret Manager作成権限（WordPress管理者パスワード保存用）
resource "google_project_iam_member" "web_secret_creator" {
  project = var.project_id
  role    = "roles/secretmanager.secretCreator"
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

resource "google_project_iam_member" "wazuh_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.wazuh_manager.email}"
}
```

### 5.3 変数と出力

**modules/iam/variables.tf:**
```hcl
variable "env" {
  description = "Environment name"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}
```

**modules/iam/outputs.tf:**
```hcl
output "web_server_service_account_email" {
  description = "Web server service account email"
  value       = google_service_account.web_server.email
}

output "web_server_service_account_id" {
  description = "Web server service account ID"
  value       = google_service_account.web_server.id
}

output "wazuh_manager_service_account_email" {
  description = "Wazuh Manager service account email"
  value       = google_service_account.wazuh_manager.email
}
```

---

## 6. Cloud Filestore設計（WordPress共有ストレージ）

### 6.1 Filestore Instance

**modules/filestore/main.tf:**
```hcl
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
  prefix_length = 29  # /29（8 IPs）- Filestoreの最小要件
  network       = var.network_id
  
  description = "Reserved IP range for Filestore"
}

# Cloud Filestore（NFS）
resource "google_filestore_instance" "wordpress" {
  name     = "${var.env}-wordpress-nfs"
  location = var.zone
  tier     = var.tier  # BASIC_HDD（1TB～）, BASIC_SSD, HIGH_SCALE_SSD
  
  file_shares {
    name        = "wordpress"
    capacity_gb = var.capacity_gb  # 最小1024GB（BASIC_HDD）
  }
  
  networks {
    network           = var.network_id  # フルリソース名が必要
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
```

**modules/filestore/variables.tf:**
```hcl
variable "env" {
  description = "Environment name"
  type        = string
}

variable "zone" {
  description = "Zone for Filestore instance"
  type        = string
}

variable "tier" {
  description = "Filestore tier"
  type        = string
  default     = "BASIC_HDD"
  
  validation {
    condition     = contains(["BASIC_HDD", "BASIC_SSD", "HIGH_SCALE_SSD"], var.tier)
    error_message = "Tier must be one of: BASIC_HDD, BASIC_SSD, HIGH_SCALE_SSD"
  }
}

variable "capacity_gb" {
  description = "Filestore capacity in GB"
  type        = number
  default     = 1024  # BASIC_HDD minimum
  
  validation {
    condition     = var.capacity_gb >= 1024
    error_message = "BASIC_HDD requires minimum 1024 GB"
  }
}

variable "network_id" {
  description = "VPC network ID (full resource name: projects/{project}/global/networks/{network})"
  type        = string
}
```

**modules/filestore/outputs.tf:**
```hcl
output "nfs_ip" {
  description = "NFS server IP address"
  value       = google_filestore_instance.wordpress.networks[0].ip_addresses[0]
}

output "nfs_path" {
  description = "NFS export path"
  value       = "/${google_filestore_instance.wordpress.file_shares[0].name}"
}

output "mount_command" {
  description = "NFS mount command"
  value       = "mount -t nfs ${google_filestore_instance.wordpress.networks[0].ip_addresses[0]}:/${google_filestore_instance.wordpress.file_shares[0].name} /mnt/wordpress"
}
```

### 6.2 コスト削減移行パス（Phase 2）

**将来的な移行オプション:**

#### オプションA: GCS FUSE（推奨）
```bash
# コスト削減: Filestore（¥15,000/月） → GCS（¥2,000/月）
# 約85%コスト削減

# GCS Bucket作成
gsutil mb gs://${PROJECT_ID}-wordpress-files

# gcsfuse インストール（起動スクリプト内）
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | \
  sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
  sudo apt-key add -
apt-get update && apt-get install -y gcsfuse

# マウント
gcsfuse -o allow_other ${PROJECT_ID}-wordpress-files /var/www/wordpress
```

**注意事項:**
- パフォーマンスは劣る（特に小ファイル多数時）
- キャッシュ設定が重要
- WordPress環境で十分テストすること

---

## 7. コンピュートリソース設計

### 7.1 インスタンステンプレート

**modules/compute/instance_template.tf:**
```hcl
# 起動スクリプト読み込み
data "template_file" "startup_script" {
  template = file("${path.module}/startup_script.sh")
  
  vars = {
    env            = var.env
    db_host        = var.db_host
    wazuh_manager  = var.wazuh_manager_ip
    project_id     = var.project_id
    nfs_ip         = var.nfs_ip
    nfs_path       = var.nfs_path
    domains_json   = jsonencode(var.domains)
  }
}

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
    domains        = jsonencode(var.domains)  # ドメインリストを渡す
  }
  
  # サービスアカウント
  service_account {
    email  = var.service_account_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/secretmanager",  # Secret Manager access
    ]
  }
  
  # テンプレート更新時に新しいリソースを先に作成
  lifecycle {
    create_before_destroy = true
  }
}
```

### 7.2 起動スクリプト（10サイト対応）

**modules/compute/startup_script.sh:**
```bash
#!/bin/bash
set -e

# ログ設定
exec 1> >(logger -s -t startup-script) 2>&1

echo "Starting WordPress web server setup..."

# 環境変数
ENV="${env}"
DB_HOST="${db_host}"
WAZUH_MANAGER="${wazuh_manager}"
PROJECT_ID="${project_id}"
NFS_IP="${nfs_ip}"
NFS_PATH="${nfs_path}"
DOMAINS_JSON='${domains_json}'

# システム更新
apt-get update
apt-get upgrade -y

# Google Cloud SDK リポジトリ追加
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
  tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
  apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# パッケージリスト更新
apt-get update

# 必須パッケージインストール（Cloud SDK含む）
apt-get install -y \
  nginx \
  php8.2-fpm \
  php8.2-mysql \
  php8.2-curl \
  php8.2-gd \
  php8.2-mbstring \
  php8.2-xml \
  php8.2-xmlrpc \
  php8.2-soap \
  php8.2-intl \
  php8.2-zip \
  php8.2-bcmath \
  php8.2-imagick \
  mysql-client \
  nfs-common \
  curl \
  wget \
  unzip \
  git \
  jq \
  google-cloud-sdk

# WP-CLIインストール
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# NFSマウント（Cloud Filestore）
mkdir -p /var/www/wordpress
if ! mount | grep -q '/var/www/wordpress'; then
  mount -t nfs -o rw,hard,intr,rsize=1048576,wsize=1048576 \
    ${NFS_IP}:${NFS_PATH} /var/www/wordpress
  
  # /etc/fstab に追加（再起動時も自動マウント）
  echo "${NFS_IP}:${NFS_PATH} /var/www/wordpress nfs rw,hard,intr,rsize=1048576,wsize=1048576 0 0" >> /etc/fstab
fi

# ドメインリストを取得（メタデータまたはテンプレート変数から）
if [ -z "$DOMAINS_JSON" ]; then
  # メタデータから取得（フォールバック）
  DOMAINS_JSON=$(curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/attributes/domains)
fi

# ドメイン数を取得
DOMAIN_COUNT=$(echo "$DOMAINS_JSON" | jq '. | length')

echo "Setting up $DOMAIN_COUNT WordPress sites..."

# ドメイン数分のディレクトリ作成
for i in $(seq 1 $DOMAIN_COUNT); do
  mkdir -p /var/www/wordpress/site${i}
done

chown -R www-data:www-data /var/www/wordpress

# Nginx基本設定
cat > /etc/nginx/nginx.conf << 'NGINX_CONF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # ログ設定
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip圧縮
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # サイト設定を読み込み
    include /etc/nginx/sites-enabled/*;
}
NGINX_CONF

# Health Checkエンドポイント
cat > /etc/nginx/sites-available/health << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location / {
        return 404;
    }
}
EOF

# Nginx設定テンプレート生成関数
generate_site_config() {
  local site_num=$1
  local domain=$2
  
  cat > /etc/nginx/sites-available/site${site_num} << SITE_EOF
server {
    listen 80;
    server_name ${domain};
    
    root /var/www/wordpress/site${site_num};
    index index.php index.html;
    
    # WordPress Permalinks
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # PHP処理
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        
        # Cache-Control（WordPress側で動的設定）
        fastcgi_hide_header Cache-Control;
    }
    
    # 静的ファイルキャッシュ
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
        access_log off;
    }
    
    # 管理画面（キャッシュ無効）
    location ~ ^/wp-(admin|login|cron) {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # セキュリティヘッダー
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # アップロードサイズ制限
    client_max_body_size 64M;
}
SITE_EOF
}

# ドメインリストを配列に変換してNginx設定生成
site_num=0
echo "$DOMAINS_JSON" | jq -r '.[]' | while IFS= read -r domain; do
  site_num=$((site_num + 1))
  echo "Configuring site${site_num}: ${domain}"
  generate_site_config $site_num "$domain"
  ln -sf /etc/nginx/sites-available/site${site_num} /etc/nginx/sites-enabled/site${site_num}
done

ln -sf /etc/nginx/sites-available/health /etc/nginx/sites-enabled/health
rm -f /etc/nginx/sites-enabled/default

# PHP-FPM設定（OPcache最適化）
cat > /etc/php/8.2/fpm/conf.d/99-wordpress-optimize.ini << 'PHP_INI'
; OPcache設定
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.revalidate_freq=2
opcache.fast_shutdown=1

; アップロード設定
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300

; セッション設定
session.cookie_httponly = 1
session.cookie_secure = 1
PHP_INI
# WordPress初期セットアップスクリプト生成
cat > /usr/local/bin/setup-wordpress-site.sh << 'SETUP_SCRIPT'
#!/bin/bash
# WordPress サイトセットアップスクリプト
# 使用方法: setup-wordpress-site.sh <site_num> <domain> <site_title>

SITE_NUM=$1
DOMAIN=$2
SITE_TITLE=$3

if [ -z "$SITE_NUM" ] || [ -z "$DOMAIN" ] || [ -z "$SITE_TITLE" ]; then
  echo "Usage: $0 <site_num> <domain> <site_title>"
  echo "Example: $0 1 example.com 'My Blog'"
  exit 1
fi

SITE_DIR="/var/www/wordpress/site${SITE_NUM}"
DB_NAME="wordpress_site_${SITE_NUM}"
DB_USER="wp_user_${SITE_NUM}"

# Secret Managerから DB パスワード取得
DB_PASS=$(gcloud secrets versions access latest \
  --secret="${ENV}-wordpress-db-password-${SITE_NUM}" \
  --project="${PROJECT_ID}")

# WordPress ダウンロード
cd $SITE_DIR
if [ ! -f wp-config.php ]; then
  sudo -u www-data wp core download
  
  # wp-config.php 作成
  sudo -u www-data wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASS}" \
    --dbhost="${DB_HOST}"
  
  # 管理者パスワード生成
  ADMIN_PASSWORD=$(openssl rand -base64 32)
  
  # WordPress インストール
  sudo -u www-data wp core install \
    --url="https://${DOMAIN}" \
    --title="${SITE_TITLE}" \
    --admin_user="admin" \
    --admin_password="${ADMIN_PASSWORD}" \
    --admin_email="admin@${DOMAIN}"
  
  # 管理者パスワードをSecret Managerに保存
  echo -n "${ADMIN_PASSWORD}" | gcloud secrets create \
    "${ENV}-wordpress-admin-password-${SITE_NUM}" \
    --data-file=- \
    --project="${PROJECT_ID}" 2>/dev/null || \
  echo -n "${ADMIN_PASSWORD}" | gcloud secrets versions add \
    "${ENV}-wordpress-admin-password-${SITE_NUM}" \
    --data-file=- \
    --project="${PROJECT_ID}"
  
  # Cache-Control プラグインインストール（オプション）
  # 実際のプラグインが決まったら、以下のようにインストール
  # sudo -u www-data wp plugin install nginx-helper --activate
  # sudo -u www-data wp plugin install w3-total-cache --activate
  
  echo "=========================================="
  echo "WordPress site ${SITE_NUM} installed successfully!"
  echo "URL: https://${DOMAIN}"
  echo "Admin User: admin"
  echo "Admin Password: Saved to Secret Manager"
  echo "  Retrieve with: gcloud secrets versions access latest --secret=${ENV}-wordpress-admin-password-${SITE_NUM}"
  echo "=========================================="
else
  echo "WordPress already installed in ${SITE_DIR}"
fi
SETUP_SCRIPT

chmod +x /usr/local/bin/setup-wordpress-site.sh

# サービス再起動
systemctl restart php8.2-fpm
systemctl restart nginx
systemctl enable nginx php8.2-fpm

# Cloud Logging Agentインストール
curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
bash add-logging-agent-repo.sh --also-install

# Wazuh Agentインストール
if [ ! -z "$WAZUH_MANAGER" ]; then
  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
  echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
  apt-get update
  WAZUH_MANAGER="$WAZUH_MANAGER" apt-get install -y wazuh-agent
  systemctl daemon-reload
  systemctl enable wazuh-agent
  systemctl start wazuh-agent
fi

echo "Startup script completed successfully!"
```

### 7.3 Managed Instance Group

**modules/compute/main.tf:**
```hcl
# Health Check
resource "google_compute_health_check" "web" {
  name                = "${var.env}-web-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
  
  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

# Managed Instance Group
resource "google_compute_region_instance_group_manager" "web" {
  name               = "${var.env}-web-mig"
  region             = var.region
  base_instance_name = "${var.env}-web"
  
  version {
    instance_template = google_compute_region_instance_template.web.id
  }
  
  target_size = var.min_replicas
  
  named_port {
    name = "http"
    port = 80
  }
  
  auto_healing_policies {
    health_check      = google_compute_health_check.web.id
    initial_delay_sec = 300
  }
  
  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    max_surge_fixed                = 3
    max_unavailable_fixed          = 0
    instance_redistribution_type   = "PROACTIVE"
    replacement_method             = "SUBSTITUTE"
  }
}
```

### 7.4 Auto Scaling

**modules/compute/autoscaling.tf:**
```hcl
resource "google_compute_region_autoscaler" "web" {
  name   = "${var.env}-web-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.web.id
  
  autoscaling_policy {
    min_replicas    = var.min_replicas  # 2
    max_replicas    = var.max_replicas  # 4
    cooldown_period = 60
    
    # CPU使用率ベース
    cpu_utilization {
      target = 0.9  # 90%でスケールアウト
    }
    
    # スケーリングモード
    mode = "ON"
    
    # スケールイン時の動作
    scale_in_control {
      max_scaled_in_replicas {
        fixed = 1
      }
      time_window_sec = 600  # 10分
    }
  }
}
```

---

## 8. ロードバランサー設計

### 8.1 Backend Service

**modules/loadbalancer/backend.tf:**
```hcl
# Backend Service
resource "google_compute_backend_service" "wordpress" {
  name                  = "${var.env}-wordpress-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = true
  
  health_checks = [var.health_check_id]
  
  backend {
    group           = var.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = 0.8
  }
  
  # Cloud CDN設定
  cdn_policy {
    cache_mode = "USE_ORIGIN_HEADERS"
    
    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = true
      
      # WordPress用クエリパラメータ
      query_string_whitelist = ["p", "page_id", "preview", "s", "cat", "tag"]
      
      # ログイン状態で区別
      include_named_cookies = [
        "wordpress_logged_in_*",
        "wp-settings-*",
        "comment_author_*"
      ]
    }
    
    default_ttl = 300   # 5分
    max_ttl     = 3600  # 1時間
    client_ttl  = 300
    
    negative_caching = true
    negative_caching_policy {
      code = 404
      ttl  = 120
    }
  }
  
  # Cloud Armor（WAF）
  security_policy = google_compute_security_policy.wordpress_waf.id
  
  # ロギング
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}
```

### 8.2 SSL証明書（Let's Encrypt）

**modules/loadbalancer/ssl.tf:**
```hcl
# Google-managed SSL証明書
resource "google_compute_managed_ssl_certificate" "wordpress" {
  name = "${var.env}-wordpress-ssl"
  
  managed {
    domains = var.domains  # ["example.com", "www.example.com"]
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# 将来的なLet's Encrypt用の予約
# Phase 2で実装: certbot + Cloud Functions + Cloud Scheduler
```

### 8.3 Frontend（URL Map、Proxy）

**modules/loadbalancer/frontend.tf:**
```hcl
# Global IP Address
resource "google_compute_global_address" "wordpress" {
  name = "${var.env}-wordpress-ip"
}

# URL Map
resource "google_compute_url_map" "wordpress" {
  name            = "${var.env}-wordpress-lb"
  default_service = google_compute_backend_service.wordpress.id
  
  # ホストルール（マルチドメイン対応）
  dynamic "host_rule" {
    for_each = var.domains
    content {
      hosts        = [host_rule.value]
      path_matcher = "wordpress"
    }
  }
  
  path_matcher {
    name            = "wordpress"
    default_service = google_compute_backend_service.wordpress.id
  }
}

# HTTPS Proxy
resource "google_compute_target_https_proxy" "wordpress" {
  name             = "${var.env}-wordpress-https-proxy"
  url_map          = google_compute_url_map.wordpress.id
  ssl_certificates = [google_compute_managed_ssl_certificate.wordpress.id]
}

# HTTP Proxy（HTTPSへリダイレクト）
resource "google_compute_target_http_proxy" "wordpress" {
  name    = "${var.env}-wordpress-http-proxy"
  url_map = google_compute_url_map.wordpress_redirect.id
}

# HTTPリダイレクト用URL Map
resource "google_compute_url_map" "wordpress_redirect" {
  name = "${var.env}-wordpress-redirect"
  
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Forwarding Rule（HTTPS）
resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.env}-wordpress-https"
  target     = google_compute_target_https_proxy.wordpress.id
  port_range = "443"
  ip_address = google_compute_global_address.wordpress.address
}

# Forwarding Rule（HTTP）
resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.env}-wordpress-http"
  target     = google_compute_target_http_proxy.wordpress.id
  port_range = "80"
  ip_address = google_compute_global_address.wordpress.address
}
```

### 8.4 Cloud Armor（WAF）

**modules/loadbalancer/armor.tf:**
```hcl
resource "google_compute_security_policy" "wordpress_waf" {
  name        = "${var.env}-wordpress-waf"
  description = "Cloud Armor WAF policy for WordPress"
  
  # OWASP Top 10対策
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "SQL Injection protection"
  }
  
  rule {
    action   = "deny(403)"
    priority = "1001"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "XSS protection"
  }
  
  rule {
    action   = "deny(403)"
    priority = "1002"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
    description = "Local File Inclusion protection"
  }
  
  rule {
    action   = "deny(403)"
    priority = "1003"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-stable')"
      }
    }
    description = "Remote File Inclusion protection"
  }
  
  rule {
    action   = "deny(403)"
    priority = "1004"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-stable')"
      }
    }
    description = "Remote Code Execution protection"
  }
  
  # レート制限
  rule {
    action   = "rate_based_ban"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      
      ban_duration_sec = 600  # 10分間バン
    }
    description = "Rate limiting: 100 req/min per IP"
  }
  
  # デフォルト許可
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }
  
  # アダプティブ保護（オプション）
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}
```

---

## 9. データベース設計

### 9.1 Cloud SQL（MySQL HA）

**modules/database/main.tf:**
```hcl
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
    availability_type = var.availability_type  # REGIONAL（HA） or ZONAL（単一）
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size
    disk_autoresize   = true
    
    # バックアップ設定
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"  # JST 12:00（UTC 03:00）
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }
    
    # メンテナンスウィンドウ
    maintenance_window {
      day          = 1  # 月曜日
      hour         = 3  # JST 12:00
      update_track = "stable"
    }
    
    # IPアドレス設定（プライベートIPのみ）
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      require_ssl     = true
    }
    
    # データベースフラグ
    database_flags {
      name  = "max_connections"
      value = "200"
    }
    
    database_flags {
      name  = "innodb_buffer_pool_size"
      value = "268435456"  # 256MB
    }
    
    # ロギング
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }
  
  deletion_protection = true  # 本番環境保護
}
```

### 9.2 データベースとユーザー作成

**modules/database/databases.tf:**
```hcl
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
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "db_passwords" {
  count  = local.site_count
  secret = google_secret_manager_secret.db_passwords[count.index].id
  
  secret_data = random_password.db_passwords[count.index].result
}
```

### 9.3 データベース変数

**modules/database/variables.tf（追加）:**
```hcl
variable "availability_type" {
  description = "Availability type: REGIONAL (HA) or ZONAL (single zone)"
  type        = string
  default     = "REGIONAL"
  
  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.availability_type)
    error_message = "availability_type must be either REGIONAL or ZONAL"
  }
}
```

### 9.4 コスト最適化移行パス（Phase 2）

**Cloud SQL コスト削減:**
```hcl
# Phase 1（無料枠期間）: HA構成
tier = "db-custom-2-7680"  # 2 vCPU, 7.5GB RAM
availability_type = "REGIONAL"
# 推定コスト: ¥15,000/月

# Phase 2（コスト重視）: スタンドアロン + 小スペック
tier = "db-custom-1-3840"  # 1 vCPU, 3.75GB RAM
availability_type = "ZONAL"
# 推定コスト: ¥5,000/月

# Phase 3（最小コスト）: VM MySQL移行
# requirements.md「8. 移行計画」参照
# 推定コスト: ¥1,500/月
```

---

## 10. セキュリティ設計

### 10.1 Wazuh Manager

**modules/security/main.tf:**
```hcl
# Wazuh Manager VM
resource "google_compute_instance" "wazuh_manager" {
  name         = "${var.env}-wazuh-manager"
  machine_type = "e2-small"
  zone         = "${var.region}-a"
  
  tags = ["wazuh-manager", "allow-ssh"]
  
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-ssd"
    }
  }
  
  network_interface {
    subnetwork = var.mgmt_subnet
    
    # プライベートIPのみ
  }
  
  metadata_startup_script = file("${path.module}/startup_script.sh")
  
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
  
  allow_stopping_for_update = true
}
```

**modules/security/startup_script.sh:**
```bash
#!/bin/bash
# Wazuh Manager初期化スクリプト

# Wazuh Managerインストール
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
bash ./wazuh-install.sh -a

# ファイアウォール設定
ufw allow 1514/tcp
ufw allow 1514/udp
ufw allow 1515/tcp
ufw allow 55000/tcp
ufw --force enable

echo "Wazuh Manager installation completed"
```

---

## 11. 監視・ログ設計

**modules/monitoring/alerting.tf:**
```hcl
# アラートポリシー: サービス監視
resource "google_monitoring_alert_policy" "http_health_check_failed" {
  display_name = "${var.env}-http-health-check-failed"
  combiner     = "OR"
  
  conditions {
    display_name = "HTTP Health Check Failed"
    
    condition_threshold {
      filter          = "resource.type=\"http_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/backend_request_count\""
      duration        = "120s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.slack.id]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Slack通知チャンネル
resource "google_monitoring_notification_channel" "slack" {
  display_name = "${var.env}-slack-alerts"
  type         = "slack"
  
  labels = {
    channel_name = var.slack_channel
  }
  
  sensitive_labels {
    auth_token = var.slack_webhook_url
  }
}
```

---

## 12. バックアップ設計

**modules/storage/main.tf:**
```hcl
# バックアップ用バケット
resource "google_storage_bucket" "backups" {
  name          = "${var.project_id}-${var.env}-backups"
  location      = var.region
  storage_class = "STANDARD"
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
  
  uniform_bucket_level_access = true
}
```

---

## 13. 変数設計

**environments/prod/variables.tf（共通定義）:**
```hcl
variable "domains" {
  description = "List of fully qualified domains served by this environment"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.domains) > 0
    error_message = "At least one domain must be specified for WordPress sites"
  }
}

variable "db_availability_type" {
  description = "REGIONAL for HA, ZONAL for single-zone"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.db_availability_type)
    error_message = "db_availability_type must be REGIONAL or ZONAL"
  }
}
```

**environments/prod/main.tf（モジュール呼び出し例）:**
```hcl
# ネットワークモジュール
module "network" {
  source = "../../modules/network"
  
  env              = var.env
  region           = var.region
  web_subnet_cidr  = var.web_subnet_cidr
  mgmt_subnet_cidr = var.mgmt_subnet_cidr
}

# データベースモジュール
module "database" {
  source = "../../modules/database"
  
  env               = var.env
  region            = var.region
  tier              = var.db_tier
  availability_type = var.db_availability_type
  disk_size         = var.db_disk_size
  network_id        = module.network.vpc_id
  domains           = var.domains  # site_count は自動計算
  
  # Service Networking 依存（モジュール全体を指定）
  depends_on = [module.network]
}

# Filestoreモジュール
module "filestore" {
  source = "../../modules/filestore"
  
  env         = var.env
  zone        = var.zone
  tier        = var.filestore_tier
  capacity_gb = var.filestore_capacity_gb
  network_id  = module.network.vpc_id  # フルリソース名
  
  # ネットワーク依存
  depends_on = [module.network]
}
```

**environments/prod/terraform.tfvars.example:**
```hcl
# プロジェクト設定
project_id = "infra-ai-agent"
region     = "asia-northeast1"
zone       = "asia-northeast1-a"
env        = "prod"

# ネットワーク
web_subnet_cidr  = "10.0.1.0/24"
mgmt_subnet_cidr = "10.0.2.0/24"

# コンピュート
machine_type  = "e2-medium"
min_replicas  = 2
max_replicas  = 4

# Cloud Filestore（Phase 1: GCP機能活用）
filestore_tier        = "BASIC_HDD"
filestore_capacity_gb = 1024  # 最小1TB

# データベース（Phase 1: HA構成）
db_tier              = "db-custom-2-7680"  # 2 vCPU, 7.5GB RAM（HA対応）
db_availability_type = "REGIONAL"          # HA構成（Primary + Standby）
db_disk_size         = 20

# ドメイン（10サイト分）
# 注意: site_count は自動計算されるため指定不要
# DB/Secret/Nginx設定すべてこのリストから生成される
domains = [
  "site1.example.com",
  "site2.example.com",
  "site3.example.com",
  "site4.example.com",
  "site5.example.com",
  "site6.example.com",
  "site7.example.com",
  "site8.example.com",
  "site9.example.com",
  "site10.example.com"
]

# Slack通知
slack_channel     = "#infra-alerts"
slack_webhook_url = "設定が必要"
```

**environments/dev/terraform.tfvars.example（コスト削減版）:**
```hcl
project_id = "infra-ai-agent"
region     = "asia-northeast1"
zone       = "asia-northeast1-a"
env        = "dev"

# 開発環境は最小構成
machine_type  = "e2-small"
min_replicas  = 1
max_replicas  = 2

# Filestore最小構成
filestore_tier        = "BASIC_HDD"
filestore_capacity_gb = 1024

# DB最小構成（HA無効）
db_tier              = "db-custom-1-3840"  # 1 vCPU, 3.75GB
db_availability_type = "ZONAL"             # スタンドアロン構成

# 開発環境は2サイトのみ
domains = [
  "dev-site1.example.com",
  "dev-site2.example.com"
]
```

---

## 14. 実装順序

### Phase 1: 基盤構築（Week 1）

```bash
# 1. API有効化
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable file.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable iam.googleapis.com

# 2. Terraform初期化
cd environments/prod
terraform init

# 3. ネットワーク（Service Networking含む）
terraform plan -target=module.network
terraform apply -target=module.network

# 4. IAM（サービスアカウントと権限）
terraform plan -target=module.iam
terraform apply -target=module.iam

# 5. Storage（バックアップ用）
terraform plan -target=module.storage
terraform apply -target=module.storage

# 6. Filestore（NFS共有ストレージ）
terraform plan -target=module.filestore
terraform apply -target=module.filestore

# 7. データベース（Service Networking依存）
terraform plan -target=module.database
terraform apply -target=module.database

# 8. セキュリティ（Wazuh）
terraform plan -target=module.security
terraform apply -target=module.security

# 9. コンピュート（Filestoreマウント、IAM権限使用）
terraform plan -target=module.compute
terraform apply -target=module.compute

# 10. ロードバランサー
terraform plan -target=module.loadbalancer
terraform apply -target=module.loadbalancer

# 11. 監視
terraform plan -target=module.monitoring
terraform apply -target=module.monitoring

# 12. 全体確認
terraform plan
terraform apply
```

### Phase 1完了後の動作確認

```bash
# 1. Filestoreマウント確認
gcloud compute ssh <vm-name> --command "df -h | grep wordpress"

# 2. Cloud SQL接続確認
MYSQL_IP=$(gcloud sql instances describe prod-wordpress-db \
  --format='value(ipAddresses[0].ipAddress)')
gcloud compute ssh <vm-name> --command "mysql -h $MYSQL_IP -u root -p"

# 3. WordPressサイトセットアップ
gcloud compute ssh <vm-name> --command "sudo /usr/local/bin/setup-wordpress-site.sh 1 site1.example.com 'Site 1'"

# 4. Load Balancer IPの取得
gcloud compute addresses describe prod-wordpress-ip --global --format="value(address)"

# 5. DNSレコード設定（Cloud DNS）
# site1.example.com → LB IP
```

### Phase 1完了時の検証項目

```bash
# 1. IAM権限確認
gcloud projects get-iam-policy infra-ai-agent \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:prod-web-server@*"

# 2. Service Networking接続確認
gcloud services vpc-peerings list \
  --network=prod-wordpress-vpc \
  --service=servicenetworking.googleapis.com

# 3. Secret Manager アクセステスト
gcloud compute ssh <vm-name> --command \
  "gcloud secrets versions access latest --secret=prod-wordpress-db-password-1"

# 4. ドメイン設定確認
gcloud compute ssh <vm-name> --command \
  "cat /etc/nginx/sites-enabled/site1 | grep server_name"
```

---

## 15. コスト推定と最適化パス

### Phase 1: GCP機能フル活用（無料枠期間）

| リソース | スペック | 月額（推定） |
|---------|---------|-------------|
| Cloud Filestore | BASIC_HDD 1TB | ¥15,000 |
| Cloud SQL | db-custom-2-7680 HA | ¥15,000 |
| MIG (e2-medium x2) | 2 vCPU, 4GB x2 | ¥6,000 |
| Cloud Load Balancer | - | ¥2,500 |
| Cloud CDN | 100GB転送 | ¥800 |
| Cloud Armor | Standard | ¥2,000 |
| Wazuh Manager | e2-small | ¥2,500 |
| その他 | DNS, Logging等 | ¥1,000 |
| **合計** | | **¥44,800/月** |

**無料枠（¥40,000）で約1ヶ月カバー可能**

### Phase 2: コスト最適化（無料枠終了後）

| リソース | 変更内容 | 月額削減 |
|---------|---------|---------|
| Filestore → GCS FUSE | NFS廃止 | -¥13,000 |
| Cloud SQL → db-custom-1-3840 ZONAL | HA無効 | -¥10,000 |
| **合計** | | **¥21,800/月** |

### Phase 3: 最小コスト構成

| リソース | 変更内容 | 月額 |
|---------|---------|------|
| GCS（WordPress Files） | 100GB | ¥2,000 |
| VM MySQL | e2-medium内 | ¥0（含） |
| MIG (e2-small x1) | 最小構成 | ¥3,000 |
| Cloud LB（簡略） | - | ¥1,500 |
| その他 | 最小化 | ¥500 |
| **合計** | | **¥7,000/月** |

**目標（¥3,000/月）達成には更なる最適化が必要**
- Cloud Armor → Cloudflare Free移行
- Cloud Load Balancer → Cloudflare Proxy移行
- MIG → 単一VM（HA無し）

---

---

## 16. 修正履歴

### v1.1 (2025-11-04) - レビュー指摘事項対応（第1回）

**修正内容:**

1. **Cloud SQL depends_on 修正**
   - `depends_on`をリソース直下に移動
   - `modules/network/outputs.tf`に`service_networking_connection`出力追加

2. **Google Cloud SDK インストール追加**
   - 起動スクリプトに`google-cloud-sdk`パッケージ追加
   - Secret Manager APIアクセスに必要な`gcloud`コマンド利用可能に

3. **IAMモジュール追加**
   - `modules/iam/`モジュール新規作成
   - サービスアカウント作成と権限バインディング実装
   - 必要な権限:
     - `roles/secretmanager.secretAccessor` - Secret読み取り
     - `roles/cloudsql.client`
     - `roles/logging.logWriter`
     - `roles/monitoring.metricWriter`
     - `roles/file.editor`

4. **ドメイン連携機能追加**
   - Instance Templateメタデータ経由でドメインリストを渡す
   - 起動スクリプトでメタデータからドメイン取得
   - Nginx設定を実際のドメインで動的生成
   - ハードコードされた`site${i}.example.com`を排除

**影響範囲:**
- セクション番号が5→6以降シフト
- 実装順序にIAMモジュール追加
- 検証項目追加

### v1.2 (2025-11-04) - レビュー指摘事項対応（第2回）

**修正内容:**

1. **Cloud SQL depends_on の正しい記述方法を明示**
   - ❌ 誤: `depends_on = [var.service_networking_connection]`（変数は不可）
   - ❌ 誤: `depends_on = [module.network.service_networking_connection]`（モジュール出力は不可）
   - ✅ 正: モジュール呼び出し側で `depends_on = [module.network]`
   - 設計書にモジュール呼び出し例を追加

2. **Filestore reserved_ip_range 追加**
   - `google_compute_global_address` で /29 IP範囲を予約
   - `networks.reserved_ip_range` パラメータに設定
   - `DIRECT_PEERING` 使用時の必須要件を満たす

3. **site_count と domains の整合性保証**
   - `site_count` 変数を廃止
   - `local.site_count = length(var.domains)` で自動計算
   - DB、Secret、Nginx設定すべてが `domains` リストから生成される
   - 不整合リスクを完全排除

**影響範囲:**
- `modules/filestore/main.tf`: IP予約リソース追加
- `modules/database/databases.tf`: locals ブロック追加、site_count → local.site_count
- `environments/prod/main.tf`: モジュール呼び出し例を追加（depends_on の正しい使い方）
- `terraform.tfvars.example`: site_count 削除、domains のみで制御

### v1.3 (2025-11-04) - API依存関係の修正

**修正内容:**

1. **Service Networking API 依存追加**
   - `google_service_networking_connection` に `depends_on = [google_project_service.servicenetworking]` 追加
   - API有効化前に接続作成が走るのを防止
   - リソース定義順序を変更（API有効化 → 接続作成）

2. **Filestore API 依存追加**
   - `google_filestore_instance` に `depends_on = [google_project_service.filestore]` 追加
   - API有効化前にインスタンス作成が走るのを防止
   - リソース定義順序を変更（API有効化 → インスタンス作成）

3. **depends_on の正しい記述方法を再修正**
   - ❌ 誤: `depends_on = [module.network.service_networking_connection]`
   - ✅ 正: `depends_on = [module.network]`（モジュール全体を指定）

**影響範囲:**
- `modules/network/service_networking.tf`: depends_on 追加、リソース順序変更
- `modules/filestore/main.tf`: depends_on 追加、リソース順序変更
- `environments/prod/main.tf`: depends_on をモジュール全体に修正

### v1.4 (2025-11-04) - Filestore network パラメータ修正

**修正内容:**

1. **Filestore network パラメータの修正**
   - ❌ 誤: `network = var.network`（短い名前）
   - ✅ 正: `network = var.network_id`（フルリソース名）
   - Filestore APIは `projects/{project}/global/networks/{network}` 形式を要求
   - モジュール変数から `var.network` を削除し、`var.network_id` のみに統一

2. **モジュール呼び出し例の修正**
   - ❌ 誤: `network = module.network.vpc_name, network_id = module.network.vpc_id`
   - ✅ 正: `network_id = module.network.vpc_id` のみ
   - 冗長な変数を削除

3. **Cloud SQLコメントの更新**
   - 古いコメント（`depends_on = [module.network.service_networking_connection]`）を削除
   - 正しい方法（`depends_on = [module.network]`）に更新

**影響範囲:**
- `modules/filestore/main.tf`: `networks.network` → `networks.network_id` に変更
- `modules/filestore/variables.tf`: `var.network` 削除、`var.network_id` の説明更新
- `environments/prod/main.tf`: Filestoreモジュール呼び出しを修正
- `modules/database/main.tf`: コメント更新

### v1.5 (2025-11-04) - Cloud SQL HA 可変化 + WordPress管理者認証情報管理

**修正内容:**

1. **Cloud SQL availability_type の変数化**
   - `availability_type` を固定値からモジュール変数に変更
   - `modules/database/variables.tf` に変数定義追加（REGIONAL/ZONAL選択可能）
   - prod環境: `REGIONAL`（HA）、dev環境: `ZONAL`（単一）を選択可能に
   - モジュール呼び出しに `availability_type = var.db_availability_type` 追加

2. **WordPress管理者パスワードの保存**
   - 生成した管理者パスワードをSecret Managerに自動保存
   - Secret名: `${ENV}-wordpress-admin-password-${SITE_NUM}`
   - 取得方法をセットアップ完了時に出力
   - ログイン不能問題を解決

3. **プラグインインストールの修正**
   - 存在しないURL（`https://path/to/cache-control-plugin.zip`）を削除
   - 実際に利用可能なプラグイン例をコメントで記載
   - `nginx-helper`、`w3-total-cache` などの実在プラグイン例を追加

**影響範囲:**
- `modules/database/main.tf`: `availability_type` を変数化
- `modules/database/variables.tf`: `availability_type` 変数追加（validation含む）
- `environments/prod/main.tf`: モジュール呼び出しに `availability_type` 追加
- `terraform.tfvars.example`: `db_availability_type` 変数追加（prod: REGIONAL, dev: ZONAL）
- `scripts/startup_script.sh`: WordPress管理者パスワード保存ロジック追加
- `scripts/startup_script.sh`: プラグインインストールを実在URLに修正

### v1.6 (2025-11-04) - Secret Manager権限の最小化

**修正内容:**

1. **Secret Manager権限の分解（最小権限の原則）**
   - ❌ 削除: `roles/secretmanager.admin`（過剰権限）
   - ✅ 追加: `roles/secretmanager.secretCreator`（Secret新規作成のみ）
   - ✅ 追加: `roles/secretmanager.secretVersionAdder`（既存Secretへのバージョン追加のみ）
   - ✅ 維持: `roles/secretmanager.secretAccessor`（読み取り専用）

**権限分離の詳細:**

| ロール | 権限 | 用途 |
|--------|------|------|
| `secretAccessor` | Secret読み取り | DBパスワード取得 |
| `secretCreator` | Secret新規作成 | WordPress管理者パスワード初回保存 |
| `secretVersionAdder` | バージョン追加 | WordPress管理者パスワード更新 |

**除外される危険な権限:**
- ❌ Secret削除（`secrets.delete`）
- ❌ IAM設定変更（`secrets.setIamPolicy`）
- ❌ Secret一覧表示（プロジェクト内全Secret）

**セキュリティ効果:**
- VMが侵害されても、Secret削除やIAM変更は不可能
- 最小権限の原則を完全に遵守
- 起動スクリプトの `create || add` ロジックがそのまま動作

**影響範囲:**
- `modules/iam/main.tf`: Secret Manager関連権限を3ロールに分解
- セキュリティリスク評価: High → Low

---

**次のステップ:** Ansible Playbook設計書の作成
