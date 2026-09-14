# Workload Identity Federation: lets the GitHub Actions deploy workflow
# authenticate to GCP without a long-lived service account key. The flow is:
#
#   1. GitHub Actions exchanges its OIDC token at the WIF provider below.
#   2. GCP returns a short-lived token that impersonates the deploy SA.
#   3. Terraform runs apply against this project as that SA.
#
# Outputs (deploy_sa_email + wif_provider) are surfaced through outputs.tf
# so they can be copied into GitHub secrets after a fresh bootstrap.

resource "google_service_account" "deploy" {
  project      = google_project.this.project_id
  account_id   = "shiori-deploy"
  display_name = "Shiori GitHub Actions deploy"
}

# Project-scoped owner: the deploy workflow runs `terraform apply`, which
# touches every resource in this project (project services, IAM, Cloud Run,
# Functions, Firestore, Secret Manager, GCS, org policy). Owner is the
# simplest contract that survives future resource additions; the impact is
# bounded because the binding is on a single project, not the org.
resource "google_project_iam_member" "deploy_owner" {
  project = google_project.this.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.this.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "OIDC federation for GitHub-hosted runners"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.this.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Mandatory since 2023: scope the provider to a single repository so that
  # a leaked workflow on another repo cannot impersonate the deploy SA.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "deploy_wif_user" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
