# ---------------------------------------------------------------------------
# ACME TLS Certificate for TFE
# ---------------------------------------------------------------------------

# Private key for the ACME account registration
resource "tls_private_key" "acme_account" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ACME account registration
resource "acme_registration" "tfe" {
  account_key_pem = tls_private_key.acme_account.private_key_pem
  email_address   = var.acme_email
}

# Private key for the TFE certificate
resource "tls_private_key" "tfe_cert" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Certificate Signing Request
resource "tls_cert_request" "tfe" {
  private_key_pem = tls_private_key.tfe_cert.private_key_pem

  subject {
    common_name  = local.tfe_hostname
    organization = var.cert_organization
  }

  dns_names = [local.tfe_hostname]
}

# ---------------------------------------------------------------------------
# Look up the existing Cloud DNS managed zone
# ---------------------------------------------------------------------------
data "google_dns_managed_zone" "tfe" {
  name = var.dns_zone_name
}

# ACME certificate (DNS-01 challenge via Google Cloud DNS)
resource "acme_certificate" "tfe" {
  account_key_pem         = acme_registration.tfe.account_key_pem
  certificate_request_pem = tls_cert_request.tfe.cert_request_pem

  dns_challenge {
    provider = "gcloud"

    config = {
      GCE_PROJECT = var.project_id
      # Authentication uses Application Default Credentials (gcloud auth application-default login)
      # No service-account key file needed when running with ADC or Workload Identity
    }
  }
}

# ---------------------------------------------------------------------------
# Read the LoadBalancer service created by the Helm chart to get its external IP
# ---------------------------------------------------------------------------
data "kubernetes_service_v1" "tfe_lb" {
  metadata {
    name      = "terraform-enterprise"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }

  depends_on = [helm_release.tfe]
}

# ---------------------------------------------------------------------------
# DNS A record pointing to the TFE load-balancer IP
# ---------------------------------------------------------------------------
resource "google_dns_record_set" "tfe" {
  name         = "${local.tfe_hostname}."
  managed_zone = data.google_dns_managed_zone.tfe.name
  type         = "A"
  ttl          = 300
  rrdatas      = [data.kubernetes_service_v1.tfe_lb.status[0].load_balancer[0].ingress[0].ip]

  depends_on = [helm_release.tfe]
}
