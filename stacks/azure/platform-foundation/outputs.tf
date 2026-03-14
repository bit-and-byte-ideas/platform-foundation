output "github_actions_app_client_ids" {
  description = "Client IDs for all GitHub Actions app registrations, keyed by logical name."
  value       = { for k, v in module.github_actions_app : k => v.client_id }
}

output "github_actions_app_service_principal_object_ids" {
  description = "Service principal object IDs for all GitHub Actions app registrations."
  value       = { for k, v in module.github_actions_app : k => v.service_principal_object_id }
}

output "state_storage_account_name" {
  description = "Name of the Terraform state storage account."
  value       = module.terraform_state.storage_account_name
}

output "state_containers" {
  description = "Blob containers available for Terraform state storage."
  value       = module.terraform_state.container_names
}
