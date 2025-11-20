# WordPress Ansible自動化

このディレクトリには、GCP上のWordPressマルチサイト環境を自動セットアップするAnsibleコードが含まれています。

## 📁 ディレクトリ構造

```
ansible/
├── ansible.cfg                    # Ansible設定ファイル
├── requirements.yml               # Ansibleコレクション依存関係
├── inventory/
│   └── gcp.yml                   # GCPダイナミックインベントリ
├── playbooks/
│   ├── setup.yml                 # 基本セットアップPlaybook
│   └── deploy-wordpress.yml      # WordPressデプロイPlaybook
└── roles/
    └── wordpress/                # WordPressロール
        ├── defaults/
        │   └── main.yml         # デフォルト変数
        ├── tasks/
        │   ├── main.yml         # メインタスク
        │   ├── packages.yml     # パッケージインストール
        │   ├── wpcli.yml        # WP-CLIセットアップ
        │   ├── nfs.yml          # NFSマウント
        │   ├── nginx.yml        # Nginx設定
        │   ├── php.yml          # PHP-FPM設定
        │   ├── sites.yml        # マルチサイト設定
        │   └── monitoring.yml   # 監視エージェント
        ├── templates/
        │   ├── nginx.conf.j2                # Nginxメイン設定
        │   ├── health.conf.j2               # Health Check設定
        │   ├── wordpress-site.conf.j2       # サイト別Nginx設定
        │   ├── php-wordpress-optimize.ini.j2 # PHP最適化設定
        │   └── setup-wordpress-site.sh.j2   # WPセットアップスクリプト
        └── handlers/
            └── main.yml         # ハンドラー（再起動など）
```

## 🚀 使い方

### 1. 事前準備

```bash
# Ansible依存関係のインストール
ansible-galaxy install -r requirements.yml

# GCP認証設定
gcloud auth application-default login
export GCP_PROJECT_ID="your-project-id"
```

### 2. WordPressデプロイ

#### 方法A: Ansibleで直接デプロイ

```bash
# 本番環境にデプロイ
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml

# 開発環境にデプロイ
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml -e "env=dev"

# 特定のタグのみ実行（Nginxのみ再設定など）
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags nginx

# ドライラン（実際の変更なし）
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --check
```

#### 方法B: Terraform startup_scriptから自動実行

Terraformでインスタンスを作成すると、startup_scriptが自動的にAnsibleを呼び出します：

```hcl
# terraform/modules/compute/startup_script_template.tf
# 既にAnsible呼び出しを含むように設定されています
```

### 3. WordPressサイトのセットアップ

デプロイ後、各サイトを個別にセットアップします：

```bash
# VMにSSH接続
gcloud compute ssh wordpress-instance-name --zone=asia-northeast1-a

# サイト1をセットアップ
sudo /usr/local/bin/setup-wordpress-site.sh 1 example.com "My WordPress Site"

# サイト2をセットアップ
sudo /usr/local/bin/setup-wordpress-site.sh 2 blog.example.com "My Blog"
```

セットアップスクリプトは以下を自動実行します：
- WordPressコアダウンロード（日本語版）
- wp-config.php作成（DB接続設定）
- 管理者アカウント作成
- 日本語化
- パーマリンク設定
- 不要プラグイン削除
- Cache-Control設定追加
- 管理者パスワードをSecret Managerに保存

### 4. 管理者パスワード取得

```bash
# サイト1の管理者パスワード
gcloud secrets versions access latest --secret=prod-wordpress-admin-password-1

# サイト2の管理者パスワード
gcloud secrets versions access latest --secret=prod-wordpress-admin-password-2
```

## 🔧 変数のカスタマイズ

### デフォルト変数（`roles/wordpress/defaults/main.yml`）

主要な変数：

```yaml
# PHP設定
php_version: "8.2"
php_memory_limit: "256M"
php_upload_max_filesize: "64M"

# OPcache設定
opcache_memory_consumption: 256
opcache_max_accelerated_files: 20000

# WordPress設定
wordpress_root: "/var/www/wordpress"

# Nginx設定
nginx_worker_processes: "auto"
nginx_client_max_body_size: "64M"
```

### 実行時に変数を上書き

```bash
# PHP memory_limitを512MBに変更
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  -e "php_memory_limit=512M"

# アップロードサイズを128MBに変更
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  -e "php_upload_max_filesize=128M nginx_client_max_body_size=128M"
```

## 📋 タスク一覧

各タスクは独立して実行可能です：

```bash
# パッケージのみインストール
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags packages

# Nginxのみ再設定
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags nginx

# PHP-FPMのみ再設定
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags php

# NFSマウントのみ
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags nfs

# WordPressサイト設定のみ
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags sites

# 監視エージェントのみ
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags monitoring
```

## 🔍 トラブルシューティング

### Ansibleが対象ホストを見つけられない

```bash
# インベントリの確認
ansible-inventory -i inventory/gcp.yml --list

# 特定ホストへの接続確認
ansible wordpress_servers -i inventory/gcp.yml -m ping

# GCP認証確認
gcloud auth application-default login
```

### NFSマウントエラー

```bash
# NFSマウント状態確認
df -h | grep /var/www/wordpress

# メタデータ確認
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nfs_ip
```

### Nginx/PHP-FPMエラー

```bash
# Nginx設定テスト
sudo nginx -t

# Nginxログ確認
sudo tail -f /var/log/nginx/error.log

# PHP-FPMログ確認
sudo journalctl -u php8.2-fpm -f

# サービス再起動
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
```

### WordPress インストールエラー

```bash
# WP-CLI動作確認
wp --version

# データベース接続確認
wp db check

# WordPressバージョン確認
cd /var/www/wordpress/site1
sudo -u www-data wp core version
```

## 🔄 既存環境への適用

既にstartup_scriptでセットアップされたVMにAnsibleを適用する場合：

```bash
# 1. まずドライランで差分確認
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --check --diff

# 2. 問題なければ適用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml
```

Ansibleは冪等性があるため、既存の設定がある場合は変更が必要な箇所のみ更新します。

## 📊 ベストプラクティス

### 1. 環境分離

```bash
# 開発環境
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  -e "env=dev" --limit "dev_*"

# 本番環境
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  -e "env=prod" --limit "prod_*"
```

### 2. ステージング→本番の段階的デプロイ

```bash
# 1. ステージングで検証
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --limit "staging_*" --check

# 2. 問題なければステージングに適用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --limit "staging_*"

# 3. 本番適用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml \
  --limit "prod_*"
```

### 3. ロールバック

設定を以前の状態に戻す場合：

```bash
# Gitで前のコミットに戻す
git checkout <previous-commit>

# Ansible再適用
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml
```

## 🔐 セキュリティ注意事項

1. **Secret Managerの使用**: データベースパスワード、管理者パスワードはすべてSecret Managerに保存
2. **SSH鍵管理**: GCP OS LoginまたはIAP経由でのSSH接続を推奨
3. **変数の暗号化**: 機密変数は`ansible-vault`で暗号化

```bash
# ansible-vaultで変数を暗号化
ansible-vault encrypt_string 'secret_password' --name 'db_password'
```

## 🎯 次のステップ

1. **SSL証明書設定**: Let's Encryptの自動更新を設定
2. **Wazuh Agent**: セキュリティ監視エージェントの追加
3. **CI/CDパイプライン**: GitHub ActionsでAnsible自動実行
4. **バックアップ自動化**: rsyncでCloud Storageへバックアップ

## 📚 参考リソース

- [Ansible公式ドキュメント](https://docs.ansible.com/)
- [WP-CLI公式ドキュメント](https://wp-cli.org/)
- [Nginx WordPress最適化ガイド](https://www.nginx.com/resources/wiki/start/topics/recipes/wordpress/)
- [PHP-FPM パフォーマンスチューニング](https://www.php.net/manual/ja/install.fpm.php)

---

**質問や問題がある場合**: GitHubのIssuesに報告してください
