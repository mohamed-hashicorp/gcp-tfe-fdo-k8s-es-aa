locals {
  cluster_name = "${var.prefix}-tfe-cluster"
  # Strip the trailing dot from the Cloud DNS zone dns_name (e.g. "example.com." → "example.com")
  dns_zone_domain = trimsuffix(data.google_dns_managed_zone.tfe.dns_name, ".")
  tfe_hostname    = "${var.tfe_subdomain}.${local.dns_zone_domain}"

  common_labels = {
    managed-by  = "terraform"
    environment = var.environment
    application = "terraform-enterprise"
  }
}
