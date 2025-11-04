terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # バックエンド設定（オプション）
  # 本番環境ではGCS バックエンドを推奨
  # backend "gcs" {
  #   bucket = "infra-ai-agent-terraform-state"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# デフォルトネットワーク用のデータソース
data "google_compute_network" "default" {
  name = "default"
}

