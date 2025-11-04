#!/usr/bin/env python3
"""
GCP接続テストスクリプト
Google Cloud Platform への接続と基本的なAPI操作を確認
"""

import os
import sys
from pathlib import Path

# プロジェクトルートをPythonパスに追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from dotenv import load_dotenv
from google.cloud import compute_v1
from google.cloud import resourcemanager_v3
from google.auth import default
from google.auth.exceptions import DefaultCredentialsError

# 環境変数の読み込み
env_path = project_root / '.env'
if env_path.exists():
    load_dotenv(env_path)
else:
    print("⚠️  .env ファイルが見つかりません")
    print("env.example を .env にコピーして設定してください")
    sys.exit(1)


class Colors:
    """ターミナルカラー"""
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


def print_success(message):
    """成功メッセージ"""
    print(f"{Colors.GREEN}✓{Colors.NC} {message}")


def print_error(message):
    """エラーメッセージ"""
    print(f"{Colors.RED}✗{Colors.NC} {message}")


def print_info(message):
    """情報メッセージ"""
    print(f"{Colors.BLUE}ℹ{Colors.NC} {message}")


def print_warning(message):
    """警告メッセージ"""
    print(f"{Colors.YELLOW}⚠{Colors.NC} {message}")


def test_authentication():
    """認証テスト"""
    print("\n" + "="*50)
    print("📋 認証テスト")
    print("="*50)
    
    try:
        credentials, project = default()
        print_success(f"認証成功")
        print_info(f"プロジェクト: {project}")
        print_info(f"認証タイプ: {type(credentials).__name__}")
        return credentials, project
    except DefaultCredentialsError as e:
        print_error("認証失敗")
        print_error(str(e))
        print_warning("以下のいずれかを実行してください:")
        print("  1. gcloud auth application-default login")
        print("  2. GOOGLE_APPLICATION_CREDENTIALS 環境変数を設定")
        return None, None


def test_project_access(project_id):
    """プロジェクトアクセステスト"""
    print("\n" + "="*50)
    print("🔐 プロジェクトアクセステスト")
    print("="*50)
    
    try:
        client = resourcemanager_v3.ProjectsClient()
        project_name = f"projects/{project_id}"
        project = client.get_project(name=project_name)
        
        print_success(f"プロジェクトアクセス成功")
        print_info(f"プロジェクトID: {project.project_id}")
        print_info(f"プロジェクト名: {project.display_name}")
        print_info(f"状態: {project.state.name}")
        return True
    except Exception as e:
        print_error(f"プロジェクトアクセス失敗: {e}")
        return False


def test_compute_api(project_id):
    """Compute Engine API テスト"""
    print("\n" + "="*50)
    print("💻 Compute Engine API テスト")
    print("="*50)
    
    try:
        client = compute_v1.InstancesClient()
        zone = os.getenv('GCP_ZONE', 'asia-northeast1-a')
        
        print_info(f"ゾーン {zone} のインスタンス一覧を取得中...")
        
        request = compute_v1.ListInstancesRequest(
            project=project_id,
            zone=zone,
        )
        
        instances = list(client.list(request=request))
        
        print_success(f"Compute Engine API 呼び出し成功")
        print_info(f"インスタンス数: {len(instances)}")
        
        if instances:
            print("\n📍 インスタンス一覧:")
            for instance in instances:
                status_color = Colors.GREEN if instance.status == "RUNNING" else Colors.YELLOW
                print(f"  • {instance.name}: {status_color}{instance.status}{Colors.NC}")
        else:
            print_info("インスタンスは存在しません")
        
        return True
    except Exception as e:
        print_error(f"Compute Engine API 呼び出し失敗: {e}")
        print_warning("Compute Engine API が有効化されていない可能性があります")
        print_info("有効化コマンド: gcloud services enable compute.googleapis.com")
        return False


def test_zones_list(project_id):
    """ゾーン一覧取得テスト"""
    print("\n" + "="*50)
    print("🌏 利用可能なゾーン")
    print("="*50)
    
    try:
        client = compute_v1.ZonesClient()
        region = os.getenv('GCP_REGION', 'asia-northeast1')
        
        request = compute_v1.ListZonesRequest(
            project=project_id,
        )
        
        zones = list(client.list(request=request))
        asia_zones = [z for z in zones if z.region.endswith(region)]
        
        if asia_zones:
            print_success(f"{region} リージョンのゾーン:")
            for zone in asia_zones:
                status_icon = "🟢" if zone.status == "UP" else "🔴"
                print(f"  {status_icon} {zone.name}")
        else:
            print_info(f"{region} リージョンのゾーンが見つかりません")
        
        return True
    except Exception as e:
        print_error(f"ゾーン一覧取得失敗: {e}")
        return False


def main():
    """メイン処理"""
    print("\n" + "="*50)
    print("🚀 Infra AI Agent - GCP接続テスト")
    print("="*50)
    
    # 環境変数の確認
    project_id = os.getenv('GCP_PROJECT_ID')
    if not project_id:
        print_error("GCP_PROJECT_ID が設定されていません")
        print_info(".env ファイルを確認してください")
        sys.exit(1)
    
    print_info(f"テスト対象プロジェクト: {project_id}")
    
    # テスト実行
    results = []
    
    # 1. 認証テスト
    credentials, detected_project = test_authentication()
    if credentials is None:
        print_error("\n❌ 認証に失敗しました。セットアップを確認してください。")
        sys.exit(1)
    results.append(True)
    
    # 2. プロジェクトアクセステスト
    results.append(test_project_access(project_id))
    
    # 3. Compute Engine APIテスト
    results.append(test_compute_api(project_id))
    
    # 4. ゾーン一覧テスト
    results.append(test_zones_list(project_id))
    
    # 結果サマリー
    print("\n" + "="*50)
    print("📊 テスト結果サマリー")
    print("="*50)
    
    success_count = sum(results)
    total_count = len(results)
    
    if success_count == total_count:
        print_success(f"すべてのテストが成功しました ({success_count}/{total_count})")
        print("\n✨ GCP接続が正常に確認できました！")
        print("\n次のステップ:")
        print("  1. Terraform でインフラを構築: cd terraform && terraform plan")
        print("  2. Ansible で設定管理: cd ansible && ansible-playbook playbooks/setup.yml")
        print("  3. AIエージェントを起動: python -m agent.main")
        return 0
    else:
        print_warning(f"一部のテストが失敗しました ({success_count}/{total_count})")
        print("\n⚠️  セットアップスクリプトを実行してください:")
        print("  bash scripts/setup.sh")
        return 1


if __name__ == "__main__":
    sys.exit(main())

