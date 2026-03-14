locals {
  # Add new GitHub Actions app registrations here.
  # Each key becomes the map key used in import blocks and state paths.
  github_actions_apps = {
    larios_income_tax = {
      display_name = "larios-income-tax-terraform"
    }
    nic_p_barber = {
      display_name = "nic-p-barber-github-actions"
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

  display_name = each.value.display_name
}

module "terraform_state" {
  source = "../../../modules/azure/terraform-state"

  resource_group_name  = "rg-terraform-state"
  location             = "westus2"
  storage_account_name = "bitbyteideasinfratfstate"
  containers           = local.state_containers
  min_tls_version      = "TLS1_0"
}
