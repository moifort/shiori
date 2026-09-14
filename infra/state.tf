resource "google_storage_bucket" "tfstate" {
  project                     = google_project.this.project_id
  name                        = "${google_project.this.project_id}-tfstate"
  location                    = local.bucket_location
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.apis]
}
