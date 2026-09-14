resource "google_identity_platform_config" "this" {
  provider                   = google-beta
  project                    = google_project.this.project_id
  autodelete_anonymous_users = false

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = false
      password_required = false
    }

    anonymous {
      enabled = false
    }
  }

  depends_on = [google_firebase_project.this]
}

# Apple Sign-In, configured as a built-in (default supported) provider.
# The iOS SDK calls OAuthProvider.appleCredential(...) which targets the
# provider id "apple.com", so a custom OIDC config (oidc.apple.com) would
# never be matched and produces "identity provider configuration is not
# found" at runtime.
#
# Identity Platform accepts the Apple key material as a JSON-encoded
# client_secret; it generates the OAuth JWT internally on each sign-in.
resource "google_identity_platform_default_supported_idp_config" "apple" {
  provider  = google-beta
  project   = google_project.this.project_id
  enabled   = true
  idp_id    = "apple.com"
  client_id = var.apple_services_id

  client_secret = jsonencode({
    teamId     = var.apple_team_id
    keyId      = var.apple_key_id
    privateKey = file(var.apple_private_key_path)
  })

  depends_on = [google_identity_platform_config.this]
}
