locals {
  # Add new GitHub Actions app registrations here.
  # Each key becomes the map key used in import blocks and state paths.
  #
  # azure_roles:     set to true to grant Storage Blob Data Contributor on the
  #                  state storage account and a scoped Contributor assignment.
  # resource_group:  when set, platform-foundation pre-creates this RG and scopes
  #                  Contributor to it (recommended for project-level apps).
  #                  Set to null only for platform_foundation itself, which needs
  #                  subscription-wide Contributor to manage tenant resources.
  github_actions_apps = {
    larios_income_tax = {
      display_name          = "larios-income-tax-terraform"
      federated_credentials = []
      azure_roles           = false
      resource_group        = null
    }
    nic_p_barber = {
      display_name = "nic-p-barber-github-actions"
      federated_credentials = [
        {
          display_name = "github-main-pull-request"
          subject      = "repo:bit-and-byte-ideas/nic-p-the-barber-website:pull_request"
        },
        {
          display_name = "github-main"
          subject      = "repo:bit-and-byte-ideas/nic-p-the-barber-website:ref:refs/heads/main"
        },
      ]
      azure_roles    = false
      resource_group = null
    }
    bit_and_byte_ideas_dev = {
      display_name = "bit-and-byte-ideas-website-dev-github-actions"
      federated_credentials = [
        {
          display_name = "github-dev"
          subject      = "repo:bit-and-byte-ideas/bit-and-byte-ideas-website:environment:dev"
        },
      ]
      azure_roles = true
      resource_group = {
        name     = "rg-bit-and-byte-ideas-website-dev"
        location = "westus2"
      }
    }
    bit_and_byte_ideas_prod = {
      display_name = "bit-and-byte-ideas-website-prod-github-actions"
      federated_credentials = [
        {
          display_name = "github-prod"
          subject      = "repo:bit-and-byte-ideas/bit-and-byte-ideas-website:environment:prod"
        },
      ]
      azure_roles = true
      resource_group = {
        name     = "rg-bit-and-byte-ideas-website-prod"
        location = "westus2"
      }
    }
    platform_foundation = {
      display_name = "platform-foundation-github-actions"
      federated_credentials = [
        {
          display_name = "plan"
          subject      = "repo:bit-and-byte-ideas/platform-foundation:pull_request"
        },
        {
          display_name = "apply"
          subject      = "repo:bit-and-byte-ideas/platform-foundation:ref:refs/heads/main"
        },
      ]
      # null resource_group keeps Contributor at subscription scope — platform_foundation
      # manages tenant-wide resources (app registrations, storage, role assignments)
      # so it legitimately needs broader access than project-level apps.
      azure_roles    = true
      resource_group = null
    }
  }

  apps_needing_azure_roles = {
    for k, v in local.github_actions_apps : k => v if v.azure_roles
  }

  # Apps that get Contributor scoped to a pre-created resource group.
  apps_with_project_rg = {
    for k, v in local.github_actions_apps : k => v if v.azure_roles && v.resource_group != null
  }

  # Apps that need subscription-level Contributor (only platform_foundation).
  apps_with_subscription_scope = {
    for k, v in local.github_actions_apps : k => v if v.azure_roles && v.resource_group == null
  }

  # State containers: one per environment per project, plus this stack's own container.
  state_containers = [
    "lariosincometax",
    "nic-p-barber",
    "platform-foundation",
    "bit-and-byte-ideas-website-dev",
    "bit-and-byte-ideas-website-prod",
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
