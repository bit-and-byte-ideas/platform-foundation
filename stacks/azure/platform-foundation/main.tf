locals {
  # App definitions live in apps/*.json — one file per GitHub Actions identity.
  # To register a new repo/environment, add a JSON file; no edits here needed.
  # See apps/bit_and_byte_ideas_prod.json for the expected schema.
  #
  # IMPORTANT — federated_credentials.subject prefix:
  # GitHub is rolling out immutable-ID-based OIDC subject claims
  # (repo:{org}@{orgId}/{repo}@{repoId}:...) as the default for newly created
  # repos, while older repos keep the legacy name-based format
  # (repo:{org}/{repo}:...). The prefix is decided by GitHub per-repo at
  # creation time and isn't controlled by this config. Before adding a new
  # app JSON, confirm the actual prefix for that repo with:
  #   gh api repos/<org>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
  # and use that value as the prefix for every subject in the file — do not
  # assume the plain "repo:{org}/{repo}" form.
  #
  # Schema fields:
  #   display_name          — Azure AD app registration display name
  #   federated_credentials — list of {display_name, subject} OIDC bindings
  #   azure_roles                   — true to grant Contributor + Storage Blob Data Contributor
  #   resource_group                — {name, location} to scope Contributor to a pre-created RG,
  #                                   or null to use subscription scope (platform_foundation only)
  #   state_container               — blob container name for this app's OpenTofu state
  #   static_web_app_custom_domain  — true to grant subscription-level permission to poll
  #                                   async operation results for Static Web App custom domains
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

  apps_with_static_web_app_custom_domain = {
    for k, v in local.github_actions_apps : k => v
    if lookup(v, "static_web_app_custom_domain", false) == true
  }

  # Pre-generated UUID so the UAA condition can reference it before first apply.
  static_web_app_domain_poller_role_id = "382f5a3a-4ed5-4215-a07f-a5729002e785"

  # Built-in "DNS Zone Contributor" role ID — needed in the UAA condition
  # allow-list below so the pipeline can grant it to the cert-manager
  # dns01 solver SP (see cert_manager_dns01.tf).
  dns_zone_contributor_role_id = "befefa01-2a29-4197-83a8-272ff33ce314"

  state_containers = [
    for k, v in local.github_actions_apps : v.state_container
    if v.state_container != null
  ]

  # DNS zone definitions live in dns_zones/*.json — one file per domain.
  # To manage a new domain's zone here, add a JSON file; no edits here
  # needed. See dns_zones/bitandbyteideas_com.json for the expected schema
  # (and modules/azure/dns-zone/variables.tf for the full `records` shape).
  #
  # Only records that aren't specific to any one app belong here (mail
  # routing/auth, domain verification, etc.) — a domain's own app repo
  # (e.g. its Static Web App's apex/www records) keeps those, referencing
  # the zone via a `data "azurerm_dns_zone"` block instead of owning it.
  dns_zones = {
    for f in fileset("${path.module}/dns_zones", "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${path.module}/dns_zones/${f}"))
  }
}

module "github_actions_app" {
  for_each = local.github_actions_apps
  source   = "../../../modules/azure/github-actions-app"

  display_name          = each.value.display_name
  federated_credentials = each.value.federated_credentials
}

module "dns_zone" {
  for_each = local.dns_zones
  source   = "../../../modules/azure/dns-zone"

  zone_name            = each.value.zone_name
  resource_group_name  = each.value.resource_group_name
  tags                 = each.value.tags
  records              = each.value.records
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

# Custom role that grants only the permission needed to poll async operation
# results when creating/updating Static Web App custom domains. The Azure
# provider hits Microsoft.Web/locations/operationResults at the subscription
# scope during the long-poll, which falls outside a resource-group-scoped
# Contributor assignment.
resource "azurerm_role_definition" "static_web_app_domain_poller" {
  name        = local.static_web_app_domain_poller_role_id
  scope       = data.azurerm_subscription.current.id
  description = "Allows polling async operation results for Static Web App custom domain provisioning."

  permissions {
    actions = [
      "Microsoft.Web/locations/operationResults/read",
      "Microsoft.Web/locations/operations/read",
    ]
  }

  assignable_scopes = [data.azurerm_subscription.current.id]
}

resource "azurerm_role_assignment" "static_web_app_domain_poller" {
  for_each           = local.apps_with_static_web_app_custom_domain
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.static_web_app_domain_poller.role_definition_resource_id
  principal_id       = module.github_actions_app[each.key].service_principal_object_id
}

# User Access Administrator for platform_foundation, conditioned to only allow
# assigning Contributor (b24988ac), Storage Blob Data Contributor (ba92f5b4),
# the custom Static Web App Domain Poller role (382f5a3a), and DNS Zone
# Contributor (befefa01).
# This prevents the pipeline from escalating its own or other identities beyond
# those roles even if the workflow or repo is compromised.
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
        ba92f5b4-2d11-453d-a403-e96b0029c9fe,
        ${local.static_web_app_domain_poller_role_id},
        ${local.dns_zone_contributor_role_id}
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
