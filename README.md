# Terraform Enterprise FDO Deployment on GCP using Kubernetes and External Services Mode

This repository provides an automated way to deploy Terraform Enterprise (TFE) on Google Cloud Platform using:
- FDO (Flexible Deployment Options)
- Kubernetes (GKE — Google Kubernetes Engine)
- External services mode
- Terraform-based infrastructure automation
- ACME / Let's Encrypt to automatically issue and renew TLS certificates via DNS-01 challenge against an existing Google Cloud DNS zone

This project automates the entire process, providing a repeatable, consistent, and reliable way to deploy TFE in minutes using Terraform.

## Architecture

```
GCP Project
├── VPC + Subnet (private GKE nodes, Cloud SQL peering)
│   └── Cloud Router + Cloud NAT (outbound internet for image pulls)
├── GKE Cluster (n2-standard-8, STANDARD_HA, private nodes)
│   └── Helm Release: terraform-enterprise
│       ├── Image pull secret  (images.releases.hashicorp.com)
│       ├── TLS secret         (ACME-issued cert)
│       └── Env secrets        (license, encryption password, DB password)
├── Cloud SQL PostgreSQL 16 (REGIONAL HA, private IP, SSL enforced)
├── Memorystore Redis 7.2    (STANDARD_HA, private IP, no auth)
├── GCS Bucket               (TFE object storage)
└── Cloud DNS A record       (tfe.<your-zone>)
    └── ACME DNS-01 challenge (Let's Encrypt)
```

## Prerequisites

This guide was executed on macOS so it assumes the following:
- You have Git installed
- GCP credentials are configured (`gcloud auth login && gcloud auth application-default login`)
- Terraform is installed (tested with Terraform 1.9+)
- Helm is installed (`brew install helm`)
- kubectl is installed (`brew install kubectl`)
- A GCP project with billing enabled
- An existing Google Cloud DNS managed zone in your project
- A TFE license key (from your HashiCorp account portal)

## Clone the Repository

- Clone the GitHub repo
```
git clone git@github.com-work:mohamed-hashicorp/gcp-tfe-fdo-k8s-es-aa.git
```
- Change the directory
```
cd gcp-tfe-fdo-k8s-es-aa
```

## Configure Your Variables

- Rename the `terraform.tfvars.example`
```
cp terraform.tfvars.example terraform.tfvars
```
- Edit `terraform.tfvars` and fill in your values:
```hcl
# Project & Region
project_id  = "my-gcp-project-id"
region      = "europe-west1"
zone        = "europe-west1-b"
prefix      = "tfe"
environment = "prod"

# GKE Cluster
node_machine_type      = "n2-standard-8"
node_disk_size_gb      = 100
node_count             = 1
node_min_count         = 1
node_max_count         = 3
subnet_cidr            = "10.10.0.0/20"
pods_cidr              = "10.20.0.0/16"
services_cidr          = "10.30.0.0/20"
master_ipv4_cidr_block = "172.16.0.0/28"

# DNS — name of your existing Cloud DNS managed zone
# Run: gcloud dns managed-zones list --project=<project>
dns_zone_name = "my-dns-zone"
tfe_subdomain = "tfe"        # results in tfe.<zone-dns-name>

# ACME / TLS
# Use staging URL for testing to avoid Let's Encrypt rate limits:
#   https://acme-staging-v02.api.letsencrypt.org/directory
# Switch to production when ready:
#   https://acme-v02.api.letsencrypt.org/directory
acme_server_url   = "https://acme-v02.api.letsencrypt.org/directory"
acme_email        = "you@example.com"
cert_organization = "My Company"

# Terraform Enterprise
tfe_namespace           = "terraform-enterprise"
tfe_chart_version       = "1.6.8"
tfe_image_tag           = "v202501-1"
tfe_encryption_password = "MyStrongEncryptionPassword#123"

# tfe_license — paste your license string:
tfe_license = "02MV4UU43BK5H..."

# Cloud SQL (PostgreSQL)
db_tier               = "db-custom-2-7680"
db_disk_size_gb       = 50
tfe_database_name     = "tfe"
tfe_database_user     = "tfe"
tfe_database_password = "MyStrongDbPassword#123"

# Redis (Memorystore) — no password required
redis_memory_size_gb = 1
redis_alt_zone       = "europe-west1-c"
```

> **Note:** `terraform.tfvars` is excluded from version control by `.gitignore` because it contains sensitive values. Never commit it.

## Create Infrastructure

- Authenticate with GCP (Application Default Credentials are required for the ACME DNS-01 challenge)
```
gcloud auth login
gcloud auth application-default login
```

- Add the HashiCorp Helm repository
```
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

- Run Terraform init
```
terraform init
```

- Run Terraform plan to preview changes
```
terraform plan
```

- Run Terraform apply
```
terraform apply
```

- Type `yes` when prompted:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

The deployment provisions infrastructure in this order:
1. GCP APIs enabled
2. VPC, subnet, Cloud Router + NAT
3. GKE cluster + node pool
4. Cloud SQL PostgreSQL instance
5. Memorystore Redis instance
6. ACME TLS certificate (DNS-01 challenge)
7. Kubernetes secrets + Helm release
8. Cloud DNS A record

> **Note:** First-time provisioning takes approximately 15–20 minutes.

## Outputs

After a successful `terraform apply`, you will see:
```
tfe_url                = "https://tfe.<your-zone-domain>"
tfe_hostname           = "tfe.<your-zone-domain>"
tfe_namespace          = "terraform-enterprise"
cluster_name           = "tfe-tfe-cluster"
db_private_ip          = "10.x.x.x"
db_connection_name     = "<project>:<region>:<instance>"
redis_host             = "10.x.x.x"
redis_port             = 6379
tfe_gcs_bucket         = "tfe-tfe-objects-<project-id>"
acme_certificate_expiry = "2026-..."
```

## Verify

- Check that TFE installation is accessible from your browser
- Open the URL printed in `tfe_url`, for example:
```
https://tfe.hc-xxxx.gcp.sbx.hashicorpdemo.com
```
- Log in with your admin user
- Click on `Create organization`
- Set the organization name and click on `Create organization`
- In the organization page, select `CLI-Driven Workflow`
- Set the workspace name and click on `Create`
- Open a terminal and log in to TFE:
```
terraform login tfe.<your-zone-domain>
```
- You will be redirected to a webpage — click on `Generate token`
- Copy the token, paste it in the terminal and press enter:
```
Token for tfe.<your-zone-domain>:
  Enter a value:
Retrieved token for user admin
---------------------------------------------------------------------------------
Success! Logged in to Terraform Enterprise (tfe.<your-zone-domain>)
```
- Create a test directory
```
mkdir ~/tfe-test && cd ~/tfe-test
```
- Create a `main.tf` with the following content:
```hcl
terraform {
  cloud {
    hostname     = "tfe.<your-zone-domain>"
    organization = "my-organization"
    workspaces {
      name = "my-workspace"
    }
  }
}

resource "null_resource" "test" {}
```
- Run terraform init and apply:
```
$ terraform init
Initializing HCP Terraform...
Initializing provider plugins...
- Finding latest version of hashicorp/null...
- Installing hashicorp/null v3.2.4...
- Installed hashicorp/null v3.2.4 (signed by HashiCorp)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.
HCP Terraform has been successfully initialized!

$ terraform apply -auto-approve
Running apply in Terraform Enterprise. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.

Terraform v1.9.x
on linux_amd64
Initializing plugins and modules...

Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:
  # null_resource.test will be created
  + resource "null_resource" "test" {
      + id = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
null_resource.test: Creating...
null_resource.test: Creation complete after 0s [id=1234567890]
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```
- Check the status of the run from the TFE UI

## Upgrading TFE

To upgrade to a newer TFE version, update `tfe_chart_version` and `tfe_image_tag` in `terraform.tfvars`:
```hcl
tfe_chart_version = "1.6.8"   # helm search repo hashicorp/terraform-enterprise
tfe_image_tag     = "v202502-1"
```

Then run:
```
terraform apply
```

The Helm release is configured with `cleanup_on_fail = true` and a 20-minute timeout, so a failed upgrade will automatically roll back to the previous working release.

## Delete Infrastructure

- When done, remove all resources with:
```
terraform destroy
```
- Type `yes` when prompted:
```
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
```

> **Note:** Cloud SQL instance names are reserved by GCP for up to **7 days** after deletion. If you redeploy immediately and get an `instance name already exists` error, either wait or change the `prefix` variable in `terraform.tfvars`.
