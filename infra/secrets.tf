resource "random_password" "admin_token" {
  count   = var.admin_token == null ? 1 : 0
  length  = 48
  special = false
}

# The key the Audible device credentials are sealed with before they reach
# Firestore. Generated once and kept in state: rotating it makes every stored
# connection unreadable, so readers would have to reconnect their account.
#
# `random_bytes` rather than `random_id`, and the difference is not cosmetic.
# Terraform prints the id of every resource it creates, and `random_id` makes the
# random material itself its id — so the first apply wrote this key, in full, into
# a build log of a public repository. `random_bytes` marks `base64` and `hex`
# sensitive and keeps the value out of its id, so nothing of it reaches a log.
resource "random_bytes" "audible_key" {
  length = 32
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
    audible-key     = random_bytes.audible_key.base64
  }

  # Secret Manager rejects empty payloads, so we drive iteration off a
  # non-sensitive set of secret IDs and skip optional ones (sentry-dsn,
  # asc-private-key) when their value is empty. Iterating a map of sensitive
  # values would propagate sensitivity into for_each keys, which Terraform
  # forbids — hence nonsensitive().
  secret_ids = toset(compact([
    "google-api-key",
    "admin-token",
    "audible-key",
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
