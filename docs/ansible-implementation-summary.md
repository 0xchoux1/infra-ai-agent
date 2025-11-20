# Ansible WordPress実装サマリー

## 実装完了内容

### ✅ 完成したコンポーネント

#### 1. Ansibleロール構造

```
ansible/roles/wordpress/
├── defaults/main.yml          # デフォルト変数（PHP, Nginx, OPcache設定）
├── tasks/
│   ├── main.yml              # メインタスク（オーケストレーション）
│   ├── packages.yml          # システムパッケージインストール
│   ├── wpcli.yml            # WP-CLIセットアップ
│   ├── nfs.yml              # Cloud Filestore NFSマウント
│   ├── nginx.yml            # Nginx設定・サービス管理
│   ├── php.yml              # PHP-FPM最適化設定
│   ├── sites.yml            # マルチサイト用ディレクトリ・Nginx設定
│   └── monitoring.yml       # Ops Agent（Cloud Monitoring/Logging）
├── templates/
│   ├── nginx.conf.j2                    # Nginxメイン設定
│   ├── health.conf.j2                   # Health Checkエンドポイント
│   ├── wordpress-site.conf.j2           # サイト別Nginx設定（ドメイン対応）
│   ├── php-wordpress-optimize.ini.j2    # PHP OPcache最適化
│   └── setup-wordpress-site.sh.j2       # WPインストールスクリプト
└── handlers/main.yml         # サービス再起動ハンドラー
```

#### 2. Playbook

| Playbook | 用途 | 対象 |
|----------|------|------|
| `deploy-wordpress.yml` | 本番デプロイ用 | GCP Dynamic Inventory |
| `quick-setup.yml` | ローカル実行用 | localhost（VM内部） |
| `setup.yml` | 基本セットアップ | 既存（汎用） |

#### 3. ドキュメント

| ファイル | 内容 |
|---------|------|
| `ansible/README.md` | Ansible全体のリファレンス |
| `docs/ansible-usage-guide.md` | 実践的な使用例・トラブルシューティング |
| `docs/ansible-implementation-summary.md` | このファイル（実装概要） |

## 主要機能

### 1. マルチサイト対応

- ドメインリストをGCPメタデータまたは変数から取得
- サイト数に応じて自動的にディレクトリ・Nginx設定を生成
- 最大10サイトに対応（拡張可能）

**実装例:**
```yaml
domains:
  - example.com
  - blog.example.com
  - shop.example.com
```

→ `/var/www/wordpress/site1`, `/var/www/wordpress/site2`, `/var/www/wordpress/site3` を自動生成

### 2. WordPress自動セットアップスクリプト

各VMに配置される`/usr/local/bin/setup-wordpress-site.sh`は以下を自動実行：

1. WP-CLIでWordPressダウンロード（日本語版）
2. `wp-config.php`作成（DB接続設定）
3. 管理者アカウント作成
4. 日本語化・タイムゾーン設定
5. パーマリンク設定
6. 不要プラグイン・テーマ削除
7. **Cache-Control設定の追加**（Cloud CDN統合）
8. 管理者パスワードをSecret Managerに保存

**使用方法:**
```bash
sudo /usr/local/bin/setup-wordpress-site.sh 1 example.com "My WordPress Site"
```

### 3. Cloud CDN統合（Cache-Control設定）

#### Nginx設定（`wordpress-site.conf.j2`）

```nginx
# 静的ファイル（1年キャッシュ）
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
}

# 管理画面（キャッシュ無効）
location ~ ^/wp-(admin|login|cron\.php) {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
}
```

#### WordPress側の動的Cache-Control

セットアップスクリプトが自動的に`functions.php`に追加：

```php
// 動的ページ（5分キャッシュ）
if (is_singular() || is_archive() || is_home()) {
    header('Cache-Control: public, max-age=300, s-maxage=300');
}
```

### 4. PHP最適化（OPcache）

**デフォルト設定:**
```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.revalidate_freq=2
upload_max_filesize=64M
post_max_size=64M
memory_limit=256M
```

### 5. セキュリティ機能

#### Nginxセキュリティヘッダー
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

#### ファイルアクセス制限
```nginx
# wp-config.phpへのアクセス拒否
location ~ /wp-config\.php {
    deny all;
}

# 隠しファイルへのアクセス拒否
location ~ /\. {
    deny all;
}
```

#### Secret Manager統合
- データベースパスワード: `<env>-wordpress-db-password-<site_num>`
- 管理者パスワード: `<env>-wordpress-admin-password-<site_num>`

### 6. 監視統合

- **Ops Agent**: Cloud Logging + Cloud Monitoring
- **Health Check**: `/health` エンドポイント（LB用）
- **ログ出力**:
  - Nginx: `/var/log/nginx/access.log`, `/var/log/nginx/error.log`
  - PHP: `/var/log/php_errors.log`

## 既存startup_scriptとの統合

### オプション1: Ansibleのみ使用（推奨）

Terraformの`startup_script`から直接Ansibleを呼び出す：

```bash
#!/bin/bash
# Ansibleインストール
apt-get update
apt-get install -y ansible git

# リポジトリクローン
git clone https://github.com/your-org/infra-ai-agent.git /tmp/infra
cd /tmp/infra/ansible

# Ansible実行
ansible-playbook playbooks/quick-setup.yml
```

### オプション2: ハイブリッド（既存スクリプト + Ansible）

既存の`startup_script.sh`を保持し、Ansibleで差分管理：

```bash
# 既存のstartup_script.shで基本インストール
bash /path/to/startup_script.sh

# Ansibleで設定ファイル管理
ansible-playbook playbooks/deploy-wordpress.yml --tags nginx,php
```

### オプション3: 完全手動実行

Terraformでインスタンス作成後、手動でAnsibleを実行：

```bash
cd ansible
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml
```

## 使用シナリオ

### シナリオ1: 新規環境構築

```bash
# 1. Terraformでインフラ作成
cd terraform/environments/prod
terraform apply

# 2. Ansibleでアプリケーション設定
cd ../../ansible
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml

# 3. WordPressサイトセットアップ
gcloud compute ssh wordpress-prod-abc1 --zone=asia-northeast1-a
sudo /usr/local/bin/setup-wordpress-site.sh 1 example.com "My Site"
```

### シナリオ2: 設定変更の適用

```bash
# Nginx設定のみ更新
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags nginx

# PHP設定のみ更新
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags php
```

### シナリオ3: スケールアウト

```bash
# 新しいインスタンスがMIGで自動作成される
# → startup_scriptでAnsibleが自動実行される
# → WordPress環境が自動セットアップされる
```

### シナリオ4: トラブルシューティング

```bash
# NFSマウント問題の修正
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags nfs

# 監視エージェント再インストール
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml --tags monitoring
```

## 冪等性の保証

すべてのAnsibleタスクは冪等性を保証：

- **パッケージインストール**: `state: present`（既にインストール済みならスキップ）
- **設定ファイル**: テンプレート比較（変更がなければスキップ）
- **サービス**: `state: started`（既に起動済みならスキップ）
- **NFSマウント**: `mountpoint`チェック（既にマウント済みならスキップ）

**何度実行しても安全です！**

## パフォーマンス最適化

### 1. OPcacheチューニング

```yaml
opcache_memory_consumption: 256      # MB
opcache_max_accelerated_files: 20000 # ファイル数
```

### 2. Nginx Gzip圧縮

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript;
```

### 3. 静的ファイルキャッシュ

```nginx
expires 1y;
add_header Cache-Control "public, max-age=31536000, immutable";
```

## 今後の拡張計画

### Phase 2: SSL自動化

- Let's Encrypt統合
- certbot Ansibleロール作成
- 証明書自動更新

### Phase 3: Wazuh統合

- Wazuh Agentロール作成
- セキュリティ監視自動化

### Phase 4: バックアップ自動化

- rsyncロール作成
- Cloud Storageバックアップ
- スケジュール設定

### Phase 5: CI/CD統合

- GitHub Actions連携
- 自動テスト
- Blue-Greenデプロイ

## トラブルシューティングチェックリスト

### Ansibleが動かない

- [ ] GCP認証確認: `gcloud auth application-default login`
- [ ] インベントリ確認: `ansible-inventory -i inventory/gcp.yml --list`
- [ ] SSH接続確認: `ansible all -i inventory/gcp.yml -m ping`

### Nginxエラー

- [ ] 設定テスト: `sudo nginx -t`
- [ ] ログ確認: `sudo tail -f /var/log/nginx/error.log`
- [ ] Ansible再適用: `ansible-playbook ... --tags nginx`

### PHP-FPMエラー

- [ ] PHPバージョン確認: `php --version`
- [ ] サービス状態: `systemctl status php8.2-fpm`
- [ ] ログ確認: `sudo journalctl -u php8.2-fpm -f`

### WordPressエラー

- [ ] DB接続確認: `wp db check`
- [ ] wp-config.php確認: `wp config list`
- [ ] パーミッション確認: `ls -la /var/www/wordpress/site1`

## まとめ

### 実装の特徴

1. **完全自動化**: 手動操作を最小限に
2. **マルチサイト対応**: 10サイトまで自動セットアップ
3. **Cloud CDN統合**: Cache-Control自動設定
4. **セキュリティ重視**: Secret Manager、セキュリティヘッダー
5. **冪等性**: 安全な再実行
6. **拡張性**: ロール・タグによる柔軟な管理

### 次のアクション

1. **テスト実行**: 開発環境でAnsibleを試す
2. **ドキュメント確認**: `ansible/README.md`を読む
3. **実践**: `docs/ansible-usage-guide.md`の例を試す
4. **カスタマイズ**: `roles/wordpress/defaults/main.yml`で設定調整

---

**質問や改善提案**: GitHub Issuesまで
