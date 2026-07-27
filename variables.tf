# ---------------------------------------------------------------------------
# Project & Region
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "The ID of the GCP project in which to create resources."
  type        = string
}

variable "region" {
  description = "The GCP region in which to create resources."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "The GCP zone for zonal resources."
  type        = string
  default     = "europe-west1-b"
}

variable "prefix" {
  description = "Prefix used for naming all resources, allowing multiple deployments in the same project."
  type        = string
  default     = "tfe"
}

variable "environment" {
  description = "Deployment environment label (e.g. prod, staging, dev)."
  type        = string
  default     = "prod"
}

# ---------------------------------------------------------------------------
# GKE Cluster
# ---------------------------------------------------------------------------

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE subnetwork."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE control-plane private endpoint."
  type        = string
  default     = "172.16.0.0/28"
}

variable "node_machine_type" {
  description = "Machine type for GKE worker nodes."
  type        = string
  default     = "n2-standard-4"
}

variable "node_disk_size_gb" {
  description = "Boot disk size in GB for each GKE node."
  type        = number
  default     = 100
}

variable "node_count" {
  description = "Initial number of nodes per zone in the node pool."
  type        = number
  default     = 1
}

variable "node_min_count" {
  description = "Minimum number of nodes per zone (for autoscaling)."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of nodes per zone (for autoscaling)."
  type        = number
  default     = 3
}

# ---------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------

variable "dns_zone_name" {
  description = "The Cloud DNS managed zone resource name of the existing zone (e.g. doormat-accountid)."
  type        = string
}

variable "tfe_subdomain" {
  description = "Subdomain for TFE (e.g. 'tfe' gives tfe.example.com)."
  type        = string
  default     = "tfe"
}

# ---------------------------------------------------------------------------
# ACME / TLS
# ---------------------------------------------------------------------------

variable "acme_server_url" {
  description = "ACME directory URL. Use Let's Encrypt production or staging URL."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "acme_email" {
  description = "Email address used for ACME account registration and certificate notifications."
  type        = string
}

variable "cert_organization" {
  description = "Organization name embedded in the TLS certificate's Subject field."
  type        = string
  default     = "HashiCorp"
}

# ---------------------------------------------------------------------------
# Terraform Enterprise
# ---------------------------------------------------------------------------

variable "tfe_namespace" {
  description = "Kubernetes namespace where TFE will be deployed."
  type        = string
  default     = "terraform-enterprise"
}

variable "tfe_chart_version" {
  description = "Version of the terraform-enterprise Helm chart."
  type        = string
}

variable "tfe_image_tag" {
  description = "Container image tag (version) for TFE."
  type        = string
}

variable "tfe_license" {
  description = "HashiCorp TFE license key (Replicated or FlexLicense format)."
  type        = string
  sensitive   = true
}

variable "tfe_encryption_password" {
  description = "Encryption password used by TFE to protect sensitive data at rest."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Cloud SQL (PostgreSQL)
# ---------------------------------------------------------------------------

variable "db_tier" {
  description = "Cloud SQL machine tier. Must be a shared-core or db-custom-* type under ENTERPRISE edition."
  type        = string
  default     = "db-custom-2-7680"
}

variable "db_disk_size_gb" {
  description = "Initial disk size in GB for the Cloud SQL instance."
  type        = number
  default     = 50
}

variable "tfe_database_name" {
  description = "Name of the PostgreSQL database to create for TFE."
  type        = string
  default     = "tfe"
}

variable "tfe_database_user" {
  description = "PostgreSQL username to create for TFE."
  type        = string
  default     = "tfe"
}

variable "tfe_database_password" {
  description = "PostgreSQL password for the TFE database user."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Redis (Memorystore)
# ---------------------------------------------------------------------------

variable "redis_memory_size_gb" {
  description = "Memory size in GiB for the Memorystore Redis instance."
  type        = number
  default     = 1
}

variable "redis_alt_zone" {
  description = "Alternative zone for the STANDARD_HA Redis replica (must differ from var.zone)."
  type        = string
  default     = "europe-west1-c"
}
