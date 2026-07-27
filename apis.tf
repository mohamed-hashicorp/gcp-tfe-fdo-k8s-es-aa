# ---------------------------------------------------------------------------
# Required GCP APIs
# All APIs the deployment depends on, enabled before any other resource runs.
# ---------------------------------------------------------------------------

locals {
  required_apis = [
    "container.googleapis.com",            # GKE
    "servicenetworking.googleapis.com",    # Cloud SQL private IP / VPC peering
    "sqladmin.googleapis.com",             # Cloud SQL
    "redis.googleapis.com",                # Memorystore Redis
    "dns.googleapis.com",                  # Cloud DNS
    "storage.googleapis.com",              # Cloud Storage (GCS)
    "compute.googleapis.com",              # VPC, subnets, global addresses
    "iam.googleapis.com",                  # Service accounts
    "cloudresourcemanager.googleapis.com", # Project metadata lookups
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
