output "nfs_ip" {
  description = "NFS server IP address"
  value       = google_filestore_instance.wordpress.networks[0].ip_addresses[0]
}

output "nfs_path" {
  description = "NFS export path"
  value       = "/${google_filestore_instance.wordpress.file_shares[0].name}"
}

output "mount_command" {
  description = "NFS mount command"
  value       = "mount -t nfs ${google_filestore_instance.wordpress.networks[0].ip_addresses[0]}:/${google_filestore_instance.wordpress.file_shares[0].name} /mnt/wordpress"
}

output "filestore_instance_id" {
  description = "Filestore instance ID"
  value       = google_filestore_instance.wordpress.id
}

