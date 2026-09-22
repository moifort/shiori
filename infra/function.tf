resource "google_service_account" "function" {
  project      = google_project.this.project_id
  account_id   = "shiori-runtime"
  display_name = "Shiori runtime"
}

resource "google_project_iam_member" "function_firestore" {
  project = google_project.this.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.function.email}"
}

# The admin metrics read actual GCP spend from the billing export dataset in
# BigQuery: the function needs to run a query job and read that dataset. The
# project holds no other BigQuery data, so project-scoped viewer is as narrow
# as it is useful.
resource "google_project_iam_member" "function_bigquery_job_user" {
  project = google_project.this.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.function.email}"
}

resource "google_project_iam_member" "function_bigquery_data_viewer" {
  project = google_project.this.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.function.email}"
}

# Cloud Functions Gen 2 builds run in Cloud Build under the default Compute
# service account. In a fresh project that role binding is not granted by
# default, so the first deploy fails with "missing permission on the build
# service account". We bind it explicitly to make bootstrap deterministic.
data "google_compute_default_service_account" "default" {
  project    = google_project.this.project_id
  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "compute_default_builder" {
  project = google_project.this.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_secret_manager_secret_iam_member" "function" {
  for_each  = google_secret_manager_secret.this
  project   = google_project.this.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function.email}"
}

resource "google_storage_bucket" "source" {
  project                     = google_project.this.project_id
  name                        = "${google_project.this.project_id}-fn-source"
  location                    = local.bucket_location
  force_destroy               = true
  uniform_bucket_level_access = true

  depends_on = [google_project_service.apis]
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.root}/../.output/server"
  output_path = "${path.root}/../.output/server-source.zip"
}

resource "google_storage_bucket_object" "source" {
  name   = "source-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.source.output_path
}

resource "google_cloudfunctions2_function" "server" {
  provider = google-beta
  project  = google_project.this.project_id
  name     = "shiori-server"
  location = var.region

  build_config {
    runtime     = "nodejs22"
    entry_point = "server"

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    available_memory = "512M"
    # A cold scan was measured at 55s end to end; the 60s Vinarium inherited
    # 504s the request after the models have already been paid for. Mirrors
    # `timeoutSeconds` in nitro.config.ts, which Terraform does not read, and
    # the app waits this long plus a margin (ScanAPI.swift): raise all three
    # together.
    timeout_seconds       = 180
    max_instance_count    = 100
    min_instance_count    = 0
    service_account_email = google_service_account.function.email

    environment_variables = {
      NITRO_FIREBASE_PROJECT_ID = google_project.this.project_id
      # Public, not credentials: the app's App Store id is printed on its store
      # page, and a Firebase uid names an account without opening it. Plain
      # environment variables, so Secret Manager holds only real secrets.
      NITRO_PREMIUM_USER_IDS = var.premium_user_ids
      # Admin metrics identifiers — the only real secret of the set, the .p8
      # key, rides the secret_environment_variables block below.
      NITRO_ASC_ISSUER_ID     = var.asc_issuer_id
      NITRO_ASC_KEY_ID        = var.asc_key_id
      NITRO_ASC_VENDOR_NUMBER = var.asc_vendor_number
      NITRO_GCP_BILLING_TABLE = var.gcp_billing_table
      # Push notifications: the key id and its team are identifiers; the .p8
      # rides the secret_environment_variables block below.
      NITRO_APNS_KEY_ID  = var.apns_key_id
      NITRO_APNS_TEAM_ID = var.apns_key_id != "" ? var.apple_team_id : ""
      # The private bucket holding wine attachments (see storage.tf).
      NITRO_ATTACHMENTS_BUCKET = google_storage_bucket.attachments.name
    }

    dynamic "secret_environment_variables" {
      for_each = google_secret_manager_secret.this
      content {
        key        = "NITRO_${replace(upper(secret_environment_variables.key), "-", "_")}"
        project_id = google_project.this.project_id
        secret     = secret_environment_variables.value.secret_id
        version    = "latest"
      }
    }
  }

  depends_on = [
    google_project_iam_member.function_firestore,
    google_storage_bucket_iam_member.function_attachments,
    google_service_account_iam_member.function_token_creator,
    google_project_iam_member.compute_default_builder,
    google_secret_manager_secret_iam_member.function,
  ]
}

# Auth is enforced inside the function itself (server/middleware/auth.ts
# verifies the Firebase ID token), so the underlying Cloud Run service is
# left publicly invokable.
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = google_project.this.project_id
  location = var.region
  service  = google_cloudfunctions2_function.server.name
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_org_policy_policy.allow_public_iam]
}
