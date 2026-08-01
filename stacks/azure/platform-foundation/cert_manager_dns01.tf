# Service principal used by cert-manager's ACME DNS-01 solver (Azure DNS)
# to issue Let's Encrypt certificates for the homelab Kubernetes cluster
# (e.g. argocd.home.bitandbyteideas.com). Consumed by a ClusterIssuer in a
# separate Kubernetes repo — no cluster-side resources are defined here.
#
# The DNS zone itself is NOT managed by this repo: it's owned by the
# bit-and-byte-ideas-website repo's own OpenTofu state (see
# deploy/infra/prod/dns_zone.tf there), alongside the Static Web App and its
# custom domain binding for bitandbyteideas.com. We only reference the zone
# via a data source to scope this role assignment — never redefine or import
# it here, and never touch the Static Web App / custom domain resources.

data "azurerm_dns_zone" "bitandbyteideas_com" {
  name                = "bitandbyteideas.com"
  resource_group_name = "rg-bit-and-byte-ideas-website-prod"
}

resource "azuread_application" "cert_manager_dns01" {
  display_name = "cert-manager-dns01-bitandbyteideas-com"
}

resource "azuread_service_principal" "cert_manager_dns01" {
  client_id = azuread_application.cert_manager_dns01.client_id
}

# NOTE — no auto-rotation: cert-manager only *consumes* this secret to
# authenticate DNS-01 TXT record updates; it does not manage the secret's
# lifecycle. This credential will silently stop working ~1 year from apply
# and must be rotated by hand (create a new azuread_application_password,
# update the ClusterIssuer's Kubernetes secret, then remove the old one).
resource "azuread_application_password" "cert_manager_dns01" {
  application_id = azuread_application.cert_manager_dns01.id
  display_name   = "cert-manager dns01 solver"
  # Fixed (not relative-to-apply) so the expiration doesn't drift on every
  # plan. ~1 year out from when this was authored — manual rotation
  # required before this date, see note above.
  end_date = "2027-07-31T00:00:00Z"
}

# Least privilege: scoped to the bitandbyteideas.com zone only (not the
# resource group or subscription), since cert-manager only ever needs to
# create/delete _acme-challenge.* TXT records in this one zone.
resource "azurerm_role_assignment" "cert_manager_dns01_zone_contributor" {
  scope                = data.azurerm_dns_zone.bitandbyteideas_com.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azuread_service_principal.cert_manager_dns01.object_id
}
