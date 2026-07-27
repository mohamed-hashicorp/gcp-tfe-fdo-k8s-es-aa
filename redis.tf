# ---------------------------------------------------------------------------
# Cloud Memorystore (Redis) for TFE
# ---------------------------------------------------------------------------
resource "google_redis_instance" "tfe" {
  name           = "${var.prefix}-tfe-redis"
  display_name   = "TFE Redis Cache"
  tier           = "STANDARD_HA"
  memory_size_gb = var.redis_memory_size_gb
  region         = var.region

  location_id             = var.zone
  alternative_location_id = var.redis_alt_zone

  authorized_network = google_compute_network.tfe.id
  connect_mode       = "DIRECT_PEERING"

  redis_version       = "REDIS_7_2"
  auth_enabled        = false
  deletion_protection = false

  labels = local.common_labels

  depends_on = [
    google_compute_network.tfe,
    google_project_service.apis,
  ]
}
