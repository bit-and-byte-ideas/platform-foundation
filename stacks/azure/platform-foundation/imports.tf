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
