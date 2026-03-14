locals {
  # Add new GitHub Actions app registrations here.
  # Each key becomes the map key used in import blocks and state paths.
  github_actions_apps = {
    larios_income_tax = {
      display_name          = "larios-income-tax-terraform"
      federated_credentials = []
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
    }
  }

  # State containers: one per project plus this stack's own container.
  state_containers = [
    "lariosincometax",
    "nic-p-barber",
    "platform-foundation",
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

# Contributor at the subscription level — allows the workflow to manage
# all Azure resources declared in this stack.
resource "azurerm_role_assignment" "platform_foundation_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = module.github_actions_app["platform_foundation"].service_principal_object_id
}

# Storage Blob Data Contributor on the state storage account — allows the
# workflow to upload and download plan files stored in blob storage.
resource "azurerm_role_assignment" "platform_foundation_blob" {
  scope                = module.terraform_state.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.github_actions_app["platform_foundation"].service_principal_object_id
}
