variable "display_name" {
  type        = string
  description = "Display name of the app registration."
}

variable "sign_in_audience" {
  type        = string
  description = "Sign-in audience for the app registration."
  default     = "AzureADMyOrg"
}

variable "federated_credentials" {
  type = list(object({
    display_name = string
    subject      = string
  }))
  description = "OIDC federated identity credentials for GitHub Actions."
  default     = []
}
