"""
GCPツール
Google Cloud Platform の各種リソースを操作するツール
"""

import os
from typing import List, Dict, Any, Optional
from google.cloud import compute_v1
from google.cloud import storage
from google.auth import default
import structlog

logger = structlog.get_logger()


class GCPTools:
    """Google Cloud Platform 操作ツール"""
    
    def __init__(self, project_id: Optional[str] = None):
        """
        初期化
        
        Args:
            project_id: GCPプロジェクトID（未指定の場合は環境変数から取得）
        """
        self.project_id = project_id or os.getenv('GCP_PROJECT_ID')
        self.region = os.getenv('GCP_REGION', 'asia-northeast1')
        self.zone = os.getenv('GCP_ZONE', 'asia-northeast1-a')
        
        if not self.project_id:
            raise ValueError("GCP_PROJECT_ID が設定されていません")
        
        self.credentials, _ = default()
        logger.info("GCPTools initialized", project_id=self.project_id)
    
    # ==================== 安全な操作（読み取り専用） ====================
    
    def list_instances(self, zone: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        VMインスタンス一覧を取得
        
        Args:
            zone: ゾーン名（未指定の場合はデフォルトゾーン）
        
        Returns:
            インスタンス情報のリスト
        """
        zone = zone or self.zone
        client = compute_v1.InstancesClient()
        
        request = compute_v1.ListInstancesRequest(
            project=self.project_id,
            zone=zone,
        )
        
        instances = []
        for instance in client.list(request=request):
            instances.append({
                'name': instance.name,
                'status': instance.status,
                'machine_type': instance.machine_type.split('/')[-1],
                'zone': zone,
                'internal_ip': instance.network_interfaces[0].network_i_p if instance.network_interfaces else None,
                'external_ip': (
                    instance.network_interfaces[0].access_configs[0].nat_i_p 
                    if instance.network_interfaces and instance.network_interfaces[0].access_configs 
                    else None
                ),
            })
        
        logger.info("Listed instances", zone=zone, count=len(instances))
        return instances
    
    def get_instance(self, instance_name: str, zone: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """
        特定のVMインスタンス情報を取得
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン名
        
        Returns:
            インスタンス情報
        """
        zone = zone or self.zone
        client = compute_v1.InstancesClient()
        
        try:
            request = compute_v1.GetInstanceRequest(
                project=self.project_id,
                zone=zone,
                instance=instance_name,
            )
            
            instance = client.get(request=request)
            logger.info("Got instance", name=instance_name)
            
            return {
                'name': instance.name,
                'status': instance.status,
                'machine_type': instance.machine_type.split('/')[-1],
                'zone': zone,
                'created': instance.creation_timestamp,
                'internal_ip': instance.network_interfaces[0].network_i_p if instance.network_interfaces else None,
                'external_ip': (
                    instance.network_interfaces[0].access_configs[0].nat_i_p 
                    if instance.network_interfaces and instance.network_interfaces[0].access_configs 
                    else None
                ),
            }
        except Exception as e:
            logger.error("Failed to get instance", name=instance_name, error=str(e))
            return None
    
    def list_buckets(self) -> List[Dict[str, Any]]:
        """
        Cloud Storage バケット一覧を取得
        
        Returns:
            バケット情報のリスト
        """
        client = storage.Client(project=self.project_id)
        
        buckets = []
        for bucket in client.list_buckets():
            buckets.append({
                'name': bucket.name,
                'location': bucket.location,
                'storage_class': bucket.storage_class,
                'created': bucket.time_created.isoformat() if bucket.time_created else None,
            })
        
        logger.info("Listed buckets", count=len(buckets))
        return buckets
    
    def list_zones(self) -> List[Dict[str, Any]]:
        """
        利用可能なゾーン一覧を取得
        
        Returns:
            ゾーン情報のリスト
        """
        client = compute_v1.ZonesClient()
        
        request = compute_v1.ListZonesRequest(
            project=self.project_id,
        )
        
        zones = []
        for zone in client.list(request=request):
            zones.append({
                'name': zone.name,
                'region': zone.region.split('/')[-1] if zone.region else None,
                'status': zone.status,
            })
        
        logger.info("Listed zones", count=len(zones))
        return zones
    
    # ==================== 要注意な操作（リソース作成・変更） ====================
    
    def start_instance(self, instance_name: str, zone: Optional[str] = None) -> bool:
        """
        VMインスタンスを起動
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン名
        
        Returns:
            成功したかどうか
        """
        zone = zone or self.zone
        client = compute_v1.InstancesClient()
        
        try:
            request = compute_v1.StartInstanceRequest(
                project=self.project_id,
                zone=zone,
                instance=instance_name,
            )
            
            operation = client.start(request=request)
            logger.info("Started instance", name=instance_name, zone=zone)
            return True
        except Exception as e:
            logger.error("Failed to start instance", name=instance_name, error=str(e))
            return False
    
    def stop_instance(self, instance_name: str, zone: Optional[str] = None) -> bool:
        """
        VMインスタンスを停止
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン名
        
        Returns:
            成功したかどうか
        """
        zone = zone or self.zone
        client = compute_v1.InstancesClient()
        
        try:
            request = compute_v1.StopInstanceRequest(
                project=self.project_id,
                zone=zone,
                instance=instance_name,
            )
            
            operation = client.stop(request=request)
            logger.warning("Stopped instance", name=instance_name, zone=zone)
            return True
        except Exception as e:
            logger.error("Failed to stop instance", name=instance_name, error=str(e))
            return False
    
    # ==================== 危険な操作（削除） ====================
    
    def delete_instance(self, instance_name: str, zone: Optional[str] = None, 
                       confirm: bool = False) -> bool:
        """
        VMインスタンスを削除（危険な操作）
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン名
            confirm: 確認フラグ（Trueにしないと実行されない）
        
        Returns:
            成功したかどうか
        """
        if not confirm:
            logger.error("Delete operation requires confirmation", name=instance_name)
            raise ValueError("削除操作には confirm=True が必要です")
        
        zone = zone or self.zone
        client = compute_v1.InstancesClient()
        
        try:
            request = compute_v1.DeleteInstanceRequest(
                project=self.project_id,
                zone=zone,
                instance=instance_name,
            )
            
            operation = client.delete(request=request)
            logger.critical("Deleted instance", name=instance_name, zone=zone)
            return True
        except Exception as e:
            logger.error("Failed to delete instance", name=instance_name, error=str(e))
            return False

