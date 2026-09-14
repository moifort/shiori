resource "google_firebase_apple_app" "ios" {
  provider     = google-beta
  project      = google_project.this.project_id
  display_name = "Shiori iOS"
  bundle_id    = var.ios_bundle_id
  team_id      = var.apple_team_id

  depends_on = [google_firebase_project.this]
}

data "google_firebase_apple_app_config" "ios" {
  provider = google-beta
  project  = google_project.this.project_id
  app_id   = google_firebase_apple_app.ios.app_id
}

resource "local_file" "google_service_info_plist" {
  filename        = "${path.root}/../ios/Shiori/GoogleService-Info.plist"
  content_base64  = data.google_firebase_apple_app_config.ios.config_file_contents
  file_permission = "0644"
}
