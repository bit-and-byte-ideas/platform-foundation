terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # Bootstrap: before running `tofu init`, create the container manually:
  #   az storage container create \
  #     --name platform-foundation \
  #     --account-name bitbyteideasinfratfstate \
  #     --auth-mode login
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "bitbyteideasinfratfstate"
    container_name       = "platform-foundation"
    key                  = "platform-foundation.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "0d84648f-60b2-4962-9d98-9ba0d9bebeb5"
  features {}
}

provider "azuread" {
  tenant_id = "e0c906a3-b766-47db-afcc-c7f76a5cea7a"
}
