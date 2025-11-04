variable "project_id" {
  description = "GCPプロジェクトID"
  type        = string
  default     = "infra-ai-agent"
}

variable "region" {
  description = "デフォルトのGCPリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "デフォルトのGCPゾーン"
  type        = string
  default     = "asia-northeast1-a"
}

variable "environment" {
  description = "環境識別子（development, staging, production）"
  type        = string
  default     = "development"
}

variable "labels" {
  description = "すべてのリソースに適用されるラベル"
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "infra-ai-agent"
  }
}

