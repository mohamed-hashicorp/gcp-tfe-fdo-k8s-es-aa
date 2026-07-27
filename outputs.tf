output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.tfe.name
}

output "cluster_endpoint" {
  description = "HTTPS endpoint of the GKE cluster API server."
  value       = "https://${google_container_cluster.tfe.endpoint}"
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the GKE cluster."
  value       = google_container_cluster.tfe.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "tfe_hostname" {
  description = "Fully-qualified domain name where TFE is reachable."
  value       = local.tfe_hostname
}

output "tfe_url" {
  description = "HTTPS URL for Terraform Enterprise."
  value       = "https://${local.tfe_hostname}"
}

output "tfe_namespace" {
  description = "Kubernetes namespace where TFE is deployed."
  value       = kubernetes_namespace_v1.tfe.metadata[0].name
}

output "dns_zone_name_servers" {
  description = "Name servers for the existing Cloud DNS managed zone."
  value       = data.google_dns_managed_zone.tfe.name_servers
}

output "db_private_ip" {
  description = "Private IP address of the Cloud SQL PostgreSQL instance."
  value       = google_sql_database_instance.tfe.private_ip_address
}

output "db_connection_name" {
  description = "Cloud SQL connection name (project:region:instance) for Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.tfe.connection_name
}

output "redis_host" {
  description = "IP address of the Memorystore Redis instance."
  value       = google_redis_instance.tfe.host
}

output "redis_port" {
  description = "Port of the Memorystore Redis instance."
  value       = google_redis_instance.tfe.port
}

output "tfe_gcs_bucket" {
  description = "Name of the GCS bucket used for TFE object storage."
  value       = google_storage_bucket.tfe.name
}

output "acme_certificate_expiry" {
  description = "Expiry date of the ACME-issued TLS certificate."
  value       = acme_certificate.tfe.certificate_not_after
}
