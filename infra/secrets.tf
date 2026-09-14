resource "random_password" "admin_token" {
  count   = var.admin_token == null ? 1 : 0
  length  = 48
  special = false
}

locals {
  admin_token_value = var.admin_token != null ? var.admin_token : random_password.admin_token[0].result

  # The App Store Connect API key, read from disk like the Apple Sign-In key.
  asc_private_key_value = var.asc_private_key_path != "" ? file(var.asc_private_key_path) : ""

  secret_values = {
    google-api-key  = var.google_api_key
    admin-token     = local.admin_token_value
    sentry-dsn      = var.sentry_dsn
    asc-private-key = local.asc_private_key_value
  }

  # Secret Manager rejects empty payloads, so we drive iteration off a
  # non-sensitive set of secret IDs and skip optional ones (sentry-dsn,
  # asc-private-key) when their value is empty. Iterating a map of sensitive
  # values would propagate sensitivity into for_each keys, which Terraform
  # forbids — hence nonsensitive().
  secret_ids = toset(compact([
    "google-api-key",
    "admin-token",
    nonsensitive(var.sentry_dsn) != "" ? "sentry-dsn" : "",
    local.asc_private_key_value != "" ? "asc-private-key" : "",
  ]))
}

resource "google_secret_manager_secret" "this" {
  for_each  = local.secret_ids
  project   = google_project.this.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "this" {
  for_each    = local.secret_ids
  secret      = google_secret_manager_secret.this[each.value].id
  secret_data = local.secret_values[each.value]
}
