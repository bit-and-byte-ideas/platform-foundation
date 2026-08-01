# Import blocks for pre-existing Azure resources.
# Run `tofu plan` after `tofu init` to verify no unexpected diffs before applying.

# --- Federated credentials: nic-p-barber-github-actions ---
import {
  id = "875ae979-27b1-4224-b45d-dda7bd974b11/federatedIdentityCredential/55df64d8-04ac-4d02-80f0-57f736b31461"
  to = module.github_actions_app["nic_p_barber"].azuread_application_federated_identity_credential.this["github-main-pull-request"]
}

import {
  id = "875ae979-27b1-4224-b45d-dda7bd974b11/federatedIdentityCredential/9a4a2400-bf3d-40d3-901f-cebae6b5bcd4"
  to = module.github_actions_app["nic_p_barber"].azuread_application_federated_identity_credential.this["github-main"]
}

# --- bitandbyteideas.com DNS zone + non-website records ---
# Migrated from the bit-and-byte-ideas-website repo's state; see
# dns_bitandbyteideas_com.tf and the paired PR there that removes these
# same 7 resources (via `removed` blocks, not destroyed).

import {
  id = "/subscriptions/0d84648f-60b2-4962-9d98-9ba0d9bebeb5/resourceGroups/rg-bit-and-byte-ideas-website-prod/providers/Microsoft.Network/dnsZones/bitandbyteideas.com"
  to = azurerm_dns_zone.bitandbyteideas_com
}

import {
  id = "/subscriptions/0d84648f-60b2-4962-9d98-9ba0d9bebeb5/resourceGroups/rg-bit-and-byte-ideas-website-prod/providers/Microsoft.Network/dnsZones/bitandbyteideas.com/MX/@"
  to = azurerm_dns_mx_record.bitandbyteideas_com_protonmail
}

import {
  id = "/subscriptions/0d84648f-60b2-4962-9d98-9ba0d9bebeb5/resourceGroups/rg-bit-and-byte-ideas-website-prod/providers/Microsoft.Network/dnsZones/bitandbyteideas.com/TXT/@"
  to = azurerm_dns_txt_record.bitandbyteideas_com_apex
}

import {
  id = "/subscriptions/0d84648f-60b2-4962-9d98-9ba0d9bebeb5/resourceGroups/rg-bit-and-byte-ideas-website-prod/providers/Microsoft.Network/dnsZones/bitandbyteideas.com/TXT/_dmarc"
  to = azurerm_dns_txt_record.bitandbyteideas_com_dmarc
}

import {
  id = "/subscriptions/0d84648f-60b2-4962-9d98-9ba0d9bebeb5/resourceGroups/rg-bit-and-byte-ideas-website-prod/providers/Microsoft.Network/dnsZones/bitandbyteideas.com/CNAME/protonmail._domainkey"
  to = azurerm_dns_cname_record.bitandbyteideas_com_protonmail_dkim
}

import {
  id = "/subscriptions/0d84648f-60b2-4962-9d98-9ba0d9bebeb5/resourceGroups/rg-bit-and-byte-ideas-website-prod/providers/Microsoft.Network/dnsZones/bitandbyteideas.com/CNAME/protonmail2._domainkey"
  to = azurerm_dns_cname_record.bitandbyteideas_com_protonmail_dkim2
}

import {
  id = "/subscriptions/0d84648f-60b2-4962-9d98-9ba0d9bebeb5/resourceGroups/rg-bit-and-byte-ideas-website-prod/providers/Microsoft.Network/dnsZones/bitandbyteideas.com/CNAME/protonmail3._domainkey"
  to = azurerm_dns_cname_record.bitandbyteideas_com_protonmail_dkim3
}
