terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

resource "azuread_application" "this" {
  display_name     = var.display_name
  sign_in_audience = var.sign_in_audience
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
}
