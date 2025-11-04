output "project_id" {
  description = "GCPプロジェクトID"
  value       = var.project_id
}

output "region" {
  description = "デプロイ先のリージョン"
  value       = var.region
}

output "zone" {
  description = "デプロイ先のゾーン"
  value       = var.zone
}

output "environment" {
  description = "環境識別子"
  value       = var.environment
}

