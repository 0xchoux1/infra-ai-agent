"""
監視ツール
Google Cloud Monitoring を使用してメトリクスを収集・分析
"""

import os
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from google.cloud import monitoring_v3
from google.auth import default
import structlog

logger = structlog.get_logger()


class MonitoringTools:
    """Google Cloud Monitoring 監視ツール"""
    
    def __init__(self, project_id: Optional[str] = None):
        """
        初期化
        
        Args:
            project_id: GCPプロジェクトID（未指定の場合は環境変数から取得）
        """
        self.project_id = project_id or os.getenv('GCP_PROJECT_ID')
        
        if not self.project_id:
            raise ValueError("GCP_PROJECT_ID が設定されていません")
        
        self.project_name = f"projects/{self.project_id}"
        self.credentials, _ = default()
        self.client = monitoring_v3.MetricServiceClient()
        
        logger.info("MonitoringTools initialized", project_id=self.project_id)
    
    def get_cpu_utilization(
        self, 
        instance_name: str, 
        zone: str,
        hours: int = 1
    ) -> List[Dict[str, Any]]:
        """
        VMインスタンスのCPU使用率を取得
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン
            hours: 過去何時間分のデータを取得するか
        
        Returns:
            CPU使用率のデータポイントリスト
        """
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours)
        
        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(end_time.timestamp())},
            "start_time": {"seconds": int(start_time.timestamp())},
        })
        
        # CPU使用率のメトリクスフィルタ
        filter_str = (
            f'resource.type = "gce_instance" '
            f'AND resource.labels.instance_id = "{instance_name}" '
            f'AND resource.labels.zone = "{zone}" '
            f'AND metric.type = "compute.googleapis.com/instance/cpu/utilization"'
        )
        
        request = monitoring_v3.ListTimeSeriesRequest(
            name=self.project_name,
            filter=filter_str,
            interval=interval,
            view=monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        )
        
        results = []
        try:
            for time_series in self.client.list_time_series(request=request):
                for point in time_series.points:
                    results.append({
                        'timestamp': point.interval.end_time.isoformat(),
                        'value': point.value.double_value * 100,  # パーセンテージに変換
                        'unit': '%',
                    })
            
            logger.info(
                "Retrieved CPU metrics", 
                instance=instance_name, 
                points=len(results)
            )
            return results
        except Exception as e:
            logger.error(
                "Failed to get CPU metrics", 
                instance=instance_name, 
                error=str(e)
            )
            return []
    
    def get_memory_utilization(
        self, 
        instance_name: str, 
        zone: str,
        hours: int = 1
    ) -> List[Dict[str, Any]]:
        """
        VMインスタンスのメモリ使用率を取得
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン
            hours: 過去何時間分のデータを取得するか
        
        Returns:
            メモリ使用率のデータポイントリスト
        """
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours)
        
        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(end_time.timestamp())},
            "start_time": {"seconds": int(start_time.timestamp())},
        })
        
        # メモリ使用率のメトリクスフィルタ
        filter_str = (
            f'resource.type = "gce_instance" '
            f'AND resource.labels.instance_id = "{instance_name}" '
            f'AND resource.labels.zone = "{zone}" '
            f'AND metric.type = "compute.googleapis.com/instance/memory/balloon/ram_used"'
        )
        
        request = monitoring_v3.ListTimeSeriesRequest(
            name=self.project_name,
            filter=filter_str,
            interval=interval,
            view=monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        )
        
        results = []
        try:
            for time_series in self.client.list_time_series(request=request):
                for point in time_series.points:
                    results.append({
                        'timestamp': point.interval.end_time.isoformat(),
                        'value': point.value.int64_value,
                        'unit': 'bytes',
                    })
            
            logger.info(
                "Retrieved memory metrics", 
                instance=instance_name, 
                points=len(results)
            )
            return results
        except Exception as e:
            logger.error(
                "Failed to get memory metrics", 
                instance=instance_name, 
                error=str(e)
            )
            return []
    
    def get_disk_io(
        self, 
        instance_name: str, 
        zone: str,
        hours: int = 1
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        VMインスタンスのディスクI/Oを取得
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン
            hours: 過去何時間分のデータを取得するか
        
        Returns:
            ディスクI/Oのデータ（read/write）
        """
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours)
        
        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(end_time.timestamp())},
            "start_time": {"seconds": int(start_time.timestamp())},
        })
        
        results = {
            'read': [],
            'write': [],
        }
        
        # 読み取りバイト数
        read_filter = (
            f'resource.type = "gce_instance" '
            f'AND resource.labels.instance_id = "{instance_name}" '
            f'AND metric.type = "compute.googleapis.com/instance/disk/read_bytes_count"'
        )
        
        # 書き込みバイト数
        write_filter = (
            f'resource.type = "gce_instance" '
            f'AND resource.labels.instance_id = "{instance_name}" '
            f'AND metric.type = "compute.googleapis.com/instance/disk/write_bytes_count"'
        )
        
        try:
            # 読み取り
            request = monitoring_v3.ListTimeSeriesRequest(
                name=self.project_name,
                filter=read_filter,
                interval=interval,
            )
            
            for time_series in self.client.list_time_series(request=request):
                for point in time_series.points:
                    results['read'].append({
                        'timestamp': point.interval.end_time.isoformat(),
                        'value': point.value.int64_value,
                        'unit': 'bytes',
                    })
            
            # 書き込み
            request = monitoring_v3.ListTimeSeriesRequest(
                name=self.project_name,
                filter=write_filter,
                interval=interval,
            )
            
            for time_series in self.client.list_time_series(request=request):
                for point in time_series.points:
                    results['write'].append({
                        'timestamp': point.interval.end_time.isoformat(),
                        'value': point.value.int64_value,
                        'unit': 'bytes',
                    })
            
            logger.info(
                "Retrieved disk I/O metrics", 
                instance=instance_name,
                read_points=len(results['read']),
                write_points=len(results['write'])
            )
            return results
        except Exception as e:
            logger.error(
                "Failed to get disk I/O metrics", 
                instance=instance_name, 
                error=str(e)
            )
            return results
    
    def detect_anomalies(
        self, 
        metrics: List[Dict[str, Any]], 
        threshold: float
    ) -> List[Dict[str, Any]]:
        """
        メトリクスから異常値を検出
        
        Args:
            metrics: メトリクスデータ
            threshold: しきい値
        
        Returns:
            異常が検出されたデータポイント
        """
        anomalies = []
        
        for point in metrics:
            if point.get('value', 0) > threshold:
                anomalies.append({
                    'timestamp': point['timestamp'],
                    'value': point['value'],
                    'threshold': threshold,
                    'severity': 'high' if point['value'] > threshold * 1.5 else 'medium',
                })
        
        if anomalies:
            logger.warning(
                "Anomalies detected", 
                count=len(anomalies), 
                threshold=threshold
            )
        
        return anomalies
    
    def get_summary(
        self, 
        instance_name: str, 
        zone: str,
        hours: int = 1
    ) -> Dict[str, Any]:
        """
        インスタンスのメトリクスサマリーを取得
        
        Args:
            instance_name: インスタンス名
            zone: ゾーン
            hours: 過去何時間分のデータを取得するか
        
        Returns:
            メトリクスサマリー
        """
        cpu_metrics = self.get_cpu_utilization(instance_name, zone, hours)
        memory_metrics = self.get_memory_utilization(instance_name, zone, hours)
        disk_io = self.get_disk_io(instance_name, zone, hours)
        
        summary = {
            'instance': instance_name,
            'zone': zone,
            'period_hours': hours,
            'cpu': {
                'data_points': len(cpu_metrics),
                'avg': sum(m['value'] for m in cpu_metrics) / len(cpu_metrics) if cpu_metrics else 0,
                'max': max((m['value'] for m in cpu_metrics), default=0),
                'min': min((m['value'] for m in cpu_metrics), default=0),
            },
            'memory': {
                'data_points': len(memory_metrics),
            },
            'disk_io': {
                'read_points': len(disk_io['read']),
                'write_points': len(disk_io['write']),
            },
        }
        
        logger.info("Generated metrics summary", instance=instance_name)
        return summary

