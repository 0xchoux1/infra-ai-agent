output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.wordpress.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.wordpress.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.wordpress.private_ip_address
}

output "database_names" {
  description = "List of created database names"
  value       = google_sql_database.wordpress_sites[*].name
}

output "database_users" {
  description = "List of created database users"
  value       = google_sql_user.wordpress_users[*].name
}

output "secret_ids" {
  description = "List of Secret Manager secret IDs for database passwords"
  value       = google_secret_manager_secret.db_passwords[*].secret_id
}

