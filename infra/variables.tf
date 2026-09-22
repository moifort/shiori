variable "project_id" {
  description = "Globally unique GCP project id (e.g. shiori-polyforms)"
  type        = string
}

variable "project_name" {
  description = "Human-readable project name shown in the GCP console"
  type        = string
  default     = "Shiori"
}

variable "org_id" {
  description = "GCP organization id (mutually exclusive with folder_id)"
  type        = string
  default     = null
}

variable "folder_id" {
  description = "GCP folder id (mutually exclusive with org_id)"
  type        = string
  default     = null
}

variable "billing_account_id" {
  description = "GCP billing account id (e.g. AAAA-BBBB-CCCC-DDDD)"
  type        = string
}

variable "region" {
  description = "Region for the Cloud Function (Gen 2)"
  type        = string
  default     = "europe-west3"
}

variable "firestore_location" {
  description = "Firestore multi-region or region (e.g. eur3, europe-west3)"
  type        = string
  default     = "eur3"
}

variable "ios_bundle_id" {
  description = "iOS app bundle identifier"
  type        = string
  default     = "com.polyforms.shiori.app"
}

# In-app purchase — public values, not credentials
variable "premium_user_ids" {
  description = "Comma-separated Firebase uids granted Premium without paying (the maker's own, a reviewer's). Not a credential, but a personal identifier, so it is passed in rather than defaulted."
  type        = string
  default     = ""
}

# Apple Sign-In — all required, comes from Apple Developer
variable "apple_team_id" {
  description = "Apple Developer Team ID (10-char alphanum). Blank leaves Sign in with Apple unconfigured."
  type        = string
  default     = ""
}

variable "apple_services_id" {
  description = "Apple Sign-In Services ID (acts as OAuth client_id). Blank leaves Sign in with Apple unconfigured."
  type        = string
  default     = ""
}

variable "apple_key_id" {
  description = "Apple private key ID (10-char alphanum, matches the .p8 filename). Blank leaves Sign in with Apple unconfigured."
  type        = string
  default     = ""
}

variable "apple_private_key_path" {
  description = "Path to the AuthKey_XXXXXXXXXX.p8 file from Apple Developer. Blank leaves Sign in with Apple unconfigured."
  type        = string
  default     = ""
}

# Backend secrets
variable "google_api_key" {
  description = "Google AI API key for the book cover scan (Gemini 2.5 Flash: multimodal extraction, web-grounded enrichment, series cataloguing)"
  type        = string
  sensitive   = true
}

variable "sentry_dsn" {
  description = "Sentry DSN for error reporting and tracing (empty disables Sentry). Exposed to the function as NITRO_SENTRY_DSN, read via runtimeConfig in the Nitro plugin. The plugin also skips Sentry entirely in dev builds, so this only ever takes effect in the deployed function."
  type        = string
  sensitive   = true
  default     = ""
}

variable "admin_token" {
  description = "Bearer token guarding /admin/* routes. Auto-generated if null."
  type        = string
  sensitive   = true
  default     = null
}

# Admin metrics — all optional: any of them blank simply leaves the matching
# figure unavailable in the admin screen, nothing crashes.
variable "asc_issuer_id" {
  description = "App Store Connect API key issuer id, for the sales reports the admin metrics read"
  type        = string
  default     = ""
}

variable "asc_key_id" {
  description = "App Store Connect API key id (matches the .p8 filename)"
  type        = string
  default     = ""
}

variable "asc_private_key_path" {
  description = "Path to the App Store Connect API .p8 private key. Blank disables the revenue figure."
  type        = string
  default     = ""
}

variable "asc_vendor_number" {
  description = "Vendor number the sales reports are filed under (App Store Connect, Payments and Financial Reports)"
  type        = string
  default     = ""
}

variable "gcp_billing_table" {
  description = "Fully qualified BigQuery billing export table (project.dataset.table). Blank disables the measured GCP cost."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to deploy via Workload Identity Federation"
  type        = string
  default     = "moifort/shiori"
}

variable "quota_project_id" {
  description = <<-EOT
    Project the provider attributes API quota to (user_project_override).

    Defaults to the project being created, which is right in steady state and
    impossible on the very first apply: the billing pre-flight calls
    cloudbilling.googleapis.com against a project that does not exist yet and
    comes back USER_PROJECT_DENIED. Point this at an existing project you can
    use for the bootstrap run, then drop it.
  EOT
  type        = string
  default     = ""
}

# Push notifications — optional: blank leaves the release alerts logged, never
# sent. The key is its own Apple key with the APNs service enabled, not the
# Sign in with Apple key; the team is the one `apple_team_id` names.
variable "apns_key_id" {
  description = "Id of the Apple key with the APNs service enabled (matches the .p8 filename)"
  type        = string
  default     = ""
}

variable "apns_private_key_path" {
  description = "Path to the APNs .p8 private key. Blank disables push notifications."
  type        = string
  default     = ""
}
