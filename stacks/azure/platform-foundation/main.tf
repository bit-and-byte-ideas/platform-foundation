locals {
  # App definitions live in apps/*.json — one file per GitHub Actions identity.
  # To register a new repo/environment, add a JSON file; no edits here needed.
  # See apps/bit_and_byte_ideas_prod.json for the expected schema.
  #
  # Schema fields:
  #   display_name          — Azure AD app registration display name
  #   federated_credentials — list of {display_name, subject} OIDC bindings
  #   azure_roles           — true to grant Contributor + Storage Blob Data Contributor
  #   resource_group        — {name, location} to scope Contributor to a pre-created RG,
  #                           or null to use subscription scope (platform_foundation only)
  #   state_container       — blob container name for this app's OpenTofu state
  github_actions_apps = {
    for f in fileset("${path.module}/apps", "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${path.module}/apps/${f}"))
  }

  apps_needing_azure_roles = {
    for k, v in local.github_actions_apps : k => v if v.azure_roles
  }

  apps_with_project_rg = {
    for k, v in local.github_actions_apps : k => v if v.azure_roles && v.resource_group != null
  }

  apps_with_subscription_scope = {
    for k, v in local.github_actions_apps : k => v if v.azure_roles && v.resource_group == null
  }

  state_containers = [
    for k, v in local.github_actions_apps : v.state_container
    if v.state_container != null
  ]
}

module "github_actions_app" {
  for_each = local.github_actions_apps
  source   = "../../../modules/azure/github-actions-app"

  display_name          = each.value.display_name
  federated_credentials = each.value.federated_credentials
}

module "terraform_state" {
  source = "../../../modules/azure/terraform-state"

  resource_group_name  = "rg-terraform-state"
  location             = "westus2"
  storage_account_name = "bitbyteideasinfratfstate"
  containers           = local.state_containers
  min_tls_version      = "TLS1_0"
}

data "azurerm_subscription" "current" {}

# Microsoft Graph — used to grant API permissions to service principals.
data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

# Application.ReadWrite.All — allows the CI workflow to read and manage all
# app registrations in the tenant via the azuread provider.
resource "azuread_app_role_assignment" "platform_foundation_app_rw" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"]
  principal_object_id = module.github_actions_app["platform_foundation"].service_principal_object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Pre-create resource groups for project apps so Contributor can be scoped
# to the RG rather than the entire subscription.
resource "azurerm_resource_group" "project" {
  for_each = local.apps_with_project_rg
  name     = each.value.resource_group.name
  location = each.value.resource_group.location
}

# Contributor scoped to the project's own resource group — limits blast radius
# if a project pipeline is compromised.
resource "azurerm_role_assignment" "rg_contributor" {
  for_each             = local.apps_with_project_rg
  scope                = azurerm_resource_group.project[each.key].id
  role_definition_name = "Contributor"
  principal_id         = module.github_actions_app[each.key].service_principal_object_id
}

# Subscription-level Contributor for platform_foundation only — it manages
# tenant-wide resources so a single RG scope is insufficient.
resource "azurerm_role_assignment" "subscription_contributor" {
  for_each             = local.apps_with_subscription_scope
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = module.github_actions_app[each.key].service_principal_object_id
}

# User Access Administrator for platform_foundation, conditioned to only allow
# assigning Contributor (b24988ac) and Storage Blob Data Contributor (ba92f5b4).
# This prevents the pipeline from escalating its own or other identities beyond
# those two roles even if the workflow or repo is compromised.
resource "azurerm_role_assignment" "platform_foundation_uaa" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "User Access Administrator"
  principal_id         = module.github_actions_app["platform_foundation"].service_principal_object_id
  condition_version    = "2.0"
  condition            = <<-EOT
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      AND !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
    )
    OR
    (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {
        b24988ac-6180-42a0-ab88-20f7382dd24c,
        ba92f5b4-2d11-453d-a403-e96b0029c9fe
      }
    )
  EOT
}

# Storage Blob Data Contributor on the state storage account — allows each
# workflow to upload and download plan files stored in blob storage.
resource "azurerm_role_assignment" "blob_contributor" {
  for_each             = local.apps_needing_azure_roles
  scope                = module.terraform_state.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.github_actions_app[each.key].service_principal_object_id
}
