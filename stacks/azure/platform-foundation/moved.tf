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
