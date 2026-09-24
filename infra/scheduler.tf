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

# Keeps every reader's Découvrir tab a day fresh: each hourly run refreshes the
# readers whose tab is oldest until two minutes are spent, so the population is
# spread across the day rather than paid for in one burst. Only readers who
# opened the tab are refreshed. Answers 200 with the counts, like the Audible
# sync, so a retry never re-runs everybody for one reader.
resource "google_cloud_scheduler_job" "refresh_discover" {
  project   = google_project.this.project_id
  region    = var.region
  name      = "refresh-discover"
  schedule  = "15 * * * *"
  time_zone = "Europe/Paris"

  attempt_deadline = "180s"

  retry_config {
    retry_count = 0
  }

  http_target {
    http_method = "POST"
    uri         = "${google_cloudfunctions2_function.server.service_config[0].uri}/admin/refresh-discover"
    headers = {
      Authorization = "Bearer ${local.admin_token_value}"
    }
  }

  depends_on = [google_project_service.apis]
}

# Pushes the translations that came out to the readers who left the alert on,
# once a morning. No model call: the daily refresh already holds the dates, and
# an edition is pushed once, so a retry sends nothing twice.
resource "google_cloud_scheduler_job" "send_release_alerts" {
  project   = google_project.this.project_id
  region    = var.region
  name      = "send-release-alerts"
  schedule  = "0 9 * * *"
  time_zone = "Europe/Paris"

  attempt_deadline = "180s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = "${google_cloudfunctions2_function.server.service_config[0].uri}/admin/send-release-alerts"
    headers = {
      Authorization = "Bearer ${local.admin_token_value}"
    }
  }

  depends_on = [google_project_service.apis]
}
