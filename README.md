# Infra AI Agent 🤖☁️

Google Cloud Platform上のシステムをエージェンティックに運用するインフラエンジニアAIエージェントプロジェクト

## 📋 プロジェクト概要

このプロジェクトは、Google Cloud上に構築されたシステムを自律的に運用・管理するAIエージェントを育成する場所です。AIエージェント自身がシステムを構築し、運用オペレーションを実行します。

### 主な特徴

- **自律的なインフラ運用**: AIエージェントが監視、トラブルシューティング、最適化を実行
- **エージェンティックアーキテクチャ**: LLMベースの判断と実行フレームワーク
- **Google Cloud統合**: GCP各種サービスとの連携
- **Infrastructure as Code**: Terraformによる宣言的インフラ管理

## 🏗️ プロジェクト構成

```
infra-ai-agent/
├── README.md                      # このファイル
├── CLAUDE.md                      # AIエージェント向け開発ガイド
├── .gitignore                     # Git除外設定
├── .env.example                   # 環境変数のテンプレート
├── requirements.txt               # Python依存関係
│
├── terraform/                     # インフラ定義（Terraform）
│   ├── README.md                  # Terraformガイド
│   ├── VALIDATION.md              # 検証手順
│   ├── environments/              # 環境別設定
│   │   ├── prod/                  # 本番環境
│   │   │   ├── provider.tf
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── terraform.tfvars.example
│   │   └── dev/                   # 開発環境
│   │       └── (同上)
│   ├── modules/                   # 再利用可能モジュール
│   │   ├── network/               # VPC、NAT、Firewall
│   │   ├── iam/                   # サービスアカウント、権限
│   │   ├── filestore/             # NFS共有ストレージ
│   │   ├── database/              # Cloud SQL
│   │   ├── compute/               # MIG、Autoscaling
│   │   ├── loadbalancer/          # LB、CDN、WAF
│   │   └── monitoring/            # アラート、ログ
│   └── scripts/
│       └── startup_script.sh      # VM起動スクリプト
│
├── ansible/                       # 構成管理（Ansible）
│   ├── README.md                   # Ansibleガイド
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/
│   │   └── gcp.yml                 # GCPダイナミックインベントリ
│   ├── playbooks/
│   │   ├── setup.yml               # 基本セットアップ
│   │   ├── deploy-wordpress.yml    # WordPressデプロイ
│   │   └── quick-setup.yml         # ローカル実行用
│   └── roles/
│       └── wordpress/              # WordPressロール
│           ├── defaults/           # デフォルト変数
│           ├── tasks/              # タスク（packages, nginx, php, etc）
│           ├── templates/          # Jinja2テンプレート
│           └── handlers/           # サービス再起動ハンドラー
│
├── agent/                         # AIエージェントコア
│   ├── __init__.py
│   ├── main.py                    # CLIエントリーポイント
│   └── tools/
│       ├── gcp_tools.py           # GCP操作
│       └── monitoring.py          # 監視
│
├── scripts/                       # ユーティリティスクリプト
│   ├── check_prerequisites.sh
│   ├── setup.sh
│   └── test_connection.py
│
├── docs/                          # 設計ドキュメント
│   ├── requirements.md            # 要件定義書（813行）
│   ├── terraform-design.md        # Terraform設計書（2,258行）
│   ├── ansible-usage-guide.md     # Ansible使用ガイド
│   └── ansible-implementation-summary.md  # Ansible実装サマリー
│
└── tests/                         # テスト（予定）
```

## 🚀 クイックスタート

### 前提条件

- Python 3.10以上
- uv (Pythonパッケージマネージャー)
- Google Cloud SDK (gcloud CLI)
- Terraform 1.5以上 (オプション)
- GCPプロジェクトとサービスアカウント

### セットアップ

#### 1. 前提条件の確認

```bash
# 前提条件チェック
bash scripts/check_prerequisites.sh
```

必要なツール：
- Python 3.10以上
- uv (Pythonパッケージマネージャー)
- gcloud CLI
- Terraform 1.5以上（オプション）

#### 2. ツールのインストール

**uvのインストール:**
```bash
sudo apt install pipx
pipx install uv
```

**gcloud CLIのインストール:**
```bash
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xzf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh
source ~/.bashrc
```

#### 3. GCP認証

```bash
# gcloud認証
gcloud auth login

# プロジェクト設定
gcloud config set project YOUR_PROJECT_ID

# Application Default Credentials設定
gcloud auth application-default login
```

#### 4. 環境変数の設定

```bash
cp .env.example .env
# .envファイルを編集してプロジェクトIDなどを設定
```

#### 5. セットアップ実行

```bash
# 自動セットアップ（仮想環境作成、依存関係インストール、API有効化）
bash scripts/setup.sh
```

#### 6. 接続テスト

```bash
# 仮想環境を有効化
source .venv/bin/activate

# GCP接続テスト
python scripts/test_connection.py
```

#### 7. AIエージェントの使用

```bash
# インフラ状態確認
python -m agent.main status

# ゾーン一覧表示
python -m agent.main zones

# VMインスタンス起動
python -m agent.main start INSTANCE_NAME --zone ZONE

# VMインスタンス停止
python -m agent.main stop INSTANCE_NAME --zone ZONE

# メトリクス監視
python -m agent.main monitor INSTANCE_NAME --hours 1
```

## 🛠️ WordPress環境のセットアップ（Ansible）

### Ansibleによる自動セットアップ

このプロジェクトでは、WordPressマルチサイト環境をAnsibleで完全自動化しています。

#### クイックスタート

```bash
# 1. Ansibleディレクトリに移動
cd ansible

# 2. GCP認証（必要に応じて）
gcloud auth application-default login
export GCP_PROJECT_ID="your-project-id"

# 3. WordPressデプロイ実行
ansible-playbook -i inventory/gcp.yml playbooks/deploy-wordpress.yml
```

#### 主な機能

- **マルチサイト対応**: 最大10サイトのWordPressを自動セットアップ
- **Nginx + PHP-FPM**: 最適化された設定（OPcache有効）
- **Cloud CDN統合**: Cache-Control自動設定
- **WP-CLI統合**: コマンドラインでのWordPress管理
- **Secret Manager**: パスワードの安全な管理
- **監視統合**: Ops Agent（Cloud Logging + Monitoring）

#### WordPressサイトのセットアップ

```bash
# VMにSSH接続
gcloud compute ssh wordpress-instance --zone=asia-northeast1-a

# サイトをセットアップ（自動でWP-CLIが実行されます）
sudo /usr/local/bin/setup-wordpress-site.sh 1 example.com "My WordPress Site"

# 管理者パスワード取得
gcloud secrets versions access latest --secret=prod-wordpress-admin-password-1
```

#### 詳細ドキュメント

- [Ansible README](ansible/README.md) - 全体リファレンス
- [使用ガイド](docs/ansible-usage-guide.md) - 実践例・トラブルシューティング
- [実装サマリー](docs/ansible-implementation-summary.md) - アーキテクチャ詳細

## 🎯 使用例

### CLIコマンド

```bash
# インフラの状態確認
python -m agent.main status

# 出力例:
# 📊 インフラステータスチェック
# 💻 VMインスタンス:
#   インスタンスが見つかりません
# 🪣 Cloud Storage バケット:
#   バケットが見つかりません

# 利用可能なゾーン一覧
python -m agent.main zones

# VMインスタンス操作
python -m agent.main start my-instance --zone asia-northeast1-a
python -m agent.main stop my-instance --zone asia-northeast1-a

# メトリクス監視
python -m agent.main monitor my-instance --hours 1
```

### Pythonコードでの使用

```python
from agent.tools import GCPTools, MonitoringTools

# GCPツールの初期化
gcp_tools = GCPTools(project_id="infra-ai-agent")

# VMインスタンス一覧取得
instances = gcp_tools.list_instances()
for instance in instances:
    print(f"{instance['name']}: {instance['status']}")

# 監視ツールの初期化
monitoring = MonitoringTools(project_id="infra-ai-agent")

# CPU使用率取得
cpu_metrics = monitoring.get_cpu_utilization(
    instance_name="my-instance",
    zone="asia-northeast1-a",
    hours=1
)

# メトリクスサマリー
summary = monitoring.get_summary("my-instance", "asia-northeast1-a", hours=24)
print(f"平均CPU使用率: {summary['cpu']['avg']:.2f}%")
```

## 🔧 開発

### 開発環境

```bash
# 仮想環境を有効化
source .venv/bin/activate

# 新しい依存関係を追加
uv pip install パッケージ名

# requirements.txtに保存
uv pip freeze > requirements.txt
```

### AIエージェントの拡張

新しいツールを追加する場合は `agent/tools/` ディレクトリに配置してください。

```python
# agent/tools/custom_tool.py
import structlog

logger = structlog.get_logger()

class CustomTools:
    """カスタムツール"""
    
    def custom_operation(self):
        """カスタムオペレーション"""
        logger.info("Custom operation executed")
        # 処理を実装
        pass
```

### テスト

```bash
# テスト実行（予定）
pytest tests/
```

## 📊 アーキテクチャ

### システム構成

```
┌─────────────────┐
│  AI Agent       │
│  (Claude/GPT)   │
└────────┬────────┘
         │
         ├─────> GCP APIs
         │       ├── Compute Engine
         │       ├── Cloud Storage
         │       ├── Cloud Monitoring
         │       └── Cloud Functions
         │
         └─────> Terraform
                 (IaC Management)
```

### エージェントフロー

1. **監視**: システムメトリクスの収集
2. **分析**: 異常検知と原因分析
3. **計画**: 対応策の立案
4. **実行**: GCP APIまたはTerraformによる変更
5. **検証**: 変更の効果確認
6. **学習**: 結果のフィードバック

## 🔒 セキュリティ

- **認証情報管理**: `.env`ファイルは**絶対に**コミットしない
- **最小権限の原則**: サービスアカウントには必要最小限の権限のみ付与
- **監査ログ**: すべてのオペレーションをCloud Loggingに記録
- **秘密情報**: Secret Managerを使用

## 📝 ライセンス

MIT License

## 🤝 コントリビューション

プルリクエストを歓迎します!大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## 📧 コンタクト

- GitHub: [@0xchoux1](https://github.com/0xchoux1)
- Project: [infra-ai-agent](https://github.com/0xchoux1/infra-ai-agent)

---

**⚠️ 注意**: このプロジェクトはAIエージェントによる自律的なインフラ運用を実現します。本番環境での使用前に十分なテストを実施してください。

