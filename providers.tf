provider "google" {
  project = var.project_id
  region  = var.region
}

# GKE auth data source – used to configure Kubernetes & Helm providers post-cluster creation
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.tfe.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.tfe.master_auth[0].cluster_ca_certificate)
}

# Helm provider v3 uses attribute-style kubernetes configuration
provider "helm" {
  kubernetes = {
    host                   = "https://${google_container_cluster.tfe.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.tfe.master_auth[0].cluster_ca_certificate)
  }
}

provider "acme" {
  server_url = var.acme_server_url
}
