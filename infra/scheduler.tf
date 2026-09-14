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
  # it the function's full 60s rather than the scheduler's shorter default.
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
