# Photos: the covers a scan keeps of a reader's own copy of a book, and the
# pictures readers choose for their avatar.
#
# The bucket is private and stays private. Nothing in it is ever public, and the
# app holds no Storage SDK: the backend writes the photos the app sends it, and
# every read goes through a URL it signed, for one object, for one hour. Who may
# see a cover is a domain rule (a book is its reader's, and a friend sees it
# only on a book the reader shares), and Storage Rules cannot read Firestore —
# so the arbitration has to happen in the function, which is only possible if
# the bucket itself is unreachable.
resource "google_storage_bucket" "attachments" {
  project                     = google_project.this.project_id
  name                        = "${google_project.this.project_id}-attachments"
  location                    = local.bucket_location
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Deleting a photo must stop the meter. The default 7-day soft delete
  # keeps billing for bytes the user believes are gone.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "function_attachments" {
  bucket = google_storage_bucket.attachments.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.function.email}"
}

# Signing a V4 URL needs a private key. Cloud Run has none on disk, so the client
# library falls back to the IAM signBlob API — which requires the runtime service
# account to be able to impersonate itself. Without this binding every signature
# fails in production with "Permission iam.serviceAccounts.signBlob denied",
# while a local run keeps working on developer credentials.
resource "google_service_account_iam_member" "function_token_creator" {
  service_account_id = google_service_account.function.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.function.email}"
}
