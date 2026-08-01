output "zone_id" {
  description = "Resource ID of the DNS zone — use to scope role assignments to just this zone."
  value       = azurerm_dns_zone.this.id
}

output "zone_name" {
  description = "The zone's domain name."
  value       = azurerm_dns_zone.this.name
}

output "resource_group_name" {
  description = "Resource group the zone lives in."
  value       = azurerm_dns_zone.this.resource_group_name
}

output "name_servers" {
  description = "Azure DNS nameservers for this zone — set these at the registrar to delegate DNS."
  value       = azurerm_dns_zone.this.name_servers
}
