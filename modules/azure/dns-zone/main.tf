terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_dns_zone" "this" {
  name                = var.zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_dns_a_record" "this" {
  for_each = { for r in var.records : r.name => r if r.type == "A" }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.values
}

resource "azurerm_dns_cname_record" "this" {
  for_each = { for r in var.records : r.name => r if r.type == "CNAME" }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = each.value.ttl
  record              = each.value.value
}

resource "azurerm_dns_mx_record" "this" {
  for_each = { for r in var.records : r.name => r if r.type == "MX" }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.mx_records
    content {
      preference = record.value.preference
      exchange   = record.value.exchange
    }
  }
}

resource "azurerm_dns_txt_record" "this" {
  for_each = { for r in var.records : r.name => r if r.type == "TXT" }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.values
    content {
      value = record.value
    }
  }
}
