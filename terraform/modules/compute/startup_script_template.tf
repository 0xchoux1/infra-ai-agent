# 起動スクリプトのテンプレート処理
data "template_file" "startup_script" {
  template = file("${path.module}/../../scripts/startup_script.sh")

  vars = {
    env           = var.env
    db_host       = var.db_host
    wazuh_manager = var.wazuh_manager_ip
    project_id    = var.project_id
    nfs_ip        = var.nfs_ip
    nfs_path      = var.nfs_path
    domains_json  = jsonencode(var.domains)
  }
}

