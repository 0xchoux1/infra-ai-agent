"""
Infra AI Agent
Google Cloud Platform インフラを自律的に運用するAIエージェント
"""

__version__ = "0.1.0"
__author__ = "0xchoux1"

from pathlib import Path

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent

# 環境変数の読み込み
from dotenv import load_dotenv
load_dotenv(PROJECT_ROOT / '.env')

