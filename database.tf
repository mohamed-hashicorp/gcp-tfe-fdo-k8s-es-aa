# ---------------------------------------------------------------------------
# Cloud SQL (PostgreSQL) for TFE
# ---------------------------------------------------------------------------

# Private IP range for Cloud SQL VPC peering
resource "google_compute_global_address" "sql_private_ip" {
  name          = "${var.prefix}-tfe-sql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.tfe.id
}

resource "google_service_networking_connection" "sql_vpc_peering" {
  network                 = google_compute_network.tfe.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_private_ip.name]
  deletion_policy         = "ABANDON"

  depends_on = [
    google_compute_network.tfe,
    google_project_service.apis,
  ]
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "tfe" {
  name                = "${var.prefix}-tfe-db"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = false

  settings {
    tier              = var.db_tier
    edition           = "ENTERPRISE"
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.db_disk_size_gb
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.tfe.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
    }

    location_preference {
      zone = var.zone
    }

    user_labels = local.common_labels
  }

  depends_on = [google_service_networking_connection.sql_vpc_peering]
}

# TFE database
resource "google_sql_database" "tfe" {
  name     = var.tfe_database_name
  instance = google_sql_database_instance.tfe.name
}

# TFE database user
resource "google_sql_user" "tfe" {
  name     = var.tfe_database_user
  instance = google_sql_database_instance.tfe.name
  password = var.tfe_database_password
}
