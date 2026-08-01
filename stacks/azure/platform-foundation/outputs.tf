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

# --- cert-manager ACME DNS-01 solver SP (see cert_manager_dns01.tf) ---
# Consumed by a Kubernetes ClusterIssuer in a separate repo.

output "cert_manager_dns01_client_id" {
  description = "Application (client) ID for the cert-manager dns01 solver SP."
  value       = azuread_application.cert_manager_dns01.client_id
}

output "cert_manager_dns01_client_secret" {
  description = "Client secret for the cert-manager dns01 solver SP. No auto-rotation — see the note in cert_manager_dns01.tf; must be rotated by hand before it expires."
  value       = azuread_application_password.cert_manager_dns01.value
  sensitive   = true
}

output "cert_manager_dns01_tenant_id" {
  description = "Azure AD tenant ID, for the cert-manager ClusterIssuer config."
  value       = data.azurerm_subscription.current.tenant_id
}

output "cert_manager_dns01_subscription_id" {
  description = "Azure subscription ID, for the cert-manager ClusterIssuer config."
  value       = data.azurerm_subscription.current.subscription_id
}

output "cert_manager_dns01_dns_zone_resource_group" {
  description = "Resource group containing the bitandbyteideas.com DNS zone, for the cert-manager ClusterIssuer config."
  value       = azurerm_dns_zone.bitandbyteideas_com.resource_group_name
}
