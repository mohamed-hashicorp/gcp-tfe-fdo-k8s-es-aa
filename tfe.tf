# ---------------------------------------------------------------------------
# TFE Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "tfe" {
  metadata {
    name = var.tfe_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [google_container_node_pool.tfe]
}

# ---------------------------------------------------------------------------
# Image pull secret
# Registry: images.releases.hashicorp.com
# Username: terraform (literal)
# Password: TFE license key
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "tfe_image_pull" {
  metadata {
    name      = "terraform-enterprise"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "images.releases.hashicorp.com" = {
          username = "terraform"
          password = var.tfe_license
          auth     = base64encode("terraform:${var.tfe_license}")
        }
      }
    })
  }
}

# ---------------------------------------------------------------------------
# TLS secret — cert and key from ACME
# The chart mounts these as cert.pem and key.pem
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "tfe_tls" {
  metadata {
    name      = "tfe-tls"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    # Chart reads tls.crt / tls.key via the certificateSecret reference
    "tls.crt" = "${acme_certificate.tfe.certificate_pem}${acme_certificate.tfe.issuer_pem}"
    "tls.key" = tls_private_key.tfe_cert.private_key_pem
  }
}

# ---------------------------------------------------------------------------
# Secrets — all sensitive env vars in one Kubernetes Secret
# Referenced in the chart via env.secretRefs[0].name
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "tfe_env" {
  metadata {
    name      = "tfe-env-secrets"
    namespace = kubernetes_namespace_v1.tfe.metadata[0].name
  }

  data = {
    TFE_LICENSE             = var.tfe_license
    TFE_ENCRYPTION_PASSWORD = var.tfe_encryption_password
    TFE_DATABASE_PASSWORD   = var.tfe_database_password
  }
}

# ---------------------------------------------------------------------------
# TFE Helm release
# ---------------------------------------------------------------------------
resource "helm_release" "tfe" {
  name             = "terraform-enterprise"
  namespace        = kubernetes_namespace_v1.tfe.metadata[0].name
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "terraform-enterprise"
  version          = var.tfe_chart_version
  create_namespace = false
  timeout          = 1200
  wait             = true
  cleanup_on_fail  = true

  set = [
    # --- Image ---
    {
      name  = "image.repository"
      value = "images.releases.hashicorp.com"
    },
    {
      name  = "image.name"
      value = "hashicorp/terraform-enterprise"
    },
    {
      name  = "image.tag"
      value = var.tfe_image_tag
    },
    {
      name  = "imagePullSecrets[0].name"
      value = kubernetes_secret_v1.tfe_image_pull.metadata[0].name
    },
    # --- TLS ---
    {
      name  = "tls.certificateSecret"
      value = kubernetes_secret_v1.tfe_tls.metadata[0].name
    },
    # --- Env secrets reference ---
    {
      name  = "env.secretRefs[0].name"
      value = kubernetes_secret_v1.tfe_env.metadata[0].name
    },
    # --- Hostname ---
    {
      name  = "env.variables.TFE_HOSTNAME"
      value = local.tfe_hostname
    },
    # --- Operational mode ---
    {
      name  = "env.variables.TFE_OPERATIONAL_MODE"
      value = "active-active"
    },
    # --- Database ---
    {
      name  = "env.variables.TFE_DATABASE_HOST"
      value = google_sql_database_instance.tfe.private_ip_address
    },
    {
      name  = "env.variables.TFE_DATABASE_NAME"
      value = var.tfe_database_name
    },
    {
      name  = "env.variables.TFE_DATABASE_USER"
      value = var.tfe_database_user
    },
    {
      name  = "env.variables.TFE_DATABASE_PARAMETERS"
      value = "sslmode=require"
    },
    # --- Object Storage (GCS) ---
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_TYPE"
      value = "google"
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_GOOGLE_BUCKET"
      value = google_storage_bucket.tfe.name
    },
    {
      name  = "env.variables.TFE_OBJECT_STORAGE_GOOGLE_PROJECT"
      value = var.project_id
    },
    # --- Redis (no auth, no TLS) ---
    {
      name  = "env.variables.TFE_REDIS_HOST"
      value = "${google_redis_instance.tfe.host}:${google_redis_instance.tfe.port}"
    },
    {
      name  = "env.variables.TFE_REDIS_USE_AUTH"
      value = "false"
    },
    {
      name  = "env.variables.TFE_REDIS_USE_TLS"
      value = "false"
    },
  ]

  depends_on = [
    kubernetes_secret_v1.tfe_tls,
    kubernetes_secret_v1.tfe_image_pull,
    kubernetes_secret_v1.tfe_env,
    acme_certificate.tfe,
    google_redis_instance.tfe,
    google_sql_database_instance.tfe,
    google_sql_user.tfe,
  ]
}

# ---------------------------------------------------------------------------
# GCS Bucket for TFE object storage
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "tfe" {
  name                        = "${var.prefix}-tfe-objects-${var.project_id}"
  location                    = var.region
  storage_class               = "REGIONAL"
  force_destroy               = false
  uniform_bucket_level_access = true
  labels                      = local.common_labels

  versioning {
    enabled = true
  }
}
