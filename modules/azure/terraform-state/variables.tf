variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
}

variable "storage_account_name" {
  type        = string
  description = "Name of the storage account (globally unique, lowercase, 3-24 chars)."
}

variable "containers" {
  type        = list(string)
  description = "List of blob container names to create for storing Terraform state."
}

variable "min_tls_version" {
  type        = string
  description = "Minimum TLS version for the storage account."
  default     = "TLS1_2"
}
