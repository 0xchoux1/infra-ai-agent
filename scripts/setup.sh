#!/bin/bash

# Infra AI Agent セットアップスクリプト
# GCP環境とツールのセットアップを自動化

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo "Infra AI Agent セットアップ"
echo "======================================"
echo ""

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 環境変数チェック
echo "📋 環境変数の確認..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${YELLOW}⚠️  .env ファイルが見つかりません${NC}"
    echo "env.example を .env にコピーして設定してください："
    echo "  cp env.example .env"
    echo "  vim .env  # 実際の値を設定"
    exit 1
fi

# .env ファイルの読み込み
source "$PROJECT_ROOT/.env"

if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${RED}❌ GCP_PROJECT_ID が設定されていません${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} GCP プロジェクト: $GCP_PROJECT_ID"
echo -e "${GREEN}✓${NC} リージョン: $GCP_REGION"
echo ""

# Python バージョンチェック
echo "🐍 Python バージョン確認..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    echo -e "${RED}❌ Python 3.10以上が必要です（現在: $PYTHON_VERSION）${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Python $PYTHON_VERSION"
echo ""

# uv チェック
echo "⚡ uv の確認..."
if ! command -v uv &> /dev/null; then
    echo -e "${RED}❌ uv がインストールされていません${NC}"
    echo "インストール方法:"
    echo "  sudo apt install pipx"
    echo "  pipx install uv"
    exit 1
fi

UV_VERSION=$(uv --version | awk '{print $2}')
echo -e "${GREEN}✓${NC} uv $UV_VERSION"
echo ""

# 仮想環境の作成
echo "📦 Python仮想環境のセットアップ（uv使用）..."
if [ ! -d "$PROJECT_ROOT/.venv" ]; then
    cd "$PROJECT_ROOT"
    uv venv
    echo -e "${GREEN}✓${NC} 仮想環境を作成しました"
else
    echo -e "${GREEN}✓${NC} 仮想環境は既に存在します"
fi

# 依存関係のインストール
echo "📥 依存パッケージのインストール（uv使用）..."
cd "$PROJECT_ROOT"
uv pip install -r requirements.txt
echo -e "${GREEN}✓${NC} 依存パッケージをインストールしました"
echo ""

# gcloud CLI チェック
echo "☁️  gcloud CLI の確認..."
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI がインストールされていません${NC}"
    echo "インストール方法: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

GCLOUD_VERSION=$(gcloud version --format="value(core)" 2>/dev/null)
echo -e "${GREEN}✓${NC} gcloud CLI $GCLOUD_VERSION"
echo ""

# gcloud 認証確認
echo "🔐 GCP認証の確認..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${YELLOW}⚠️  GCPに認証されていません${NC}"
    echo "認証を実行します..."
    gcloud auth login
fi

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
echo -e "${GREEN}✓${NC} 認証済み: $ACTIVE_ACCOUNT"
echo ""

# プロジェクト設定
echo "🔧 GCPプロジェクトの設定..."
gcloud config set project "$GCP_PROJECT_ID" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} プロジェクトを設定しました: $GCP_PROJECT_ID"
echo ""

# 必要なAPIの有効化
echo "🔌 GCP APIの有効化..."
REQUIRED_APIS=(
    "compute.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "iam.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "storage-api.googleapis.com"
)

for API in "${REQUIRED_APIS[@]}"; do
    echo "  - $API を有効化中..."
    gcloud services enable "$API" --project="$GCP_PROJECT_ID" > /dev/null 2>&1
done

echo -e "${GREEN}✓${NC} 必要なAPIを有効化しました"
echo ""

# Terraform チェック
echo "🏗️  Terraform の確認..."
if ! command -v terraform &> /dev/null; then
    echo -e "${YELLOW}⚠️  Terraform がインストールされていません${NC}"
    echo "インストール方法: https://www.terraform.io/downloads"
else
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓${NC} Terraform $TERRAFORM_VERSION"
fi
echo ""

# Terraform 初期化
if [ -d "$PROJECT_ROOT/terraform" ]; then
    echo "📦 Terraform の初期化..."
    cd "$PROJECT_ROOT/terraform"
    
    # terraform.tfvars の作成
    if [ ! -f "terraform.tfvars" ] && [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${GREEN}✓${NC} terraform.tfvars を作成しました（値を確認・編集してください）"
    fi
    
    terraform init > /dev/null 2>&1
    echo -e "${GREEN}✓${NC} Terraform を初期化しました"
    cd "$PROJECT_ROOT"
fi
echo ""

# Ansible チェック
echo "⚙️  Ansible の確認..."
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1 | awk '{print $3}' | tr -d ']')
    echo -e "${GREEN}✓${NC} Ansible $ANSIBLE_VERSION"
    
    # Ansible Galaxy コレクションのインストール
    if [ -f "$PROJECT_ROOT/ansible/requirements.yml" ]; then
        echo "📥 Ansible コレクションのインストール..."
        ansible-galaxy collection install -r "$PROJECT_ROOT/ansible/requirements.yml" > /dev/null 2>&1
        echo -e "${GREEN}✓${NC} Ansible コレクションをインストールしました"
    fi
else
    echo -e "${YELLOW}⚠️  Ansible がインストールされていません（requirements.txtに含まれています）${NC}"
fi
echo ""

# セットアップ完了
echo "======================================"
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo "======================================"
echo ""
echo "次のステップ:"
echo "  1. 接続テスト: python scripts/test_connection.py"
echo "  2. Terraform: cd terraform && terraform plan"
echo "  3. Ansible: cd ansible && ansible-playbook playbooks/setup.yml"
echo ""
echo "仮想環境の有効化:"
echo "  source .venv/bin/activate"
echo ""

