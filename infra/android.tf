# The Android app: registered with Firebase so it signs in, reports analytics and receives the
# release alerts through FCM. Its config file is written next to the Gradle module, as the iOS
# plist is written next to the Xcode project; it stays out of git and CI writes it from a secret.
resource "google_firebase_android_app" "android" {
  provider      = google-beta
  project       = google_project.this.project_id
  display_name  = "Shiori Android"
  package_name  = var.android_package_name
  sha256_hashes = var.android_cert_sha256

  depends_on = [google_firebase_project.this]
}

data "google_firebase_android_app_config" "android" {
  provider = google-beta
  project  = google_project.this.project_id
  app_id   = google_firebase_android_app.android.app_id
}

resource "local_file" "google_services_json" {
  filename        = "${path.root}/../android/app/google-services.json"
  content_base64  = data.google_firebase_android_app_config.android.config_file_contents
  file_permission = "0644"
}

# Sign in with Google: the Android app's only way in. The web OAuth client is the one Credential
# Manager asks an ID token for; Identity Platform checks the token against it.
locals {
  google_sign_in_configured = var.google_oauth_client_id != "" && var.google_oauth_client_secret != ""
}

resource "google_identity_platform_default_supported_idp_config" "google" {
  count = local.google_sign_in_configured ? 1 : 0

  provider      = google-beta
  project       = google_project.this.project_id
  enabled       = true
  idp_id        = "google.com"
  client_id     = var.google_oauth_client_id
  client_secret = var.google_oauth_client_secret

  depends_on = [google_identity_platform_config.this]
}
