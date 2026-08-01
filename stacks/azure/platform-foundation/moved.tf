# Tracks resource renames so OpenTofu migrates state without destroy/recreate.
# These blocks can be removed once all team members have run `tofu apply`.

moved {
  from = azurerm_role_assignment.platform_foundation_contributor
  to   = azurerm_role_assignment.subscription_contributor["platform_foundation"]
}

moved {
  from = azurerm_role_assignment.platform_foundation_blob
  to   = azurerm_role_assignment.blob_contributor["platform_foundation"]
}

# --- bitandbyteideas.com DNS zone + records: flat resources -> dns-zone module ---
# Same 7 resources adopted from bit-and-byte-ideas-website in a prior PR;
# this just moves them into the reusable module now used for all domains.

moved {
  from = azurerm_dns_zone.bitandbyteideas_com
  to   = module.dns_zone["bitandbyteideas_com"].azurerm_dns_zone.this
}

moved {
  from = azurerm_dns_mx_record.bitandbyteideas_com_protonmail
  to   = module.dns_zone["bitandbyteideas_com"].azurerm_dns_mx_record.this["@"]
}

moved {
  from = azurerm_dns_txt_record.bitandbyteideas_com_apex
  to   = module.dns_zone["bitandbyteideas_com"].azurerm_dns_txt_record.this["@"]
}

moved {
  from = azurerm_dns_txt_record.bitandbyteideas_com_dmarc
  to   = module.dns_zone["bitandbyteideas_com"].azurerm_dns_txt_record.this["_dmarc"]
}

moved {
  from = azurerm_dns_cname_record.bitandbyteideas_com_protonmail_dkim
  to   = module.dns_zone["bitandbyteideas_com"].azurerm_dns_cname_record.this["protonmail._domainkey"]
}

moved {
  from = azurerm_dns_cname_record.bitandbyteideas_com_protonmail_dkim2
  to   = module.dns_zone["bitandbyteideas_com"].azurerm_dns_cname_record.this["protonmail2._domainkey"]
}

moved {
  from = azurerm_dns_cname_record.bitandbyteideas_com_protonmail_dkim3
  to   = module.dns_zone["bitandbyteideas_com"].azurerm_dns_cname_record.this["protonmail3._domainkey"]
}
