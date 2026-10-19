resource "google_firebase_project" "this" {
  provider = google-beta
  project  = google_project.this.project_id

  depends_on = [google_project_service.apis]
}

resource "google_firestore_database" "default" {
  provider                    = google-beta
  project                     = google_project.this.project_id
  name                        = "(default)"
  location_id                 = var.firestore_location
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"

  # A console click or a stray script cannot delete the database: protection must be
  # turned off first, on purpose.
  delete_protection_state = "DELETE_PROTECTION_ENABLED"

  # Keeps every document version for seven days, readable and restorable to the minute,
  # so a failed migration or a bug that overwrites books can be undone.
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"

  depends_on = [google_firebase_project.this]
}
