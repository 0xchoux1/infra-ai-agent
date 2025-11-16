# Terraform Infrastructure

WordPress マルチテナント環境のTerraform実装

## 📁 ディレクトリ構造

```
terraform/
├── environments/
│   ├── prod/          # 本番環境
│   └── dev/           # 開発環境
├── modules/
│   ├── network/       # VPC、サブネット、NAT、Service Networking
│   ├── iam/           # サービスアカウント、権限
│   ├── filestore/     # NFS共有ストレージ
│   ├── database/      # Cloud SQL、DBユーザー
│   ├── compute/       # Instance Template、MIG、Autoscaling
│   ├── loadbalancer/  # LB、CDN、Cloud Armor、SSL
│   └── monitoring/    # アラート、ログ
└── scripts/
    └── startup_script.sh  # VM起動スクリプト
```

## 🚀 セットアップ

### 1. 前提条件

- Terraform >= 1.5.0
- gcloud CLI 認証済み
- GCP プロジェクト作成済み
- 必要なGCP APIが有効化されている

### 2. GCP認証

```bash
# Application Default Credentials設定
gcloud auth application-default login

# プロジェクト設定
gcloud config set project infra-ai-agent
```

### 3. terraform.tfvars作成

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars

# エディタで編集
vi terraform.tfvars
```

**必須設定項目:**
- `project_id`: GCPプロジェクトID
- `domains`: WordPressドメインリスト（10サイト分）

### 4. Terraform初期化

```bash
cd environments/prod
terraform init
```

## 📋 デプロイ手順

### Phase 1: 検証

```bash
# フォーマットチェック
terraform fmt -recursive

# 構文検証
terraform validate

# 実行計画確認
terraform plan
```

### Phase 2: 適用

```bash
# 本番環境デプロイ
terraform apply

# 確認プロンプトで "yes" と入力
```

**注意事項:**
- 初回デプロイは約15-20分かかります
- Cloud SQLとFilestoreの作成に時間がかかります
- SSL証明書のプロビジョニングには最大60分かかる場合があります

## 📊 デプロイ後の確認

### 1. 出力値の確認

```bash
terraform output
```

**主要な出力:**
- `load_balancer_ip`: ロードバランサーのグローバルIP
- `database_private_ip`: Cloud SQLのプライベートIP
- `nfs_mount_command`: Filestore NFSマウントコマンド

### 2. DNSレコード設定

terraform outputで取得したIPアドレスを、各ドメインのAレコードに設定：

```
example1.com.    A    <load_balancer_ip>
example2.com.    A    <load_balancer_ip>
...
```

### 3. SSL証明書のステータス確認

```bash
# SSL証明書がACTIVEになるまで待機（最大60分）
gcloud compute ssl-certificates list --project=infra-ai-agent
```

### 4. WordPressセットアップ

各VMインスタンスで自動セットアップスクリプトを実行：

```bash
# VMにSSH接続（IAP経由）
gcloud compute ssh prod-web-xxxx --zone=asia-northeast1-a --tunnel-through-iap

# WordPressセットアップ（サイト1の例）
sudo /usr/local/bin/setup-wordpress-site.sh 1 example1.com "Site 1 Title"

# 管理者パスワード取得
gcloud secrets versions access latest --secret=prod-wordpress-admin-password-1
```

## 🔧 運用

### リソース更新

```bash
# 変更を適用
terraform apply

# 特定のリソースのみ更新
terraform apply -target=module.compute
```

### リソース削除

```bash
# 全リソース削除（注意！）
terraform destroy

# deletion_protectionがあるため、Cloud SQLは手動削除が必要
```

### ステート管理

```bash
# ステート確認
terraform state list

# 特定リソースの状態表示
terraform state show module.network.google_compute_network.vpc
```

## 📝 環境別の違い

| 項目 | prod | dev |
|------|------|-----|
| Cloud SQL | REGIONAL (HA) | ZONAL |
| Cloud SQL スペック | db-custom-2-7680 | db-custom-1-3840 |
| VM台数 | 2-4台 | 1-2台 |
| VM type | e2-small | e2-micro |
| サイト数 | 10 | 3 |

## 🐛 トラブルシューティング

### エラー: Service Networking connection failed

```bash
# Service Networking API有効化
gcloud services enable servicenetworking.googleapis.com

# VPC Peeringの確認
gcloud compute networks peerings list --network=prod-wordpress-vpc
```

### エラー: Filestore creation failed

```bash
# Filestore API有効化
gcloud services enable file.googleapis.com

# IP範囲の重複確認
gcloud compute addresses list --global
```

### エラー: SSL certificate provisioning

- DNSレコードが正しく設定されているか確認
- DNS伝播に時間がかかる場合があります（最大48時間）
- `nslookup example.com` でAレコードを確認

## 📚 参考資料

- [Terraform設計書](../../docs/terraform-design.md)
- [要件定義書](../../docs/requirements.md)
- [GCP公式ドキュメント](https://cloud.google.com/docs)

## ⚠️ セキュリティ注意事項

1. **terraform.tfvars をGitにコミットしない**
   - `.gitignore` で除外済み
   - パスワードや機密情報が含まれる

2. **State ファイルの管理**
   - GCS バックエンドの使用を推奨
   - ローカルのstate ファイルを共有しない

3. **IAM権限の最小化**
   - サービスアカウントは最小権限
   - Secret Manager権限は3ロールに分離済み

## 📞 サポート

問題が発生した場合は、以下を確認してください：
1. GCP APIが有効化されているか
2. terraform.tfvarsの設定が正しいか
3. gcloud CLIの認証が有効か
4. quota制限に達していないか

詳細は [Issue](https://github.com/0xchoux1/infra-ai-agent/issues) で報告してください。

