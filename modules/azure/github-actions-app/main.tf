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

resource "azuread_application_federated_identity_credential" "this" {
  for_each = { for fc in var.federated_credentials : fc.display_name => fc }

  application_id = azuread_application.this.id
  display_name   = each.value.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value.subject
}
