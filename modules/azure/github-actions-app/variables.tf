variable "display_name" {
  type        = string
  description = "Display name of the app registration."
}

variable "sign_in_audience" {
  type        = string
  description = "Sign-in audience for the app registration."
  default     = "AzureADMyOrg"
}
