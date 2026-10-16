# A read-only account for watching production from outside it: the daily health routine on
# the Mac reads logs, metrics, scheduler state, Firestore and the bill through it, so it never
# depends on a personal gcloud login that expires. Viewer roles only — nothing it holds can
# change the project. Its key is created by hand and kept off the repository and the state
# (~/.config/shiori-observer), since a key made here would sit in plain text in the state.
#
# The bill lives in vinarium-prod (dataset billing_export), which this deploy account cannot
# grant on: reading it was granted by hand, as for the runtime account (see function.tf).
resource "google_service_account" "observer" {
  project      = google_project.this.project_id
  account_id   = "shiori-observer"
  display_name = "Shiori read-only observer"
}

resource "google_project_iam_member" "observer" {
  for_each = toset([
    "roles/logging.viewer",
    "roles/monitoring.viewer",
    "roles/cloudscheduler.viewer",
    "roles/cloudfunctions.viewer",
    "roles/run.viewer",
    "roles/datastore.viewer",
    # Runs the billing query jobs here; the export itself is read under the grant above.
    "roles/bigquery.jobUser",
    "roles/bigquery.dataViewer",
  ])

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.observer.email}"
}
