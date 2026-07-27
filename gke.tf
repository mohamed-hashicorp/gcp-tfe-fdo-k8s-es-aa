# ---------------------------------------------------------------------------
# GKE Cluster
# ---------------------------------------------------------------------------
resource "google_container_cluster" "tfe" {
  name                = local.cluster_name
  location            = var.region
  deletion_protection = false

  # We manage the node pool separately for better control
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.tfe.name
  subnetwork = google_compute_subnetwork.tfe.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  resource_labels = local.common_labels
}

# ---------------------------------------------------------------------------
# Node Pool
# ---------------------------------------------------------------------------
resource "google_container_node_pool" "tfe" {
  name       = "${local.cluster_name}-node-pool"
  cluster    = google_container_cluster.tfe.name
  location   = var.region
  node_count = var.node_count

  autoscaling {
    min_node_count = var.node_min_count
    max_node_count = var.node_max_count
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = "pd-ssd"
    service_account = google_service_account.gke_node.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = local.common_labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ---------------------------------------------------------------------------
# Cloud Router + NAT — required for private nodes to pull images from internet
# ---------------------------------------------------------------------------
resource "google_compute_router" "tfe" {
  name    = "${var.prefix}-tfe-router"
  region  = var.region
  network = google_compute_network.tfe.id
}

resource "google_compute_router_nat" "tfe" {
  name                               = "${var.prefix}-tfe-nat"
  router                             = google_compute_router.tfe.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---------------------------------------------------------------------------
# VPC Network
# ---------------------------------------------------------------------------
resource "google_compute_network" "tfe" {
  name                    = "${var.prefix}-tfe-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "tfe" {
  name          = "${var.prefix}-tfe-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.tfe.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# ---------------------------------------------------------------------------
# Service Account for GKE nodes
# ---------------------------------------------------------------------------
resource "google_service_account" "gke_node" {
  account_id   = "${var.prefix}-gke-node-sa"
  display_name = "GKE Node Service Account for TFE"
}

resource "google_project_iam_member" "gke_node_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}
