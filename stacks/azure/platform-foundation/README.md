# Onboarding an app + domain

This stack is data-driven off two directories:

- **`apps/`** — one file per GitHub Actions identity (app registration,
  federated credentials, Azure role assignments). See the comment block
  above `github_actions_apps` in `main.tf` for the schema.
- **`dns_zones/`** — one file per Azure DNS zone (one apex domain), plus any
  records that aren't specific to a single app — mail routing/auth,
  domain-verification TXT records, etc. A domain's own app repo (e.g. its
  Static Web App's apex/www records) keeps those, referencing the zone via a
  `data "azurerm_dns_zone"` block instead of owning it. See
  `../../../modules/azure/dns-zone/variables.tf` for the full `records`
  schema.

Onboarding a new domain touches **two repos**: this one (owns the zone,
the app's resource group, and its GitHub Actions service principal) and the
app repo (owns the Static Web App and the app-specific DNS records that
point at it). Neither repo is sufficient on its own — the steps below have
to happen roughly in this order.

## 1. Register the app's GitHub Actions identity (this repo)

Add `apps/<name>.json` — see `apps/bit_and_byte_ideas_prod.json` for the
schema, and the comment block above `github_actions_apps` in `main.tf` for
field docs. Two things people miss:

- **OIDC subject prefix.** GitHub uses either `repo:{org}/{repo}:...` or
  `repo:{org}@{orgId}/{repo}@{repoId}:...` depending on when the repo was
  created, and it isn't something this config controls. Confirm it first:
  ```
  gh api repos/<org>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
  ```
  Get this wrong and the federated credential silently never matches —
  the workflow's OIDC login fails with no useful error pointing back here.
- **`static_web_app_custom_domain: true`** if the app binds a custom domain
  to a Static Web App. Without it, `CreateOrUpdateStaticSiteCustomDomain`
  fails with `AuthorizationFailed` on the polling step — see
  [Known pitfalls](#known-pitfalls) below.

## 2. Register the DNS zone (this repo)

Add `dns_zones/<name>.json`. Point `resource_group_name` at the *app's*
resource group (matching `apps/<name>.json`'s `resource_group.name`), not a
shared DNS resource group — that's the convention every existing zone
follows, and the app repo's `data "azurerm_dns_zone"` lookup depends on it.
Start with `"records": []` unless you already know you need MX/TXT records
that aren't app-specific.

## 3. Apply, then wire secrets into the app repo

Merge to `main` here so `tofu-apply.yml` provisions the resource group, the
zone, the app registration + federated credentials, and role assignments.
Then pull the app registration's `client_id` (Azure Portal → App
registrations, or `tofu output` against this stack's state) and set it as a
GitHub Actions **repository variable** in the app repo — this is a manual
step, nothing here pushes it automatically. Match the names the reusable
workflow expects (see `bit-and-byte-ideas/azure-static-webapp-cicd-kit`'s
`opentofu.yml` and any existing `deploy-infra-*.yaml` for the exact list):

| App repo variable | Value |
|---|---|
| `AZURE_CLIENT_ID_PROD` (or `_DEV`) | this app's `client_id` output |
| `AZURE_TENANT_ID` | shared across all apps in the tenant |
| `AZURE_SUBSCRIPTION_ID` | shared across all apps in the subscription |
| `TF_BACKEND_RESOURCE_GROUP` / `_STORAGE_ACCOUNT` | the shared `rg-terraform-state` backend (`modules/azure/terraform-state`) |
| `TF_BACKEND_CONTAINER_PROD` / `_KEY_PROD` | this app's `state_container` from `apps/<name>.json`, and a `.tfstate` key of your choosing |

## 4. Point the app repo at the zone and bind the domain

In the app repo's Tofu config (see `solthoth/ProfileSite`'s
`deploy/infra/prod/{dns_zone,cname,apex}.tf` for a working reference):

- A `data "azurerm_dns_zone"` block, looked up by the same zone name +
  resource group used in step 2.
- A `www` CNAME pointed at the Static Web App's default hostname
  (`cname-delegation` validation — resolves automatically once the CNAME
  exists).
- An apex `azurerm_static_web_app_custom_domain` with
  `validation_type = "dns-txt-token"`, plus an apex ALIAS A record pointed
  at the Static Web App resource.

## 5. The apex TXT-token dance

Apex custom domains use `dns-txt-token` validation, and the token doesn't
exist until Azure generates it — which only happens *after* you've applied
the `azurerm_static_web_app_custom_domain` resource in the app repo once.
That first apply will leave the custom domain stuck in `Validating`. Then:

1. Read the validation token off the Static Web App resource (Azure
   Portal → Static Web App → Custom domains, or
   `az staticwebapp hostname show`).
2. Add it as a `TXT` record at `@` in this repo's `dns_zones/<name>.json`
   (see `pixlhungry_com.json`'s history — `defb00a` — for a real example),
   then merge/apply here.
3. Azure re-validates against the new TXT record within a few minutes and
   the custom domain resource flips to `Ready`.

If it's still stuck in `Validating` after ~30 minutes with no progress, the
custom domain resource itself is wedged — delete and recreate it in the
app repo (this issues a **new** token, invalidating the old TXT value), then
repeat step 2 with the new token (`bdd49b0` is a real instance of this).

## Known pitfalls

- **Missing poller-role actions → `AuthorizationFailed` on
  `CreateOrUpdateStaticSiteCustomDomain`.** The Azure provider polls the
  subscription-scoped `Microsoft.Web/locations/...` endpoints while
  creating/updating a Static Web App custom domain, which falls outside a
  resource-group-scoped `Contributor` assignment. `main.tf` defines a
  custom role (`static_web_app_domain_poller`) for exactly this. This has
  bitten twice: missing `operationResults/read` (commit `183be0f`), then
  missing `staticSitesOperationStatuses/read`. The second one doesn't
  exist in Microsoft.Web's own registered operations catalog at all —
  `az provider operation show --namespace Microsoft.Web` doesn't list it
  under any casing, and `azurerm_role_definition` rejects both the exact
  string *and* a wildcard scoped to that specific pseudo-resource type
  (`.../staticSitesOperationStatuses/*`) with `InvalidActionOrNotAction:
  "does not match any of the actions supported by the providers"`. Azure's
  role-definition validation apparently requires a wildcard's prefix to
  have at least one real match in the catalog; `Microsoft.Web/locations/*`
  does (`operationResults/read`, `operations/read`, `apioperations/read`,
  etc. all live there) and is what's actually granted now — broader than
  ideal, but there's no narrower wildcard Azure will accept, and RBAC
  matches wildcards by string prefix at evaluation time regardless of
  catalog membership. If a future provider version polls yet another
  undocumented endpoint under a *different* top-level resource type, this
  same trick (widen to the nearest ancestor wildcard with catalog matches)
  is the move — confirm with `az provider operation show` before assuming
  the exact string will validate.
- **Registrar NS delegation is out of scope for this repo.** Creating the
  zone here only makes Azure DNS authoritative *if* the domain's registrar
  delegates to it — set the zone's `name_servers` output as NS records at
  wherever the domain is registered. That's a one-time manual step outside
  both repos.
