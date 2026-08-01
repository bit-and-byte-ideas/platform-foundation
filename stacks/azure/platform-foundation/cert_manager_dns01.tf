# Service principal used by cert-manager's ACME DNS-01 solver (Azure DNS)
# to issue Let's Encrypt certificates for the homelab Kubernetes cluster
# (e.g. argocd.home.bitandbyteideas.com). Consumed by a ClusterIssuer in a
# separate Kubernetes repo — no cluster-side resources are defined here.
#
# The DNS zone itself is managed in dns_bitandbyteideas_com.tf — this role
# assignment just scopes to it. Never touch the Static Web App / custom
# domain resources, which remain owned by the bit-and-byte-ideas-website repo.

resource "azuread_application" "cert_manager_dns01" {
  display_name = "cert-manager-dns01-bitandbyteideas-com"
}

resource "azuread_service_principal" "cert_manager_dns01" {
  client_id = azuread_application.cert_manager_dns01.client_id
}

# NOTE — no auto-rotation: cert-manager only *consumes* this secret to
# authenticate DNS-01 TXT record updates; it does not manage the secret's
# lifecycle. This credential will silently stop working ~1 year from the
# last rotation and must be rotated by hand.
#
# To rotate (routine expiry, OR immediately if the value ever leaks):
#   1. Bump the date in `display_name` below and push `end_date` out
#      (every argument on this resource is ForceNew, so any change here
#      is enough to trigger a fresh secret — the date is just so it's
#      self-documenting in the Azure portal and in `tofu plan`).
#   2. Open a PR, let CI plan it, get the `prod` environment apply approved.
#   3. `tofu output -raw cert_manager_dns01_client_secret` to get the new
#      value, update the ClusterIssuer's Kubernetes secret with it.
#   4. Nothing further to do — create_before_destroy below means the old
#      secret is only destroyed after the new one exists, and the same
#      apply that creates the new secret is what destroys the old one.
#
# If a secret leaks, don't wait for the PR to merge before containing it:
# revoke it immediately (`az ad app credential delete --id <app id>
# --key-id <key id>`, from `az ad app credential list --id <app id>`),
# then do steps 1-3 to reissue. The next `tofu plan` after an out-of-band
# revoke just shows the resource being (re)created, since OpenTofu finds
# nothing left to destroy — the rotation PR is what closes the loop.
resource "azuread_application_password" "cert_manager_dns01" {
  application_id = azuread_application.cert_manager_dns01.id
  display_name   = "cert-manager dns01 solver (rotated 2026-07-31)"
  end_date       = "2027-07-31T00:00:00Z"

  lifecycle {
    create_before_destroy = true
  }
}

# Least privilege: scoped to the bitandbyteideas.com zone only (not the
# resource group or subscription), since cert-manager only ever needs to
# create/delete _acme-challenge.* TXT records in this one zone.
resource "azurerm_role_assignment" "cert_manager_dns01_zone_contributor" {
  scope                = azurerm_dns_zone.bitandbyteideas_com.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azuread_service_principal.cert_manager_dns01.object_id
}
