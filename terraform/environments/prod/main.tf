# Network Module
module "network" {
  source = "../../modules/network"

  env              = var.env
  project_id       = var.project_id
  region           = var.region
  web_subnet_cidr  = "10.0.1.0/24"
  mgmt_subnet_cidr = "10.0.2.0/24"
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  env        = var.env
  project_id = var.project_id
}

# Filestore Module
module "filestore" {
  source = "../../modules/filestore"

  env         = var.env
  zone        = var.zone
  tier        = var.filestore_tier
  capacity_gb = var.filestore_capacity_gb
  network_id  = module.network.vpc_name  # ネットワーク名のみ（prod-wordpress-vpc）

  depends_on = [module.network]
}

# Database Module
module "database" {
  source = "../../modules/database"

  env               = var.env
  region            = var.region
  tier              = var.db_tier
  availability_type = var.db_availability_type
  network_id        = module.network.vpc_id
  domains           = var.domains

  depends_on = [module.network]
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  env                   = var.env
  project_id            = var.project_id
  region                = var.region
  machine_type          = var.machine_type
  network               = module.network.vpc_name
  subnetwork            = module.network.web_subnet_name
  service_account_email = module.iam.web_server_service_account_email
  db_host               = module.database.private_ip_address
  wazuh_manager_ip      = "" # Phase 2で実装
  nfs_ip                = module.filestore.nfs_ip
  nfs_path              = module.filestore.nfs_path
  domains               = var.domains
  min_replicas          = var.min_replicas
  max_replicas          = var.max_replicas

  depends_on = [module.database, module.filestore, module.iam]
}

# Load Balancer Module
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  env             = var.env
  health_check_id = module.compute.health_check_id
  instance_group  = module.compute.instance_group
  domains         = var.domains

  depends_on = [module.compute]
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  env = var.env

  depends_on = [module.loadbalancer]
}

