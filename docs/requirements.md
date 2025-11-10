# WordPress マルチテナント ホスティング環境 要件定義書

**プロジェクト名**: GCP WordPress Hosting Platform  
**作成日**: 2025-11-04  
**バージョン**: 1.0  
**ステータス**: Phase 1 - 基盤構築

---

## 1. プロジェクト概要

### 1.1 目的
Google Cloud Platform上に、複数のWordPressサイトをホスティングできるマルチテナント環境を構築する。AIエージェントによる自律的な運用を前提とし、GCPネイティブサービスの活用を優先する。

### 1.2 目標
- 10サイトのWordPressをホスティング可能
- 高可用性（HA）構成の実装
- セキュリティ強化（WAF、IDS/IPS）
- コスト最適化（長期目標: 月額3,000円）
- AIエージェントによる自律運用

---

## 2. 機能要件

### 2.1 ホスティング要件

| 項目 | 要件 | 詳細 |
|------|------|------|
| **ホスト数** | 10サイト | マルチテナント構成 |
| **想定トラフィック** | 小規模 | 人気サイトなし |
| **同時接続数** | 100接続 | ピーク時 |
| **マルチドメイン** | 対応 | 各サイト独自ドメイン可 |
| **WordPress管理** | WP-CLI対応 | コマンドライン管理 |

### 2.2 Webサーバースタック

```
┌─────────────────────────────────────────────┐
│ Cloud HTTP(S) Load Balancer + Cloud CDN    │
│        + Cloud Armor (WAF)                  │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────┐
│  Managed Instance Group     │
│  (Auto Scaling: 2-4台)      │
│  ┌────────────────────────┐ │
│  │ VM: Nginx + PHP-FPM    │ │
│  │ WordPress Files        │ │
│  └────────────────────────┘ │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│  Cloud SQL (MySQL 8.0)      │
│  HA構成 (Primary + Standby) │
└─────────────────────────────┘
```

**コンポーネント:**
- **Webサーバー**: Nginx 1.24+ (リバースプロキシ、FastCGI Cache不使用)
- **PHP**: PHP 8.2 (PHP-FPM + OPcache)
- **WordPress**: 最新安定版
- **データベース**: Cloud SQL MySQL 8.0
- **CDN**: Cloud CDN (USE_ORIGIN_HEADERS モード)

### 2.3 メール送信機能

| 項目 | 要件 |
|------|------|
| **送信方法** | Gmail API |
| **認証** | サービスアカウント |
| **送信制限** | Gmail API制限内（1日2,000通程度） |
| **将来対応** | Google Workspace SMTP Relay移行可能 |

### 2.4 キャッシュ戦略（2層構成・シンプル）

```
[ユーザー] 
    ↓
[Cloud CDN] ← 静的・動的コンテンツ両方キャッシュ
    ↓        （USE_ORIGIN_HEADERS モード）
[Cloud Load Balancer]
    ↓
[Nginx] ← リバースプロキシ、Cache-Controlヘッダー設定
    ↓
[PHP-FPM + OPcache]
    ↓
[Cloud SQL]
```

**キャッシュ階層（Phase 1）:**
1. **Cloud CDN**: グローバルエッジキャッシュ（静的・動的両方）
2. **OPcache**: PHPバイトコードキャッシュ

**設計思想:**
- Cloud CDNの`USE_ORIGIN_HEADERS`モードで動的コンテンツもキャッシュ
- オリジン（Nginx）のCache-Controlヘッダーに従ってキャッシュ
- シンプルな構成で管理が容易
- トラフィック規模（同時100接続）には十分

**⚠️ キャッシュ一貫性の保証:**

**1. Cloud CDN キャッシュモード設定**
```hcl
# Terraform設定
cache_mode = "USE_ORIGIN_HEADERS"

cdn_policy {
  cache_key_policy {
    include_host         = true
    include_protocol     = true
    include_query_string = true
    
    # WordPress用クエリパラメータ
    query_string_whitelist = ["p", "page_id", "preview", "s"]
    
    # ログイン状態で区別
    include_named_cookies = [
      "wordpress_logged_in_*",
      "wp-settings-*",
      "comment_author_*"
    ]
  }
  
  default_ttl = 300   # 5分（デフォルト）
  max_ttl     = 3600  # 1時間（最大）
  client_ttl  = 300   # ブラウザキャッシュ5分
}
```

**2. Cache-Controlヘッダー戦略（Nginx設定）**
```nginx
# 静的ファイル（CSS/JS/画像）
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
}

# WordPress動的ページ（ログアウト時）
location / {
    # PHPで動的に設定（後述）
    fastcgi_pass php-fpm;
}

# 管理画面（キャッシュ無効）
location ~ ^/wp-(admin|login|cron) {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    fastcgi_pass php-fpm;
}
```

**3. WordPress Cache-Control設定**
```php
// functions.php または専用プラグイン
add_action('send_headers', function() {
    // 管理画面・ログインユーザー
    if (is_admin() || is_user_logged_in()) {
        header('Cache-Control: no-cache, no-store, must-revalidate');
        header('Pragma: no-cache');
        header('Expires: 0');
        return;
    }
    
    // 動的ページ（一般ユーザー）
    if (is_singular() || is_archive() || is_home()) {
        header('Cache-Control: public, max-age=300, s-maxage=300');
        header('Vary: Cookie, Accept-Encoding');
    }
    
    // 404ページ
    if (is_404()) {
        header('Cache-Control: public, max-age=60');
    }
});
```

**4. キャッシュパージ戦略**
```
WordPress記事更新/公開
    ↓
① OPcache: 自動リロード（必要に応じて）
    ↓
② Cloud CDN: gcloud API経由で該当URLをパージ
    ├─ 記事URL
    ├─ トップページ
    ├─ カテゴリページ
    └─ アーカイブページ
```

**WordPress統合（Cloud CDN パージ）:**
```php
// 記事公開時にCloud CDNキャッシュをクリア
add_action('save_post', function($post_id) {
    if (wp_is_post_revision($post_id)) return;
    
    $urls = [
        get_permalink($post_id),
        home_url('/'),
        // その他関連URL
    ];
    
    // gcloud CLIまたはREST API経由でパージ
    foreach ($urls as $url) {
        purge_cdn_cache($url);
    }
});

function purge_cdn_cache($url) {
    $command = sprintf(
        'gcloud compute url-maps invalidate-cdn-cache %s --path="%s" --async',
        'wordpress-lb',
        parse_url($url, PHP_URL_PATH)
    );
    exec($command);
}
```

**5. キャッシュヒット率の監視**
```
Cloud Monitoring メトリクス:
- cdn/cache_hit_count
- cdn/cache_miss_count
- 目標: ヒット率 > 80%
```

**Phase 2拡張オプション:**
パフォーマンスが不足した場合：
- Nginx FastCGI Cacheを追加（3層構成）
- Redis Object Cacheを追加
- Varnish Cacheを検討

---

## 3. 非機能要件

### 3.1 可用性

| 項目 | 目標値 | 実装方法 |
|------|--------|----------|
| **稼働率** | 99.5% | HA構成、Auto Healing |
| **RTO** | 5分以内 | 自動フェイルオーバー |
| **RPO** | 12時間以内 | 自動バックアップ（1日2回） |

**HA構成:**
- Managed Instance Group（最小2台、最大4台）
- Cloud SQL HA構成（Primary + Standby）
- Health Check（HTTP /health エンドポイント）
- Auto Healing（異常インスタンスの自動再作成）

### 3.2 バックアップ

| 種類 | 頻度 | 保持期間 | 実装 |
|------|------|----------|------|
| **統合バックアップ** | 1日2回 | 2日分 | Cloud SQL + VMスナップショット（同時実行） |
| **ファイルバックアップ** | 1日1回 | 7日分 | Cloud Storage + rsync |

**バックアップスケジュール（整合性重視）:**
```
03:00 JST（深夜バックアップ）:
  1. Cloud SQL自動バックアップ開始
  2. 完了確認（通常1-2分）
  3. VMスナップショット実行
  → 5分以内に完了、ほぼ同時点のデータを保証

15:00 JST（日中バックアップ）:
  同上の手順を繰り返し

04:00 JST（ファイルバックアップ）:
  WordPressファイルをCloud Storageにrsync
```

**整合性の保証:**
- DBとVMスナップショットを5分以内に取得
- リストア時、ファイルとDBの不整合を最小化
- トランザクションログも保持（ポイントインタイムリカバリ可能）

**代替案: アプリケーションレベルバックアップ**
より厳密な整合性が必要な場合：
```bash
# WordPress全体をアトミックにバックアップ
wp db export backup.sql
tar czf wordpress-$(date +%Y%m%d-%H%M).tar.gz \
  /var/www/wordpress backup.sql
gsutil cp wordpress-*.tar.gz gs://backup-bucket/
```

### 3.3 パフォーマンス

| 指標 | 目標値 | 測定方法 |
|------|--------|----------|
| **ページロード時間** | < 2秒（初回） | Google PageSpeed Insights |
| **TTFB** | < 500ms（キャッシュミス時） | Cloud Monitoring |
| **TTFB** | < 50ms（キャッシュヒット時） | Cloud Monitoring |
| **Cloud CDNヒット率** | > 80% | Cloud Monitoring |
| **OPcacheヒット率** | > 95% | PHP Status |

### 3.4 スケーラビリティ

**Auto Scaling設定:**
```
最小インスタンス数: 2台
最大インスタンス数: 4台
スケールアウト条件: CPU使用率 > 90%
スケールイン条件: CPU使用率 < 70%（10分継続）
```

**設計思想:** CPUリソースは限界まで活用し、コスト効率を最大化

---

## 4. セキュリティ要件

### 4.1 ネットワークセキュリティ

```
[Internet]
    ↓
[Cloud Armor (WAF)] ← OWASP Top 10対策、DDoS防御
    ↓
[Cloud Load Balancer]
    ↓
[VPC - Private Subnet]
    ├─ Web Servers (内部IPのみ)
    ├─ Cloud SQL (プライベート接続)
    └─ Wazuh Manager (内部IP)
```

**ファイアウォールルール:**
- インターネット → Load Balancer: 80/443のみ許可
- Load Balancer → Web Servers: 内部通信のみ
- Web Servers → Cloud SQL: 3306のみ許可
- Wazuh Agent ⇄ Wazuh Manager: 1514, 1515, 55000

### 4.2 WAF（Cloud Armor）

**保護ルール:**
- OWASP ModSecurity Core Rule Set
- SQLインジェクション対策
- XSS対策
- ディレクトリトラバーサル対策
- レート制限（1IP当たり100req/分）
- Geo-blocking（必要に応じて）

### 4.3 SSL/TLS証明書

| 項目 | 実装 |
|------|------|
| **証明書発行** | Let's Encrypt（無料） |
| **自動更新** | certbot + Cloud Scheduler |
| **更新頻度** | 60日ごと（90日有効期限） |
| **チャレンジ方式** | DNS-01（Cloud DNS API使用） |
| **証明書管理** | Certificate Manager |

**証明書自動更新フロー:**
```
Cloud Scheduler (毎月1日)
    ↓
Cloud Functions
    ↓
certbot + Cloud DNS API
    ↓
Let's Encrypt
    ↓
Certificate Managerに更新
    ↓
Load Balancerに自動適用
```

### 4.4 IDS/IPS（Wazuh）

**構成:**
```
┌─────────────────────────────┐
│  Wazuh Manager VM           │
│  - e2-small                 │
│  - Elasticsearch + Kibana   │
│  - Wazuh Server             │
└──────────────┬──────────────┘
               │ Syslog (1514/UDP)
               │ Agent (1515/TCP)
               │
        ┌──────┴──────┬──────────────┐
        ▼             ▼              ▼
  Web Server 1  Web Server 2  Web Server N
  (Wazuh Agent) (Wazuh Agent) (Wazuh Agent)
```

**監視項目:**
- ファイル整合性監視（FIM）
- ログ分析（Nginx、PHP、SSH）
- 脆弱性検知
- ルートキット検知
- コンプライアンスチェック（CIS Benchmarks）

---

## 5. インフラ構成

### 5.1 GCPリソース構成

| リソース | 用途 | スペック | 数量 | 推定月額 |
|---------|------|----------|------|----------|
| **Cloud HTTP(S) Load Balancer** | L7ロードバランサー | - | 1 | ¥2,500 |
| **Cloud CDN** | コンテンツ配信 | - | 1 | ¥500-1,000 |
| **Cloud Armor** | WAF | Standard Tier | 1 | ¥2,000 |
| **Managed Instance Group** | Webサーバー | e2-medium x 2-4 | 1 | ¥6,000-12,000 |
| **Cloud SQL** | MySQL 8.0 | db-f1-micro HA | 1 | ¥8,000 |
| **Wazuh Manager VM** | セキュリティ監視 | e2-small | 1 | ¥2,500 |
| **Cloud DNS** | DNS管理 | - | 1 | ¥300 |
| **Cloud Logging** | ログ管理 | 10GB/月 | - | ¥500 |
| **Cloud Monitoring** | メトリクス | - | - | ¥0（無料枠） |
| **Cloud Storage** | バックアップ | Standard 50GB | - | ¥150 |
| **Cloud Scheduler** | 定期実行 | - | - | ¥0（無料枠） |
| **合計** | | | | **¥22,450-29,950** |

**⚠️ コスト最適化計画:**
- 初期: 無料クレジット¥40,000活用
- Phase 2: Cloud SQL → VM MySQL移行で約¥8,000削減
- Phase 3: Sustained Use Discountで約20%削減
- **長期目標: 月額¥3,000**

### 5.2 VM仕様

#### Web Server VM
```yaml
Machine Type: e2-medium (2 vCPU, 4GB RAM)
OS: Debian 11 (Bullseye)
Disk: 
  - Boot: 20GB SSD (OS + アプリ)
  - Data: 50GB Standard PD (WordPress files)
Network: VPC Private Subnet
```

**インストールソフトウェア:**
- Nginx 1.24+
- PHP 8.2 + PHP-FPM + Extensions
  - php-mysql, php-gd, php-curl, php-mbstring, php-xml
  - php-imagick, php-zip, php-intl
- WP-CLI
- Wazuh Agent 4.x
- Cloud Logging Agent

#### Wazuh Manager VM
```yaml
Machine Type: e2-small (2 vCPU, 2GB RAM)
OS: Ubuntu 22.04 LTS
Disk: 50GB SSD
Network: VPC Private Subnet
```

**インストールソフトウェア:**
- Wazuh Manager
- Elasticsearch (Single Node)
- Kibana

### 5.3 ネットワーク構成

```
VPC: wordpress-vpc (asia-northeast1)
├─ Subnet: web-subnet (10.0.1.0/24)
│   ├─ Web Server 1 (10.0.1.10)
│   ├─ Web Server 2 (10.0.1.11)
│   └─ NAT Gateway (外部通信用)
│
├─ Subnet: mgmt-subnet (10.0.2.0/24)
│   └─ Wazuh Manager (10.0.2.10)
│
└─ Cloud SQL Private Connection
    └─ MySQL (Private IP: 10.0.3.x)
```

**ファイアウォール設計:**
| ルール名 | 方向 | ソース | ターゲット | プロトコル/ポート |
|---------|------|--------|-----------|-----------------|
| allow-lb-to-web | Ingress | LB Health Check | web-subnet | TCP:80,443 |
| allow-web-to-sql | Egress | web-subnet | Cloud SQL | TCP:3306 |
| allow-wazuh-agent | Egress | web-subnet | mgmt-subnet | TCP:1514,1515 |
| allow-ssh-iap | Ingress | IAP Range | All | TCP:22 |
| deny-all-ingress | Ingress | 0.0.0.0/0 | All | All |

---

## 6. ログ管理とモニタリング

### 6.1 ログ収集

**ログソース:**
```
Web Servers:
├─ Nginx Access Log → Cloud Logging
├─ Nginx Error Log → Cloud Logging
├─ PHP Error Log → Cloud Logging
└─ Wazuh Agent → Wazuh Manager

Wazuh Manager:
└─ Security Events → Wazuh Dashboard

Cloud SQL:
├─ MySQL Slow Query Log → Cloud Logging
└─ MySQL Error Log → Cloud Logging

Load Balancer:
└─ HTTP Access Log → Cloud Logging
```

**ログ保持期間:**
- Cloud Logging: 30日（デフォルト）
- Wazuh: 90日
- アーカイブ（Cloud Storage）: 1年

### 6.2 監視項目

#### サービス監視（最優先）
| 監視項目 | 閾値 | アラート条件 |
|---------|------|-------------|
| **HTTP Health Check** | 失敗 | 2回連続失敗 → Critical |
| **HTTPS証明書有効期限** | < 7日 | Warning |
| **WordPress管理画面応答** | タイムアウト | 3回連続 → Critical |

#### リソース監視（Phase 2）
| 監視項目 | 閾値 | アラート条件 |
|---------|------|-------------|
| CPU使用率 | > 80% | 10分継続 → Warning |
| メモリ使用率 | > 90% | 5分継続 → Critical |
| ディスク使用率 | > 85% | Warning |
| Cloud SQL接続数 | > 90% | Warning |

### 6.3 アラート通知

**通知フロー:**
```
Cloud Monitoring Alert
    ↓
Cloud Functions (Webhook)
    ↓
┌───────────────────┬─────────────────────┐
│ Slack通知         │ AIエージェント起動   │
│ #infra-alerts     │ @ai-agent メンション │
└───────────────────┴─────────────────────┘
                    ↓
          AIエージェントが自律的に対応
          ├─ ログ分析
          ├─ メトリクス確認
          ├─ 自動復旧試行
          └─ 人間へのエスカレーション判断
```

**Slack通知フォーマット:**
```
🚨 [CRITICAL] Web Server Health Check Failed
━━━━━━━━━━━━━━━━━━━━━━━━━━
Instance: web-server-1
Zone: asia-northeast1-a
Time: 2025-11-04 20:30:00 JST
Message: HTTP health check failed (2 consecutive)

@ai-agent 自動復旧を試行してください
━━━━━━━━━━━━━━━━━━━━━━━━━━
View Logs: [Link]
View Metrics: [Link]
```

---

## 7. デプロイメント戦略

### 7.1 Infrastructure as Code

**使用ツール:**
- **Terraform**: GCPリソースのプロビジョニング
- **Ansible**: VM内部の構成管理
- **WP-CLI**: WordPress設定

**リポジトリ構成:**
```
infra-ai-agent/
├─ terraform/
│   ├─ modules/
│   │   ├─ network/        # VPC, Subnet, Firewall
│   │   ├─ compute/        # MIG, Instance Template
│   │   ├─ loadbalancer/   # LB, Cloud Armor, SSL
│   │   ├─ database/       # Cloud SQL
│   │   └─ security/       # Wazuh Manager
│   ├─ environments/
│   │   ├─ dev/
│   │   └─ prod/
│   └─ main.tf
│
├─ ansible/
│   ├─ roles/
│   │   ├─ webserver/      # Nginx, PHP, WP
│   │   ├─ wazuh-agent/
│   │   └─ wazuh-manager/
│   └─ playbooks/
│       ├─ deploy-web.yml
│       └─ deploy-security.yml
│
└─ scripts/
    ├─ wordpress-setup.sh  # WP-CLI自動セットアップ
    └─ certbot-renewal.sh  # SSL証明書更新
```

### 7.2 デプロイフロー

```
1. インフラプロビジョニング
   terraform apply

2. VM設定適用
   ansible-playbook deploy-web.yml

3. WordPress初期セットアップ
   ./scripts/wordpress-setup.sh

4. セキュリティツール展開
   ansible-playbook deploy-security.yml

5. 動作確認
   python -m agent.main status
   curl -I https://example.com
```

---

## 8. 移行計画

### 8.1 Cloud SQL → VM MySQL 移行手順

**移行理由:** コスト削減（¥8,000/月 → ¥1,500/月）

**手順:**
1. **準備**
   - MySQLダンプ取得（mysqldump）
   - VM内にMySQL 8.0インストール
   
2. **移行実行**
   ```bash
   # 1. Cloud SQLからエクスポート
   gcloud sql export sql INSTANCE_NAME gs://BUCKET/backup.sql
   
   # 2. VM MySQLにインポート
   gsutil cp gs://BUCKET/backup.sql /tmp/
   mysql < /tmp/backup.sql
   
   # 3. WordPress wp-config.php更新
   # DB_HOST を Cloud SQL IP → VM IP に変更
   
   # 4. 動作確認
   wp db check
   
   # 5. Cloud SQL削除
   terraform destroy -target=module.database
   ```

3. **ロールバック計画**
   - Cloud SQLバックアップは7日間保持
   - 問題発生時は即座にCloud SQLに戻す

**所要時間:** 2-3時間（ダウンタイム: 10-15分）

### 8.2 既存ドメインのCloud DNS移行

**手順:**
1. Cloud DNSゾーン作成
2. 既存DNSレコードをエクスポート
3. Cloud DNSにインポート
4. ネームサーバー変更（レジストラ側）
5. 伝播確認（24-48時間）

---

## 9. 開発・運用フロー

### 9.1 CI/CDパイプライン（Phase 2）

```
GitHub Push (main branch)
    ↓
GitHub Actions
    ├─ Terraform Plan
    ├─ Ansible Lint
    └─ テスト実行
    ↓
承認待ち（手動トリガー）
    ↓
Deploy to Production
    ├─ terraform apply
    ├─ ansible-playbook
    └─ Smoke Test
    ↓
Slack通知（成功/失敗）
```

### 9.2 AIエージェント自律運用

**エージェントの役割:**

1. **監視と分析**
   - Cloud Monitoringメトリクス収集
   - ログ分析（異常パターン検知）
   - Wazuhアラート確認

2. **自動復旧**
   ```
   異常検知
       ↓
   [判断] 自動復旧可能？
       ├─ Yes → 復旧アクション実行
       │         ├─ インスタンス再起動
       │         ├─ サービス再起動
       │         └─ キャッシュクリア
       └─ No  → 人間にエスカレーション
   ```

3. **定期メンテナンス**
   - WordPressコア/プラグイン更新
   - SSL証明書更新確認
   - バックアップ検証
   - コスト分析レポート

**実装方針:**
- Phase 1: 手動オペレーション + ログ記録
- Phase 2: 簡単な自動復旧（再起動など）
- Phase 3: LLM統合で高度な判断

---

## 10. 成功基準

### 10.1 Phase 1完了条件

- [ ] 全GCPリソースがTerraformで管理されている
- [ ] WordPressが10サイトホスティング可能
- [ ] Cloud Armorで基本的なWAFルールが動作
- [ ] Let's EncryptのSSL証明書が自動更新される
- [ ] Cloud SQLが自動バックアップされる（1日2回）
- [ ] Wazuhで基本的なセキュリティ監視ができる
- [ ] Slack通知が正常に動作する
- [ ] AIエージェントが基本情報を取得できる

### 10.2 性能目標

| 指標 | 目標 | 測定方法 |
|------|------|----------|
| ページロード時間 | < 2秒 | Google PageSpeed Insights |
| 稼働率 | > 99.5% | Cloud Monitoring |
| セキュリティスコア | A+ | Mozilla Observatory |
| SSL Labs評価 | A+ | SSL Labs Test |

### 10.3 コスト目標

| フェーズ | 月額コスト | 期間 |
|---------|-----------|------|
| Phase 1（初期） | ¥20,000-25,000 | 1-2ヶ月（無料クレジット活用） |
| Phase 2（最適化後） | ¥10,000-12,000 | 3-6ヶ月 |
| Phase 3（長期運用） | ¥3,000-5,000 | 6ヶ月以降 |

---

## 11. リスクと対策

| リスク | 影響度 | 対策 |
|--------|--------|------|
| コスト超過 | 高 | Cloud Billing Alertで¥3,000で通知 |
| Cloud SQL障害 | 高 | HA構成 + 自動バックアップ |
| DDoS攻撃 | 中 | Cloud Armor + レート制限 |
| SSL証明書期限切れ | 中 | 自動更新 + 期限監視アラート |
| データ損失 | 高 | 多層バックアップ（DB, VM, Files） |
| 不正アクセス | 高 | Wazuh監視 + Cloud Armor |

---

## 12. スケジュール

### Phase 1: 基盤構築（2-3週間）
- Week 1: Terraform基盤構築
- Week 2: WordPress環境構築 + セキュリティ設定
- Week 3: テスト + ドキュメント化

### Phase 2: 運用最適化（1-2週間）
- コスト最適化
- 監視・アラート調整
- AI自動化機能追加

### Phase 3: 機能拡張（継続的）
- パフォーマンス最適化
- 追加セキュリティ機能
- スケーリング対応

---

## 付録A: 用語集

| 用語 | 説明 |
|------|------|
| **HA** | High Availability（高可用性） |
| **RTO** | Recovery Time Objective（目標復旧時間） |
| **RPO** | Recovery Point Objective（目標復旧時点） |
| **WAF** | Web Application Firewall |
| **IDS/IPS** | 侵入検知/防御システム |
| **CDN** | Content Delivery Network |

---

**承認:**
- [ ] 技術要件承認
- [ ] セキュリティ要件承認
- [ ] コスト計画承認

**次のアクション:**
Terraform設計書の作成 → `docs/terraform-design.md`

