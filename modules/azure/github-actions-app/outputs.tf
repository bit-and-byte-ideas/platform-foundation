output "client_id" {
  description = "Application (client) ID used for authentication."
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Object ID of the app registration."
  value       = azuread_application.this.object_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal."
  value       = azuread_service_principal.this.object_id
}
