# Ansible WordPressセットアップガイド

## 概要

このガイドでは、AnsibleによるWordPress環境のセットアップ方法を説明します。

## セットアップ方法の選択肢

### 方法1: Terraformと統合（推奨）

Terraformでインスタンスを作成すると、startup_scriptが自動的に実行されます。

**メリット:**
- インスタンス作成時に自動セットアップ
- 手動操作不要
- 既存のstartup_scriptと併用可能

**使い方:**

```bash
# Terraformでインスタンス作成
cd terraform/environments/prod
terraform apply

# インスタンスが起動すると自動的にWordPress環境が構築されます
```

### 方法2: Ansibleを直接実行

既存のインスタンスに対してAnsibleを実行します。

**メリット:**
- 設定変更の再適用が簡単
- 複数インスタンスへの一括適用
- 冪等性による安全な再実行

**使い方:**

```bash
cd ansible

# GCP Dynamic Inventoryを使用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml

# 特定のホストのみ対象
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --limit "wordpress-prod-*"
```

### 方法3: ローカル実行（VM内部から）

VMにSSH接続してローカルでAnsibleを実行します。

**メリット:**
- GCP認証不要
- 特定のVMのみ素早くセットアップ

**使い方:**

```bash
# VMにSSH接続
gcloud compute ssh wordpress-instance --zone=asia-northeast1-a

# Ansibleインストール（初回のみ）
sudo apt-get update
sudo apt-get install -y ansible git

# リポジトリクローン
git clone https://github.com/your-org/infra-ai-agent.git
cd infra-ai-agent/ansible

# ローカル実行
ansible-playbook playbooks/quick-setup.yml
```

## 実践例

### 例1: 新規WordPressサイトの追加

10サイト中、サイト3つをセットアップする場合：

```bash
# VMにSSH接続
gcloud compute ssh wordpress-prod-abc1 --zone=asia-northeast1-a

# サイト1: 会社ホームページ
sudo /usr/local/bin/setup-wordpress-site.sh 1 example.com "株式会社サンプル"

# サイト2: ブログ
sudo /usr/local/bin/setup-wordpress-site.sh 2 blog.example.com "Tech Blog"

# サイト3: ECサイト
sudo /usr/local/bin/setup-wordpress-site.sh 3 shop.example.com "オンラインストア"

# 管理者パスワード取得
gcloud secrets versions access latest --secret=prod-wordpress-admin-password-1
gcloud secrets versions access latest --secret=prod-wordpress-admin-password-2
gcloud secrets versions access latest --secret=prod-wordpress-admin-password-3
```

### 例2: PHP設定の変更（全サイト）

すべてのWordPressサイトのPHPメモリ制限を変更する場合：

```bash
cd ansible

# Playbookで変数を上書き
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags php \
  -e "php_memory_limit=512M"

# 適用後、PHP-FPMが自動的に再起動されます
```

### 例3: Nginx設定の調整

アップロードサイズ制限を128MBに変更：

```bash
cd ansible

# Nginx設定を更新
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags nginx \
  -e "nginx_client_max_body_size=128M"

# PHP側も合わせて変更
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags php \
  -e "php_upload_max_filesize=128M php_post_max_size=128M"
```

### 例4: 新しいドメインの追加（マルチサイト拡張）

サイト4を追加する場合：

```bash
# 1. Terraformでドメインリスト更新
# terraform/environments/prod/main.tf
domains = [
  "example.com",
  "blog.example.com",
  "shop.example.com",
  "new-site.example.com"  # 追加
]

# 2. Terraform適用
cd terraform/environments/prod
terraform apply

# 3. Ansibleでサイト設定を再生成
cd ../../ansible
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags sites

# 4. WordPressセットアップ
gcloud compute ssh wordpress-prod-abc1 --zone=asia-northeast1-a
sudo /usr/local/bin/setup-wordpress-site.sh 4 new-site.example.com "New Site"
```

### 例5: 監視エージェントの再インストール

Ops Agentに問題がある場合：

```bash
cd ansible

# 監視エージェントのみ再インストール
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags monitoring

# サービス確認
ansible wordpress_servers -i inventory/gcp.yml \
  -m shell -a "systemctl status google-cloud-ops-agent" -b
```

## トラブルシューティング実例

### 問題1: NFSマウント失敗

**症状:** `/var/www/wordpress`にアクセスできない

**解決方法:**

```bash
# 1. メタデータ確認
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nfs_ip

curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nfs_path

# 2. Ansibleで再マウント
cd ansible
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags nfs
```

### 問題2: Nginx設定エラー

**症状:** `nginx -t`でエラーが出る

**解決方法:**

```bash
# 1. エラー内容確認
sudo nginx -t

# 2. Ansible設定を再適用
cd ansible
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags nginx --check --diff

# 3. 問題なければ適用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags nginx
```

### 問題3: WordPress管理画面に入れない

**症状:** 500エラーまたはDatabase connection error

**解決方法:**

```bash
# 1. データベース接続確認
cd /var/www/wordpress/site1
sudo -u www-data wp db check

# 2. wp-config.phpの確認
sudo -u www-data wp config list

# 3. Secret Managerのパスワード確認
gcloud secrets versions access latest --secret=prod-wordpress-db-password-1

# 4. 必要に応じてwp-config.php再生成
sudo -u www-data wp config create \
  --dbname=wordpress_site_1 \
  --dbuser=wp_user_1 \
  --dbpass="$(gcloud secrets versions access latest --secret=prod-wordpress-db-password-1)" \
  --dbhost="<DB_HOST>" \
  --force
```

## ベストプラクティス

### 1. 変更前に必ずドライラン

```bash
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --check --diff
```

### 2. タグを活用した部分適用

```bash
# 必要な部分のみ変更
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --tags "nginx,php"
```

### 3. 環境分離

```bash
# 開発環境で先にテスト
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --limit "dev_*"

# 本番環境に適用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --limit "prod_*"
```

### 4. バージョン管理

```bash
# 変更前にGitコミット
git add .
git commit -m "Update PHP memory limit to 512M"

# Ansible適用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml

# 問題があればロールバック
git revert HEAD
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml
```

## 次のステップ

1. **SSL証明書の自動更新設定**
   - Let's Encrypt + certbot
   - Cloud Scheduler連携

2. **Wazuh Agentの追加**
   - セキュリティ監視
   - ファイル整合性チェック

3. **バックアップ自動化**
   - rsync + Cloud Storage
   - スケジュール実行

4. **CI/CDパイプライン構築**
   - GitHub Actions
   - 自動テスト
   - ステージング→本番デプロイ

---

**質問や問題がある場合**:
- GitHub Issues: https://github.com/your-org/infra-ai-agent/issues
- ドキュメント: `ansible/README.md`
