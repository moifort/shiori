# Refreshes the admin metrics projection (user counts, subscribers, App Store
# revenue, GCP bill) once a day, before anyone in France is awake. The endpoint
# is idempotent and admin-token gated, so the scheduler authenticates exactly
# like the CI migration step does.
resource "google_cloud_scheduler_job" "refresh_admin_metrics" {
  project   = google_project.this.project_id
  region    = var.region
  name      = "refresh-admin-metrics"
  schedule  = "0 6 * * *"
  time_zone = "Europe/Paris"

  # The refresh calls App Store Connect (~30 daily reports) and BigQuery; give
  # it the function's full 180s rather than the scheduler's shorter default.
  attempt_deadline = "180s"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = "${google_cloudfunctions2_function.server.service_config[0].uri}/admin/refresh-metrics"
    headers = {
      Authorization = "Bearer ${local.admin_token_value}"
    }
  }

  depends_on = [google_project_service.apis]
}

# Passes over every reader who left the Audible sync on, once a night: titles
# bought since the last pass are catalogued, and imported books follow the
# listening. Runs before the metrics refresh and well before anyone in France is
# awake, so a reader wakes up to a library already up to date.
#
# The endpoint answers 200 even when a reader's sync failed — the body carries
# the counts — so a retry here means the whole population is read again, not one
# revoked device. It is idempotent: what makes a title new is a purchase date the
# previous run already moved past.
resource "google_cloud_scheduler_job" "sync_audible_libraries" {
  project   = google_project.this.project_id
  region    = var.region
  name      = "sync-audible-libraries"
  schedule  = "0 4 * * *"
  time_zone = "Europe/Paris"

  # The job stops on its own after two minutes of the function's 180s ceiling and
  # leaves the readers it could not reach for the next night, so the deadline is
  # the ceiling rather than the scheduler's shorter default.
  attempt_deadline = "180s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = "${google_cloudfunctions2_function.server.service_config[0].uri}/admin/sync-audible"
    headers = {
      Authorization = "Bearer ${local.admin_token_value}"
    }
  }

  depends_on = [google_project_service.apis]
}
