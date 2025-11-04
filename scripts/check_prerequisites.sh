#!/bin/bash

# 前提条件チェックスクリプト
# 必要なツールがインストールされているか確認

set -e

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================"
echo "前提条件チェック"
echo "======================================"
echo ""

MISSING_TOOLS=0

# Python チェック
echo -n "🐍 Python 3.10+: "
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 10 ]; then
        echo -e "${GREEN}✓${NC} $PYTHON_VERSION"
    else
        echo -e "${RED}✗${NC} バージョンが古い ($PYTHON_VERSION)"
        echo "   Python 3.10以上が必要です"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
else
    echo -e "${RED}✗${NC} インストールされていません"
    echo "   インストール: sudo apt install python3 python3-pip"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

# gcloud CLI チェック
echo -n "☁️  gcloud CLI: "
if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud version --format="value(core)" 2>/dev/null)
    echo -e "${GREEN}✓${NC} $GCLOUD_VERSION"
else
    echo -e "${RED}✗${NC} インストールされていません"
    echo "   インストール手順:"
    echo "   curl https://sdk.cloud.google.com | bash"
    echo "   exec -l \$SHELL"
    echo "   gcloud init"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

# Terraform チェック（オプション）
echo -n "🏗️  Terraform: "
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓${NC} $TERRAFORM_VERSION"
else
    echo -e "${YELLOW}⚠${NC} インストールされていません（オプション）"
    echo "   インストール: https://www.terraform.io/downloads"
fi

# uv チェック
echo -n "⚡ uv: "
if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version | awk '{print $2}')
    echo -e "${GREEN}✓${NC} $UV_VERSION"
else
    echo -e "${RED}✗${NC} インストールされていません"
    echo "   インストール: sudo apt install pipx && pipx install uv"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

# git チェック
echo -n "🔧 git: "
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    echo -e "${GREEN}✓${NC} $GIT_VERSION"
else
    echo -e "${YELLOW}⚠${NC} インストールされていません（推奨）"
    echo "   インストール: sudo apt install git"
fi

# curl チェック
echo -n "🌐 curl: "
if command -v curl &> /dev/null; then
    CURL_VERSION=$(curl --version | head -n1 | awk '{print $2}')
    echo -e "${GREEN}✓${NC} $CURL_VERSION"
else
    echo -e "${RED}✗${NC} インストールされていません"
    echo "   インストール: sudo apt install curl"
    MISSING_TOOLS=$((MISSING_TOOLS + 1))
fi

echo ""
echo "======================================"

if [ $MISSING_TOOLS -eq 0 ]; then
    echo -e "${GREEN}✅ すべての必須ツールがインストールされています${NC}"
    echo ""
    echo "次のステップ:"
    echo "  1. gcloud auth login"
    echo "  2. gcloud config set project infra-ai-agent"
    echo "  3. gcloud auth application-default login"
    echo "  4. cp env.example .env"
    echo "  5. bash scripts/setup.sh"
    exit 0
else
    echo -e "${RED}❌ $MISSING_TOOLS 個の必須ツールが不足しています${NC}"
    echo ""
    echo "上記のインストール手順に従ってツールをインストールしてください。"
    exit 1
fi

