# The bitandbyteideas.com DNS zone and its non-website records — mail
# routing/auth and domain verification, none of it specific to any one
# app's deploy pipeline. Migrated here (see imports.tf) from the
# bit-and-byte-ideas-website repo, which now references this zone via a
# data source and keeps only the records tied to its own Static Web App
# (apex A record, www CNAME).
#
# The zone stays in rg-bit-and-byte-ideas-website-prod — moving it to a
# dedicated resource group would change its resource ID and invalidate the
# cert-manager DNS Zone Contributor role assignment (cert_manager_dns01.tf).

resource "azurerm_dns_zone" "bitandbyteideas_com" {
  name                = "bitandbyteideas.com"
  resource_group_name = "rg-bit-and-byte-ideas-website-prod"

  tags = {
    owner       = "bit-and-byte-ideas"
    environment = "prod"
    managed_by  = "opentofu"
    source      = "github.com/bit-and-byte-ideas/platform-foundation"
  }
}

resource "azurerm_dns_mx_record" "bitandbyteideas_com_protonmail" {
  name                = "@"
  zone_name           = azurerm_dns_zone.bitandbyteideas_com.name
  resource_group_name = azurerm_dns_zone.bitandbyteideas_com.resource_group_name
  ttl                 = 300

  record {
    preference = 10
    exchange   = "mail.protonmail.ch."
  }
  record {
    preference = 20
    exchange   = "mailsec.protonmail.ch."
  }
}

# Domain verification (Atlassian, Protonmail) + SPF. Azure DNS only allows
# one record set per name/type, so these must stay in a single resource —
# same reason the website repo originally bundled them with the SWA
# validation token before both custom domains finished validating.
resource "azurerm_dns_txt_record" "bitandbyteideas_com_apex" {
  name                = "@"
  zone_name           = azurerm_dns_zone.bitandbyteideas_com.name
  resource_group_name = azurerm_dns_zone.bitandbyteideas_com.resource_group_name
  ttl                 = 300

  record {
    value = "atlassian-domain-verification=tbGo0150p21lA6kaANcW2PauHlwaPSqB5a6GiahGN7W4vA9o3FzyKzMOfdiRenLS"
  }
  record {
    value = "protonmail-verification=7bfc9f22578142f18755e7f44fc7974535152c2c"
  }
  record {
    value = "v=spf1 include:_spf.protonmail.ch ~all"
  }
}

resource "azurerm_dns_txt_record" "bitandbyteideas_com_dmarc" {
  name                = "_dmarc"
  zone_name           = azurerm_dns_zone.bitandbyteideas_com.name
  resource_group_name = azurerm_dns_zone.bitandbyteideas_com.resource_group_name
  ttl                 = 300

  record {
    value = "v=DMARC1; p=quarantine"
  }
}

resource "azurerm_dns_cname_record" "bitandbyteideas_com_protonmail_dkim" {
  name                = "protonmail._domainkey"
  zone_name           = azurerm_dns_zone.bitandbyteideas_com.name
  resource_group_name = azurerm_dns_zone.bitandbyteideas_com.resource_group_name
  ttl                 = 300
  record              = "protonmail.domainkey.dgeesy544louti5wx6ruah54qtjo4cq5rjlt25frofn464zeldgdq.domains.proton.ch."
}

resource "azurerm_dns_cname_record" "bitandbyteideas_com_protonmail_dkim2" {
  name                = "protonmail2._domainkey"
  zone_name           = azurerm_dns_zone.bitandbyteideas_com.name
  resource_group_name = azurerm_dns_zone.bitandbyteideas_com.resource_group_name
  ttl                 = 300
  record              = "protonmail2.domainkey.dgeesy544louti5wx6ruah54qtjo4cq5rjlt25frofn464zeldgdq.domains.proton.ch."
}

resource "azurerm_dns_cname_record" "bitandbyteideas_com_protonmail_dkim3" {
  name                = "protonmail3._domainkey"
  zone_name           = azurerm_dns_zone.bitandbyteideas_com.name
  resource_group_name = azurerm_dns_zone.bitandbyteideas_com.resource_group_name
  ttl                 = 300
  record              = "protonmail3.domainkey.dgeesy544louti5wx6ruah54qtjo4cq5rjlt25frofn464zeldgdq.domains.proton.ch."
}
