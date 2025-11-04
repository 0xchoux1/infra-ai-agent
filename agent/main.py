#!/usr/bin/env python3
"""
Infra AI Agent メインスクリプト
Google Cloud Platform インフラを自律的に運用するAIエージェント
"""

import os
import sys
from pathlib import Path

# プロジェクトルートをPythonパスに追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

import click
import structlog
from dotenv import load_dotenv

from agent.tools import GCPTools, MonitoringTools

# 環境変数の読み込み
load_dotenv()

# ロギング設定
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.dev.ConsoleRenderer()
    ]
)

logger = structlog.get_logger()


@click.group()
@click.option('--project-id', envvar='GCP_PROJECT_ID', help='GCPプロジェクトID')
@click.pass_context
def cli(ctx, project_id):
    """Infra AI Agent - GCPインフラ運用AIエージェント"""
    ctx.ensure_object(dict)
    ctx.obj['project_id'] = project_id
    
    if not project_id:
        click.echo("❌ GCP_PROJECT_ID が設定されていません", err=True)
        click.echo(".env ファイルを確認してください", err=True)
        sys.exit(1)


@cli.command()
@click.pass_context
def status(ctx):
    """インフラの現在の状態を確認"""
    click.echo("📊 インフラステータスチェック\n")
    
    project_id = ctx.obj['project_id']
    gcp_tools = GCPTools(project_id)
    
    # VMインスタンス一覧
    click.echo("💻 VMインスタンス:")
    instances = gcp_tools.list_instances()
    
    if instances:
        for instance in instances:
            status_icon = "🟢" if instance['status'] == "RUNNING" else "🔴"
            click.echo(f"  {status_icon} {instance['name']}")
            click.echo(f"     状態: {instance['status']}")
            click.echo(f"     タイプ: {instance['machine_type']}")
            click.echo(f"     内部IP: {instance['internal_ip']}")
            if instance['external_ip']:
                click.echo(f"     外部IP: {instance['external_ip']}")
            click.echo()
    else:
        click.echo("  インスタンスが見つかりません\n")
    
    # Cloud Storage バケット
    click.echo("🪣 Cloud Storage バケット:")
    buckets = gcp_tools.list_buckets()
    
    if buckets:
        for bucket in buckets:
            click.echo(f"  📦 {bucket['name']}")
            click.echo(f"     ロケーション: {bucket['location']}")
            click.echo(f"     ストレージクラス: {bucket['storage_class']}")
            click.echo()
    else:
        click.echo("  バケットが見つかりません\n")


@cli.command()
@click.argument('instance_name')
@click.option('--zone', envvar='GCP_ZONE', help='ゾーン')
@click.option('--hours', default=1, help='過去何時間分のデータを表示するか')
@click.pass_context
def monitor(ctx, instance_name, zone, hours):
    """インスタンスのメトリクスを監視"""
    click.echo(f"📈 {instance_name} のメトリクス監視\n")
    
    project_id = ctx.obj['project_id']
    zone = zone or os.getenv('GCP_ZONE', 'asia-northeast1-a')
    
    monitoring_tools = MonitoringTools(project_id)
    
    # メトリクスサマリー取得
    summary = monitoring_tools.get_summary(instance_name, zone, hours)
    
    click.echo(f"インスタンス: {summary['instance']}")
    click.echo(f"ゾーン: {summary['zone']}")
    click.echo(f"期間: 過去{summary['period_hours']}時間\n")
    
    # CPU
    click.echo("💻 CPU:")
    cpu = summary['cpu']
    click.echo(f"  平均: {cpu['avg']:.2f}%")
    click.echo(f"  最大: {cpu['max']:.2f}%")
    click.echo(f"  最小: {cpu['min']:.2f}%")
    click.echo(f"  データポイント: {cpu['data_points']}\n")
    
    # CPU異常検知
    if cpu['max'] > 80:
        click.echo("  ⚠️  CPU使用率が高くなっています", fg='yellow')
    
    # メモリ
    click.echo("💾 メモリ:")
    memory = summary['memory']
    click.echo(f"  データポイント: {memory['data_points']}\n")
    
    # ディスクI/O
    click.echo("💿 ディスクI/O:")
    disk_io = summary['disk_io']
    click.echo(f"  読み取りポイント: {disk_io['read_points']}")
    click.echo(f"  書き込みポイント: {disk_io['write_points']}\n")


@cli.command()
@click.argument('instance_name')
@click.option('--zone', envvar='GCP_ZONE', help='ゾーン')
@click.pass_context
def start(ctx, instance_name, zone):
    """インスタンスを起動"""
    project_id = ctx.obj['project_id']
    zone = zone or os.getenv('GCP_ZONE', 'asia-northeast1-a')
    
    click.echo(f"🚀 {instance_name} を起動中...")
    
    gcp_tools = GCPTools(project_id)
    
    if gcp_tools.start_instance(instance_name, zone):
        click.echo(f"✅ {instance_name} の起動を開始しました")
    else:
        click.echo(f"❌ {instance_name} の起動に失敗しました", err=True)
        sys.exit(1)


@cli.command()
@click.argument('instance_name')
@click.option('--zone', envvar='GCP_ZONE', help='ゾーン')
@click.pass_context
def stop(ctx, instance_name, zone):
    """インスタンスを停止"""
    project_id = ctx.obj['project_id']
    zone = zone or os.getenv('GCP_ZONE', 'asia-northeast1-a')
    
    click.echo(f"⏸️  {instance_name} を停止中...")
    
    gcp_tools = GCPTools(project_id)
    
    if gcp_tools.stop_instance(instance_name, zone):
        click.echo(f"✅ {instance_name} の停止を開始しました")
    else:
        click.echo(f"❌ {instance_name} の停止に失敗しました", err=True)
        sys.exit(1)


@cli.command()
@click.pass_context
def zones(ctx):
    """利用可能なゾーン一覧を表示"""
    click.echo("🌏 利用可能なゾーン\n")
    
    project_id = ctx.obj['project_id']
    gcp_tools = GCPTools(project_id)
    
    zones = gcp_tools.list_zones()
    
    # リージョンごとにグループ化
    regions = {}
    for zone in zones:
        region = zone['region']
        if region not in regions:
            regions[region] = []
        regions[region].append(zone)
    
    for region, region_zones in sorted(regions.items()):
        click.echo(f"📍 {region}")
        for zone in region_zones:
            status_icon = "🟢" if zone['status'] == "UP" else "🔴"
            click.echo(f"  {status_icon} {zone['name']}")
        click.echo()


def main():
    """メイン関数"""
    try:
        cli(obj={})
    except Exception as e:
        logger.error("Fatal error", error=str(e))
        sys.exit(1)


if __name__ == '__main__':
    main()

