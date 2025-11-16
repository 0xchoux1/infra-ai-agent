# Terraform検証ガイド

Terraformコードの検証手順

## 前提条件

```bash
# Terraformインストール確認
terraform version

# 必要なバージョン: >= 1.5.0
```

## 検証ステップ

### 1. フォーマット確認

```bash
cd /home/choux1/dev/github.com/0xchoux1/infra-ai-agent/terraform

# フォーマット実行（変更があれば自動修正）
terraform fmt -recursive

# 変更があったファイルが表示されます
```

### 2. 構文検証（各環境）

#### prod環境

```bash
cd environments/prod

# 初期化
terraform init

# 構文検証
terraform validate
```

#### dev環境

```bash
cd environments/dev

# 初期化
terraform init

# 構文検証
terraform validate
```

### 3. 実行計画確認（GCP認証後）

```bash
# GCP認証
gcloud auth application-default login
gcloud config set project infra-ai-agent

# terraform.tfvars作成
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # 実際の値を設定

# 実行計画確認（dry-run）
terraform plan
```

## 期待される結果

### ✅ 成功時

```
Success! The configuration is valid.
```

### ❌ よくあるエラーと対処法

#### 1. Module not found

```
Error: Module not found
```

**対処法:**
```bash
terraform init  # モジュールを再ダウンロード
```

#### 2. Provider not configured

```
Error: google_compute_network.vpc: Provider "google" not configured
```

**対処法:**
- `provider.tf` が存在するか確認
- `terraform init` を実行

#### 3. Invalid reference

```
Error: Reference to undeclared resource
```

**対処法:**
- モジュールの`outputs.tf`で出力が定義されているか確認
- 変数名のtypoがないか確認

## 検証済み項目

- [x] ディレクトリ構造
- [x] 全モジュールのファイル作成
- [x] 環境別設定（prod/dev）
- [ ] `terraform fmt` 実行（要Terraform CLI）
- [ ] `terraform validate` 実行（要Terraform CLI）
- [ ] `terraform plan` 実行（要GCP認証）

## 次のステップ

1. ローカル環境でTerraform CLIをインストール
2. GCP認証を設定
3. 上記の検証ステップを実行
4. エラーがあれば修正
5. `terraform apply` で実際にデプロイ

## 参考リンク

- [Terraform CLI インストール](https://developer.hashicorp.com/terraform/downloads)
- [GCP Provider ドキュメント](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraformベストプラクティス](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

