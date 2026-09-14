output "project_id" {
  value       = google_project.this.project_id
  description = "GCP project id"
}

output "function_url" {
  value       = google_cloudfunctions2_function.server.service_config[0].uri
  description = "HTTPS URL of the Cloud Function (Gen 2)"
}

output "admin_token" {
  value       = local.admin_token_value
  sensitive   = true
  description = "Bearer token for /admin/* routes (used by the post-deploy migration step)"
}

output "ios_app_id" {
  value       = google_firebase_apple_app.ios.app_id
  description = "Firebase iOS app id"
}

output "ios_plist_path" {
  value       = local_file.google_service_info_plist.filename
  description = "Local path of the generated GoogleService-Info.plist"
}

output "tfstate_bucket" {
  value       = google_storage_bucket.tfstate.name
  description = "GCS bucket holding the Terraform state. Referenced by infra/backend.tf."
}

output "deploy_sa_email" {
  value       = google_service_account.deploy.email
  description = "Service account impersonated by the GitHub Actions deploy workflow (GitHub secret GCP_DEPLOY_SA)"
}

output "wif_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full resource name of the WIF provider (GitHub secret GCP_WIF_PROVIDER)"
}


output "attachments_bucket" {
  value       = google_storage_bucket.attachments.name
  description = "Private bucket holding the files attached to wine sheets."
}
